import trade.*;

/** Real controller/protocol on both sides; only native party RPCs are simulated. */
class PartyTest {
    static var checks=0;
    static var leaves:Array<Dynamic>=[];
    static var invites=0;
    static var joins=0;
    static var players:Array<Dynamic>;
    static var now:Float;
    static function check(value:Bool,why:String):Void { checks++; if(!value)throw why; }
    static function group(members:Array<Dynamic>):Dynamic {
        var g:Dynamic={players:{array:members}};
        g.get_isSolo=()->g.players.array.length==1;
        g.requestLeave=(done:Bool->Void)->{leaves.push({group:g,done:done});return null;};
        g.invitePlayer=(uid:Dynamic,done:Bool->Void)->{
            invites++;
            var recipient=players.filter(p->p.__uid==uid)[0],sender=g.players.array[0];
            check(recipient!=null&&sender.group==g&&recipient.group.get_isSolo(),"Invite uses native player ID after both old parties have been left");
            var notice:Dynamic={kind:"PlayerGroupInvited",targetPlayer:recipient,fromPlayer:sender};
            notice.select=(yes:Bool,reply:Bool->Void)->{
                check(yes,"The expected party invitation is accepted");joins++;
                recipient.group=g;g.players.array.push(recipient);notice.removed=true;reply(true);return null;
            };
            recipient.netNotifies.array.push(notice);done(true);return null;
        };
        return g;
    }
    static function fixture():Array<TradeController> {
        leaves=[];invites=joins=0;TradeChat.sent=[];TradeChat.delivered=true;TradeMod.rejectAllRequests=false;
        GameAccess.lines=[];GameAccess.ui={windows:[],get_chat:()->{messages:{}}};now=haxe.Timer.stamp();
        players=[for(id in ["alice","bob"]) {
            uid:id,__uid:"native-"+id,isMe:true,getName:()->id,
            hero:{__uid:"hero-"+id,loadout:{inventory:{content:[],getFreeSize:()->10}},position:{x:0.,y:0.,z:0.},isDead:()->false},
            netNotifies:{array:[]}
        }];
        var layer:Dynamic={players:{array:players}};
        for(p in players){p.layer=layer;p.group=group([p,{uid:"old-teammate-"+p.uid}]);}
        return [for(p in players){var c=new TradeController();GameAccess.app={me:p,isInCutscene:()->false};c.ensure(p);c;}];
    }
    static function asPlayer(c:TradeController):Void GameAccess.app={me:c.player,isInCutscene:()->false};
    static function step(a:TradeController,b:TradeController):Void {
        now+=0.3;
        for(c in [a,b]) {
            asPlayer(c);TradeChat.sent=[];c.update(GameAccess.app,now);
            var messages=TradeChat.sent.copy(),other=c==a?b:a;
            asPlayer(other);
            for(m in messages)other.receive(null,{sender:c.state.self},m.text);
        }
    }
    static function leavePending():Void {
        var pending=leaves.copy();leaves=[];
        for(r in pending) {
            var p=r.group.players.array[0];p.group=group([p]);r.done(true);
        }
    }
    static function packet(c:TradeController,op:String,?sender:String,?id:String):Void {
        asPlayer(c);
        for(text in new TradeWire("test"+checks+op).encode({id:id==null?c.state.id:id,to:c.state.self,op:op}))
            c.receive(null,{sender:sender==null?c.state.peer:sender},text);
    }
    static function main():Void {
        var cs=fixture(),a=cs[0],b=cs[1];asPlayer(a);a.requestName("bob");step(a,b);
        check(a.state.phase=="inviting"&&b.state.phase=="invited","Nearby non-party player can be requested by name");
        check(leaves.length==0&&invites==0,"Receiving a request does not change either party");
        packet(a,"join");check(!a.state.editable(),"A premature join cannot unlock an out-of-party exchange");
        asPlayer(b);b.join();step(a,b);step(a,b);
        check(a.state.phase=="joining"&&b.state.phase=="joining"&&!a.canAccept()&&!b.canAccept(),"Offers stay locked while forming the party");
        check(leaves.length==2&&invites==0,"Both leave RPCs run once and invitations wait for replicated solo groups");
        step(a,b);check(leaves.length==2,"Delayed replication does not repeat the leave RPC");
        leavePending();for(_ in 0...9)step(a,b);
        check(invites==1&&joins==1&&a.player.group==b.player.group,"A single native party invitation joins both players");
        check(a.state.phase=="offering"&&b.state.phase=="offering"&&a.state.peerRevision==0&&b.state.peerRevision==0,"Both offers synchronize after native membership is confirmed");
        step(a,b);check(a.state.phase=="offering"&&b.state.phase=="offering","Expected party changes do not cancel the new trade");
        b.player.group=group([b.player]);a.player.group.players.array=[a.player];step(a,b);
        check(!a.state.active()&&!b.state.active(),"Leaving the party after setup cancels the trade");

        // When an automatically formed trade party is no longer needed, both
        // clients send exactly one native leave request. Before a party is
        // formed, an invitation rejection must preserve existing parties.
        cs=fixture();a=cs[0];b=cs[1];asPlayer(a);a.requestName("bob");step(a,b);
        asPlayer(b);b.join();step(a,b);step(a,b);leavePending();
        for(_ in 0...9)step(a,b);
        check(a.state.editable()&&b.state.editable()&&leaves.length==0,
            "Trade group has finished setup before cancellation");
        asPlayer(b);b.cancelByUser();
        check(leaves.length==1&&leaves[0].group==b.player.group,
            "Cancelling leaves the temporary trade party");
        step(a,b);step(a,b);
        check(leaves.length==2&&leaves[1].group==a.player.group,
            "The peer also leaves after receiving cancellation");
        step(a,b);step(a,b);check(leaves.length==2,
            "Terminal frames cannot send repeated leave requests");

        cs=fixture();a=cs[0];b=cs[1];asPlayer(a);a.requestName("bob");step(a,b);
        asPlayer(b);b.join();step(a,b);step(a,b);leavePending();
        for(_ in 0...9)step(a,b);
        a.state.phase="complete";b.state.phase="complete";
        step(a,b);
        check(leaves.length==2&&leaves[0].group==leaves[1].group,
            "Completion requests one leave for each trade participant");
        step(a,b);check(leaves.length==2,"Completion cleanup is idempotent");

        // Existing parties used directly for trading are also left when the
        // actual trade ends, but not before the request has been accepted.
        cs=fixture();a=cs[0];b=cs[1];
        var existing=group([a.player,b.player]);
        a.player.group=existing;b.player.group=existing;
        asPlayer(a);a.requestName("bob");step(a,b);
        check(leaves.length==0,"Merely requesting a trade does not leave an existing party");
        asPlayer(b);b.join();step(a,b);step(a,b);
        check(a.state.editable()&&b.state.editable(),"Existing-party trade reaches offering");
        asPlayer(b);b.cancelByUser();step(a,b);step(a,b);
        check(leaves.length==2&&leaves[0].group==existing&&leaves[1].group==existing,
            "A finished trade in an existing party leaves the same party");

        cs=fixture();a=cs[0];b=cs[1];asPlayer(a);a.request("bob");step(a,b);asPlayer(b);b.cancelByUser();step(a,b);
        check(leaves.length==0&&invites==0&&!a.state.active(),"Declining preserves both old parties");
        cs=fixture();a=cs[0];b=cs[1];asPlayer(a);a.request("bob");step(a,b);asPlayer(b);b.join();step(a,b);
        leaves[0].done(false);step(a,b);step(a,b);
        check(!a.state.active()&&!b.state.active()&&invites==0,"Failed party leave cancels safely");

        cs=fixture();a=cs[0];b=cs[1];asPlayer(a);a.request("bob");step(a,b);
        var stale:Dynamic={kind:"PlayerGroupInvited",targetPlayer:b.player,fromPlayer:a.player,select:(_,_) -> {throw "Stale invitation accepted";}};
        b.player.netNotifies.array.push(stale);asPlayer(b);b.join();
        b.player.group=group([b.player]);
        b.player.netNotifies.array.push({kind:"PlayerGroupInvited",targetPlayer:b.player,fromPlayer:{uid:"someone-else"},select:(_,_) -> {throw "Unrelated invitation accepted";}});
        b.player.netNotifies.array.push({kind:"OtherPrompt",targetPlayer:b.player,fromPlayer:a.player,select:(_,_) -> {throw "Wrong notification accepted";}});
        asPlayer(b);b.update(GameAccess.app,now+1);
        check(b.state.phase=="joining"&&joins==0,"Only a fresh party invitation from the accepted trade partner may be auto-accepted");
        b.update(GameAccess.app,now+60);
        check(b.state.phase=="cancelled"&&b.state.error.indexOf("party")>=0,"Party setup has a bounded timeout");
        Sys.println("Trade party checks passed: "+checks);
    }
}
