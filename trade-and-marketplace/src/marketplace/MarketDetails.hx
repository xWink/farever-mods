package marketplace;

import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTooltips;
import trade.TradeTypes;

/** Native tooltip descriptions, preserving modifier values, colours and icons. */
class MarketDetails {
    public static function text(offer:TradeItem,?item:Dynamic):Null<String> {
        if(item==null)item=TradeTooltips.previewItem(offer);
        if(item==null||!G.isA(item,"st.item.Gear"))return null;
        var lines=affixes(G.call("st.Item","getItemAffixes",item));
        // Infusion labels are plain text; modifier markup below comes only from
        // the game's validated item definitions, never from a listing's text.
        for(line in MarketText.detail(offer.detail,TradeInventory.skillName).split("\n"))
            if(StringTools.startsWith(line,"Infusion:" )||StringTools.startsWith(line,"Infusion bonus:"))
                lines.push(trade.TradeUi.escape(line));
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
