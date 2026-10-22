import trade.TradeSession;
import trade.TradeWire;
import trade.TradeOffer;
import trade.TradePreview;
import trade.TradeTypes;
class ProtocolTest {
    static var checks = 0;
    static function check(value:Bool,message:String):Void { checks++; if (!value) throw message; }
    static function deliver(from:TradeSession,to:TradeSession,now:Float):Void {
        var messages = from.outbox.copy(); from.outbox = []; for (p in messages) to.receive(from.self,p,now);
    }
    static function main() {
        var a = new TradeSession("alice"), b = new TradeSession("bob"); a.start("bob","session",0); deliver(a,b,0);
        check(b.phase == "invited" && !a.editable() && !b.editable(),"Invitation locks offers");
        b.join(1); deliver(b,a,1); deliver(a,b,1); deliver(b,a,1);
        var item:TradeItem = {uid:"1",kind:"Copper",count:1,name:"Copper",detail:"",color:0,fingerprint:"fp",preview:null};
        a.setOffer([item],2); deliver(a,b,2); deliver(b,a,2);
        check(a.canAccept() && b.canAccept(),"One-sided gift supported after synchronization");
        a.accept(3); deliver(a,b,3); b.setOffer([item],4); deliver(b,a,4); deliver(a,b,4);
        check(!a.accepted && !a.peerAccepted && !b.accepted && !b.peerAccepted,"Offer edit resets both acceptances");
        a.accept(5); deliver(a,b,5); b.accept(5); deliver(b,a,5); deliver(a,b,5); deliver(b,a,5); deliver(a,b,5);
        check(a.phase == "exchanging" && b.phase == "exchanging","Both sides complete prepare/commit handshake");
        check(!a.cancelByUser() && !b.cancelByUser(),"User cannot cancel committed exchange");
        a.gotItems(); deliver(a,b,6); b.gotItems(); deliver(b,a,6); check(a.phase == "complete" && b.phase == "complete","Both receipts required");
        var wire = new TradeWire("ABC"), packet:Dynamic = {id:"id",to:"bob",op:"offer",items:[item],padding:[for(_ in 0...1000) "é"].join("")};
        var parts = wire.encode(packet); check(parts.length > 1,"Unicode payload fragments"); parts.reverse(); var result:Dynamic = null;
        for (p in parts) { var next = wire.receive("alice",p,0); if (next != null) result = next; }
        check(result != null && result.padding == packet.padding,"Reordered fragments reconstruct UTF-8");
        check(wire.receive("alice","!winktrade1:X:99:2:AAAA",0) == null,"Reject invalid fragment indices");
        check(wire.receive("alice","!winktrade1:X:0:97:AAAA",0) == null,"Reject oversized fragment counts");
        check(!TradeOffer.valid([item,item]),"Reject duplicate offered UIDs");
        check(!TradePreview.valid({flags:0,level:0,upgrade:0,rarity:"",infusion:"",bonus:"",mastery:"",slots:[],effects:[{skill:"x",source:"untrusted"}]}),"Reject unknown effect sources");
        var timed = new TradeSession("timer"); timed.id = "t"; timed.peer = "peer"; timed.phase = "exchanging";
        timed.progress(100); check(timed.deadline == 110,"Progress grants ten seconds");
        timed.tick(105); check(timed.active(),"Exchange survives old five-second deadline");
        timed.tick(109.99); check(timed.active(),"Exchange survives until ten-second deadline");
        timed.tick(110); check(timed.phase == "cancelled" && timed.error.indexOf("10 seconds") >= 0,"Exchange stops after ten seconds without progress");
        var prep = new TradeSession("alice"); prep.id = "p"; prep.peer = "bob"; prep.phase = "offering";
        prep.leader = true; prep.mine = [item]; prep.ack = prep.revision; prep.peerRevision = 0; prep.peerAccepted = true;
        prep.accept(0); check(prep.phase == "preparing" && prep.deadline == 10,"Prepare handshake also allows ten seconds");
        var legacy=new TradeSession("alice"),oldPeer=new TradeSession("bob");
        legacy.start("bob","legacy",0);deliver(legacy,oldPeer,0);
        legacy.tick(1);legacy.tick(10);
        check(legacy.phase=="inviting"&&!legacy.requestReceived&&legacy.error=="","Older peers do not need to acknowledge receipt");
        oldPeer.join(10);deliver(oldPeer,legacy,10);deliver(legacy,oldPeer,10);deliver(oldPeer,legacy,10);
        legacy.setOffer([item],11);deliver(legacy,oldPeer,11);deliver(oldPeer,legacy,11);
        check(legacy.canAccept()&&oldPeer.canAccept(),"A delayed join without a receipt still synchronizes offers");
        var receipt=new TradeSession("alice");receipt.start("bob","receipt",0);
        receipt.receive("outsider",{id:"receipt",to:"alice",op:"received"},1);
        receipt.receive("bob",{id:"old-request",to:"alice",op:"received"},1);
        receipt.receive("bob",{id:"receipt",to:"someone-else",op:"received"},1);
        check(!receipt.requestReceived,"Only the matching peer, session and recipient can acknowledge");
        receipt.receive("bob",{id:"receipt",to:"alice",op:"received"},1);
        receipt.tick(44.99);check(receipt.requestReceived&&receipt.phase=="inviting","Optional receipt is recorded without accepting the trade");
        receipt.tick(45);check(receipt.phase=="cancelled","Normal unanswered invitation expiry remains");
        receipt.receive("bob",{id:"receipt",to:"alice",op:"received"},46);check(receipt.phase=="cancelled","Late receipt cannot reopen trade");
        receipt.start("bob","next-request",47);check(!receipt.requestReceived,"A new request clears the previous receipt");
        Sys.println("Protocol checks passed: "+checks);
    }
}
