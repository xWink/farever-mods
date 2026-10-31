import marketplace.MarketController;
import marketplace.MarketExport;
import marketplace.MarketItemIdentity;
import marketplace.MarketWorker;
import trade.TradeInventory;

@:access(marketplace.MarketController)
@:access(MarketplaceBuyOrderTest)
class MarketplaceBuyDuplicateTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace buy duplicate assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,status:Int,body:Dynamic):Void MarketplaceBuyOrderTest.reply(c,app,status,body);
    public static function run():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app:Dynamic={me:player,connectionInfo:{heroID:"buy-character"}};
        var c=new MarketController();c.player=player;c.app=app;c.inv=new TradeInventory(player);c.server="europe";
        c.chooseTab("Buy");check(!c.busy&&MarketWorker.current.sent.length==0);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"ready",message:"Connected"});c.update(app,0);
        check(c.busy&&Std.string(MarketplaceBuyOrderTest.last().path).indexOf("mine=true&orderType=any")>=0);
        c.buy=MarketplaceBuyOrderTest.draft();
        var value=MarketExport.buySnapshot(c.buy,"north-america",app,player);
        // Owned exports preserve identity; public item text/stats may be enriched by the API.
        var row:Dynamic={id:"existing-buy",revision:1,orderType:"buy",server:"north-america",export:value,item:{baseId:value.item.baseId},expiresAt:"2099-01-01T00:00:00.000Z"};
        var expired:Dynamic={id:"expired-buy",orderType:"buy",server:"europe",export:value,expiresAt:"2000-01-01T00:00:00.000Z"};
        var sell:Dynamic={id:"same-sell",server:"europe",item:value.item};
        reply(c,app,200,{listings:[sell,expired],nextCursor:"next"});
        check(c.busy&&!c.buyAlreadyListed());
        reply(c,app,200,{listings:[row],nextCursor:null});
        check(!c.busy&&c.ownedKnown&&c.buyAlreadyListed()&&c.ownedBuyCount==0&&c.ownedSellCount==1);
        var sent=MarketWorker.current.sent.length;c.submitBuy();
        check(MarketWorker.current.sent.length==sent&&c.message==MarketController.error("duplicate_item","buy"));

        c.buy.quantity="";c.buy.totalTrays="";c.buy.offers=true;
        check(c.buyAlreadyListed()); // Neither incomplete pricing nor quantities change item identity.
        c.buy.quantity="99";c.buy.totalTrays="12";c.buy.offers=false;check(c.buyAlreadyListed());
        c.buy.setLevel("16");check(!c.buyAlreadyListed());c.buy.setLevel("15");check(c.buyAlreadyListed());
        c.buy.setAnyLevel(true);check(!c.buyAlreadyListed());c.buy.setAnyLevel(false);check(c.buyAlreadyListed());
        c.buy.bonus="Strength";c.buy.updatePreview();check(!c.buyAlreadyListed());
        c.buy.bonus="Vitality";c.buy.updatePreview();check(c.buyAlreadyListed());
        c.buy.prismatic=false;c.buy.updatePreview();check(!c.buyAlreadyListed());
        c.buy.prismatic=true;c.buy.updatePreview();check(c.buyAlreadyListed());
        c.buy.selected.weapon=true;c.buy.setRarity("Rare");check(!c.buyAlreadyListed());
        c.buy=MarketplaceBuyOrderTest.draft();c.buy.setLevel("16");c.submitBuy();check(c.busy);
        c.buy.setLevel("17");reply(c,app,201,{id:"second-buy",revision:1,orderType:"buy",server:"europe"});
        check(!c.buyAlreadyListed()&&c.buy.selected!=null);
        c.buy.setLevel("16");check(c.buyAlreadyListed());c.buy.setLevel("15");check(c.buyAlreadyListed());

        // Refresh reconciles cancelled/expired orders while retaining the draft.
        c.refresh();check(c.busy&&c.buy.selected!=null);
        reply(c,app,200,{listings:[],nextCursor:null});check(!c.buyAlreadyListed()&&c.ownedKnown);
        c.submitBuy();check(c.busy);c.buy.setLevel("18");
        reply(c,app,409,{error:{code:"duplicate_item"}});
        check(!c.buyAlreadyListed()&&c.message==MarketController.error("duplicate_item","buy"));
        c.buy.setLevel("15");check(c.buyAlreadyListed());
        sent=MarketWorker.current.sent.length;c.submitBuy();check(!c.busy&&MarketWorker.current.sent.length==sent);

        c.refresh();reply(c,app,200,{listings:[row],nextCursor:null});check(c.buyAlreadyListed());
        c.chooseTab("My listings");c.selected=row;c.remove();reply(c,app,409,{error:{code:"stale_revision"}});
        check(c.buyAlreadyListed());
        c.selected=row;c.remove();reply(c,app,204,null);c.chooseTab("Buy");check(!c.busy&&!c.buyAlreadyListed());
        c.ownedBuyItems[MarketItemIdentity.key(MarketExport.buyItem(c.buy))]=1;check(!c.buyAlreadyListed());
        c.ownedBuyItems[MarketItemIdentity.key(MarketExport.buyItem(c.buy))]=0;check(c.buyAlreadyListed());
        c.reconnect();check(!c.buyAlreadyListed());
        Sys.println("Marketplace buy duplicate checks passed: "+checks);
    }
}
