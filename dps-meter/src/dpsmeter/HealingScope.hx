package dpsmeter;

import dpsmeter.CombatModel;

/** Holds only meter-owned data, never a live native HitData/skill/hero. */
class HealingScope {
    var fights:Array<Fight>;
    var info:PlayerInfo;
    public var combat(default, null):Bool = false;
    public function new(fights:Array<Fight>, info:PlayerInfo, session:Fight) {
        this.fights = fights; this.info = info;
        for (f in fights) { f.pendingHealing++; if (f != session) combat = true; }
    }
    public function finish(?event:DamageEvent):Void {
        for (f in fights) {
            if (event != null) {
                var end = f.last;
                f.add(event, info);
                // Healing cannot extend a boss's damage clock or a closed fight.
                f.last = end;
            }
            f.pendingHealing--;
        }
        fights = [];
    }
}
