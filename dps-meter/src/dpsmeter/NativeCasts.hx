package dpsmeter;

import dpsmeter.GameAccess as G;

/** Resolve child skills, statuses and summons to the skill responsible for them. */
class NativeCasts {
    public static function passive(skill:Dynamic):Bool {
        var inf = G.field(skill, "inf");
        return inf != null && G.staticCall("HSkill", "isPassive", [inf]) == true;
    }
    public static function applicationDriven(skill:Dynamic):Bool {
        var inf = G.field(skill, "inf");
        return inf != null && (G.staticCall("HSkill", "isPassive", [inf]) == true
            || G.staticCall("HSkill", "isStatus", [inf]) == true);
    }
    /** Whether an effect came from a summon of this same originating skill. */
    public static function summonEffect(skill:Dynamic, originSkill:Dynamic):Bool {
        var seen:Array<Dynamic> = [];
        while (skill != null && seen.length < 16 && seen.indexOf(skill) < 0) {
            seen.push(skill);
            var source = G.call(hl.Type.getDynamic(skill).getTypeName(), "getSourceObject", skill);
            var summonSkill = G.field(source, "summonSourceSkill");
            if (summonSkill != null && origin(summonSkill) == originSkill) return true;
            if (skill == originSkill) break;
            var instigator = G.field(skill, "instigatorSkill");
            skill = instigator != null ? instigator : G.field(skill, "parent");
            if (skill != null && G.field(skill, "kind") == null) break;
        }
        return false;
    }
    public static function item(skill:Dynamic):String {
        if (skill == null) return "";
        return G.text(G.field(G.call("st.skill.BaseSkill", "getSourceItem", skill), "kind"));
    }
    /** ConsumeItem is shared by different items; retain the actual item ID. */
    public static function id(skill:Dynamic):String {
        var kind = G.text(G.field(skill, "kind"));
        if (kind == "ConsumeItem") {
            var sourceItem = item(skill);
            if (sourceItem != "") return sourceItem;
        }
        return kind;
    }
    public static function origin(skill:Dynamic):Dynamic {
        if (skill == null) return null;
        try {
            var source = G.call(hl.Type.getDynamic(skill).getTypeName(), "getSourceSkill", skill);
            return source == null ? skill : source;
        } catch (_:Dynamic) return skill;
    }
}
