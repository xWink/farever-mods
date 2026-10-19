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
        c.chooseTab("Sell an item");c.chosen=c.inventory[0];var chosen=c.chosen;
        c.sellSearch="should";c.searchInventory();c.view.close();c.open();
        check(c.tab=="Sell an item"&&c.chosen==chosen&&c.sellSearch=="should"&&c.inventory[0]==chosen);
        c.sellSearch="no match";c.searchInventory();check(c.chosen==null&&c.total==0);
        c.sellSearch="";c.searchInventory();check(c.total==1&&c.page==1);
        c.chooseTab("Browse");reply(c,app,{id:"third"},null);c.selected=c.rows[0];c.page=2;
        c.disconnect();check(c.selected==null&&c.rows.length==0&&c.page==1&&!c.view.shown);
        c.player=player;c.inv=new TradeInventory(player);c.server="europe";
        var before=MarketWorker.current.sent.length;c.open();
        check(MarketWorker.current.sent.length==before+1&&Std.string(MarketWorker.current.sent[before].path).indexOf("cursor=")<0);
        Sys.println("Marketplace state checks passed: "+checks);
    }
}
