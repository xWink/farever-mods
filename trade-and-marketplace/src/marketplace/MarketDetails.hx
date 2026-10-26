package marketplace;

import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTooltips;
import trade.TradeTypes;

/** Native tooltip descriptions, preserving modifier values, colours and icons. */
class MarketDetails {
    public static function text(offer:TradeItem,?item:Dynamic,buyOrder=false):Null<String> {
        var hasNativeState=item!=null||offer.preview!=null;
        if(item==null)item=TradeTooltips.previewItem(offer);
        if(item==null||!G.isA(item,"st.item.Gear"))return null;
        var lines=affixes(G.call("st.Item","getItemAffixes",item));
        if(hasNativeState) {
            // Reconstructed item state is authoritative. The optional saved
            // summary can be absent, outdated, or written in another language.
            var infusion=G.text(G.field(item,"infusion")),bonus=G.text(G.field(item,"infusionBonusStat"));
            if(infusion!="")lines.push(trade.TradeUi.escape("Infusion: "+TradeInventory.skillName(infusion)));
            if(bonus!="") {
                var definition=G.call("haxe.ds.StringMap","get",G.field(G.current("Data","attribute"),"byId"),[bonus]);
                var name=G.text(G.field(definition,"name"));
                lines.push(trade.TradeUi.escape("Infusion bonus: "+(name!=""?name:bonus)));
            } else if(buyOrder&&G.staticCall("HInfusion","canBeInfused",[TradeInventory.definition(offer.kind)])==true)
                lines.push("Infusion bonus: Any");
        } else {
            // Legacy listings without an instance snapshot only have a summary.
            for(line in MarketText.detail(offer.detail,TradeInventory.skillName).split("\n"))
                if(StringTools.startsWith(line,"Infusion:")||StringTools.startsWith(line,"Infusion bonus:"))
                    lines.push(trade.TradeUi.escape(line));
        }
        for(slot in G.array(G.field(item,"slots"),true)) {
            var id=G.text(slot);
            if(id=="")continue;
            var definition=TradeInventory.definition(id);
            if(definition==null)continue;
            // Use the database's native String ID for the game's affix cache.
            var nativeId=G.field(definition,"id");
            lines.push("[!"+id+"]");
            if(G.array(G.field(definition,"skills")).length>0) {
                var desc=G.text(G.staticCall("HText","item",[definition,G.enumeration("ETextKind","Desc"),null]));
                if(desc!="")lines.push(desc);
            }
            lines=lines.concat(affixes(G.call("st.item.Gear","getSlotAffixes",item,[nativeId])));
        }
        if(G.isA(item,"st.item.Weapon"))for(effect in G.array(G.call("st.item.Weapon","getEffects",item,[null]))) {
            var text=G.text(G.staticCall("HText","weaponEffect",[effect]));
            if(text!="")lines.push(text);
        }
        return lines.join("\n");
    }
    static function affixes(values:Dynamic):Array<String> {
        if(values==null)return [];
        return [for(value in G.array(G.staticCall("HText","makeAfxDescTextsComparisons",[values,null,null])))G.text(value)];
    }
}
