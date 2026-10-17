package dpsmeter;

import dpsmeter.GameAccess as G;

/** Resolve child skills, statuses and summons to the skill responsible for them. */
class NativeCasts {
    public static function origin(skill:Dynamic):Dynamic {
        if (skill == null) return null;
        try {
            var source = G.call(hl.Type.getDynamic(skill).getTypeName(), "getSourceSkill", skill);
            return source == null ? skill : source;
        } catch (_:Dynamic) return skill;
    }
}
