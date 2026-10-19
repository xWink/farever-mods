package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;
/** Takes a fresh snapshot only on selection/submission, never on a frame timer. */
class MarketExport {
    public static function server(region:String):String return switch(region.toLowerCase()) {
        case "eu","europe": "europe";
        case "na","northamerica","north-america": "north-america";
        case "sa","southamerica","latin-america": "latin-america";
        case "asia","as": "asia";
        case "cn","china","mainland-china": "mainland-china";
        default: "";
    };
    public static function uuid():String {
        var b=MarketNative.random(); b.set(6,(b.get(6)&15)|64);b.set(8,(b.get(8)&63)|128);
        var hex=b.toHex().substr(0,32);b.fill(0,b.length,0);
        return hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20);
    }
    public static function snapshot(inv:TradeInventory,offer:TradeItem,quantity:Int,trays:Int,offers:Bool,server:String,app:Dynamic,bankOnly=false):Dynamic {
        if(server=="")throw "The connected server could not be identified. Reconnect before listing items.";
        var source=MarketInventory.source(inv,offer.uid,bankOnly);
        var stack=source==null?null:source.find(offer.uid);
        if(quantity<1)throw "Choose a quantity of at least 1.";
        if(stack!=null&&quantity>stack.count)throw "Not enough of this item. You have "+stack.count+" available.";
        if(stack==null||TradeInventory.fingerprint(stack.item)!=offer.fingerprint||!source.canDrop(stack,quantity))
            throw "This item changed, is locked, or cannot be traded. Refresh and choose it again.";
        if(quantity<1||quantity>10000||(!offers&&(trays<1||trays>200000)))throw "Choose a valid quantity and a total price of 1 to 200,000 Silver Trays.";
        var character=G.text(G.field(G.field(app,"connectionInfo"),"heroID"));
        if(character==""||character=="0")throw "Your character is still loading. Try again shortly.";
        var item=stack.item,p=TradeInventory.preview(item),rarity=G.text(G.field(G.staticCall("HItem","getRarity",[G.field(item,"inf")]),"id"));
        // Only persistent visual flags belong in detached tooltip objects, never bound/network flags.
        p.flags&=3;
        if(!trade.TradePreview.valid(p))throw "This item's modifiers are not supported yet.";
        var detail=TradeInventory.describe(item,quantity).detail;
        var data:Dynamic={schemaVersion:2,server:server,gameVersion:G.text(G.staticCall("Config","getVersion",[])),
            character:{id:character,name:G.text(G.call("st.Player","getName",inv.player))},
            item:{baseId:offer.kind,quantity:quantity,rarity:rarity,requiredLevel:G.integer(G.call("st.Item","getRequiredLevel",item)),
                itemLevel:G.integer(G.call("st.Item","getILevel",item)),upgradeLevel:p.upgrade,prismatic:(p.flags&2)!=0,flawless:(p.flags&1)!=0,
                stats:[],modifiers:[],native:p,detail:detail},
            price:offers?{mode:"offers"}:{mode:"fixed",silverTrays:trays}};
        if(haxe.io.Bytes.ofString(haxe.Json.stringify(data)).length>16384)throw "This item contains too much data to list.";
        return data;
    }
    public static function offer(row:Dynamic):TradeItem {
        var i=row.item,p:TradeItemPreview=i.native;
        if(!trade.TradePreview.valid(p))throw "Update the mod to inspect this listing.";
        var detail:String=i.detail==null?"":i.detail;
        if(p==null) {
            var lines=[i.rarity+" · Upgrade +"+i.upgradeLevel];
            if(Std.isOfType(i.stats,Array)) for(stat in (cast i.stats:Array<Dynamic>))lines.push(G.text(stat.name)+": "+stat.value+(stat.unit=="percent"?"%":""));
            if(Std.isOfType(i.modifiers,Array))for(m in (cast i.modifiers:Array<Dynamic>))lines.push(G.text(m.name));
            detail=lines.join("\n");
        }
        return {uid:"",kind:i.baseId,count:i.quantity,name:TradeInventory.itemName(i.baseId),detail:detail,
            color:0xDAC9AA,fingerprint:"",preview:p};
    }
}
