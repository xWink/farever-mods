package dpsmeter;

import dpsmeter.GameAccess as G;

/** Read client-visible ownership/scaling without running server heal logic or RNG. */
class NativeHealing {
    public static function owner(source:Dynamic, skill:Dynamic):{source:Dynamic, skill:Dynamic} {
        if (source == null && skill != null)
            source = G.call(hl.Type.getDynamic(skill).getTypeName(), "getSourceObject", skill);
        var seen:Array<Dynamic> = [];
        while (source != null && seen.length < 16 && seen.indexOf(source) < 0) {
            seen.push(source);
            var summonSkill = G.field(source, "summonSourceSkill");
            var parent = G.field(source, "summonOwner");
            if (summonSkill != null) {
                var origin = G.call(hl.Type.getDynamic(summonSkill).getTypeName(), "getSourceSkill", summonSkill);
                if (G.text(G.field(origin, "kind")) != "") skill = origin;
                if (parent == null && origin != null)
                    parent = G.call(hl.Type.getDynamic(origin).getTypeName(), "getSourceObject", origin);
            }
            if (parent == null || parent == source) break;
            source = parent;
        }
        if (source != null) source = G.call("ent.GameObject", "resolveProxy", source);
        return {source: source, skill: skill};
    }
    public static function key(skill:Dynamic, step:Int):String {
        return G.text(G.field(skill, "kind")) + "/" + G.uid(skill) + "/" + step;
    }
    public static function estimate(hit:Dynamic, target:Dynamic):Null<Float> {
        var step = G.field(hit, "step"), skill = G.field(step, "baseSkill");
        if (step == null || G.field(hit, "ctx") == null || skill == null) return null;
        var sum = 0.0, found = false;
        for (effect in G.array(G.field(G.field(step, "inf"), "effects"))) {
            // HSkill.getEffectRange returns zero for Heal. Never evaluate a
            // damage effect here: that path can advance the game's RNG.
            if (G.integer(G.field(effect, "effect"), -1) != 1) continue;
            var heroic = G.field(effect, "heroic");
            if (heroic != null) {
                var difficulty = G.integer(G.field(G.field(G.field(target, "layer"), "config"), "difficulty"), -1);
                var force = G.field(G.current("Config", "prefs"), "forceHeroic") == true;
                if (heroic != (difficulty == 2 || force)) continue;
            }
            var alignment = G.field(effect, "alignment");
            if (alignment != null && G.call("st.skill.BaseSkill", "checkAlignment", skill, [target, alignment]) != true) continue;
            var amount = G.number(G.staticCall("HSkill", "getStepEffectVal", [effect, hit]), Math.NaN);
            if (!Math.isFinite(amount)) return null;
            sum += Math.max(0, amount); found = true;
        }
        // Rank/attribute scaling, status stacks and tick spreading are included.
        // Server evalHeal scripts, crit rolls and final modifiers are NOT.
        return found && sum > 0 ? sum : null;
    }
}
