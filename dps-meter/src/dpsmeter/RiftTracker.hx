package dpsmeter;

import dpsmeter.CombatModel;

/** One continuous gates encounter followed by one continuous boss encounter. */
class RiftTracker {
    static inline var FINAL_DAMAGE_SECONDS:Float = 0.5;
    var phase:Int = 0; // 0: monsters, 1: boss, 2: finished
    var fights:Array<Null<Fight>> = [null, null];
    var ended:Array<Float> = [-1, -1];
    var exported:Array<Bool> = [false, false];
    public var current(get, never):Null<Fight>;
    public var last(get, never):Null<Fight>;

    public function new() {}

    function get_current():Null<Fight> return phase < 2 ? fights[phase] : null;
    function get_last():Null<Fight> {
        if (ended[1] >= 0 && fights[1] != null) return fights[1];
        return ended[0] >= 0 ? fights[0] : null;
    }

    public function updateState(now:Float, gatesFinished:Bool, bossDefeated:Bool):Void {
        if (phase == 0 && (gatesFinished || bossDefeated)) {
            finish(0, now);
            phase = 1;
        }
        if (phase == 1 && bossDefeated) {
            finish(1, now);
            phase = 2;
        }
    }

    function finish(index:Int, now:Float):Void {
        ended[index] = now;
        var fight = fights[index];
        if (fight == null) return;
        fight.last = Math.max(fight.start, now);
        fight.closed = now;
        fight.defeated = true;
    }

    public function record(e:DamageEvent, info:PlayerInfo, difficulty:Int, activityId:String, me:String):Void {
        // RiftContext.onFoeKilled uses bit 16 for the final boss. The ordinary
        // meter's wider mask also includes elites encountered during waves.
        var bossHit = e.effect != 1 && (e.bossFlags & 16) != 0;
        if (phase == 0 && bossHit) updateState(e.time, true, false);
        var index = phase == 2 ? 1 : phase;
        if (phase >= 1 && !bossHit) {
            // A final wave kill can arrive after the gates objective completes.
            if (e.kill && e.time <= ended[0] + FINAL_DAMAGE_SECONDS
                && (fights[1] == null || (fights[0] != null && fights[0].targets.exists(e.target)))) index = 0;
            else if (fights[1] == null) return; // Start the boss timer on its first hit.
        }
        var fight = fights[index];
        var closed = ended[index] >= 0;
        if (closed) {
            // Allow late lethal RPCs before exporting, including a one-shot
            // whose objective completion arrived before its only damage event.
            if (!e.kill || e.effect == 1 || exported[index] || e.time < ended[index]
                || e.time > ended[index] + FINAL_DAMAGE_SECONDS) return;
            if (index == 1 && (!bossHit || (fight != null && fight.bossUid != e.target))) return;
        }
        if (fight == null) {
            if (e.effect == 1) return;
            fight = new Fight(e.time);
            fight.phase = index == 0 ? "rift phase" : "boss phase";
            fight.isBoss = index == 1;
            fight.bossName = index == 0 ? "Rift phase" : "Boss phase";
            fight.difficulty = difficulty;
            fight.activityId = activityId;
            fight.me = me;
            fights[index] = fight;
        }
        var end = fight.last;
        fight.add(e, info);
        if (closed) {
            fight.last = end;
            fight.closed = Math.max(fight.start, ended[index]);
            fight.defeated = true;
        }
        if (bossHit && index == 1) {
            fight.bossKind = e.bossKind;
            fight.bossName = e.bossName != null && e.bossName != "" ? e.bossName : e.bossKind;
            fight.bossUid = e.target;
            fight.bossLevel = e.bossLevel;
            fight.bossFoeId = e.bossFoeId;
            if (e.kill && phase == 1) updateState(e.time, true, true);
        }
    }

    public function drain(now:Float, completed:Array<Fight>, force:Bool = false):Void {
        for (index in 0...2) {
            if (ended[index] < 0 || exported[index] || (!force && now < ended[index] + FINAL_DAMAGE_SECONDS)) continue;
            exported[index] = true;
            if (fights[index] != null) completed.push(fights[index]);
        }
    }
}
