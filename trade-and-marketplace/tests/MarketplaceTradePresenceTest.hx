import marketplace.MarketController;
import marketplace.MarketTradePresence;
import marketplace.MarketWorker;
import trade.GameAccess as G;
import trade.TradeInventory;

@:access(marketplace.MarketController)
class MarketplaceTradePresenceTest {
    static var checks=0;
    static var answers:Array<{online:Bool,message:String}>;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function fixture():MarketController {
        G.globals=["lib.Network.realmId"=>1,"lib.Network.OFFLINE_MODE"=>false,"Options.serverRegion"=>"eu"];
        var c=new MarketController();c.player={uid:"sender",isMe:true,hero:{loadout:{banks:[]}}};
        c.inv=new TradeInventory(c.player);c.app={me:c.player};c.server="europe";c.account="sender";
        c.key="fv1_"+StringTools.rpad("x","x",43);c.ready=true;answers=[];return c;
    }
    static function send(c:MarketController,account="target:ABC"):Dynamic {
        c.checkTradePresence(account,"europe",(online,message)->answers.push({online:online,message:message}));
        var sent=MarketWorker.current.sent;
        return sent.length==0?null:sent[sent.length-1];
    }
    static function reply(c:MarketController,job:Dynamic,body:String,status=200,retry=""):Void {
        MarketWorker.current.incoming.push({generation:job.generation,op:"trade-presence",ticket:job.ticket,
            response:{status:status,body:body,error:status==200?"":"HTTP error",retryAfter:retry}});
        c.update(c.app,haxe.Timer.stamp());
    }
    public static function run():Void {
        var c=fixture();c.busy=true;c.message="existing marketplace task";
        var job=send(c);
        check(job.op=="trade-presence"&&job.method=="GET"&&job.path=="/api/v1/marketplace/presence?accountId=target%3AABC&server=europe","Direct trades use a separate exact-account presence request");
        check(c.rows.length==0&&!c.view.shown&&c.busy&&c.message=="existing marketplace task","Presence works without listings or an open window and does not replace a marketplace request");
        reply(c,job,'{"online":true}');
        check(answers.length==1&&answers[0].online&&c.busy,"Fresh result is delivered without clearing marketplace busy state");
        c.busy=false;job=send(c);reply(c,job,'{"online":false}');
        check(answers.length==2&&!answers[1].online&&answers[1].message==MarketTradePresence.OFFLINE,"False response reaches the local trade error callback");
        c=fixture();var stale=send(c);c.cancelTradePresence();job=send(c,"other");
        reply(c,stale,'{"online":true}');check(answers.length==0,"A cancelled ticket cannot approve the replacement request");
        reply(c,job,'{"online":true}');check(answers.length==1&&answers[0].online,"The replacement ticket remains usable");
        c=fixture();job=send(c);reply(c,job,'{"online":true}',429,"90");
        var sent=MarketWorker.current.sent.length;send(c,"another");
        check(!answers[0].online&&MarketWorker.current.sent.length==sent&&answers[1].message.indexOf("Please wait")>=0,"429 blocks new recipients until Retry-After elapses");
        c=fixture();job=send(c);c.cancelTradePresence();reply(c,job,"unavailable",503,"60");
        sent=MarketWorker.current.sent.length;send(c);
        check(MarketWorker.current.sent.length==sent&&answers.length==1&&!answers[0].online,"Even cancelled responses retain the API cooldown");
        for(status in [401,403]) {
            c=fixture();job=send(c);reply(c,job,"unauthorized",status);
            sent=MarketWorker.current.sent.length;send(c);
            check(!c.ready&&c.connectionIssue&&MarketWorker.current.sent.length==sent,"Authentication errors stop further trade lookups");
        }
        c=fixture();c.key="";send(c);check(MarketWorker.current.sent.length==0&&answers[0].message==MarketTradePresence.LOGIN,"Missing sender credentials never send an anonymous lookup");
        c=fixture();G.globals["Options.serverRegion"]="na";send(c);
        check(MarketWorker.current.sent.length==0&&!answers[0].online,"A stale controller region cannot authorize a lookup");
        c=fixture();job=send(c);G.globals["Options.serverRegion"]="na";reply(c,job,'{"online":true}');
        check(answers.length==1&&!answers[0].online,"Region changes cancel an in-flight result before it is used");
        c=fixture();job=send(c);c.disconnect();reply(c,job,'{"online":true}');
        check(answers.filter(a->a.online).length==0,"Disconnect invalidates the request generation");
        G.globals=[];
        Sys.println('Marketplace trade presence integration checks passed: $checks');
    }
}
