package trade;
import trade.GameAccess as G;
import trade.TradeTypes;
class TradeTooltips {
    public static function create(offer:TradeItem,inv:TradeInventory):Dynamic {
        try {
            var s = inv == null ? null : inv.find(offer.uid);
            var item = s != null && TradeInventory.fingerprint(s.item) == offer.fingerprint ? s.item : null;
            if (item == null) item = previewItem(offer);
            return item == null ? null : G.staticCall("ui.Tooltip","fromItem",[G.field(item,"inf"),item]);
        } catch(e:Dynamic) { TradeDiagnostics.log("Item tooltip: "+e); return null; }
    }
    public static function previewItem(offer:TradeItem):Dynamic {
        var p = offer.preview;
        if (!TradePreview.valid(p) || TradeInventory.definition(offer.kind) == null) return null;
        if (p != null) {
            if (!known("rarity",p.rarity) || !known("skill",p.infusion) || !known("attribute",p.bonus)) return null;
            for (s in p.slots) if (!known("item",s)) return null;
            for (e in p.effects) if (!known("skill",e.skill)) return null;
            if (p.mastery != "" && lookup(G.current("DataCache","SKILLS_MASTERIES"),p.mastery) == null) return null;
        }
        // Never borrow a remote UID or attach a network host to this display-only object.
        var item = G.staticCall("st.Item","create",[offer.kind,null]);
        if (item == null || G.field(item,"__host") != null) return null;
        if (p != null) {
            var flags = G.create("hxbit.EnumFlagsData",[null]); G.set(flags,"value",p.flags); G.set(item,"flags",flags);
            if (G.isA(item,"st.item.Gear")) {
                G.set(item,"level",p.level); G.set(item,"upgradeLevel",p.upgrade); G.set(item,"infusion",nullable(p.infusion)); G.set(item,"infusionBonusStat",nullable(p.bonus));
                // The game's affix cache compares enum parameters using its own String class.
                // Inserting mod-owned strings into a dynamic array can show gift names while
                // missing their cached affix values. Keep the database's native IDs here.
                G.set(item,"slots",proxy([for(s in p.slots) s == "" ? null : G.field(TradeInventory.definition(s),"id")]));
            }
            if (G.isA(item,"st.item.Weapon")) {
                G.set(item,"rarity",nullable(p.rarity));
                G.set(item,"effects",proxy([for(e in p.effects) {skill:e.skill,source:G.enumeration("st.item.WeaponEffectSource",e.source)}]));
            }
            if (G.isA(item,"st.item.Mastery")) G.set(item,"mastery",nullable(p.mastery));
        }
        G.call("st.Item","makeInf",item); return item;
    }
    static function nullable(s:String):String return s == "" ? null : s;
    static function lookup(map:Dynamic,key:String):Dynamic return map == null ? null : G.call("haxe.ds.StringMap","get",map,[key]);
    static function known(table:String,key:String):Bool return key == "" || lookup(G.field(G.current("Data",table),"byId"),key) != null;
    static function proxy(values:Array<Dynamic>):Dynamic {
        var array = G.create("hl.types.ArrayDyn",[]);
        for (v in values) G.call("hl.types.ArrayDyn","push",array,[v]);
        return G.create("hxbit.ArrayProxyData",[array]);
    }
}
