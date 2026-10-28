import dpsmeter.EncounterCoverage;
import dpsmeter.NativeEncounterCoverage;
import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.Collector;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess as G;

private enum CoverageTarget { Unit(kind:String); }

class EncounterCoverageTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function unit(kind:String = "Boss", active:Bool = false, phase:Int = 1):Dynamic return {
        __uid:kind, kind:kind, name:kind, inf:{flags:0x10}, isInCombat:active, phase:phase,
        health:1000., maxHealth:1000., dead:false, removed:false
    };
    static function layer(boss:Dynamic, state:String = ""):Dynamic return {
        units:[boss], isRift:false, mainActivity:{globalCtx:{dungeonState:state, objectives:{array:[]}}}
    };
    static function recorded(c:NativeEncounterCoverage, target:Dynamic, time:Float):CoverageEvidence {
        var hit = c.damage(target, time);
        check(hit != null, "Encounter damage has coverage evidence");
        return hit.attempt.record(hit);
    }
    static function main():Void {
        world(); dungeon(); phrixes(); phrixesCheckpoint(); rifts(); snapshots(); collectorReconnect();
        Sys.println('Encounter coverage: $checks checks passed');
    }
    static function world():Void {
        var boss = unit(), map = layer(boss), c = new NativeEncounterCoverage();
        c.poll(null, map, "Other"); boss.isInCombat = true;
        check(recorded(c, boss, 10).complete, "An idle boss observed before the opening hit qualifies");
        boss.phase = 2; boss.health = 1000.; c.poll(null, map, "Other");
        check(recorded(c, boss, 30).complete, "Complete evidence survives later full-health phases");
        map.units = []; c.poll(null, map, "Other");
        check(c.interrupted.length == 1 && c.interrupted[0] == "Boss", "Losing a recorded boss invalidates its coverage before any further damage");
        map.units = [boss]; c.poll(null, map, "Other");
        check(!recorded(c, boss, 30.5).complete, "Returning to replication range cannot repair a missed phase");
        var reconnect = new NativeEncounterCoverage(); reconnect.poll(null, map, "Other");
        check(!recorded(reconnect, boss, 31).complete, "Reconnect at full health in phase two is partial");
        boss.phase = 3; c.poll(null, map, "Other"); reconnect.poll(null, map, "Other");
        check(!recorded(reconnect, boss, 40).complete, "Later phases never repair a reconnect");
        boss.isInCombat = false; boss.phase = 1; boss.health = 1000.; reconnect.poll(null, map, "Other");
        boss.isInCombat = true;
        check(recorded(reconnect, boss, 50).complete, "A witnessed reset permits the next attempt");

        boss = unit(); map = layer(boss); c = new NativeEncounterCoverage(); c.poll(null, map, "Other");
        c.damage(boss, 10); // Unknown source or someone outside the recorded party.
        check(!recorded(c, boss, 10).complete, "Even simultaneous later hits cannot replace an unrecorded opening hit");
        boss = unit("Unknown", true); map = layer(boss); c = new NativeEncounterCoverage();
        c.poll(null, map, "Other");
        check(!recorded(c, boss, 20).complete, "An already-active first observation fails closed even at full HP");
        c = new NativeEncounterCoverage();
        check(!recorded(c, unit(), 1).complete, "The first damage RPC cannot establish its own idle baseline");
        boss = unit("Reset", true); boss.health = 500.; map = layer(boss);
        c = new NativeEncounterCoverage(); c.poll(null, map, "Other");
        recorded(c, boss, 10); boss.isInCombat = false; c.poll(null, map, "Other");
        boss.health = 1000.; c.poll(null, map, "Other"); boss.isInCombat = true;
        check(recorded(c, boss, 20).complete, "Reset health can arrive after the combat-exit flag");
    }
    static function dungeon():Void {
        var queen = unit("Cleodora"), mini = unit("Miniboss"), finalBoss = unit("Queenslayer");
        mini.inf.flags = 0; // Ordinary add damage starts Honeyzabeth's timer too.
        var map = layer(queen, "Explo"), ctx = map.mainActivity.globalCtx, c = new NativeEncounterCoverage();
        c.poll(null, map, "Boss Dungeons");
        ctx.dungeonState = "BossStart"; // Opening RPC arrives before the next poll.
        check(recorded(c, mini, 10).complete, "Pre-pull dungeon evidence covers the opening miniboss");
        ctx.dungeonState = "BossPhase"; c.poll(null, map, "Boss Dungeons");
        check(recorded(c, finalBoss, 100).complete, "Queenslayer remains part of the observed original attempt");
        c = new NativeEncounterCoverage(); c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, queen, 110).complete, "Joining Honeyzabeth after minibosses is partial");
        check(!recorded(c, finalBoss, 150).complete, "A new full-health Queenslayer cannot clear that restriction");
        ctx.dungeonState = "BossLoose"; c.poll(null, map, "Boss Dungeons");
        ctx.dungeonState = "BossStart";
        check(recorded(c, mini, 200).complete, "A confirmed dungeon wipe arms the next attempt");

        ctx.dungeonState = "BossPhase";
        var hero:Dynamic = {player:{context:{dungeonState:"Explo"}}};
        c = new NativeEncounterCoverage(); c.poll(hero, map, "Boss Dungeons");
        check(!recorded(c, mini, 210).complete, "An active shared context overrides a lagging personal idle state");
        ctx.dungeonState = ""; c = new NativeEncounterCoverage(); c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, queen, 220).complete, "Missing dungeon start metadata fails closed");
    }
    static function phrixes():Void {
        var boss = unit("Phrixes", true, 1), map = layer(boss, "BossPhase"), c = new NativeEncounterCoverage();
        c.poll(null, map, "Boss Dungeons"); recorded(c, boss, 10);
        boss.phase = 2;
        check(recorded(c, boss, 20).complete, "Observed phase 1-to-2 transition starts Phrixes' ranked portion");
        boss.phase = 3; boss.isInCombat = false; c.poll(null, map, "Boss Dungeons");
        boss.phase = 4; boss.isInCombat = true;
        check(recorded(c, boss, 40).complete, "The bridge preserves phase-two start evidence");
        c = new NativeEncounterCoverage(); boss.phase = 2; c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, boss, 50).complete, "First seeing phase two already underway is partial");
        boss.phase = 3; c.poll(null, map, "Boss Dungeons"); boss.phase = 4;
        check(!recorded(c, boss, 60).complete, "An incomplete phase two stays incomplete after the bridge");
        boss.phase = 1; c = new NativeEncounterCoverage(); c.poll(null, map, "Boss Dungeons");
        map.units = []; c.poll(null, map, "Boss Dungeons");
        boss.phase = 2; map.units = [boss]; c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, boss, 70).complete, "Returning to phase two after losing sight of phase one is not a witnessed transition");
    }
    static function phrixesCheckpoint():Void {
        var boss = unit("Phrixes", false, 2), map = layer(boss, "BossLoose"), c = new NativeEncounterCoverage();
        c.poll(null, map, "Boss Dungeons"); boss.isInCombat = true;
        check(recorded(c, boss, 10).complete, "An observed idle darkness-form checkpoint qualifies without the opening form");

        boss.isInCombat = false; c = new NativeEncounterCoverage();
        check(!recorded(c, boss, 20).complete, "A first damage callback cannot certify a phase-two start by itself");
        c = new NativeEncounterCoverage(); boss.isInCombat = true; c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, boss, 30).complete, "An active phase-two first observation stays partial even at full HP");
        c = new NativeEncounterCoverage(); boss.isInCombat = false; boss.health = 500.; c.poll(null, map, "Boss Dungeons");
        check(!recorded(c, boss, 40).complete, "Idle alone cannot qualify a damaged phase-two boss");
        for (phase in [3, 4]) {
            c = new NativeEncounterCoverage(); boss.phase = phase; boss.health = 1000.; c.poll(null, map, "Boss Dungeons");
            check(!recorded(c, boss, 50 + phase).complete, "An idle full-health later Chakram phase is not a checkpoint start");
        }
        boss = unit("OtherBoss", false, 2); map = layer(boss); c = new NativeEncounterCoverage();
        c.poll(null, map, "Other");
        check(!recorded(c, boss, 60).complete, "The darkness-form exception does not qualify another boss's second phase");
    }
    static function rifts():Void {
        var boss = unit(), map = layer(boss), c = new NativeEncounterCoverage(); map.isRift = true;
        var wait = {kind:"EventWait", completed:false};
        map.mainActivity.globalCtx.objectives.array = ([wait, {kind:"KillBoss", target:CoverageTarget.Unit("Boss")}] : Array<Dynamic>);
        var mob = unit("GateMob"); mob.inf.flags = 0;
        c.poll(null, map, "World Bosses");
        check(c.damage(mob, 1) == null, "Warm-up damage does not consume gates start evidence");
        wait.completed = true;
        check(recorded(c, mob, 10).complete, "An observed countdown covers the first gates hit between polls");
        check(recorded(c, boss, 100).complete, "A completely observed gates phase permits the boss phase");
        c = new NativeEncounterCoverage(); c.poll(null, map, "World Bosses");
        check(!recorded(c, mob, 101).complete, "Joining after the countdown produces a partial rift");
        check(!recorded(c, boss, 200).complete, "A later rift boss cannot repair missing gates coverage");
    }
    static function snapshots():Void {
        var attempt = new EncounterCoverage(); attempt.ready();
        var proof = attempt.record(attempt.damage(10));
        var info:PlayerInfo = {uid:"me", name:"Wink", isMe:true, className:"rogue", weapon:null, classSkills:[], weaponSkills:[]};
        var e:DamageEvent = {time:10, source:"me", amount:10, effect:0, critical:false, kill:false, skill:"Hit",
            target:"boss", bossKind:"Boss", bossFlags:0x10, bossLevel:1, bossFoeId:1, coverage:proof};
        var fight = new Fight(10); fight.add(e, info); fight.last = 20;
        check(fight.recordingComplete && fight.copy().recordingComplete, "Fight snapshots preserve positive evidence");
        fight.interruptRecording("unrelated-boss");
        check(fight.recordingComplete, "Losing an unrelated boss does not invalidate this recording");
        check(FightHistory.decode(FightHistory.encode(fight, "full")).recordingComplete,
            "Complete recordings retain their evidence on disk");
        var late = new Fight(15); late.add(e, info);
        check(!late.recordingComplete, "Restarting the meter cannot reuse an earlier start's evidence");
        fight.interruptRecording(); fight.add(e, info);
        check(!fight.recordingComplete, "A recording gap is sticky even if later hits have valid evidence");
        var record = FightHistory.encode(fight.copy(), "partial");
        check(record.recordingComplete == false && !FightHistory.decode(record).recordingComplete,
            "Partial recordings remain readable and partial after saving/loading");
        Reflect.deleteField(record, "recordingComplete");
        check(!FightHistory.decode(record).recordingComplete, "Legacy history remains readable without assuming completeness");
    }
    static function collectorReconnect():Void {
        G.globals["activities"] = ["CoverageArena" => {types:["Dungeon"]}];
        var boss = unit(), map = layer(boss, "Explo");
        map.config = {activityID:"CoverageArena", difficulty:0};
        map.mainActivity.kind = "CoverageArena";
        map.mainActivity.globalCtx.objectives.array = [{kind:"KillBoss", target:CoverageTarget.Unit("Boss"), completed:false}];
        var hero:Dynamic = {__uid:"me", name:"Wink", player:{isMe:true, heroData:{kind:"rogue"}}, layer:map, isInCombat:false};
        var app:Dynamic = {hero:hero}, c = new Collector(MeterConfig.defaults());
        var hit:Dynamic = {source:hero, weakSource:"me", skill:{kind:"Rogue_Attack"}, _amount:10., effect:0, physical:true};
        c.update(app, 1); map.mainActivity.globalCtx.dungeonState = "BossStart";
        hero.isInCombat = true; boss.isInCombat = true; c.combatEnter("me", 2); c.damage(boss, hit, 2);
        check(c.model.current.recordingComplete, "Real collector marks a fresh pull complete");
        c.update({hero:null}, 3); c.update(app, 4); c.damage(boss, hit, 5);
        check(c.model.current != null && !c.model.current.recordingComplete, "Logout/login resets display but cannot qualify the resumed fight");
        map.mainActivity.globalCtx.dungeonState = "BossPhase"; c.update(app, 6); c.damage(boss, hit, 7);
        check(!c.model.current.recordingComplete, "Collector keeps reconnect restriction through phase changes");
        c.interruptRecording(); c.damage(boss, hit, 8);
        check(!c.model.current.recordingComplete, "Disabling/re-enabling capture cannot restore eligibility");
        hero.isInCombat = false; boss.isInCombat = false;
        map.mainActivity.globalCtx.dungeonState = "BossLoose"; c.update(app, 9); c.update(app, 10);
        map.mainActivity.globalCtx.dungeonState = "BossStart";
        hero.isInCombat = true; boss.isInCombat = true; c.combatEnter("me", 11); c.damage(boss, hit, 11);
        check(c.model.current.recordingComplete, "Collector permits a fresh attempt after a confirmed wipe");
    }
}
