package trade;
import trade.TradeTypes;
class TradePreview {
    public static function integer(v:Dynamic, min:Int, max:Int):Bool return Std.isOfType(v, Int) && v >= min && v <= max;
    public static function valid(v:Dynamic):Bool {
        if (v == null) return true;
        if (!Reflect.isObject(v) || Std.isOfType(v,String) || Std.isOfType(v,Array)) return false;
        if (!integer(v.flags,0,0x7fffffff) || !integer(v.level,0,10000) || !integer(v.upgrade,0,100)) return false;
        for (key in ["rarity","infusion","bonus","mastery"]) if (!TradeOffer.str(Reflect.field(v,key),120)) return false;
        if (!Std.isOfType(v.slots,Array) || !Std.isOfType(v.effects,Array)) return false;
        var slots:Array<Dynamic> = v.slots, effects:Array<Dynamic> = v.effects;
        if (slots.length > 16 || effects.length > 8) return false;
        for (s in slots) if (!TradeOffer.str(s,120)) return false;
        for (e in effects) if (e == null || !Reflect.isObject(e) || Std.isOfType(e,String) || Std.isOfType(e,Array)
            || !TradeOffer.str(e.skill,120) || e.skill == "" || e.source != "RoguePoison") return false;
        return haxe.Json.stringify(canonical(v)).length <= 1800;
    }
    public static function canonical(p:TradeItemPreview):Dynamic return p == null ? null :
        [p.flags,p.level,p.upgrade,p.rarity,p.infusion,p.bonus,p.mastery,p.slots,[for(e in p.effects) [e.skill,e.source]]];
    public static function copy(p:TradeItemPreview):TradeItemPreview return p == null ? null : {
        flags:p.flags,level:p.level,upgrade:p.upgrade,rarity:p.rarity,infusion:p.infusion,bonus:p.bonus,mastery:p.mastery,
        slots:p.slots.copy(),effects:[for(e in p.effects) {skill:e.skill,source:e.source}]
    };
}
