import marketplace.MarketController;
import marketplace.MarketWorker;
import trade.TradeInventory;
class MarketplaceStateTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace state assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,listing:Dynamic,cursor:Null<String>):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({listings:[listing],nextCursor:cursor})}});
        c.update(app,0);
    }
    static function main():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        c.open();check(c.view.shown&&MarketWorker.current.sent.length==1);
        reply(c,app,{id:"first"},"next-page");
        c.page=2;c.refresh();check(Std.string(MarketWorker.current.sent[1].path).indexOf("cursor=next-page")>=0);
        reply(c,app,{id:"second"},null);c.selected=c.rows[0];
        var selected=c.selected;
        c.view.close();c.open();
        check(MarketWorker.current.sent.length==2&&!c.busy);
        check(c.page==2&&c.selected==selected&&c.rows[0]==selected&&c.view.shown);
        c.chooseTab("Sell");c.chosen=c.inventory[0];var chosen=c.chosen;
        c.sellSearch="should";c.searchInventory();c.view.close();c.open();
        check(c.tab=="Sell"&&c.chosen==chosen&&c.sellSearch=="should"&&c.inventory[0]==chosen);
        c.sellSearch="no match";c.searchInventory();check(c.chosen==null&&c.total==0);
        c.sellSearch="";c.searchInventory();check(c.total==1&&c.page==1);
        c.inv.inventory={content:[for(i in 0...21){item:{uid:Std.string(i),inf:{}},count:1}]};
        c.loadInventory();check(c.total==21&&c.pages==3&&c.pageSize()==9);
        c.page=3;c.refresh();check(c.page==3&&c.pages==3&&c.total==21);
        c.chooseTab("Browse");reply(c,app,{id:"third"},null);c.selected=c.rows[0];c.page=2;
        c.disconnect();check(c.selected==null&&c.rows.length==0&&c.page==1&&!c.view.shown);
        c.player=player;c.inv=new TradeInventory(player);c.server="europe";
        var before=MarketWorker.current.sent.length;c.open();
        check(MarketWorker.current.sent.length==before+1&&Std.string(MarketWorker.current.sent[before].path).indexOf("cursor=")<0);
        reply(c,app,{id:"delete-me",revision:7},null);
        c.tab="My listings";c.ready=true;c.selected=c.rows[0];
        var sent=MarketWorker.current.sent.length;
        c.page=2;c.remove();
        var deletion=MarketWorker.current.sent[sent];
        check(deletion.method=="DELETE"&&deletion.path=="/api/v1/marketplace/listings/delete-me");
        var headers:Map<String,String>=deletion.headers;
        check(headers["If-Match"]=='"7"'&&deletion.body==null);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:204,error:"",retryAfter:"",body:""}});
        c.update(app,0);
        check(MarketWorker.current.sent.length==sent+2&&MarketWorker.current.sent[sent+1].method=="GET");
        check(c.selected==null&&c.page==1&&Std.string(MarketWorker.current.sent[sent+1].path).indexOf("limit=9")>=0);
        reply(c,app,{id:"remaining",revision:1},null);
        check(!c.busy&&c.selected==null&&c.rows.length==1&&c.rows[0].id=="remaining");
        c.selected=c.rows[0];sent=MarketWorker.current.sent.length;c.remove();
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:409,error:"HTTP Error #409",retryAfter:"",body:'{"error":{"code":"stale_revision"}}'}});
        c.update(app,0);
        check(!c.busy&&c.rows[0].id=="remaining"&&MarketWorker.current.sent.length==sent+1);
        check(c.message=="This listing changed. Refresh before removing it.");
        Sys.println("Marketplace state checks passed: "+checks);
    }
}
