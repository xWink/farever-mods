import marketplace.MarketController;
import marketplace.MarketCooldown;
import marketplace.MarketWorker;
import trade.TradeInventory;

class MarketplaceRecoveryTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace recovery assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,status:Int,body:Dynamic,delay=""):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:status,body:body==null?"":haxe.Json.stringify(body),error:status>=200&&status<300?"":"Transport error",retryAfter:delay}});
        c.update(app,haxe.Timer.stamp());
    }
    public static function run():Void {
        var url="/api/v1/marketplace/listings",own=url+"?mine=true&orderType=any&limit=50";
        var cooldown=new MarketCooldown();
        cooldown.record("DELETE",url+"/one",429,"10",100,1000);
        check(cooldown.remaining("DELETE",url+"/two",100)==10);
        check(cooldown.remaining("POST",url,105)==5&&cooldown.remaining("POST",url,110)==0);
        check(cooldown.remaining("GET",url,100)==0&&cooldown.remaining("GET",own,100)==0);
        cooldown.clear();cooldown.record("POST",url,429,"1",100,1000);
        check(cooldown.remaining("POST",url,100)==1);
        cooldown.clear();cooldown.record("GET",url,429,"60",100,1000);
        check(cooldown.remaining("POST",url,100)==0&&cooldown.remaining("GET",own,100)==60);
        cooldown.clear();cooldown.record("GET",url,0,"",100,1000);
        check(cooldown.remaining("GET",url,100)==0);

        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.ready=true;c.server="europe";
        c.open();reply(c,app,0,null);
        check(!c.busy&&c.ready&&!c.connectionIssue&&c.message.indexOf("API key")<0);
        var sent=MarketWorker.current.sent.length;c.view.close();c.open();
        check(c.busy&&MarketWorker.current.sent.length==sent+1);
        reply(c,app,200,{listings:[{id:"recovered"}],nextCursor:null});
        check(c.rows[0].id=="recovered"&&!c.busy&&c.ready&&!c.connectionIssue);
        c.request("DELETE",url+"/one",null,null,_ -> {});
        reply(c,app,429,{error:{code:"rate_limited"}},"10");
        check(!c.busy&&c.ready&&!c.connectionIssue&&c.message.indexOf("10 seconds")>=0);
        check(!c.request("POST",url,{},null,_ -> {})&&!c.busy);
        check(c.request("GET",url,null,null,_ -> {}));reply(c,app,200,{});
        check(c.request("GET",own,null,null,_ -> {}));reply(c,app,200,{});
        c.disconnect();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        check(c.request("POST",url,{},null,_ -> {}));reply(c,app,200,{});
        c.chooseTab("Sell");
        var first:Array<Dynamic>=[for(i in 0...50){id:Std.string(i),revision:1,server:i<19?"europe":i<39?"north-america":"asia"}];
        reply(c,app,200,{listings:first,nextCursor:"second"});
        check(c.busy&&MarketWorker.current.sent[MarketWorker.current.sent.length-1].path==own+"&cursor=second");
        reply(c,app,200,{listings:[{id:"50",revision:1,server:"europe"}],nextCursor:null});
        check(!c.busy&&c.listingLimitReached("sell"));
        c.chooseTab("My listings");check(c.pages==1&&c.total==20);
        c.selected=c.rows[0];c.remove();reply(c,app,204,null);
        check(!c.listingLimitReached("sell"));check(c.total==19);
        c.refresh();reply(c,app,200,{listings:[for(i in 0...20){id:Std.string(i),server:"north-america"}],nextCursor:null});
        check(!c.listingLimitReached("sell")&&c.total==0);
        c.request("GET",own,null,null,_ -> {});reply(c,app,401,{error:{code:"unauthorized"}});
        check(!c.ready&&c.connectionIssue&&!c.busy);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"ready",message:"Connected"});c.update(app,0);
        check(c.ready&&!c.connectionIssue);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"connection-error",message:"Temporary outage"});c.update(app,0);
        check(c.ready&&!c.connectionIssue);
        Sys.println("Marketplace recovery checks passed: "+checks);
    }
}
