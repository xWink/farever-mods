import dpsmeter.Collector;
import dpsmeter.CombatModel;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess as G;
import dpsmeter.FightHistory;
import dpsmeter.FareverlyContract;

private enum ChakramTarget { Unit(kind:String); }
private typedef ChakramFixture = {
    collector:Collector, model:CombatModel, app:Dynamic, hero:Dynamic, layer:Dynamic,
    ctx:Dynamic, primary:Dynamic, finalGoal:Dynamic, chakram:Dynamic, night:Dynamic, gate:Dynamic, damage:Dynamic
};

/** Exercise the production collector, objective metadata, model and recording
    coverage together. NightGod gates are summons, not ordinary boss targets. */
class CollectorChakramHeroicTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function fixture(heroic:Bool = true, reconnect:Bool = false, stale:Bool = false):ChakramFixture {
        G.globals["Main.get_branchName"] = true; G.globals["gameBranch"] = "MAIN";
        G.globals["activities"] = ["ChakramArena" => {types:["Dungeon"]}];
        var primary:Dynamic = {kind:"KillBoss", target:ChakramTarget.Unit("Phrixes"), completed:reconnect};
        var finalGoal:Dynamic = {kind:"KillBossAlt", target:ChakramTarget.Unit("Phrixes_NightGod"), completed:stale, blocked:true};
        var ctx:Dynamic = {dungeonState:reconnect ? "BossPhase" : "Explo", objectives:{array:heroic ? [primary, finalGoal] : [primary]}};
        var layer:Dynamic = {isRift:false, config:{activityID:"ChakramArena", difficulty:heroic ? 2 : 1},
            mainActivity:{kind:"ChakramArena", bossId:"Phrixes", globalCtx:ctx}};
        ctx.layer = layer; ctx.activity = layer.mainActivity;
        var player:Dynamic = {isMe:true, heroData:{kind:"rogue"}, context:ctx};
        var hero:Dynamic = {__uid:"me", name:"Wink", player:player, layer:layer, isInCombat:false};
        var chakram:Dynamic = {__uid:"chakram", kind:"Phrixes", name:"High Inquisitor Chakram", layer:layer,
            phase:1, health:1000., maxHealth:1000., isInCombat:false, inf:{flags:0x10}, _level:30, foeId:1};
        var night:Dynamic = {__uid:"night", kind:"Phrixes_NightGod", name:"Final boss", layer:layer,
            phase:1, health:1000., maxHealth:1000., isInCombat:true, inf:{flags:0x10}, _level:30, foeId:2};
        var gate:Dynamic = {__uid:"gate", kind:"Phrixes_NightGodGate", name:"Gate", layer:layer,
            summonOwner:night, health:1000., maxHealth:1000., inf:{flags:0x10}, _level:30, foeId:3};
        layer.units = reconnect ? [night, gate] : [chakram];
        var app:Dynamic = {hero:hero};
        var collector = new Collector(MeterConfig.defaults()); collector.update(app, 1);
        var damage:Dynamic = {source:hero, weakSource:"me", skill:{kind:"Rogue_Attack"}, _amount:100.,
            _critical:false, _kill:false, effect:0, physical:true, magical:false};
        return {collector:collector, model:collector.model, app:app, hero:hero, layer:layer, ctx:ctx,
            primary:primary, finalGoal:finalGoal, chakram:chakram, night:night, gate:gate, damage:damage};
    }
    static function hit(f:ChakramFixture, target:Dynamic, time:Float, amount:Float = 100, kill:Bool = false):Void {
        f.damage._amount = amount; f.damage._kill = kill; f.collector.damage(target, f.damage, time);
    }
    static function start(f:ChakramFixture):Fight {
        f.ctx.dungeonState = "BossPhase"; f.hero.isInCombat = true; f.chakram.isInCombat = true;
        f.collector.combatEnter("me", 10); hit(f, f.chakram, 10);
        check(f.model.current == null && f.model.history.length == 0, "Opening health bar stays live-only");
        f.chakram.phase = 2; f.collector.update(f.app, 20);
        hit(f, f.chakram, 21);
        check(f.model.current != null && f.model.current.start == 21 && f.model.current.recordingComplete,
            "Observed surrender starts a fresh, complete ranked recording");
        return f.model.current;
    }
    static function transition(f:ChakramFixture):Void {
        f.chakram.phase = 4; f.chakram.dead = true; f.chakram.isInCombat = false;
        hit(f, f.chakram, 30, 200, true); f.collector.targetDeath(f.chakram, 30);
        f.primary.completed = true; f.hero.isInCombat = false;
        f.collector.combatExit("me", 30); f.collector.update(f.app, 31);
    }
    static function spawnFinal(f:ChakramFixture):Void {
        f.chakram.removed = true; f.layer.units = [];
        f.collector.update(f.app, 31.5);
        f.layer.units = [f.night, f.gate]; f.finalGoal.blocked = false;
        f.collector.update(f.app, 32);
    }
    static function main():Void {
        victory(); lateSurrenderHit(); deathBeforeObjective(); wipeAndRetry(); objectiveOrdering(); partial(); normal(); replacement();
        Sys.println('Chakram Heroic collector: $checks checks passed');
    }
    static function lateSurrenderHit():Void {
        for (polled in [false, true]) for (knownSource in [false, true]) {
            var f = fixture();
            f.ctx.dungeonState = "BossPhase"; f.hero.isInCombat = true; f.chakram.isInCombat = true;
            f.collector.combatEnter("me", 10); hit(f, f.chakram, 10);
            f.chakram.phase = 2;
            if (polled) f.collector.update(f.app, 20);
            // The phase can replicate before the first bar's lethal damage RPC.
            // CombatModel deliberately excludes that hit from the ranked clock.
            if (!knownSource) { f.damage.source = null; f.damage.weakSource = ""; }
            hit(f, f.chakram, 20.1, 500, true);
            f.damage.source = f.hero; f.damage.weakSource = "me";
            check(f.model.current == null, "Late surrender damage does not start the ranked fight");
            hit(f, f.chakram, 21);
            var fight = f.model.current;
            check(fight != null && fight.start == 21 && fight.recordingComplete,
                "A late first-bar lethal RPC cannot consume the ranked opening hit");
            transition(f); spawnFinal(f); hit(f, f.gate, 33);
            f.finalGoal.completed = true; f.ctx.dungeonState = "BossWin";
            f.collector.update(f.app, 34); f.collector.update(f.app, 35);
            check(FareverlyContract.candidate(FightHistory.encode(f.model.history[0], "late-surrender")),
                "A fully observed run with out-of-order surrender damage remains uploadable");
        }
    }
    static function deathBeforeObjective():Void {
        var f = fixture(), fight = start(f);
        f.chakram.phase = 4; f.chakram.dead = true; f.chakram.isInCombat = false;
        hit(f, f.chakram, 30, 200, true); f.collector.targetDeath(f.chakram, 30);
        f.chakram.removed = true; f.layer.units = [f.night, f.gate];
        f.collector.update(f.app, 31);
        check(fight.recordingComplete && !fight.defeated,
            "Observed Chakram death may precede objective replication and entity removal");
        f.primary.completed = true; f.finalGoal.blocked = false; f.collector.update(f.app, 32);
        hit(f, f.gate, 33, 300, true); f.night.dead = true; f.collector.targetDeath(f.night, 33);
        f.night.removed = true; f.layer.units = []; f.collector.update(f.app, 33.5);
        check(fight.recordingComplete && !fight.defeated,
            "Observed final-boss death preserves coverage while waiting for its objective");
        f.finalGoal.completed = true; f.ctx.dungeonState = "BossWin";
        f.collector.update(f.app, 34); f.collector.update(f.app, 35);
        var saved = f.model.history[0];
        check(saved.outcome == "Victory" && FareverlyContract.candidate(FightHistory.encode(saved, "death-ordering")),
            "Removal before objective replication cannot make a fully recorded victory partial");
    }
    static function victory():Void {
        var f = fixture(), fight = start(f); transition(f);
        check(f.model.current == fight && !fight.defeated && f.model.history.length == 0 && f.model.completed.length == 0,
            "Chakram's death and lethal hit cannot archive Heroic victory");
        spawnFinal(f);
        check(f.model.current == fight && fight.recordingComplete, "Expected original-boss unload preserves complete coverage");
        hit(f, f.gate, 33, 300, true);
        check(f.model.current == fight && fight.players["me"].damage == 600 && fight.start == 21,
            "Gate damage after local combat exit stays in the original encounter");
        check(fight.bossKind == "Phrixes" && fight.bossUid == "chakram" && fight.bossName == "High Inquisitor Chakram"
            && fight.bossLevel == 30 && fight.recordingComplete, "Summoned gates keep Chakram identity and complete recording");
        f.collector.targetDeath(f.night, 33); f.night.dead = true; f.night.isInCombat = false;
        f.collector.dungeonVictory(f.ctx, 33);
        check(!fight.defeated, "Neither final-boss death nor a banner replaces the required final objective");
        // Replicated hero combat exit can lag behind objective completion.
        f.hero.isInCombat = true; f.collector.combatEnter("me", 33.5);
        f.finalGoal.completed = true; f.ctx.dungeonState = "BossWin";
        f.collector.update(f.app, 34);
        check(f.model.current == null && fight.closed == 34, "Both completed objectives end the encounter even without another hero exit");
        var lastGate = Reflect.copy(f.gate); lastGate.__uid = "last-gate";
        hit(f, lastGate, 34.1, 400, true); f.collector.update(f.app, 35);
        check(f.model.history.length == 1 && f.model.completed.length == 0, "Final callbacks save exactly one encounter");
        var saved = f.model.history[0], record = FightHistory.encode(saved, "chakram-heroic");
        check(saved.outcome == "Victory" && saved.duration() == 13 && saved.players["me"].damage == 1000,
            "Late lethal gate damage reconciles without changing the frozen completion time");
        check(record.recordingComplete && FareverlyContract.candidate(record), "The fully recorded victory qualifies for upload");
    }
    static function wipeAndRetry():Void {
        var f = fixture(), fight = start(f); transition(f); spawnFinal(f); hit(f, f.gate, 33, 200, true);
        // A death callback still cannot replace the required final objective.
        f.collector.targetDeath(f.night, 39);
        f.night.removed = true; f.night.isInCombat = false; f.layer.units = [];
        f.ctx.dungeonState = "BossLoose"; f.collector.update(f.app, 40); f.collector.update(f.app, 41.1);
        check(f.model.history.length == 1 && f.model.history[0].outcome == "Defeat" && fight.closed == 40,
            "Wiping after Chakram's death remains a defeat despite killed boss/gate entries");
        // A checkpoint retry can reuse the original entity. It must not inherit
        // the last attempt's completion evidence, clock, damage, or gate UID.
        f.primary.completed = false; f.finalGoal.completed = false;
        f.chakram.dead = false; f.chakram.removed = false; f.chakram.phase = 1; f.chakram.isInCombat = false;
        f.layer.units = [f.chakram]; f.ctx.dungeonState = "Explo"; f.collector.update(f.app, 45);
        f.chakram.phase = 2; f.chakram.isInCombat = true; f.hero.isInCombat = true; f.ctx.dungeonState = "BossPhase";
        f.collector.update(f.app, 46); hit(f, f.chakram, 47, 25);
        check(f.model.current != fight && f.model.current.start == 47 && f.model.current.players["me"].damage == 25
            && !f.model.current.defeated && f.model.current.recordingComplete, "A witnessed retry gets fresh attempt state");
        f.layer.units = []; f.collector.update(f.app, 47.5);
        check(!f.model.current.recordingComplete, "The previous attempt's death cannot excuse losing a live retry boss");
        f.model.reset(48);
        check(f.model.history.length == 2 && f.model.history[1].outcome == "Defeat", "Leaving a retry cannot turn it into victory");
    }
    static function objectiveOrdering():Void {
        var f = fixture(true, false, true), fight = start(f); transition(f); spawnFinal(f);
        hit(f, f.gate, 33); f.collector.update(f.app, 34);
        check(f.model.current == fight && !fight.defeated, "A stale completed alternate objective cannot win a new attempt");
        f.night.isInCombat = false; f.ctx.dungeonState = "BossLoose";
        f.collector.update(f.app, 40); f.collector.update(f.app, 41.1);
        check(f.model.history.length == 1 && f.model.history[0].outcome == "Defeat", "Stale completion plus a retry wipe stays a defeat");

        f = fixture(); fight = start(f); f.chakram.phase = 4; f.finalGoal.completed = true;
        f.collector.update(f.app, 30);
        check(f.model.current == fight && !fight.defeated, "The alternate goal alone cannot win while the primary goal is incomplete");
        f.primary.completed = true; f.collector.update(f.app, 31); f.collector.update(f.app, 32);
        check(f.model.history.length == 1 && f.model.history[0].outcome == "Victory",
            "Out-of-order objective replication still recognizes both completed goals");
    }
    static function partial():Void {
        var f = fixture(true, true); f.hero.isInCombat = true; f.collector.combatEnter("me", 10);
        hit(f, f.gate, 11); var fight = f.model.current;
        check(fight != null && fight.bossKind == "Phrixes" && !fight.recordingComplete,
            "Reconnecting during the gates labels Chakram but cannot fabricate start coverage");
        f.finalGoal.completed = true; f.ctx.dungeonState = "BossWin";
        f.collector.update(f.app, 20); f.collector.update(f.app, 21);
        var saved = f.model.history[0], record = FightHistory.encode(saved, "partial-chakram");
        check(saved.outcome == "Victory" && !record.recordingComplete && !FareverlyContract.candidate(record),
            "Partial final-phase victory is kept locally and cannot upload");

        f = fixture(); fight = start(f); f.collector.interruptRecording(); transition(f); spawnFinal(f);
        hit(f, f.gate, 33); f.finalGoal.completed = true;
        f.collector.update(f.app, 34); f.collector.update(f.app, 35);
        check(!f.model.history[0].recordingComplete, "A gap before the final phase remains partial at victory");

        f = fixture(); fight = start(f); transition(f); spawnFinal(f);
        f.layer.units = []; f.collector.update(f.app, 33);
        check(!fight.recordingComplete, "Losing the live final boss from replication invalidates the original recording");
        f.layer.units = [f.night, f.gate]; f.collector.update(f.app, 34); hit(f, f.gate, 35);
        check(!fight.recordingComplete, "Returning to the gates never repairs a missed portion");
        f.collector.targetDeath(f.night, 35.1); f.night.removed = true; f.layer.units = [];
        f.finalGoal.completed = true; f.ctx.dungeonState = "BossWin";
        f.collector.update(f.app, 36); f.collector.update(f.app, 37);
        check(!FareverlyContract.candidate(FightHistory.encode(f.model.history[0], "gap-then-death")),
            "A later witnessed death cannot repair an earlier recording gap");

        f = fixture(); f.chakram.phase = 2; f.chakram.isInCombat = true; f.ctx.dungeonState = "BossPhase";
        f.collector = new Collector(MeterConfig.defaults()); f.model = f.collector.model;
        f.collector.update(f.app, 20); f.hero.isInCombat = true; f.collector.combatEnter("me", 20);
        hit(f, f.chakram, 20.1, 500, true); hit(f, f.chakram, 21);
        check(!f.model.current.recordingComplete, "Ignoring surrender damage cannot qualify a reconnect into phase two");
    }
    static function normal():Void {
        var f = fixture(false), fight = start(f); transition(f); f.collector.update(f.app, 32);
        check(f.model.history.length == 1 && f.model.history[0].outcome == "Victory" && fight.closed == 30,
            "Normal Chakram still ends at his own final death");
    }
    static function replacement():Void {
        var f = fixture(), fight = start(f); transition(f);
        var next = Reflect.copy(f.chakram); next.__uid = "next-chakram"; next.dead = false; next.phase = 2; next.isInCombat = true;
        f.layer.units = [next]; f.primary.completed = false; f.collector.update(f.app, 32);
        check(f.model.current == null && fight.bossUid == "chakram" && fight.closed == 32,
            "A replacement boss closes the old attempt without stealing its identity");
        f.hero.isInCombat = true; f.collector.combatEnter("me", 33); hit(f, next, 33, 50); f.collector.update(f.app, 34);
        check(f.model.history.length == 1 && f.model.history[0].outcome == "Defeat" && f.model.current.bossUid == "next-chakram"
            && f.model.current.players["me"].damage == 50, "The replacement starts a separate attempt");
    }
}
