package moresettings;

import moresettings.GameAccess as G;
import moresettings.SkillClassifier.SkillFacts;

class NativeSkillFacts {
    static var cache:Map<String, {inf:Dynamic, value:Bool}> = [];
    static var factsCache:Map<String, SkillFacts> = [];

    public static function clear():Void { cache = []; factsCache = []; }

    public static function beneficial(skill:Dynamic):Bool {
        var inf = G.field(skill, "inf");
        var id = G.text(G.field(inf, "id"));
        var old = cache[id];
        if (old != null && old.inf == inf) return old.value;
        var value = SkillClassifier.beneficial(facts(inf), lookup);
        if (id != "") cache[id] = {inf: inf, value: value};
        return value;
    }

    static function lookup(id:String):Null<SkillFacts> {
        if (factsCache.exists(id)) return factsCache[id];
        var inf = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "skill"), "byId"), [id]);
        if (inf == null) return null;
        var result = facts(inf);
        factsCache[id] = result;
        return result;
    }

    static function facts(inf:Dynamic):SkillFacts {
        var result:SkillFacts = {damage: false, beneficial: false, offensiveStatus: false, references: []};
        var props = G.field(inf, "props");
        for (entry in G.array(G.field(G.field(props, "status"), "types"))) {
            var id = G.text(G.field(entry, "type"));
            var visited:Map<String, Bool> = [];
            while (id != "" && !visited.exists(id)) {
                visited[id] = true;
                if (id == "Buff") result.beneficial = true;
                if (id == "Debuff") result.offensiveStatus = true;
                var status = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "statusType"), "byId"), [id]);
                var flags = G.integer(G.field(status, "flags"));
                if ((flags & 8) != 0) result.beneficial = true; // HoT
                if ((flags & 7) != 0) result.offensiveStatus = true; // DoT / CC
                id = G.text(G.field(status, "parent"));
            }
        }
        for (sub in G.array(G.field(props, "subskills"))) reference(result, G.field(sub, "skill"));
        for (step in G.array(G.field(inf, "steps"))) {
            var stepProps = G.field(step, "props");
            var status = G.field(stepProps, "status");
            reference(result, G.field(status, "ref"));
            reference(result, G.field(stepProps, "targetSkill"));
            // An ally-facing area is useful even when its on-hit script supplies
            // the buff, rather than the declarative effects array.
            if ((G.integer(G.field(G.field(stepProps, "area"), "hitFilter")) & 6) != 0)
                result.beneficial = true;
            for (effect in G.array(G.field(step, "effects"))) {
                var type = G.integer(G.field(effect, "effect"), -1);
                var alignment = G.field(effect, "alignment");
                var friendly = alignment == null || (G.integer(alignment) & 6) != 0;
                if (type == 0) result.damage = true;
                if (friendly && (type == 1 || type == 2)) result.beneficial = true;
                if (friendly && type == 3) {
                    if (G.number(G.field(effect, "baseVal")) > 0) result.beneficial = true;
                    for (scale in G.array(G.field(effect, "scaling")))
                        if (G.number(G.field(scale, "ratio")) > 0) result.beneficial = true;
                }
                reference(result, G.field(effect, "status"));
            }
        }
        return result;
    }

    static function reference(facts:SkillFacts, id:Dynamic):Void {
        var value = G.text(id);
        if (value != "" && facts.references.indexOf(value) < 0) facts.references.push(value);
    }
}
