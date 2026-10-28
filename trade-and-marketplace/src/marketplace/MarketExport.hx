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
    static var requestSequence=0;
    public static function uuid():String {
        // This is a non-secret idempotency token, not authentication entropy.
        // Keep listing submission independent of the optional sign-in desktop plugin.
        var seed=Std.string(Date.now().getTime())+":"+Std.string(haxe.Timer.stamp())+":"+Std.string(requestSequence++);
        for(_ in 0...4)seed+=":"+Std.string(Math.random());
        var b=haxe.crypto.Sha256.make(haxe.io.Bytes.ofString(seed)); b.set(6,(b.get(6)&15)|64);b.set(8,(b.get(8)&63)|128);
        var hex=b.toHex().substr(0,32);b.fill(0,b.length,0);
        return hex.substr(0,8)+"-"+hex.substr(8,4)+"-"+hex.substr(12,4)+"-"+hex.substr(16,4)+"-"+hex.substr(20);
    }
    public static function available(inv:TradeInventory,offer:TradeItem,bankOnly=false):Int {
        var source=MarketInventory.source(inv,offer.uid,bankOnly),stack=source==null?null:source.find(offer.uid);
        if(stack==null||TradeInventory.fingerprint(stack.item)!=offer.fingerprint||!source.canDrop(stack,1))return 0;
        return MarketInventory.available(inv,itemData(stack.item,offer,1));
    }
    public static function snapshot(inv:TradeInventory,offer:TradeItem,quantity:Int,trays:Int,offers:Bool,server:String,app:Dynamic,bankOnly=false):Dynamic {
        if(server=="")throw "The connected server could not be identified. Reconnect before listing items.";
        var source=MarketInventory.source(inv,offer.uid,bankOnly);
        var stack=source==null?null:source.find(offer.uid);
        if(quantity<1)throw "Choose a quantity of at least 1.";
        if(stack==null||TradeInventory.fingerprint(stack.item)!=offer.fingerprint||!source.canDrop(stack,1))
            throw "This item changed, is locked, or cannot be traded. Refresh and choose it again.";
        var total=MarketInventory.available(inv,itemData(stack.item,offer,1));
        if(quantity>total)throw "Not enough of this item. You have "+total+" available.";
        if(quantity<1||quantity>10000||(!offers&&(trays<1||trays>200000)))throw "Choose a valid quantity and a total price of 1 to 200,000 Silver Trays.";
        var character=G.text(G.field(G.field(app,"connectionInfo"),"heroID"));
        if(character==""||character=="0")throw "Your character is still loading. Try again shortly.";
        var data:Dynamic={schemaVersion:2,orderType:"sell",server:server,gameVersion:G.text(G.staticCall("Config","getVersion",[])),
            character:{id:character,name:G.text(G.call("st.Player","getName",inv.player))},
            item:itemData(stack.item,offer,quantity),price:offers?{mode:"offers"}:{mode:"fixed",silverTrays:trays}};
        if(haxe.io.Bytes.ofString(haxe.Json.stringify(data)).length>16384)throw "This item contains too much data to list.";
        return data;
    }
    /** A requested item is detached native state, never an inventory claim. */
    public static function buySnapshot(buy:MarketBuy,server:String,app:Dynamic,player:Dynamic):Dynamic {
        if(server=="")throw "The connected server could not be identified. Reconnect before posting a buy order.";
        var total=buy.offers?0:MarketQuantity.totalPrice(buy.quantity,buy.unitTrays);
        if(!MarketQuantity.valid(buy.quantity,1,10000)||total==null)
            throw "Choose a valid quantity and a total price of 1 to 200,000 Silver Trays.";
        var quantity=Std.parseInt(buy.quantity),trays:Int=total;
        var character=G.text(G.field(G.field(app,"connectionInfo"),"heroID"));
        if(player==null||character==""||character=="0")throw "Your character is still loading. Try again shortly.";
        if(buy.selected==null)throw "Select an item to buy first.";
        buy.updatePreview();
        var data:Dynamic={schemaVersion:2,orderType:"buy",server:server,gameVersion:G.text(G.staticCall("Config","getVersion",[])),
            character:{id:character,name:G.text(G.call("st.Player","getName",player))},item:buyItem(buy,quantity),
            price:buy.offers?{mode:"offers"}:{mode:"fixed",silverTrays:trays}};
        if(haxe.io.Bytes.ofString(haxe.Json.stringify(data)).length>16384)throw "This item contains too much data to list.";
        return data;
    }
    /** Duplicate checks use the requested details even while price/quantity inputs are incomplete. */
    public static function buyItem(buy:MarketBuy,quantity=1):Dynamic {
        if(buy.selected==null||buy.nativePreview==null||buy.preview==null)
            throw "This item's requested details could not be prepared. Refresh and choose it again.";
        var item=itemData(buy.nativePreview,buy.preview,quantity);
        if(!buy.selected.gear||buy.anyLevel){Reflect.deleteField(item,"requiredLevel");Reflect.deleteField(item,"itemLevel");}
        return item;
    }
    /** The same item state is used for submission and account-wide duplicate checks. */
    public static function itemData(item:Dynamic,offer:TradeItem,quantity:Int):Dynamic {
        var p=TradeInventory.preview(item),rarity=G.text(G.field(G.staticCall("HItem","getRarity",[G.field(item,"inf")]),"id"));
        p.flags&=3;
        if(!trade.TradePreview.valid(p))throw "This item's modifiers are not supported yet.";
        return {baseId:offer.kind,quantity:quantity,rarity:rarity,
            requiredLevel:G.integer(G.call("st.Item","getRequiredLevel",item)),itemLevel:G.integer(G.call("st.Item","getILevel",item)),
            upgradeLevel:p.upgrade,prismatic:(p.flags&2)!=0,flawless:(p.flags&1)!=0,
            stats:[],modifiers:[],native:p,detail:offer.detail};
    }
    public static function offer(row:Dynamic):TradeItem {
        var i=row.item,p:TradeItemPreview=i.native;
        if(!trade.TradePreview.valid(p))throw "Update the mod to inspect this listing.";
        var detail:String=i.detail==null?"":i.detail;
        if(p==null||StringTools.trim(detail)==""||detail==G.text(i.rarity)) {
            var lines=[G.text(i.rarity)];
            if(G.integer(i.upgradeLevel)>0)lines.push("Upgrade +"+MarketText.number(i.upgradeLevel));
            if(Std.isOfType(i.stats,Array)) for(stat in (cast i.stats:Array<Dynamic>))lines.push(G.text(stat.name)+": "+MarketText.number(stat.value)+(stat.unit=="percent"?"%":""));
            if(Std.isOfType(i.modifiers,Array))for(m in (cast i.modifiers:Array<Dynamic>))lines.push(G.text(m.name));
            detail=lines.join("\n");
        }
        var kind=G.text(i.baseId),serverName=G.text(i.name,kind);
        // A seller's API name can be English. Resolve the stable base ID in
        // this client's native game-data catalogue first.
        var localName="";
        try localName=TradeInventory.itemName(kind) catch(_:Dynamic){}
        var displayName=localName!=""&&localName!=kind&&localName.indexOf("::")<0?localName:serverName;
        return {uid:"",kind:i.baseId,count:i.quantity,name:MarketText.itemName(kind,displayName,TradeInventory.itemName),detail:MarketText.detail(detail,TradeInventory.skillName,p==null?"":p.infusion),
            color:0xDAC9AA,fingerprint:"",preview:p};
    }
}
