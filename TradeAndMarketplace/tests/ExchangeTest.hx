import trade.TradeExchange;
import trade.TradeSession;
import trade.TradeInventory;
import trade.TradeTypes;
class ExchangeTest {
    static var checks = 0;
    static function check(value:Bool,message:String):Void { checks++; if (!value) throw message; }
    static function item(uid:String,count:Int = 1):TradeItem return {uid:uid,kind:"Copper",count:count,name:"Copper",detail:"",color:0,fingerprint:"fp",preview:null};
    static function session(leader = true):TradeSession {
        var s = new TradeSession("alice"); s.id = "test"; s.peer = "bob"; s.phase = "exchanging"; s.leader = leader; s.deadline = 10; return s;
    }
    static function main() {
        var s = session(), inv = new TradeInventory(); s.mine = [item("own",2)];
        inv.stack = {index:0,item:{fingerprint:"fp"},count:5}; inv.counts["fp"] = 5;
        var e = new TradeExchange(s,inv,()->""); e.update(0); check(inv.requests == 1,"Issue one drop request");
        inv.reply(true); e.update(1); e.update(2); check(inv.requests == 1 && s.outbox.length == 0,"Callback alone must not confirm or retry drop");
        inv.stack.count = 3; inv.ground = [{__uid:"drop",count:2,item:{__uid:"clone",fingerprint:"fp"}}];
        e.update(2.1); check(s.outbox[0].op == "drop" && s.outbox[0].drop == "drop","Confirm cloned partial stack from inventory and new ground object");
        check(inv.requests == 1,"Confirmed partial drop is never repeated");
        var follower = session(false), fi = new TradeInventory(); follower.mine = [item("own")]; follower.theirs = [item("peer")];
        fi.stack = {index:0,item:{fingerprint:"fp"},count:1}; var fe = new TradeExchange(follower,fi,()->"");
        fe.update(0); check(fi.requests == 0,"Follower waits for all initiator drops");
        fe.announced({key:follower.key(),item:"peer",drop:"remote"},1); var deadline = follower.deadline;
        fe.announced({key:follower.key(),item:"peer",drop:"remote"},2); check(follower.deadline == deadline,"Duplicate announcements do not extend deadline");
        fe.update(2); check(fi.requests == 1,"Follower may now drop"); fi.reply(false); check(follower.phase == "cancelled","Rejected drop cancels");
        var receiver = session(), ri = new TradeInventory(); receiver.theirs = [item("peer")]; var re = new TradeExchange(receiver,ri,()->"");
        var pickup:Bool->Void = null; var target:Dynamic = {__uid:"remote",count:1,item:{__uid:"clone",fingerprint:"fp"},distance:8.0};
        target.getInteractRange = ()->5.0; target.canInteract = (_:Dynamic)->true; target.allowedToLoot = (_:Dynamic)->true;
        target.canRequestInteraction = (_:Dynamic)-> { check(TradeExchange.authorizesPickup(target),"Bypass limited to native validation call"); return true; };
        target.requestInteraction = function(_:Dynamic,reply:Bool->Void) { check(TradeExchange.authorizesPickup(target),"Bypass limited to native request call"); pickup = reply; };
        ri.ground = [target]; re.announced({key:receiver.key(),item:"peer",drop:"remote"},0); re.update(0);
        check(re.collectionTarget == target && pickup == null,"Out-of-range item becomes movement target without pickup");
        target.distance = 1; re.update(1); check(!TradeExchange.authorizesPickup(target),"Pickup bypass cleared immediately");
        pickup(true); re.update(2); check(!receiver.received,"Successful pickup callback still waits for replicated inventory");
        ri.counts["fp"] = 1; re.update(3); check(receiver.received,"Replicated receipt confirms delivery");
        var bad = session(), bi = new TradeInventory(); bad.theirs = [item("peer")]; var be = new TradeExchange(bad,bi,()->"");
        bi.ground = [{__uid:"remote",count:1,item:{fingerprint:"wrong"}}]; be.announced({key:bad.key(),item:"peer",drop:"remote"},0); be.update(0);
        check(bad.phase == "cancelled","Mismatched ground item cancels before pickup");
        var stalled = session(), si = new TradeInventory(); stalled.mine = [item("own")]; si.stack = {index:0,item:{fingerprint:"fp"},count:1};
        var se = new TradeExchange(stalled,si,()->""); se.update(0); se.update(5);
        check(stalled.phase == "exchanging", "Unconfirmed drop survives the old five-second limit"); se.update(10);
        check(stalled.phase == "cancelled" && si.requests == 1,"Unconfirmed drop times out without retry");
        var stale = session(), sti = new TradeInventory(); stale.mine = [item("own")]; sti.stack = {index:0,item:{fingerprint:"fp"},count:1};
        var ste = new TradeExchange(stale,sti,()->""); ste.update(0); stale.id = "replacement"; sti.reply(false);
        check(stale.phase == "exchanging","Late callback cannot cancel a replacement session");
        var locked = session(), li = new TradeInventory(); locked.mine = [item("own")];
        li.stack = {index:0,item:{fingerprint:"fp"},count:1}; li.dropAllowed = false;
        var le = new TradeExchange(locked,li,()->""); le.update(0);
        check(locked.phase == "cancelled" && li.requests == 0,"Lock added after acceptance prevents any drop request");
        var fast = session(), qi = new TradeInventory(); fast.theirs = [item("first"),item("second")];
        var qe = new TradeExchange(fast,qi,()->""), picked:Array<String> = [];
        qi.ground = [for (id in ["first","second"]) {
            __uid:id,count:1,item:{fingerprint:"fp"},distance:1.0,
            getInteractRange:()->5.0,canInteract:(_:Dynamic)->true,allowedToLoot:(_:Dynamic)->true,
            canRequestInteraction:(_:Dynamic)->true,
            requestInteraction:(_:Dynamic,reply:Bool->Void)->{picked.push(id); reply(true);}
        }];
        for (id in ["first","second"]) qe.announced({key:fast.key(),item:id,drop:id},0);
        qe.update(0); qe.update(0.06);
        check(picked.length == 2,"Confirmed pickups have no artificial half-second pause");
        check(!fast.received,"Faster pickup still requires inventory replication");
        Sys.println("Exchange safety checks passed: "+checks);
    }
}
