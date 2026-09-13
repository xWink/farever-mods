package moresettings;

typedef SkillFacts = {
    var damage:Bool;
    var beneficial:Bool;
    var offensiveStatus:Bool;
    var references:Array<String>;
}

/** Conservatively keep mixed damage/support abilities in the buffs category. */
class SkillClassifier {
    public static function beneficial(root:SkillFacts, lookup:String->Null<SkillFacts>):Bool {
        var pending = [root];
        var seen:Map<String, Bool> = [];
        var offensive = false;
        while (pending.length > 0) {
            var facts = pending.pop();
            if (facts.beneficial) return true;
            offensive = offensive || facts.damage || facts.offensiveStatus;
            for (id in facts.references) {
                if (id == "" || seen.exists(id)) continue;
                seen[id] = true;
                var next = lookup(id);
                if (next != null) pending.push(next);
            }
        }
        // Utility abilities with no damage are never removed by attack hiding.
        return !offensive;
    }
}
