import trade.*;

@:access(ControllerTest)
@:access(trade.TradeController)
class TradePresenceTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function fixture():TradeController {
        var c=ControllerTest.fixture(false);TradeMod.deferPresence=true;
        c.nearbyPlayer("peer").__uid="internal-player-object";
        return c;
    }
    static function tick(c:TradeController):Void c.update(GameAccess.app,haxe.Timer.stamp());
    static function answer(online:Bool,index=0,message="offline"):Void TradeMod.presenceChecks[index].done(online,message);
    public static function run():Void {
        var c=fixture();c.request("peer");tick(c);
        check(TradeChat.sent.length==0&&c.state.phase=="idle"&&!c.open,"No whisper, session or popup before a presence answer");
        check(TradeMod.presenceChecks[0].account=="peer"&&TradeMod.presenceChecks[0].region=="europe","Lookup uses Farever account ID and connected region, not native object ID");
        c.request("peer");check(TradeMod.presenceChecks.length==1,"Repeated clicks cannot duplicate a pending lookup");
        answer(false,0,"This player does not have the Trade and Marketplace mod or is not signed into Fareverly.");tick(c);
        var errorText:String=GameAccess.lines[GameAccess.lines.length-1].text;
        check(TradeChat.sent.length==0&&!c.state.active()&&errorText.indexOf("not signed into Fareverly")>=0,"Offline shows the local explanation without sending a probe or cancellation");
        c=fixture();c.request("peer");answer(true);
        check(TradeChat.sent.length==0,"The callback alone cannot send the whisper");tick(c);
        check(c.state.phase=="inviting"&&TradeChat.sent.length==1&&TradeChat.sent[0].to=="peer","A fresh online answer allows exactly one invitation");
        answer(true);tick(c);check(TradeChat.sent.length==1,"Duplicate callback cannot resend the invitation");
        c.cancelByUser();c.update(GameAccess.app,haxe.Timer.stamp()+1);TradeChat.sent=[];
        c.request("peer");check(TradeMod.presenceChecks.length==2&&TradeChat.sent.length==0,"A later trade needs another lookup, even for the same player");
        for(cancel in ["cancel","disable","logout","region","moved","removed","hero","timeout","failure"]) {
            c=fixture();c.request("peer");
            switch(cancel) {
                case "cancel":c.cancelByUser();
                case "disable":TradeMod.on=false;
                case "logout":GameAccess.app.me=null;
                case "region":TradeMod.region="north-america";
                case "moved":c.nearbyPlayer("peer").hero.position.x=100;
                case "removed":c.nearbyPlayer("peer").removed=true;
                case "hero":GameAccess.app.me.hero={};
                case "timeout":c.presenceAttempt.deadline=0;
                case "failure":c.fail("verification failed");
            }
            tick(c);answer(true);tick(c);
            check(TradeChat.sent.length==0,"Late success discarded after "+cancel);
        }
        c=fixture();c.request("peer");answer(true);TradeMod.region="north-america";tick(c);
        check(TradeChat.sent.length==0,"Region is checked again after approval and before the first whisper");
        c=fixture();c.request("peer");answer(true);c.presenceAttempt.deadline=0;tick(c);
        check(TradeChat.sent.length==0,"An approval cannot linger in an outgoing queue indefinitely");
        c=fixture();
        c.player.group.players.array.push({uid:"other",getName:()->"Other",hero:{position:{x:0.,y:0.,z:0.},isDead:()->false}});
        c.request("peer");c.request("other");answer(true,0);tick(c);
        check(TradeChat.sent.length==0,"Changing the requested recipient invalidates its old callback");
        answer(true,1);tick(c);check(TradeChat.sent.length==1&&TradeChat.sent[0].to=="other","Only the latest selected player receives a verified request");
        c=fixture();c.request("peer");ControllerTest.invite(c,"incoming");answer(true);tick(c);
        check(c.state.phase=="invited"&&ControllerTest.sentPackets().length==0,"An incoming trade supersedes the pending outgoing check");
        TradeMod.resetPresence();
        Sys.println('Trade request presence checks passed: $checks');
    }
}
