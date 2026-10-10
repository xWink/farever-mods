package dpsmeter;

import dpsmeter.CombatModel.DamageEvent;

/** Healing output includes overheal; effective healing cannot be measured reliably. */
class HealingStats {
    public var output:Float = 0;
    public var hits:Int = 0;
    public var crits:Int = 0;
    public var knownCritHits:Int = 0;
    public var estimatedHits:Int = 0;
    public var unknownOutputHits:Int = 0;
    public var unattributedHits:Int = 0;
    public var casts:Int = 0;
    public var lastHit:Float = -1;
    public function new() {}
    public function add(e:DamageEvent):Void {
        output += e.amount; hits++;
        if (e.unknownHealingCrit != true) { knownCritHits++; if (e.critical) crits++; }
        if (e.estimatedHealing == true) estimatedHits++;
        if (e.unknownHealing == true) unknownOutputHits++;
        if (e.unattributedHealing == true) unattributedHits++;
        if (lastHit < 0 || e.time - lastHit > .350) casts++;
        lastHit = e.time;
    }
    public function copy():HealingStats {
        var s = read(json()); s.lastHit = lastHit; return s;
    }
    public function json():Dynamic return {output: output,
        hits: hits, crits: crits, casts: casts, knownCritHits: knownCritHits,
        estimatedHits: estimatedHits, unknownOutputHits: unknownOutputHits,
        unattributedHits: unattributedHits};
    /** Imports retain output but never copy obsolete effective-healing fields. */
    public static function outputRecord(value:Dynamic):Dynamic {
        if (value == null) return null;
        var result = read(value).json();
        Reflect.setField(result, "skills", [for (s in FightHistory.array(value.skills)) {
            var skill = read(s).json(); Reflect.setField(skill, "id", FightHistory.text(s.id)); skill;
        }]);
        return result;
    }
    public static function read(value:Dynamic):HealingStats {
        var s = new HealingStats();
        if (value == null) return s;
        s.output = FightHistory.number(value.output);
        s.hits = Std.int(FightHistory.number(value.hits));
        s.crits = Std.int(FightHistory.number(value.crits)); s.casts = Std.int(FightHistory.number(value.casts));
        // Older healing logs contained only exact notifications.
        s.knownCritHits = value.knownCritHits == null ? s.hits : Std.int(FightHistory.number(value.knownCritHits));
        s.estimatedHits = Std.int(FightHistory.number(value.estimatedHits));
        s.unknownOutputHits = Std.int(FightHistory.number(value.unknownOutputHits));
        s.unattributedHits = Std.int(FightHistory.number(value.unattributedHits));
        return s;
    }
}
