package dpsmeter;

import dpsmeter.MeterConfig.MeterSettings;
import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

class Collector {
    public var model:CombatModel;
    public var timeline:NativeTimeline;
    var config:MeterSettings;
    var hero:Dynamic;
    var layer:Dynamic;
    var lastRoster:Float = -1;
    var lastGroupSeen:Float = -1;
    var groupMembers:Map<String, Bool> = [];
    var profileRefresh:Map<String, Float> = [];
    var profileWeapons:Map<String, Dynamic> = [];
    var phrixes:Dynamic;
    var cleodora:Dynamic;
    var queenslayer:Dynamic;
    var honeyzabethTransition:Bool = false;
    var riftWait:Dynamic;
    var coverage = new NativeEncounterCoverage();
    var appliedStatuses:Map<String, Bool> = [];
    var countedSummons:Map<String, Bool> = [];
    var countedBombletAreas:Map<String, Bool> = [];
    var goldenBombletUntil:Map<String, Float> = [];
    // Replicated proc steps are authoritative execution evidence, but a single
    // activation may play multiple steps (e.g. a pair of Unstable Bomblets).
    // Group only near-simultaneous steps; never estimate casts from hit count.
    static inline var PROC_BURST:Float = 0.15;
    var recentProcSteps:Map<String, Float> = [];
    var recentProcStatuses:Map<String, Float> = [];
    public function new(config:MeterSettings, ?timeline:NativeTimeline) {
        this.config = config;
        this.timeline = timeline;
        if (timeline != null) healingCapture.onRecorded = e -> {
            try timeline.healed(e) catch (error:Dynamic) timeline.report(error);
        };
        var version = "";
        try version = G.text(G.staticCall("Config", "getVersion", []))
        catch (error:Dynamic) trace("[DPS Meter] Could not read game version: " + Std.string(error));
        var branch=GameBranch.capture(version);
        model = new CombatModel(haxe.Timer.stamp(), version, branch);
    }
    public function update(app:Dynamic, now:Float):Void {
        var nextHero = G.field(app, "hero");
        var nextLayer = G.field(nextHero, "layer");
        if (hero != nextHero || layer != nextLayer) {
            healingCapture.flush(now, true);
            model.reset(now); hero = nextHero; layer = nextLayer;
            groupMembers = []; lastGroupSeen = -1; lastRoster = -1;
            profileRefresh = []; profileWeapons = [];
            phrixes = null;
            cleodora = null;
            queenslayer = null; honeyzabethTransition = false;
            riftWait = null;
            coverage = new NativeEncounterCoverage();
            appliedStatuses = [];
            countedSummons = [];
            countedBombletAreas = []; goldenBombletUntil = [];
            recentProcSteps = []; recentProcStatuses = [];
        }
        healingCapture.flush(now);
        if (timeline != null) timeline.update(hero, now);
        if (hero == null) return;
        if (now - lastRoster < 0.25) return;
        lastRoster = now;
        var mine = profile(hero);
        if (mine == null) return;
        model.me = mine.uid;
        var player = G.field(hero, "player");
        var group = G.field(player, "group");
        var inRift = G.field(layer, "isRift") == true;
        if (inRift) model.enableRift();
        var roster:Array<Dynamic> = [];
        if (inRift) roster = G.array(G.field(layer, "players"), true);
        else if (group != null) roster = G.array(G.field(group, "players"), true);
        var members:Map<String, Bool> = [];
        var hasMe = false;
        for (p in roster) {
            if (p == player || G.field(p, "isMe") == true) hasMe = true;
            var h = G.field(p, "hero");
            var info = profile(h);
            if (info == null) continue;
            members[info.uid] = true;
        }
        if (hasMe) { groupMembers = members; lastGroupSeen = now; }
        else if (now - lastGroupSeen > 5) groupMembers = [];
        model.party = inRift ? members : groupMembers.copy();
        model.party[mine.uid] = true;
        if (!inRift && !hasMe && now - lastGroupSeen > 5) {
            var names = [for (s in config.group.split(",")) StringTools.trim(s).toLowerCase()];
            for (p in model.profiles) if (names.indexOf(p.name.toLowerCase()) >= 0) model.party[p.uid] = true;
        }
        var layerConfig = G.field(layer, "config");
        model.difficulty = G.integer(G.field(layerConfig, "difficulty"), -1);
        model.activityId = G.text(G.field(layerConfig, "activityID"));
        if (model.activityId == "") model.activityId = G.text(G.field(G.field(layer, "mainActivity"), "kind"));
        // Objectives can arrive after entering the map; keep checking at the
        // roster's 4 Hz cadence. Completion does not remove the clearing goal.
        model.activityCategory = NativeCombatMetadata.activityCategory(model.activityId, inRift, player, G.field(layer, "mainActivity"));
        try {
            coverage.poll(hero, layer, model.activityCategory);
            for (uid in coverage.interrupted) model.interruptRecording(uid);
        } catch (_:Dynamic) interruptRecording();
        refreshDungeonBoss(inRift);
        if (inRift) updateRiftState(player, now);
        refreshPhrixes(now);
        // Encounter timing must not depend on optional lobby/report metadata.
        var localInCombat = G.field(hero, "isInCombat") == true;
        // Teammates, or Honeyzabeth's active miniboss phase, can prolong an
        // existing encounter. Neither starts the local meter without damage.
        var displayed = model.displayedFight();
        var partyInCombat = displayed != null && displayed.closed == 0 && (!localInCombat || !model.inCombat)
            && (PartyCombat.active(hero) || honeyzabethInCombat());
        model.update(now, localInCombat, partyInCombat);
        if (group != null && model.activityId != "" && model.difficulty < 0) {
            // Never assign a stale lobby from another dungeon to an open-world boss.
            var lobbies = G.array(G.field(group, "instanceLobbies"), true);
            for (lobby in lobbies) {
                var activity = G.text(G.field(lobby, "activityId"));
                if (activity != model.activityId) continue;
                model.difficulty = G.integer(G.field(lobby, "difficulty"), -1);
            }
        }
    }
    public function skillUse(skill:Dynamic, sourceContext:Dynamic):Void {
        if (!config.enabled || hero == null || skill == null || sourceContext != null
            || G.field(skill, "simulatingServer") == true) return;
        // Child/status/summon starts are consequences, not another activation.
        if (NativeCasts.origin(skill) != skill || NativeCasts.passive(skill)) return;
        var owner = G.field(skill, "owner");
        if (profile(owner) == null) return;
        model.recordCast(G.uid(owner), NativeCasts.id(skill));
    }
    /** Disabling collection or losing a damage callback leaves a real gap. */
    public function interruptRecording():Void {
        model.interruptRecording();
        coverage = new NativeEncounterCoverage();
    }
    /** Count the server-replicated execution of a passive infusion/enchant.
        One proc may hit several targets or play multiple client steps. Do not
        infer an activation from any damage/healing notification. */
    public function procStep(skill:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || skill == null || !Math.isFinite(now)
            || G.field(skill, "simulatingServer") == true) return;
        var origin = NativeCasts.origin(skill);
        if (!NativeCasts.stepDrivenProc(origin)) return;
        var source = NativeHealing.owner(null, origin).source;
        if (profile(source) == null) return;
        var uid = G.uid(source), id = NativeCasts.id(origin);
        if (uid == "" || uid == "0" || id == "") return;
        var key=uid+"/"+id;
        var last=recentProcSteps.get(key);
        if (last!=null && now>=last && now-last<PROC_BURST) return;
        // Avoid counting twice if the same passive first applied a periodic
        // status and then replicated the corresponding client skill step.
        var status=recentProcStatuses.get(key);
        if (status!=null && now>=status && now-status<PROC_BURST) return;
        recentProcSteps[key]=now;
        model.recordCast(uid,id);
    }

    /** Unstable Bomblets does not play a passive client skill step. The
        game's Infusion_Kobold_DPS.onInflictDamage instead creates a SkillArea
        with a "Bomblet" or "GoldenBomblet" step. Observe that replicated
        area once, not its later damage hits or tick events.

        Golden bomblets spawn several child Bomblet areas on their first
        tick. Ignore those near the parent explosion, while letting later
        independent normal procs count separately. */
    public function bombletArea(area:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || area == null || !Math.isFinite(now)
            || G.field(area, "simulatingServer") == true) return;
        var root = NativeCasts.origin(G.field(area, "baseSkill"));
        var id = NativeCasts.id(root);
        if (id != "Infusion_Kobold_DPS") return;
        var stepKind = G.text(G.call("st.skill.SkillArea", "get_stepKind", area));
        if (stepKind != "Bomblet" && stepKind != "GoldenBomblet") return;
        var areaUid = G.uid(area);
        if (areaUid == "" || areaUid == "0" || countedBombletAreas.exists(areaUid)) return;
        var source = NativeHealing.owner(null, root).source;
        if (profile(source) == null) return;
        var uid = G.uid(source);
        if (uid == "" || uid == "0") return;
        // The same area may initialize or be observed through replication
        // more than once; count its identity even if it is a child fragment.
        countedBombletAreas[areaUid] = true;
        var key = uid + "/" + id;
        var recentGolden = goldenBombletUntil.get(key);
        if (stepKind == "Bomblet" && recentGolden != null && now < recentGolden) return;
        if (stepKind == "GoldenBomblet") {
            // The golden first tick creates its fragments after the parent
            // area is established. Use the native duration if available, but
            // never hold suppression across a long fight.
            var seconds = G.number(G.field(area, "duration"));
            goldenBombletUntil[key] = now + Math.min(2.5, Math.max(0.6, seconds + 0.3));
        }
        var last = recentProcSteps.get(key);
        if (last != null && now >= last && now - last < PROC_BURST) return;
        var status = recentProcStatuses.get(key);
        if (status != null && now >= status && now - status < PROC_BURST) return;
        recentProcSteps[key] = now;
        model.recordCast(uid, id);
    }

    public function statusApplied(status:Dynamic, refreshed = false):Void {
        if (!config.enabled || hero == null || status == null || G.field(status, "simulatingServer") == true
            || G.call("st.skill.Status", "isPeriodic", status) != true) return;
        var origin = NativeCasts.origin(status);
        // Active abilities already count at Skill.start. Passive DoTs/HoTs have
        // no such activation: count each application/refresh, never each tick.
        if (origin != status && !NativeCasts.applicationDriven(origin)) return;
        // A summoned unit's periodic attacks belong to the summon cast too.
        if (NativeCasts.summonEffect(status, origin)) return;
        var owner = NativeHealing.owner(null, status).source;
        if (profile(owner) == null) return;
        var instance = G.uid(status);
        if (instance == "" || instance == "0" || (!refreshed && appliedStatuses.exists(instance))) return;
        appliedStatuses[instance] = true;
        var uid=G.uid(owner), id=NativeCasts.id(origin);
        if (NativeCasts.stepDrivenProc(origin)) {
            var now=haxe.Timer.stamp(), key=uid+"/"+id;
            var step=recentProcSteps.get(key);
            // A replicated step for this same passive may create the status.
            // Keep the existing per-instance/refresh counting otherwise.
            if (step!=null && now>=step && now-step<PROC_BURST) return;
            recentProcStatuses[key]=now;
        }
        model.recordCast(uid,id);
    }
    public function statusRemoved(status:Dynamic):Void {
        appliedStatuses.remove(G.uid(status));
    }
    public function summonCreated(summon:Dynamic):Void {
        if (!config.enabled || hero == null || summon == null || G.field(summon, "removed") == true
            || G.field(summon, "simulatingServer") == true) return;
        var instance = G.uid(summon), skill = G.field(summon, "summonSourceSkill");
        if (instance == "" || instance == "0" || skill == null || countedSummons.exists(instance)) return;
        var attributed = NativeHealing.owner(summon, skill);
        // Active summoning abilities already count at Skill.start. Passive and
        // status-driven procs instead count once for each unit they create.
        if (!NativeCasts.applicationDriven(attributed.skill) || profile(attributed.source) == null) return;
        var id = NativeCasts.id(attributed.skill);
        if (id == "") return;
        countedSummons[instance] = true;
        model.recordCast(G.uid(attributed.source), id);
        // Keep only the UID until a zone/character reset: repeated replication
        // or a summon returning to view must not become another cast.
    }
    public function combatEnter(uid:String, now:Float):Void {
        if (uid == model.me) {
            refreshPhrixes(now);
            // Capture the current objective before a new attempt's opening
            // hit, even when entry occurs between the regular roster polls.
            if (model.dungeonBoss != null) refreshDungeonBoss(G.field(layer, "isRift") == true);
        }
        model.onCombatEnter(uid, now);
    }
    public function dungeonVictory(context:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || context == null || G.field(context, "simulatingServer") == true
            || G.field(hero, "layer") != layer || G.field(context, "layer") != layer) return;
        var activity = G.field(layer, "mainActivity");
        if (activity == null || G.field(context, "activity") != activity) return;
        var personal = G.call("st.Player", "getActivityContext", G.field(hero, "player"), [activity]);
        if (context != personal && context != G.field(activity, "globalCtx")) return;
        refreshDungeonBoss(G.field(layer, "isRift") == true);
        model.onDungeonVictory(now);
    }
    public function combatExit(uid:String, now:Float):Void {
        if (uid == model.me) refreshPhrixes(now);
        else if (model.inCombat || model.current == null || !model.party.exists(uid)) return;
        // A phase/death update can arrive between roster polls and this RPC.
        if (model.dungeonBoss != null) refreshDungeonBoss(G.field(layer, "isRift") == true);
        var displayed = model.displayedFight();
        model.onCombatExit(uid, now, displayed != null && displayed.closed == 0
            && (PartyCombat.active(hero, uid) || honeyzabethInCombat()));
    }
    function refreshDungeonBoss(inRift:Bool):Void {
        if (inRift || NativeCombatMetadata.dungeonBoss(model.activityId) != "Cleodora") {
            cleodora = null; queenslayer = null; honeyzabethTransition = false; model.setDungeonBoss(null); return;
        }
        var player = G.field(hero, "player"), activity = G.field(layer, "mainActivity");
        var altCompleted = NativeCombatMetadata.dungeonBossCompletion(player, activity, "Queenslayer", "KillBossAlt");
        var heroic = model.difficulty == 2 || altCompleted != null;
        var previousQueen = cleodora;
        cleodora = dungeonUnit("Cleodora", cleodora);
        if (cleodora != previousQueen) queenslayer = null;
        queenslayer = heroic ? dungeonUnit("Queenslayer", queenslayer) : null;
        var name = "";
        if (cleodora != null) name = G.text(G.call("ent.Unit", "getName", cleodora));
        else {
            var byId = G.field(G.current("Data", "unit"), "byId");
            var inf = byId == null ? null : G.call("haxe.ds.StringMap", "get", byId, ["Cleodora"]);
            if (inf != null) name = G.text(G.staticCall("HText", "unit", [inf, null]));
        }
        // Heroic continues after Queenslayer kills Honeyzabeth. Her death and
        // KillBoss goal are only a transition into the final fight.
        // Death/removal during a wipe is not evidence of a Heroic win. The
        // model checks an objective transition or a fresh server victory RPC.
        var queenCompleted = NativeCombatMetadata.dungeonBossCompletion(player, activity, "Cleodora");
        var finalBoss = heroic ? queenslayer : cleodora;
        var defeated = !heroic && (finalBoss != null
            ? G.call("ent.GameObject", "isDead", finalBoss) == true : queenCompleted == true);
        model.setDungeonBoss({kind:"Cleodora", name:name == "" ? "Cleodora" : name, uid:G.uid(cleodora),
            level:G.integer(G.field(cleodora, "_level")), foeId:G.integer(G.field(cleodora, "foeId")), defeated:defeated,
            victoryKind:heroic ? "Queenslayer" : "Cleodora", victoryUid:G.uid(finalBoss),
            victoryObjective:altCompleted,
            victoryActive:heroic && finalBoss != null && G.field(finalBoss, "removed") != true
                && G.field(finalBoss, "isInCombat") == true && G.call("ent.GameObject", "isDead", finalBoss) != true});
        var fight = model.displayedFight();
        var confirmed = fight != null && fight.closed == 0 && fight.bossKind == "Cleodora" && fight.defeated;
        honeyzabethTransition = heroic && !confirmed
            && (queenCompleted == true || (cleodora != null && G.call("ent.GameObject", "isDead", cleodora) == true))
            && NativeCombatMetadata.dungeonInCombat(player, activity);
    }
    function dungeonUnit(kind:String, cached:Dynamic):Dynamic {
        if (cached != null && (G.field(cached, "layer") != layer || G.field(cached, "removed") == true)) cached = null;
        if (cached == null || G.call("ent.GameObject", "isDead", cached) == true) for (unit in G.array(G.field(layer, "units"))) {
            if (G.text(G.field(unit, "kind")) != kind || G.field(unit, "summonOwner") != null
                || G.field(unit, "removed") == true || G.call("ent.GameObject", "isDead", unit) == true) continue;
            cached = unit; break;
        }
        return cached;
    }
    function honeyzabethInCombat():Bool {
        // These replicated fields are available even while canBeHit is false.
        // Never query isAtDeathDoor: the shipped client makes it server-only.
        for (unit in [cleodora, queenslayer]) if (unit != null && G.field(unit, "removed") != true
            && G.field(unit, "isInCombat") == true && G.call("ent.GameObject", "isDead", unit) != true) return true;
        return honeyzabethTransition;
    }
    function refreshPhrixes(now:Float, observedHit:Bool = false):Void {
        if (phrixes == null) return;
        var uid = G.uid(phrixes);
        if (!observedHit && !model.trackingPhrixes(uid)) { phrixes = null; return; }
        var phase = G.integer(G.field(phrixes, "phase"));
        var dead = G.call("ent.GameObject", "isDead", phrixes) == true;
        // Phase 2 is playable after surrender; phase 3 covers the bridge. At
        // phase 1's lethal hit the server holds health at 1 before advancing.
        // isAtDeathDoor() throws !isServer in the shipped client. Use the
        // replicated health instead so phase-one hits reach model.record().
        var transition = phase == 3 || (phase == 1
            && G.number(G.call("ent.Unit", "get_health", phrixes), 2) <= 1);
        model.updatePhrixes(now, uid, phase, G.field(phrixes, "isInCombat") == true, transition, dead);
        if (!model.trackingPhrixes(uid)) phrixes = null;
    }
    function updateRiftState(player:Dynamic, now:Float):Void {
        var activity = G.field(layer, "mainActivity");
        if (activity == null) return;
        var context = G.call("st.Player", "getActivityContext", player, [activity]);
        if (context == null) context = G.field(activity, "globalCtx");
        if (context == null) return;
        var bossKind = "";
        var bossDefeated = false;
        for (objective in G.array(G.field(context, "objectives"), true)) {
            if (G.text(G.field(objective, "kind")) == "EventWait") riftWait = objective;
            if (G.text(G.field(objective, "kind")) == "CloseGates")
                model.updateRiftGates(G.integer(G.call("st.Objective", "getCurrentValue", objective), -1));
            if (G.text(G.field(objective, "kind")) != "KillBoss") continue;
            bossDefeated = G.call("st.Objective", "isCompleted", objective) == true;
            var target = G.field(objective, "target");
            if (target != null && Type.enumConstructor(target) == "Unit")
                bossKind = G.text(Type.enumParameters(target)[0]);
        }
        refreshRiftGates();
        // Countdown expiry stops new gates, but the remaining gates still need
        // clearing. The real boss only spawns after that cleanup and its delay.
        // RiftContext.boss is server-only; use the replicated objective's unit
        // kind and the client's live units instead.
        var bossSpawned = false;
        if (bossKind != "") for (unit in G.array(G.field(layer, "units"))) {
            if (G.text(G.field(unit, "kind")) != bossKind || G.field(unit, "summonOwner") != null) continue;
            bossSpawned = true;
            break;
        }
        model.updateRiftState(now, bossSpawned, bossDefeated, bossKind);
    }
    function refreshRiftGates():Void {
        // EventWait completion is replicated; gatesEndTime is the END of the
        // wave timer, not the start. Keep counting cleanup after it expires.
        if (!model.waitingForRiftGates()) return;
        if (riftWait == null) {
            // The context may replicate between the roster poll and a hit.
            // Resolve only the objective here, never scan all rift units.
            var activity = G.field(layer, "mainActivity");
            if (activity == null) return;
            var context = G.call("st.Player", "getActivityContext", G.field(hero, "player"), [activity]);
            if (context == null) context = G.field(activity, "globalCtx");
            for (objective in G.array(G.field(context, "objectives"), true))
                if (G.text(G.field(objective, "kind")) == "EventWait") { riftWait = objective; break; }
        }
        if (riftWait != null && G.call("st.Objective", "isCompleted", riftWait) == true) model.startRiftGates();
    }
    public var healingCapture:HealingCapture = new HealingCapture();
    public function healthChanged(attributes:Dynamic, after:Float, ?now:Float):Void {
        if (!config.enabled || hero == null) return;
        var host = G.field(attributes, "__host");
        if (host == null || G.integer(G.field(host, "isSyncingProperty"), -1) < 0) return;
        var target = G.field(attributes, "unit"), uid = G.uid(target);
        var before = G.number(G.field(attributes, "health"));
        if (uid == "" || before <= 0 || before >= after) return;
        if (!model.profiles.exists(uid) && G.field(target, "player") == null
            && G.field(target, "summonOwner") == null) return;
        // Only combat recovery on known heroes can become unattributed healing.
        // Other units' HP may still correlate with an explicitly sourced heal.
        var scope:Null<HealingScope> = null;
        if (after > before && model.profiles.exists(uid)) scope = model.captureHealing(uid);
        healingCapture.health(uid, before, after, now == null ? haxe.Timer.stamp() : now, scope);
    }
    function healingSource(source:Dynamic, skill:Dynamic, fallbackUid:String = ""):Null<{uid:String, skill:Dynamic}> {
        var resolved = NativeHealing.owner(source, skill);
        resolved.skill = NativeCasts.origin(resolved.skill);
        source = resolved.source;
        var uid = G.uid(source);
        if (uid == "" || uid == "0") uid = fallbackUid;
        if (profile(source) == null && !model.profiles.exists(uid)) return null;
        if (G.field(layer, "isRift") == true) {
            model.enableRift(); refreshRiftGates();
            if (G.field(source, "layer") == layer) model.party[uid] = true;
        }
        if (model.profiles[uid].className == "") model.profiles[uid].className = inferClass(G.text(G.field(resolved.skill, "kind")));
        return {uid: uid, skill: resolved.skill};
    }
    public function healing(receiver:Dynamic, result:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || result == null || G.field(receiver, "simulatingServer") == true) return;
        var rawSkill = gamecompat.HitSkill.read(result, G.field);
        var owner = healingSource(G.call("st.skill.DamageResult", "get_source", result), rawSkill, G.text(G.field(result, "weakSource")));
        var target = G.field(result, "target");
        var observation = healingTrace(G.call("st.skill.DamageResult", "get_source", result), target, rawSkill, now);
        if (owner == null && observation == null) return;
        var amount = G.number(G.field(result, "_amount"));
        if (amount <= 0) return;
        var e = HealingCapture.event(now, owner == null ? observation.source : owner.uid, G.uid(target),
            owner == null ? observation.skill : NativeCasts.id(owner.skill), amount);
        e.critical = G.field(result, "_critical") == true;
        e.timeline = observation;
        e.activation = model.activation(e.source, e.skill);
        var key = NativeHealing.key(rawSkill, G.integer(G.field(result, "stepIdx")));
        healingCapture.heal(e, owner == null ? null : model.captureHealing(owner.uid), key, true);
    }
    public function healingFX(target:Dynamic, hit:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || hit == null || G.field(target, "simulatingServer") == true) return;
        var rawSkill = G.field(hit, "skill");
        // ScriptHitData.get_source follows Status.instigator, not the recipient
        // who owns a heal-over-time status. It also resolves source proxies.
        var owner = healingSource(G.call("st.skill.ScriptHitData", "get_source", hit), rawSkill);
        var observation = healingTrace(G.call("st.skill.ScriptHitData", "get_source", hit), target, rawSkill, now);
        if (owner == null && observation == null) return;
        var estimate:Null<Float> = null;
        try estimate = NativeHealing.estimate(hit, target) catch (_:Dynamic) {}
        var e = HealingCapture.event(now, owner == null ? observation.source : owner.uid, G.uid(target),
            owner == null ? observation.skill : NativeCasts.id(owner.skill), estimate == null ? 0 : estimate);
        e.unknownHealing = estimate == null;
        e.timeline = observation;
        e.activation = model.activation(e.source, e.skill);
        var key = NativeHealing.key(rawSkill, G.integer(G.field(G.field(hit, "step"), "index")));
        healingCapture.heal(e, owner == null ? null : model.captureHealing(owner.uid), key, false);
    }
    function healingTrace(source:Dynamic, target:Dynamic, skill:Dynamic, now:Float):Null<CombatTimeline.TimelineEvent> {
        if (timeline != null) try return timeline.prepareHeal(source, target, skill, now)
            catch (error:Dynamic) timeline.report(error);
        return null;
    }
    public function damage(target:Dynamic, damage:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || damage == null) return;
        // The uploader may resume a copied boss snapshot; settle its pending
        // heals before copying, never mutate an already exported report.
        if (model.boss == null && model.lastBoss != null && model.lastBoss.pendingHealing > 0)
            healingCapture.flush(now, true);
        // Blocked hits retain their calculated amount even though no damage is dealt.
        var blocker = G.text(G.field(damage, "blocker"));
        if (blocker == "InvulnerableHit" || blocker == "DamageDodge") return;
        var coverageHit = G.integer(G.field(damage, "effect")) != 1 && G.number(G.field(damage, "_amount")) > 0
            ? coverage.damage(target, now) : null;
        var source:Dynamic = G.call("st.skill.DamageResult", "get_source", damage);
        var skill = NativeCasts.origin(gamecompat.HitSkill.read(damage, G.field));
        var uid = G.text(G.field(damage, "weakSource"));
        if (uid == "" || uid == "0") uid = G.uid(source);
        var summoner = G.field(source, "summonOwner");
        var summonSkill = G.field(source, "summonSourceSkill");
        if (summonSkill != null) {
            // Use the exact skill that created this minion. The native resolver
            // follows nested summons, child skills and Status.instigatorSkill.
            // Resolve on the actual type so Status's override is preserved.
            var origin = G.call(hl.Type.getDynamic(summonSkill).getTypeName(), "getSourceSkill", summonSkill);
            if (G.text(G.field(origin, "kind")) != "") skill = origin;
            // A source-skill link can arrive before summonOwner during replication.
            if (summoner == null && origin != null)
                summoner = G.call(hl.Type.getDynamic(origin).getTypeName(), "getSourceObject", origin);
        }
        if (summoner != null) {
            // Ownership is independent of whether a minion inherits its owner's
            // combat stats. Follow every summonOwner even for nested summons.
            while (summoner != null) {
                source = summoner;
                summoner = G.field(source, "summonOwner");
            }
            source = G.call("ent.GameObject", "resolveProxy", source);
            uid = G.uid(source);
        }
        var info = profile(source);
        if (info == null && !model.profiles.exists(uid)) return;
        if (G.field(layer, "isRift") == true) {
            model.enableRift();
            // Read the cached objective on the first real hit after countdown,
            // avoiding a 4 Hz polling gap or a full unit scan for each hit.
            refreshRiftGates();
            // A newly arrived player's hit can precede the next roster refresh.
            if (G.field(source, "layer") == layer) model.party[uid] = true;
        }
        var skillId = NativeCasts.id(skill);
        // Remote heroes may not have populated equipment caches. As in the
        // original meter, an observed class skill can fill in their class.
        var attributed = model.profiles[uid];
        if (attributed != null && attributed.className == "") attributed.className = inferClass(skillId);
        var inf = G.field(target, "inf");
        var kind = G.text(G.field(target, "kind"));
        if (kind == "") kind = G.text(G.field(inf, "id"));
        var bossFlags = G.integer(G.field(inf, "flags"));
        if (kind == "Phrixes" && G.field(target, "summonOwner") == null && G.field(layer, "isRift") != true
            && G.integer(G.field(damage, "effect")) != 1 && G.number(G.field(damage, "_amount")) > 0
            && (uid == model.me || model.party.exists(uid))) {
            phrixes = target;
            refreshPhrixes(now, true);
        }
        var bossName = "";
        if ((bossFlags & 0x38) != 0) {
            // Use the game's localized, phase-aware name instead of its data ID.
            try bossName = G.text(G.call("ent.Unit", "getName", target)) catch (_:Dynamic) {}
            if (bossName == "") bossName = kind;
        }
        var affinity = G.text(G.field(damage, "affinity"));
        // Raw is an explicit affinity, independent of the physical/magic getters.
        var damageType = DamageBreakdown.classify(null, null, affinity);
        var effect = G.integer(G.field(damage, "effect"));
        if (effect != 1 && damageType != "raw") try {
            damageType = DamageBreakdown.classify(G.call("st.skill.DamageResult", "get_isPhysical", damage),
                G.call("st.skill.DamageResult", "get_isMagic", damage));
        } catch (_:Dynamic) {} // Keep counting the hit if classification is unavailable.
        model.record({time: now, source: uid, amount: G.number(G.field(damage, "_amount")),
            critical: G.field(damage, "_critical") == true, kill: G.field(damage, "_kill") == true,
            effect: effect, skill: skillId, damageType: damageType, affinity: affinity,
            activation: model.activation(uid, skillId),
            coverage: coverageHit != null && (uid == model.me || model.party.exists(uid)) ? coverageHit.attempt.record(coverageHit) : null,
            target: G.uid(target), bossKind: kind, bossName: bossName, bossFlags: bossFlags,
            targetDummy: NativeCombatMetadata.isTargetDummy(inf),
            summoned: G.field(target, "summonOwner") != null,
            bossLevel: G.integer(G.field(target, "_level")), bossFoeId: G.integer(G.field(target, "foeId"))});
    }
    public function profile(h:Dynamic):Null<PlayerInfo> {
        var name = G.text(G.field(h, "name"));
        var player = G.field(h, "player");
        if (h == null || name == "" || player == null) return null;
        var id = G.uid(h);
        if (id == "" || id == "0") return null;
        var now = haxe.Timer.stamp();
        var heldWeapon = G.field(h, "weaponInHand");
        if (model.profiles.exists(id) && model.profiles[id].name == name
            && profileRefresh.exists(id) && now - profileRefresh[id] < 0.25
            && profileWeapons[id] == heldWeapon) return model.profiles[id];
        var classSkills:Array<String> = [];
        var weaponSkills:Array<String> = [];
        for (key in ["attackComboSkill", "secondarySkill", "dashSkill"]) addSkill(classSkills, G.field(h, key));
        for (key in ["attackSkills", "skillSlots"]) for (skill in G.array(G.field(h, key))) addSkill(classSkills, skill);
        for (skill in G.array(G.field(h, "weaponSkills"))) addSkill(weaponSkills, skill);
        // Hero.getDetailedInfos uses inf.id as heroClass. Remote heroes can
        // lack the local skill caches / HeroData, especially before attacking.
        // Read that replicated unit definition so healing-only players also
        // receive their class colour without first needing a damage event.
        var className = inferClass(G.text(G.field(G.field(h, "inf"), "id")));
        if (className == "") for (id in classSkills) { className = inferClass(id); if (className != "") break; }
        if (className == "") className = inferClass(G.text(G.field(h, "kind")));
        if (className == "") className = inferClass(G.text(G.field(G.field(player, "heroData"), "kind")));
        if (className == "" && model.profiles.exists(id) && model.profiles[id].name == name)
            className = model.profiles[id].className;
        var weapon = G.field(h, "weaponInHand");
        var w:Null<WeaponInfo> = null;
        if (weapon != null) {
            var weaponKind = G.text(G.field(weapon, "kind"));
            if (weaponKind != "") w = {kind: weaponKind, rarity: G.text(G.field(weapon, "rarity")),
                level: G.integer(G.field(weapon, "level")), upgrade: G.integer(G.field(weapon, "upgradeLevel"))};
        }
        var info:PlayerInfo = {uid: id, name: name,
            accountId: NativePlayerIdentity.accountId(h), characterId: NativePlayerIdentity.characterId(h),
            isMe: G.field(player, "isMe") == true || (config.me != "" && config.me.toLowerCase() == name.toLowerCase()),
            className: className, weapon: w, classSkills: classSkills, weaponSkills: weaponSkills,
            equippedWeapons: NativeWeapons.capture(h)};
        model.profiles[id] = info;
        profileRefresh[id] = now; profileWeapons[id] = heldWeapon;
        return info;
    }
    static function addSkill(list:Array<String>, skill:Dynamic):Void {
        // Hero.skillSlots contains skill IDs; the other caches hold Skill objects.
        var id = Std.isOfType(skill, String) ? G.text(skill) : G.text(G.field(skill, "kind"));
        if (id != "" && list.indexOf(id) < 0) list.push(id);
    }
    public static function inferClass(id:String):String {
        id = id.toLowerCase();
        for (name in ["warrior", "cleric", "mage", "rogue"]) if (id.indexOf(name) >= 0) return name;
        return id.indexOf("priest") >= 0 ? "cleric" : "";
    }
}
