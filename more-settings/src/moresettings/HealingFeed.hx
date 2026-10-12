package moresettings;

import moresettings.GameAccess as G;

/** Native displayHeal appends one heal row only when scaled healing is >= 1. */
class HealingFeed {
    public static function lastAddedRow(feed:Dynamic, damage:Dynamic):Dynamic {
        if (feed == null || damage == null) return null;
        var amount = G.number(G.call("st.skill.DamageResult", "get_amount", damage));
        var scale = G.number(G.call("st.skill.DamageResult", "getDynamicScalingFactor", damage));
        if (amount * scale < 1) return null;
        // Performance backlog trimming can remove older rows during addLine.
        var lines = G.field(feed, "activeLines");
        var count = G.integer(G.field(lines, "length"));
        if (count == 0) return null;
        var line = G.call("hl.types.ArrayObj", "getDyn", lines, [count - 1]);
        var element = G.field(line, "elt");
        var dom = G.field(element, "dom");
        return dom != null && G.call("domkit.Properties", "hasClass", dom, ["heal"]) == true ? element : null;
    }
}
