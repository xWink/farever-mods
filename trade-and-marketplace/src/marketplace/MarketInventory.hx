package marketplace;

import trade.GameAccess as G;
import trade.TradeInventory;

/** Read-only listing sources. Direct trades continue to use the backpack only. */
class MarketInventory {
    public static function sources(backpack:TradeInventory,bankOnly:Bool):Array<TradeInventory> {
        if(backpack==null)return [];
        var result:Array<TradeInventory>=bankOnly?[]:[backpack];
        if(bankOnly) {
            var loadout=G.field(backpack.hero,"loadout");
            for(bank in G.array(G.field(loadout,"banks"),true)) {
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
    public static function source(backpack:TradeInventory,uid:String,bankOnly:Bool):TradeInventory {
        for(source in sources(backpack,bankOnly))if(source.find(uid)!=null)return source;
        return null;
    }
}
