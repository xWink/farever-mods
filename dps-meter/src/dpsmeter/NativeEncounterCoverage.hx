package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.EncounterCoverage;

private typedef ObservedBoss = {
    unit:Dynamic, attempt:EncounterCoverage, phase:Int, engaged:Bool, ready:Bool
};

/** Client-replicated evidence only. combatStartTime is a local clock and
    full health alone cannot distinguish a fresh pull from a new boss phase. */
class NativeEncounterCoverage {
    public var interrupted(default, null):Array<String> = [];
    var dungeon = new EncounterCoverage();
    var dungeonState = "";
    var dungeonMode = false;
    var riftMode = false;
    var rift = new EncounterCoverage();
    var riftBoss:Null<EncounterCoverage>;
    var riftBossKind = "";
    var riftWait:Dynamic;
    var dungeonContext:Dynamic;
    var dungeonGlobal:Dynamic;
    var bosses:Map<String, ObservedBoss> = [];
    var phrixesDungeon = false;
    var phrixesAttempt:Null<EncounterCoverage>;
    var phrixesEntry:Null<ObservedBoss>;
    var phrixesFinalUid = "";
    var phrixesDead = false;
    var phrixesFinalDead = false;

    public function new() {}

    public function poll(hero:Dynamic, layer:Dynamic, category:String):Void {
        interrupted = [];
        riftMode = G.field(layer, "isRift") == true;
        dungeonMode = !riftMode && (category == "Boss Dungeons" || category == "Classic Dungeons");
        var activity = G.field(layer, "mainActivity");
        var context = activity == null ? null : G.call("st.Player", "getActivityContext", G.field(hero, "player"), [activity]);
        var global = G.field(activity, "globalCtx");
        if (context == null) context = global;
        if (riftMode) {
            // An incomplete EventWait is the pre-gates countdown. A completed
            // countdown on first observation is not proof of the rift's start.
            for (objective in G.array(G.field(context, "objectives"), true)) {
                var kind = G.text(G.field(objective, "kind"));
                if (kind == "EventWait") {
                    riftWait = objective;
                    if (G.call("st.Objective", "isCompleted", objective) == true) rift.begin();
                    else rift.ready();
                }
                if (kind == "KillBoss") {
                    var target = G.field(objective, "target");
                    if (target != null && Type.enumConstructor(target) == "Unit")
                        riftBossKind = G.text(Type.enumParameters(target)[0]);
                }
            }
            return;
        }
        if (dungeonMode) {
            dungeonContext = context; dungeonGlobal = global;
            observeDungeon();
        }
        phrixesDungeon = dungeonMode && (G.text(G.field(activity, "bossId")) == "Phrixes"
            || NativeCombatMetadata.dungeonBoss(G.text(G.field(activity, "kind"))) == "Phrixes");
        var phrixesDefeated = phrixesDungeon
            && NativeCombatMetadata.dungeonBossCompletion(G.field(hero, "player"), activity, "Phrixes") == true;
        var finalDefeated = phrixesDungeon
            && NativeCombatMetadata.dungeonBossCompletion(G.field(hero, "player"), activity, "Phrixes_NightGod", "KillBossAlt") == true;
        var seen:Map<String, Bool> = [];
        for (unit in G.array(G.field(layer, "units"))) {
            if (phrixesDungeon && G.text(G.field(unit, "kind")) == "Phrixes_NightGod"
                && G.field(unit, "removed") != true) {
                var uid = G.uid(unit);
                if (phrixesFinalUid != uid) phrixesFinalDead = false;
                phrixesFinalUid = uid; seen[uid] = true;
            }
            if (!bossUnit(unit)) continue;
            if (dungeonMode && G.text(G.field(unit, "kind")) != "Phrixes") continue;
            var uid = G.uid(unit);
            if (uid == "" || uid == "0") continue;
            seen[uid] = true;
            observeBoss(unit);
        }
        // Leaving replication range during an attempt loses coverage too.
        for (uid => entry in bosses) if (!seen.exists(uid)) {
            // Death/removal can replicate before the objective. A witnessed
            // death ends this entity's coverage, not the shared encounter.
            if (entry == phrixesEntry && (phrixesDefeated || phrixesDead)) continue;
            if (entry.attempt.complete()) interrupted.push(uid);
            entry.attempt.interrupt();
            // A phase first seen after returning to range is not an observed
            // transition from the last phase seen before the gap.
            entry.phase = -1; entry.engaged = false; entry.ready = false;
        }
        if (phrixesFinalUid != "" && !seen.exists(phrixesFinalUid) && !finalDefeated && !phrixesFinalDead && phrixesAttempt != null) {
            if (phrixesEntry != null && phrixesAttempt.complete()) interrupted.push(G.uid(phrixesEntry.unit));
            phrixesAttempt.interrupt();
        }
    }

    /** The replicated death RPC is distinct from removal/range loss. This only
        prevents a false coverage gap; objectives still decide Heroic victory. */
    public function death(target:Dynamic):Void {
        if (!phrixesDungeon || phrixesAttempt == null) return;
        var uid = G.uid(target), kind = G.text(G.field(target, "kind"));
        if (uid == "" || uid == "0") return;
        if (kind == "Phrixes" && phrixesEntry != null && G.uid(phrixesEntry.unit) == uid
            && G.integer(G.field(target, "phase")) > 2) phrixesDead = true;
        else if (kind == "Phrixes_NightGod" && (phrixesFinalUid == "" || phrixesFinalUid == uid)) {
            phrixesFinalUid = uid; phrixesFinalDead = true;
        }
    }

    static function bossUnit(unit:Dynamic):Bool return unit != null && G.field(unit, "summonOwner") == null
        && G.field(unit, "player") == null && (G.integer(G.field(G.field(unit, "inf"), "flags")) & 0x38) != 0;

    function observeDungeon():Void {
        var state = G.text(G.field(dungeonContext, "dungeonState"));
        var shared = G.text(G.field(dungeonGlobal, "dungeonState"));
        // A lagging personal Explo state cannot override an active shared one.
        // These are the shipped DungeonState string constants.
        if (shared == "BossStart" || shared == "BossPhase") state = shared;
        if (state == "BossLoose" || state == "Explo") {
            if (state != dungeonState && dungeonState != "") dungeon = new EncounterCoverage();
            dungeon.ready();
        } else if (state == "BossStart" || state == "BossPhase" || state == "BossWin") dungeon.begin();
        if (state != "") dungeonState = state;
    }

    function observeBoss(unit:Dynamic, allowReset:Bool = true):ObservedBoss {
        var uid = G.uid(unit), phase = G.integer(G.field(unit, "phase"), -1);
        var phrixes = G.text(G.field(unit, "kind")) == "Phrixes";
        var active = G.field(unit, "isInCombat") == true;
        var alive = G.field(unit, "removed") != true && G.call("ent.GameObject", "isDead", unit) != true;
        var hp = G.number(G.call("ent.Unit", "get_health", unit), -1);
        var max = G.number(G.call("ent.Unit", "get_maxHealth", unit), -1);
        // Chakram retries start in the darkness form (phase 2), never replaying
        // the excluded opening form. Seeing that reset boss idle at full HP
        // before damage is a valid start, even without a 1-to-2 transition.
        // Active phase 2 and later full-health phases cannot arm a recording.
        var ready = alive && G.field(unit, "isInCombat") == false && phase >= 0 && phase <= (phrixes ? 2 : 1)
            && max > 0 && hp >= max;
        var entry = bosses[uid];
        if (entry == null) {
            entry = {unit:unit, attempt:new EncounterCoverage(), phase:phase,
                engaged:active || (max > 0 && hp < max), ready:ready};
            bosses[uid] = entry;
            if (ready) entry.attempt.ready(); else entry.attempt.begin();
        } else {
            // Phrixes' first bar is deliberately local-only. The ranked fight
            // starts at phase 2; phases 3 and 4 must retain the same evidence.
            if (phrixes && entry.unit == unit && entry.phase == 1 && phase == 2) {
                entry.attempt = new EncounterCoverage(); entry.attempt.ready();
            } else if (allowReset && ready && !entry.ready
                && (entry.engaged || entry.phase > phase || (phrixes && phase == 2))) {
                // Respawning can put the old boss out of replication range.
                // Its freshly observed idle checkpoint is still a new pull;
                // prior fights retain their own sticky incomplete status.
                entry.attempt = new EncounterCoverage(); entry.attempt.ready();
                entry.engaged = false;
            }
            if (active || !alive || (max > 0 && hp < max)) entry.attempt.begin();
            if (active || (max > 0 && hp < max)) entry.engaged = true;
            entry.unit = unit; entry.phase = phase; entry.ready = ready;
        }
        if (phrixes) trackPhrixes(entry);
        return entry;
    }

    function trackPhrixes(entry:ObservedBoss):Void {
        if (phrixesAttempt != entry.attempt) {
            phrixesFinalUid = ""; phrixesDead = false; phrixesFinalDead = false;
        }
        phrixesEntry = entry; phrixesAttempt = entry.attempt;
    }

    /** Called before source/party filtering, including damage we cannot record. */
    public function damage(target:Dynamic, now:Float, killingHit:Bool = false):Null<CoverageHit> {
        if (target == null || G.field(target, "player") != null) return null;
        var kind = G.text(G.field(target, "kind"));
        // These summoned gates are the actual Heroic final-phase targets.
        if (G.field(target, "summonOwner") != null && !(phrixesDungeon && kind == "Phrixes_NightGodGate")) return null;
        // Opening hits can precede the next roster poll. Read the cached
        // replicated context, without scanning all units for every damage RPC.
        if (dungeonMode) observeDungeon();
        if (riftMode) {
            if (riftWait != null && G.call("st.Objective", "isCompleted", riftWait) != true) return null;
            if (riftBossKind != "" && G.text(G.field(target, "kind")) == riftBossKind) {
                if (riftBoss == null) {
                    riftBoss = new EncounterCoverage();
                    if (rift.complete()) riftBoss.ready();
                }
                return riftBoss.damage(now);
            }
            return riftBoss == null ? rift.damage(now) : riftBoss.damage(now);
        }
        if (phrixesDungeon && kind != "Phrixes") {
            // Do not replace phase-two start evidence with the dungeon state
            // or a newly spawned full-health final boss. Reconnects stay partial.
            if (phrixesAttempt == null) phrixesAttempt = new EncounterCoverage();
            return phrixesAttempt.damage(now);
        }
        if (G.text(G.field(target, "kind")) != "Phrixes" && dungeonMode && (dungeonState == "BossStart" || dungeonState == "BossPhase"
            || dungeonState == "BossWin" || bossUnit(target))) return dungeon.damage(now);
        if (!bossUnit(target)) return null;
        // Never establish an idle baseline from the opening hit itself: this
        // RPC may be a replay on login or a new full-health phase.
        var entry = bosses[G.uid(target)];
        if (entry == null) {
            entry = {unit:target, attempt:new EncounterCoverage(), phase:G.integer(G.field(target, "phase"), -1),
                engaged:true, ready:false};
            bosses[G.uid(target)] = entry;
            if (kind == "Phrixes") trackPhrixes(entry);
        } else entry = observeBoss(target, false);
        // Surrender's lethal first-bar RPC can arrive after phase 2. The model
        // excludes it from the ranked fight, so it must not consume that fight's
        // first hit or start time. Still observe the phase transition above.
        if (kind == "Phrixes" && killingHit && G.integer(G.field(target, "phase")) <= 2) return null;
        return entry.attempt.damage(now);
    }
}
