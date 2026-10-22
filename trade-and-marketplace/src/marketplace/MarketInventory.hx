package marketplace;

import trade.GameAccess as G;
import trade.TradeInventory;

/** Read-only listing sources. Direct trades continue to use the backpack only. */
class MarketInventory {
    /** Display-only distinction after canDrop failed. Item Utilities blocks the
        permission wrapper; the native check still reports Ok for a locked,
        otherwise tradable item. Never use this check to authorize a listing. */
    public static function locked(source:TradeInventory,stack:{index:Int,item:Dynamic,count:Int}):Bool {
        if(source==null||stack==null)return false;
        return G.enumName(G.call("st.Inventory","checkRequestDropIndex",source.inventory,[stack.index,true,1]))=="Ok";
    }
    public static function bankNames(backpack:TradeInventory):Array<String> {
        if(backpack==null)return [];
        var banks=G.array(G.field(G.field(backpack.hero,"loadout"),"banks"),true);
        var tabs=G.array(G.field(G.field(backpack.player,"accountProgress"),"bankTabs"),true);
        return [for(source in sources(backpack,true)) {
            var i=banks.indexOf(source.inventory);
            var name=i<tabs.length?StringTools.trim(G.text(G.field(tabs[i],"name"))):"";
            name==""?"Bank "+(i+1):name;
        }];
    }
    public static function slotCount(source:TradeInventory):Int {
        if(source==null)return 0;
        var content=G.array(G.field(source.inventory,"content"));
        var count=G.integer(G.call("st.Inventory","getTotalSlots",source.inventory));
        return Std.int(Math.max(count,content.length));
    }
    public static function filter(items:Array<trade.TradeTypes.TradeItem>,search:String):Array<trade.TradeTypes.TradeItem> {
        var query=StringTools.trim(search).toLowerCase();
        return items.filter(item->query==""||item.name.toLowerCase().indexOf(query)>=0);
    }
    public static function sources(backpack:TradeInventory,bankOnly:Bool):Array<TradeInventory> {
        if(backpack==null)return [];
        var result:Array<TradeInventory>=bankOnly?[]:[backpack];
        if(bankOnly) {
            var loadout=G.field(backpack.hero,"loadout");
            var banks=G.array(G.field(loadout,"banks"),true);
            var count=G.field(G.field(backpack.player,"accountProgress"),"nbBanks");
            var unlocked=Std.int(Math.min(4,count==null?banks.length:G.integer(count)));
            for(bank in banks.slice(0,Std.int(Math.max(0,unlocked)))) {
                if(bank==null||bank==backpack.inventory)continue;
                var duplicate=false;
                for(source in result)if(source.inventory==bank)duplicate=true;
                if(duplicate)continue;
                var source=new TradeInventory(backpack.player);
                source.inventory=bank;result.push(source);
            }
        }
        return result;
    }
    /** Count identical tradable copies, including separate non-stackable items.
        A null scope searches both backpack and unlocked bank tabs. */
    public static function available(backpack:TradeInventory,item:Dynamic,?bankOnly:Bool):Int {
        if(backpack==null||item==null)return 0;
        var identity=MarketItemIdentity.key(item),count=0;
        var scopes=bankOnly==null?[false,true]:[bankOnly];
        for(bank in scopes)for(source in sources(backpack,bank))for(stack in source.stacks()) {
            var kind=G.text(G.field(stack.item,"kind"));
            if((kind!=""&&kind!=G.text(G.field(item,"baseId")))||!source.canDrop(stack,stack.count))continue;
            var offer=TradeInventory.describe(stack.item,stack.count);
            if(MarketItemIdentity.key(MarketExport.itemData(stack.item,offer,stack.count))==identity)
                count=Std.int(Math.min(10000,count+stack.count));
        }
        return count;
    }
    public static function source(backpack:TradeInventory,uid:String,bankOnly:Bool):TradeInventory {
        for(source in sources(backpack,bankOnly))if(source.find(uid)!=null)return source;
        return null;
    }
}
