package dpsmeter;

import dpsmeter.CombatModel.DamageEvent;

/** Healing output includes overheal. Effective healing is observed separately. */
class HealingStats {
    public var output:Float = 0;
    public var actual:Float = 0;
    public var measuredOutput:Float = 0;
    public var hits:Int = 0;
    public var measuredHits:Int = 0;
    public var crits:Int = 0;
    public var knownCritHits:Int = 0;
    public var estimatedHits:Int = 0;
    public var unknownOutputHits:Int = 0;
    public var estimatedActualHits:Int = 0;
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
        if (e.actualHealing != null && Math.isFinite(e.actualHealing)) {
            actual += Math.max(0, Math.min(e.amount, e.actualHealing));
            measuredOutput += e.amount; measuredHits++;
            if (e.estimatedActual == true) estimatedActualHits++;
        }
    }
    public function complete():Bool return hits == measuredHits;
    public function copy():HealingStats {
        var s = read(json()); s.lastHit = lastHit; return s;
    }
    public function json():Dynamic return {output: output, actual: actual, measuredOutput: measuredOutput,
        overheal: complete() && unknownOutputHits == 0 ? Math.max(0, output - actual) : null,
        hits: hits, measuredHits: measuredHits, crits: crits, casts: casts, knownCritHits: knownCritHits,
        estimatedHits: estimatedHits, unknownOutputHits: unknownOutputHits,
        estimatedActualHits: estimatedActualHits, unattributedHits: unattributedHits};
    public static function read(value:Dynamic):HealingStats {
        var s = new HealingStats();
        if (value == null) return s;
        s.output = FightHistory.number(value.output); s.actual = FightHistory.number(value.actual);
        s.measuredOutput = FightHistory.number(value.measuredOutput);
        s.hits = Std.int(FightHistory.number(value.hits)); s.measuredHits = Std.int(FightHistory.number(value.measuredHits));
        s.crits = Std.int(FightHistory.number(value.crits)); s.casts = Std.int(FightHistory.number(value.casts));
        // Older healing logs contained only exact notifications.
        s.knownCritHits = value.knownCritHits == null ? s.hits : Std.int(FightHistory.number(value.knownCritHits));
        s.estimatedHits = Std.int(FightHistory.number(value.estimatedHits));
        s.unknownOutputHits = Std.int(FightHistory.number(value.unknownOutputHits));
        s.estimatedActualHits = Std.int(FightHistory.number(value.estimatedActualHits));
        s.unattributedHits = Std.int(FightHistory.number(value.unattributedHits));
        return s;
    }
}
