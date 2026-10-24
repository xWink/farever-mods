import marketplace.MarketController;
import marketplace.MarketWorker;
import trade.TradeInventory;

@:access(marketplace.MarketController)
@:access(MarketplaceBuyOrderTest)
class MarketplaceLimitsTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace limits assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,status:Int,body:Dynamic):Void MarketplaceBuyOrderTest.reply(c,app,status,body);
    public static function run():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app:Dynamic={me:player,connectionInfo:{heroID:"limit-character"}};
        var c=new MarketController();c.player=player;c.app=app;c.inv=new TradeInventory(player);c.ready=true;c.server="europe";

        // Collect every region and both types across pages. Characters share the region's slots.
        var all:Array<Dynamic>=[];
        for(region in ["europe","north-america","latin-america","asia","mainland-china"])for(i in 0...40) {
            var row:Dynamic={id:region+i,revision:1,server:region,character:{id:"character"+(i%2)},expiresAt:"2099-01-01T00:00:00.000Z"};
            if(i<20)row.orderType="buy"; // Omitted types remain legacy sell orders.
            all.push(row);
        }
        c.chooseTab("My listings");
        for(page in 0...4) {
            reply(c,app,200,{listings:all.slice(page*50,(page+1)*50),nextCursor:page<3?"page"+(page+1):null});
            if(page<3)check(c.busy&&!c.ownedKnown&&Std.string(MarketplaceBuyOrderTest.last().path).indexOf("orderType=any")>=0);
        }
        check(c.ownedKnown&&!c.busy&&c.total==40&&c.rows.length==40);
        check(c.ownedBuyCount==20&&c.ownedSellCount==20);
        check(c.listingLimitReached("buy")&&c.listingLimitReached("sell"));

        c.selected=c.rows[0];c.remove();reply(c,app,409,{error:{code:"stale_revision"}});
        check(c.total==40&&c.ownedBuyCount==20&&c.ownedSellCount==20);
        c.remove();reply(c,app,204,null);
        check(c.total==39&&!c.listingLimitReached("buy")&&c.listingLimitReached("sell"));
        c.selected=c.rows.filter(row->row.orderType!="buy")[0];c.remove();reply(c,app,204,null);
        check(c.total==38&&c.ownedBuyCount==19&&c.ownedSellCount==19);

        // Expired orders and other regions cannot exhaust the current region's capacity.
        c.ownedRows=[{id:"expired-buy",orderType:"buy",server:"europe",expiresAt:"2000-01-01T00:00:00.000Z"},
            {id:"expired-sell",server:"europe",expiresAt:"2000-01-01T00:00:00.000Z"},
            {id:"remote",orderType:"buy",server:"north-america"},
            {id:"export-buy",server:"europe",export:{orderType:"buy"}},{id:"legacy-sell",server:"europe"}];
        c.indexOwned();check(c.ownedBuyCount==1&&c.ownedSellCount==1);

        // Posting a buy at the sell cap preserves both independent counts.
        c.ownedSellCount=20;c.ownedBuyCount=19;c.chooseTab("Buy");c.buy=MarketplaceBuyOrderTest.draft();
        c.submitBuy();check(c.busy&&haxe.Json.parse(MarketplaceBuyOrderTest.last().body).orderType=="buy");
        reply(c,app,201,{id:"last-buy",revision:1,orderType:"buy",server:"europe"});
        check(!c.ownedKnown&&c.ownedBuyCount==20&&c.ownedSellCount==20);
        c.buy=MarketplaceBuyOrderTest.draft();var sent=MarketWorker.current.sent.length;c.submitBuy();
        check(MarketWorker.current.sent.length==sent&&c.message==MarketController.error("listing_limit","buy"));

        // Posting a sell at the buy cap also works after navigating away during submission.
        c.ownedKnown=true;c.ownedSellCount=19;c.ownedItems=[];c.ownedKinds=[];
        c.chooseTab("Sell");c.chosen=c.inventory[0];c.list(1,1,false);
        check(c.busy&&haxe.Json.parse(MarketplaceBuyOrderTest.last().body).orderType=="sell");
        c.chooseTab("Buy");reply(c,app,201,{id:"last-sell",revision:1,orderType:"sell",server:"europe"});
        check(c.ownedBuyCount==20&&c.ownedSellCount==20&&!c.ownedKnown&&c.tab=="Buy");

        // A server-side cap belongs to the submitted type, never the currently visible tab.
        c.ownedKnown=true;c.ownedSellCount=7;c.ownedBuyCount=4;c.buy=MarketplaceBuyOrderTest.draft();c.buy.level=16;
        c.submitBuy();c.chooseTab("Sell");reply(c,app,409,{error:{code:"listing_limit"}});
        check(c.ownedBuyCount==20&&c.ownedSellCount==7&&!c.listingLimitReached("sell"));
        c.ownedItems=[];c.ownedKinds=[];c.chosen=c.inventory[0];c.list(1,1,false);
        check(c.busy&&haxe.Json.parse(MarketplaceBuyOrderTest.last().body).orderType=="sell");
        c.ownedBuyCount=4;c.chooseTab("Buy");reply(c,app,409,{error:{code:"listing_limit"}});
        check(c.ownedSellCount==20&&c.ownedBuyCount==4&&!c.listingLimitReached("buy"));
        check(c.message==MarketController.error("listing_limit","sell"));
        c.buy=MarketplaceBuyOrderTest.draft();c.buy.level=17;c.submitBuy();check(c.busy);
        reply(c,app,409,{error:{code:"duplicate_item"}});
        check(c.ownedSellCount==20&&c.ownedBuyCount==4);

        c.reconnect();check(c.ownedSellCount==0&&c.ownedBuyCount==0&&!c.ownedKnown);
        c.ownedSellCount=20;c.ownedBuyCount=20;c.disconnect();
        check(!c.listingLimitReached("buy")&&!c.listingLimitReached("sell"));
        Sys.println("Marketplace limits checks passed: "+checks);
    }
}
