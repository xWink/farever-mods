import marketplace.MarketDetails;
import marketplace.MarketExport;
import marketplace.MarketController;
import marketplace.MarketWindow;
import trade.GameAccess as G;
import trade.TradeInventory;

class MarketplaceDetailsTest {
    static var checks=0;
    static function check(value:Bool,message:String):Void {checks++;if(!value)throw message;}
    static function visible(text:String):Bool return G.labels.filter(l->Std.string(l.text).indexOf(text)>=0).length==1;
    public static function run(example:Dynamic):Void {
        var oldDefinitions=TradeInventory.definitions,oldData=G.dataFields;
        var kind="InfusionDetailsArmor";
        TradeInventory.definitions=[kind=>{id:kind,gear:true,infusable:true}];
        var attributes:Map<String,Dynamic>=["FervorRating"=>{name:"Ferveur"},"Vitality"=>{name:"Vitalité"}];
        G.dataFields=["Data.attribute"=>{byId:attributes}];
        var row:Dynamic=haxe.Json.parse(haxe.Json.stringify(example));
        row.item.baseId=kind;row.item.category="Armor";row.item.detail="";
        row.item.native.infusion="Infusion_Manfish_DPS";row.item.native.bonus="FervorRating";
        row.item.native.slots=[];row.item.native.effects=[];
        var offer=MarketExport.offer(row);
        var text=MarketDetails.text(offer);
        check(text.indexOf("Infusion: Overwhelming Tides")>=0,"Remote infusion survives a missing summary");
        check(text.indexOf("Infusion bonus: Ferveur")>=0,"Remote bonus uses the viewer's native attribute name");
        offer.detail="Infusion: Outdated effect\nInfusion bonus: Wrong stat\nInfusion bonus: <img src='bad'/>";
        text=MarketDetails.text(offer);
        check(text.indexOf("Outdated")==-1&&text.indexOf("Wrong")==-1&&text.indexOf("bad")==-1,
            "Saved summary cannot override native infusion state");
        check(text.split("Infusion bonus:").length==2,"Infusion bonus appears once");
        attributes["FervorRating"].name="Fervor <bonus> & power";
        text=MarketDetails.text(offer);
        check(text.indexOf("Fervor &lt;bonus&gt; &amp; power")>=0,"Attribute labels are escaped as plain text");
        attributes["FervorRating"].name="Ferveur";
        var local:Dynamic={nativeType:"st.item.Gear",infusion:null,infusionBonusStat:"Vitality"};
        text=MarketDetails.text(offer,local);
        check(text.indexOf("Infusion bonus: Vitalité")>=0&&text.indexOf("Overwhelming")==-1,
            "Owned items use their actual current fields");
        offer.preview.infusion="";offer.preview.bonus="";
        check(MarketDetails.text(offer).indexOf("Infusion")==-1,"Empty sell fields do not revive stale summary labels");
        check(MarketDetails.text(offer,null,true).indexOf("Infusion bonus: Any")>=0,
            "An unspecified buy requirement displays Any");
        TradeInventory.definitions[kind].infusable=false;
        check(MarketDetails.text(offer,null,true).indexOf("Infusion")==-1,"Non-infusable gear does not display Any");
        TradeInventory.definitions[kind].gear=false;
        check(MarketDetails.text(offer,null,true)==null,"Non-gear keeps its existing details path");
        TradeInventory.definitions[kind].gear=true;TradeInventory.definitions[kind].infusable=true;
        offer.preview=null;offer.detail="Infusion: Infusion_Manfish_DPS\nInfusion bonus: Vitality";
        check(MarketDetails.text(offer).indexOf("Infusion: Overwhelming Tides")>=0,
            "Legacy listings without a native snapshot retain their summary");

        // Check the order type reaches the renderer in both listing views.
        row.item.native.infusion="";row.item.native.bonus="";row.item.detail="";
        var c=new MarketController();c.rows=[row];c.selected=row;
        var view=new MarketWindow(c);c.view=view;view.open();
        for(tab in ["Browse","My listings"]) {
            c.tab=tab;row.orderType="buy";view.dirty=true;view.update();
            check(visible("Infusion bonus: Any"),tab+" shows the unspecified buy bonus");
            row.item.native.bonus="FervorRating";view.dirty=true;view.update();
            check(visible("Infusion bonus: Ferveur")&&!visible("Infusion bonus: Any"),tab+" shows a specific buy bonus");
            row.orderType="sell";view.dirty=true;view.update();
            check(visible("Infusion bonus: Ferveur"),tab+" shows a seller's bonus without a summary");
            row.item.native.bonus="";view.dirty=true;view.update();
            check(!visible("Infusion bonus:"),tab+" does not interpret an uninfused sale as Any");
        }
        view.close();TradeInventory.definitions=oldDefinitions;G.dataFields=oldData;
        Sys.println("Marketplace infusion detail checks passed: "+checks);
    }
}
