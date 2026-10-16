package dpsmeter;

import dpsmeter.CombatTimeline;
import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

private typedef TimelineUse = {event:TimelineEvent, context:Dynamic, previousContext:Dynamic, ended:Bool};

/** Passive client observations. Never evaluates a skill, rolls RNG, or changes combat. */
class NativeTimeline {
    public final journal:CombatTimeline;
    var config:MeterConfig.MeterSettings;
    var hero:Dynamic;
    var me:String = "";
    var statuses:Map<String, TimelineEvent> = [];
    var statusDurations:Map<String, Float> = [];
    var procs:Map<String, Bool> = [];
    var activeUses:Map<String, TimelineUse> = [];
    var pendingUses:Map<String, Array<TimelineUse>> = [];
    var statusInfo:Map<String, {kind:String, hidden:Bool}> = [];
    var consumedProcs:Map<String, Bool> = [];
    var names:Map<String, String> = [];
    var skillNames:Map<String, String> = [];
    var lastPoll:Float = -1;
    var wasEnabled:Bool = false;
    var reported:Bool = false;
    public function new(config:MeterConfig.MeterSettings, journal:CombatTimeline) {
        this.config = config; this.journal = journal;
    }
    function enabled():Bool return config.enabled && config.detailedCombatLogs && hero != null && me != "";
    public function report(error:Dynamic):Void {
        if (reported) return;
        reported = true;
        trace("[DPS Meter] Detailed recording: " + Std.string(error));
        if (enabled()) { var e = CombatTimeline.event("recording_gap", me); e.outcome = "An observation failed; this report may be incomplete."; emit(e); }
    }
    public function update(next:Dynamic, now:Float):Void {
        var changed = next != hero;
        if (changed) {
            if (wasEnabled) journal.append(CombatTimeline.event("recording_stopped", me), now);
            wasEnabled = false;
            hero = next; me = G.uid(hero); statuses = []; statusDurations = []; activeUses = []; pendingUses = []; procs = []; consumedProcs = []; names = [];
            journal.clearState(); lastPoll = -1;
        }
        var active = enabled();
        if (active != wasEnabled || (active && changed)) {
            // A gap invalidates our cached status/proc state. Re-seed from the
            // current client state when recording resumes, without inventing
            // application/removal events during the gap.
            statuses = []; statusDurations = []; activeUses = []; pendingUses = []; procs = []; consumedProcs = []; journal.clearState(); lastPoll = -1;
            var e = CombatTimeline.event(active ? "recording_started" : "recording_stopped", me);
            journal.append(e, now); wasEnabled = active;
            if (active) {
                for (status in G.array(G.field(hero, "statuses"), true)) statusChanged(status, "status_present");
                sampleHealth();
            }
        }
        if (active && now - lastPoll >= .05) {
            lastPoll = now;
            // Small local skill cache; independent of HUD visibility and More Settings.
            var skills = G.array(G.field(hero, "weaponSkills"));
            for (s in G.array(G.field(hero, "skills"))) if (skills.indexOf(s) < 0) skills.push(s);
            for (s in skills) if (G.field(s, "owner") == hero)
                highlight(s, G.call("st.skill.Skill", "shouldHighlight", s) == true);
        }
        journal.update(now);
    }
    function emit(e:TimelineEvent, ?now:Float):Void {
        if (!enabled()) return;
        if (e.skill != "") {
            if (!skillNames.exists(e.skill)) skillNames[e.skill] = NativeCombatMetadata.skillName(e.skill);
            e.skillName = skillNames[e.skill];
        }
        journal.append(e, now == null ? haxe.Timer.stamp() : now);
    }
    function name(unit:Dynamic):String {
        if (unit == null) return "Unknown";
        var id = G.uid(unit);
        if (names.exists(id)) return names[id];
        var value = G.text(G.field(unit, "name"));
        if (value == "") try value = G.text(G.call("ent.Unit", "getName", unit)) catch (_:Dynamic) {}
        if (value == "") value = G.text(G.field(unit, "kind"), "Unknown");
        if (names.keys().hasNext() && Lambda.count(names) > 1024) names = [];
        names[id] = value; return value;
    }
    public function hit(kind:String, source:Dynamic, target:Dynamic, skill:Dynamic):Null<TimelineEvent> {
        if (!enabled()) return null;
        var owner = NativeHealing.owner(source, skill);
        var sourceId = G.uid(owner.source), targetId = G.uid(target);
        if (sourceId != me && targetId != me) return null;
        var e = CombatTimeline.event(kind, sourceId, targetId, G.text(G.field(skill, "kind")));
        e.sourceName = name(owner.source); e.targetName = name(target);
        var targetKind = G.text(G.field(target, "kind"));
        if (targetKind != "") e.targetKind = targetKind;
        if (skill != null) {
            var origin = G.call(hl.Type.getDynamic(skill).getTypeName(), "getSourceSkill", skill);
            e.origin = G.text(G.field(origin, "kind"));
            e.instance = G.uid(skill);
            if (e.skill == "ConsumeItem") {
                // This skill is shared by Spark Cube and other consumables.
                // Capture identity while the native item reference still exists.
                var item = G.call("st.skill.BaseSkill", "getSourceItem", skill);
                var id = G.text(G.field(item, "kind"));
                if (id != "") { e.item = id; e.itemName = NativeCombatMetadata.itemName(id); }
            }
        }
        return e;
    }
    public function damage(receiver:Dynamic, result:Dynamic, now:Float):Void {
        if (!enabled() || result == null || G.field(receiver, "simulatingServer") == true) return;
        var e = hit("damage", G.call("st.skill.DamageResult", "get_source", result),
            G.field(result, "target"), gamecompat.HitSkill.read(result, G.field));
        if (e == null) return;
        var blocker = G.text(G.field(result, "blocker"));
        var avoided = blocker == "DamageDodge" || blocker == "InvulnerableHit";
        e.kind = avoided ? "avoided" : "damage";
        e.outcome = blocker != "" ? blocker : G.number(G.field(result, "_block")) > 0 ? "Blocked" : "Hit";
        e.amount = avoided ? 0 : G.number(G.field(result, "_amount"));
        e.critical = G.field(result, "_critical") == true;
        e.lethal = G.field(result, "_kill") == true;
        e.hits = G.integer(G.field(result, "_hitCount"), 1);
        e.damageType = DamageBreakdown.classify(null, null, G.text(G.field(result, "affinity")));
        if (e.damageType != "raw") e.damageType = DamageBreakdown.classify(
            G.call("st.skill.DamageResult", "get_isPhysical", result), G.call("st.skill.DamageResult", "get_isMagic", result));
        emit(e, now);
    }
    public function prepareHeal(source:Dynamic, target:Dynamic, skill:Dynamic, now:Float):Null<TimelineEvent> {
        var e = hit("heal", source, target, skill);
        if (e != null) { var order = journal.reserve(now); e.seq = order.seq; e.time = order.time; }
        return e;
    }
    public function healed(e:DamageEvent):Void {
        // Ordinary HP recovery has no skill/potion source and is intentionally absent.
        if (e.timeline == null || e.unattributedHealing == true || e.skill == "Regen / unattributed") return;
        var row = e.timeline;
        row.amount = e.unknownHealing == true && e.amount <= 0 ? null : e.amount;
        
        row.critical = e.unknownHealingCrit == true ? null : e.critical;
        row.estimated = e.estimatedHealing == true || e.unknownHealing == true;
        emit(row, e.time);
        if (row.target == me) sampleHealth();
    }
    function sampleHealth():Void {
        var hp = G.number(G.field(G.field(hero, "attr"), "health"), Math.NaN);
        if (Math.isFinite(hp)) { var state = CombatTimeline.event("health_sample", "", me); state.after = hp; emit(state); }
    }
    public function health(attributes:Dynamic, after:Float):Void {
        if (!enabled() || G.field(attributes, "unit") != hero) return;
        var host = G.field(attributes, "__host");
        if (host == null || G.integer(G.field(host, "isSyncingProperty"), -1) < 0) return;
        var before = G.number(G.field(attributes, "health"));
        if (!Math.isFinite(after) || after >= before) return;
        var e = CombatTimeline.event("health_loss", "", me);
        e.before = before; e.after = after; e.amount = before - after;
        e.outcome = "Health lost";
        emit(e);
    }
    public function use(unit:Dynamic, skill:Dynamic, ?target:Dynamic):Void {
        if (!enabled() || unit != hero || skill == null || G.field(skill, "simulatingServer") == true) return;
        var id = G.text(G.field(skill, "kind"));
        if (procs[id] != true && !consumedProcs.exists(id))
            highlight(skill, G.call("st.skill.Skill", "shouldHighlight", skill) == true);
        var type = skill == G.field(hero, "dashSkill") || id == "Dash" ? "dodge_use"
            : G.call("st.skill.BaseSkill", "isBlock", skill) == true ? "block_use" : "skill_use";
        var targetObject:Dynamic = null;
        if (target != null && Type.enumConstructor(target) == "Target") targetObject = Type.enumParameters(target)[0];
        var e = hit(type, hero, targetObject, skill);
        if (e == null) return;
        e.outcome = "Used"; emit(e);
        var key = G.uid(skill);
        if (!pendingUses.exists(key)) pendingUses[key] = [];
        pendingUses[key].push({event:e, context:null, previousContext:G.field(skill, "runningCtx"), ended:false});
        if (procs[id] == true) {
            var proc = CombatTimeline.event("proc_used", me, "", id); proc.related = e.seq;
            emit(proc); procs[id] = false; consumedProcs[id] = true;
        }
    }
    /** Complete a start after native targeting has resolved, without moving the use timestamp. */
    public function started(skill:Dynamic, context:Dynamic):Void {
        if (!enabled() || G.field(skill, "owner") != hero || G.field(skill, "simulatingServer") == true) return;
        var id = G.uid(skill), pending = pendingUses[id];
        if (pending == null || pending.length == 0) return;
        var use = pending.pop();
        if (pending.length == 0) pendingUses.remove(id);
        use.context = context;
        if (!use.ended && context != null) activeUses[id] = use;
        var e = hit("skill_context", hero, G.field(context, "aimTarget"), skill);
        if (e == null) return;
        e.related = use.event.seq; emit(e);
    }
    public function stopped(skill:Dynamic, reason:Dynamic):Void {
        if (!enabled() || G.field(skill, "owner") != hero || G.field(skill, "simulatingServer") == true) return;
        var id = G.uid(skill), context = G.field(skill, "runningCtx");
        var use = activeUses[id];
        // A restarted skill stops its previous context inside start(). Instant
        // skills can also stop before start() returns. Match the actual context.
        if (use == null || use.context != context) {
            use = null;
            var pending = pendingUses[id];
            if (pending != null && pending.length > 0) {
                var candidate = pending[pending.length - 1];
                if (context != null && context != candidate.previousContext) use = candidate;
            }
        }
        // Recording may begin during an already-running skill. Its stop must
        // never be attached to the new use that just restarted it.
        if (use == null || use.ended) return;
        var e = hit("skill_end", hero, G.field(context, "aimTarget"), skill);
        if (e == null) return;
        e.outcome = Std.string(reason);
        if (use != null && !use.ended) {
            use.ended = true; e.related = use.event.seq;
            e.useDuration = Math.max(0, haxe.Timer.stamp() - journal.epoch - use.event.time);
            if (activeUses[id] == use) activeUses.remove(id);
        }
        emit(e);
    }
    public function block(skill:Dynamic, wellTimed:Bool):Void {
        if (!enabled() || G.field(skill, "owner") != hero) return;
        var e = hit("block_success", hero, null, skill);
        e.outcome = wellTimed ? "Perfect block" : "Block"; emit(e);
    }
    public function highlight(skill:Dynamic, value:Bool):Void {
        if (!enabled() || G.field(skill, "owner") != hero) return;
        var id = G.text(G.field(skill, "kind"));
        // A use callback can precede removal of the native highlight. Do not
        // announce that same still-glowing proc as newly available again.
        if (consumedProcs.exists(id)) {
            if (!value) consumedProcs.remove(id);
            return;
        }
        if (id == "" || procs[id] == value || (!procs.exists(id) && !value)) return;
        procs[id] = value;
        var e = CombatTimeline.event(value ? "proc_available" : "proc_ended", me, "", id);
        e.outcome = value ? "Skill proc available" : "Proc no longer available";
        emit(e);
    }
    public function charges(skill:Dynamic, value:Float):Void {
        if (!enabled() || G.field(skill, "owner") != hero) return;
        // getCurrentCharges floors fractional progress. Comparing its result
        // to an RPC value would mislabel ordinary partial progress as a reset.
        var before = G.number(G.field(skill, "charges"));
        if (value <= before + .0001) return;
        var e = hit("charge_update", hero, null, skill);
        e.before = before; e.after = value;
        e.outcome = "Charge increase"; emit(e);
        if (Math.floor(value) > Math.floor(before)) consumedProcs.remove(G.text(G.field(skill, "kind")));
    }
    function statusRow(status:Dynamic, kind:String):Null<TimelineEvent> {
        var e = hit(kind, G.field(status, "instigator"), G.field(status, "owner"), status);
        if (e != null) {
            if (!statusInfo.exists(e.skill)) {
                var info = NativeCombatMetadata.statusMetadata(e.skill);
                if (info != null) statusInfo[e.skill] = info;
            }
            var info = statusInfo[e.skill];
            if (info != null) { e.statusType = info.kind; e.hiddenStatus = info.hidden; }
        }
        return e;
    }
    public function statusChanged(status:Dynamic, kind:String):Void {
        var e = statusRow(status, kind);
        if (e == null || e.instance == "") return;
        var prior = statuses[e.instance];
        e.stacks = G.integer(G.field(status, "stacks"));
        e.duration = G.call("st.skill.Status", "isInfinite", status) == true ? -1
            : G.number(G.call("st.skill.BaseSkill", "getDurationLeft", status));
        if (kind == "status_stacks" && (prior == null || prior.stacks == e.stacks)) return;
        if ((kind == "status_applied" || kind == "status_present") && prior != null) return;
        statusDurations[e.instance] = G.number(G.field(status, "duration"));
        statuses[e.instance] = Reflect.copy(e); emit(e);
        if (prior == null) {
            var shield = G.number(G.field(status, "shieldAmount"));
            if (shield > 0) {
                if (kind == "status_present") {
                    var shieldState = statusRow(status, "shield_present");
                    shieldState.after = shield; shieldState.outcome = "Shield already active"; emit(shieldState);
                } else shieldChanged(status, 0, shield);
            }
        }
    }
    public function statusRpc(status:Dynamic):Void {
        if (!enabled()) return;
        var id = G.uid(status);
        if (!statuses.exists(id) || !statusDurations.exists(id)) return;
        // Compare the stored full duration, not the naturally decreasing time
        // remaining. Other callbacks update this cache, so one RPC cannot
        // duplicate a refresh/application already observed inside dispatch.
        var duration = G.number(G.field(status, "duration"));
        if (Math.abs(duration - statusDurations[id]) > .000001) statusChanged(status, "status_duration");
    }
    public function statusRemoved(status:Dynamic, ?reason:Dynamic):Void {
        var id = G.uid(status);
        if (!enabled() || !statuses.exists(id)) return;
        var e:TimelineEvent = Reflect.copy(statuses[id]);
        e.seq = 0; e.kind = "status_removed";
        var reasonName = reason == null ? "" : Std.string(reason);
        e.outcome = switch reasonName {
            case "Consume": "Consumed";
            case "Death": "Removed on death";
            case "Cancel": "Cancelled";
            case "Interrupt": "Interrupted";
            case "ForceEnd": "Removed";
            case "End": G.call("st.skill.Status", "isInfinite", status) != true
                && G.number(G.call("st.skill.BaseSkill", "getDurationLeft", status)) <= 0 ? "Expired" : "Ended";
            default: reasonName == "" ? "Removed" : reasonName;
        };
        statuses.remove(id); statusDurations.remove(id); emit(e);
    }
    public function shieldChanged(status:Dynamic, before:Float, after:Float):Void {
        if (!enabled() || before == after || !statuses.exists(G.uid(status))) return;
        var e = statusRow(status, after > before ? "shield_applied" : "shield_changed");
        if (e == null) return;
        e.before = before; e.after = after; e.amount = Math.abs(after - before);
        e.outcome = after > before ? "Shield added" : "Shield reduced";
        emit(e);
    }
    public function death(unit:Dynamic):Void {
        if (!enabled() || unit != hero) return;
        var e = CombatTimeline.event("death", "", me); e.targetName = name(hero); emit(e);
    }
}
