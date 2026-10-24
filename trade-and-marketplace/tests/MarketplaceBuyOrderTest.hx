import marketplace.MarketBuy;
import marketplace.MarketController;
import marketplace.MarketExport;
import marketplace.MarketOrder;
import marketplace.MarketWorker;
import trade.TradeInventory;
import trade.TradePreview;

@:access(marketplace.MarketController)
class MarketplaceBuyOrderTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace buy order assertion "+checks;}
    static function last():Dynamic return MarketWorker.current.sent[MarketWorker.current.sent.length-1];
    static function reply(c:MarketController,app:Dynamic,status:Int,body:Dynamic):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:status,error:status>=200&&status<300?"":"Transport error",retryAfter:"",body:haxe.Json.stringify(body)}});
        c.update(app,0);
    }
    static function draft(gear=true):MarketBuy {
        var b=new MarketBuy(),kind=gear?"Shield_OrbitWater":"Potion";
        b.selected={kind:kind,name:kind,category:gear?"Armor":"Consumables",subcategory:"",classes:[],rarity:"Epic",level:15,gear:gear,infusable:gear,
            offer:{uid:"",kind:kind,name:kind,count:1,detail:"",color:0,fingerprint:"",
                preview:{flags:0,level:0,upgrade:0,rarity:"",infusion:"",bonus:"",mastery:"",slots:[],effects:[]}}};
        b.level=gear?15:0;b.bonus=gear?"Vitality":"";b.prismatic=gear;b.quantity="12";b.trays="7";
        return b;
    }
    public static function run():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app:Dynamic={me:player,connectionInfo:{heroID:"buy-character"}};
        var b=draft(),value=MarketExport.buySnapshot(b,"europe",app,player);
        check(value.schemaVersion==2&&value.orderType=="buy"&&value.server=="europe");
        check(value.character.id=="buy-character"&&value.character.name=="Tester"&&value.gameVersion=="0.3.1.31390");
        check(value.item.quantity==12&&value.price.mode=="fixed"&&value.price.silverTrays==7);
        check(value.item.native.level==15&&value.item.native.bonus=="Vitality"&&value.item.prismatic&&value.item.native.flags==2);
        check(TradePreview.valid(value.item.native)&&value.item.requiredLevel==15&&value.item.itemLevel==35);
        b=draft(false);b.offers=true;b.trays="";value=MarketExport.buySnapshot(b,"europe",app,player);
        check(value.price.mode=="offers"&&!Reflect.hasField(value.price,"silverTrays"));
        check(!Reflect.hasField(value.item,"requiredLevel")&&!Reflect.hasField(value.item,"itemLevel")&&!value.item.prismatic);
        for(field in ["quantity","trays"])for(invalid in ["","0","-1","1.5","1e3","NaN","4294967297",field=="quantity"?"10001":"200001"]) {
            b=draft();Reflect.setField(b,field,invalid);var rejected=false;
            try MarketExport.buySnapshot(b,"europe",app,player)catch(_:Dynamic)rejected=true;
            check(rejected);
        }
        b=draft();b.quantity="10000";b.trays="200000";value=MarketExport.buySnapshot(b,"europe",app,player);
        check(value.item.quantity==10000&&value.price.silverTrays==200000);
        for(which in ["server","character","preview"]) {
            b=draft();var rejected=false;
            trade.TradeTooltips.previewAvailable=which!="preview";
            try MarketExport.buySnapshot(b,which=="server"?"":"europe",which=="character"?{}:app,player)catch(_:Dynamic)rejected=true;
            check(rejected);trade.TradeTooltips.previewAvailable=true;
        }
        check(MarketOrder.prefix({})=="S> "&&MarketOrder.prefix({orderType:"sell"})=="S> "&&MarketOrder.prefix({orderType:"buy"})=="B> ");
        check(MarketOrder.isBuy({export:{orderType:"buy"}})&&MarketOrder.ownerLabel({orderType:"buy"})=="Buyer");

        // No inventory ownership is needed. A timeout retains the exact request
        // body and UUID; only a successful, valid receipt clears the draft.
        var c=new MarketController();c.player=player;c.app=app;c.server="europe";c.tab="Buy";c.ready=true;c.buy=draft();c.inv=null;
        c.submitBuy();var first=last(),body=first.body,key=first.headers.get("Idempotency-Key");
        check(c.busy&&first.method=="POST"&&first.path=="/api/v1/marketplace/listings");
        check(~/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.match(key));
        check(haxe.Json.parse(body).orderType=="buy"&&haxe.Json.parse(body).item.quantity==12);
        c.submitBuy();check(MarketWorker.current.sent.length==1);
        reply(c,app,0,null);check(!c.busy&&c.buy.selected!=null&&c.buyRequestId==key);
        c.submitBuy();check(last().body==body&&last().headers.get("Idempotency-Key")==key);
        reply(c,app,200,{id:"new-buy",revision:1,orderType:"buy",server:"europe",replayed:true});
        check(!c.busy&&c.buy.selected==null&&c.buyRequestId==""&&c.buyExpectedBody==""&&c.message=="Buy order posted.");
        check(!c.ownedKnown&&c.ownedListingCount==1&&c.tab=="Buy");
        c.buy=draft();c.submitBuy();key=last().headers.get("Idempotency-Key");
        reply(c,app,0,null);c.buy.quantity="13";c.submitBuy();
        check(last().headers.get("Idempotency-Key")!=key&&haxe.Json.parse(last().body).item.quantity==13);
        c.buy.quantity="14";
        reply(c,app,201,{id:"second-buy",revision:1,orderType:"buy",server:"europe"});
        check(c.buy.selected!=null&&c.buy.quantity=="14");
        c.submitBuy();reply(c,app,200,{id:"bad-receipt",revision:1,orderType:"sell",server:"europe"});
        check(c.buy.selected!=null&&c.buyRequestId!=""&&c.message.indexOf("Unsupported marketplace response")>=0);
        var sent=MarketWorker.current.sent.length;c.ready=false;c.submitBuy();check(MarketWorker.current.sent.length==sent&&!c.busy);
        c.ready=true;c.ownedListingCount=20;c.submitBuy();check(MarketWorker.current.sent.length==sent&&c.message==MarketController.error("listing_limit"));
        c.ownedListingCount=0;c.submitBuy();reply(c,app,409,{error:{code:"duplicate_listing"}});
        check(c.buy.selected!=null&&!c.busy);
        c.submitBuy();c.chooseTab("My listings");check(c.navigationPending&&c.busy);
        reply(c,app,201,{id:"third-buy",revision:1,orderType:"buy",server:"europe"});
        check(c.busy&&last().path=="/api/v1/marketplace/listings?mine=true&orderType=any&limit=50");

        value=MarketExport.buySnapshot(draft(),"europe",app,player);
        var buyRow:Dynamic={id:"owned-buy",revision:1,orderType:"buy",server:"europe",item:value.item,price:value.price,export:value};
        reply(c,app,200,{listings:[buyRow],nextCursor:null});
        check(c.rows.length==1&&c.rows[0].id=="owned-buy"&&c.ownedListingCount==1&&c.ownedKnown);
        check(!c.ownedKinds.exists(value.item.baseId)&&!c.ownedItems.keys().hasNext());
        c.selected=c.rows[0];check(c.beginEdit()&&c.editQuantityLimit==10000);
        c.edit(10000,9,false);var edit=haxe.Json.parse(last().body);
        check(last().method=="PUT"&&edit.orderType=="buy"&&edit.item.quantity==10000&&edit.price.silverTrays==9);
        check(edit.character.id=="buy-character"&&last().headers.get("If-Match")=='"1"');
        reply(c,app,200,{id:"owned-buy",revision:2});
        check(c.selected.item.quantity==10000&&c.selected.export.orderType=="buy"&&c.editingListingId=="");
        c.remove();reply(c,app,204,null);check(c.rows.length==0&&c.ownedListingCount==0);
        var sellRow:Dynamic=haxe.Json.parse(haxe.Json.stringify(buyRow));sellRow.id="owned-sell";sellRow.orderType="sell";sellRow.export.orderType="sell";
        c.ownedRows=[buyRow,sellRow];c.indexOwned();
        check(c.ownedListingCount==2&&c.ownedKinds.exists(value.item.baseId));

        c.chooseTab("Browse");check(last().path.indexOf("orderType=any")>=0&&last().path.indexOf("pricing=")<0);
        reply(c,app,200,{listings:[buyRow],nextCursor:"old-cursor"});
        c.filters["orderType"]="buy";c.refresh();
        check(last().path.indexOf("orderType=buy")>=0&&last().path.indexOf("cursor=")<0);
        reply(c,app,200,{listings:[buyRow],nextCursor:null});
        c.filters["orderType"]="sell";c.refresh();check(last().path.indexOf("orderType=sell")>=0&&last().path.indexOf("cursor=")<0);
        reply(c,app,200,{listings:[sellRow],nextCursor:null});check(c.rows[0].orderType=="sell");
        c.disconnect();check(c.buyRequestId==""&&c.buyExpectedBody=="");
        Sys.println("Marketplace buy order checks passed: "+checks);
    }
}
