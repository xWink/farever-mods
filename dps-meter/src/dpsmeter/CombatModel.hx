package dpsmeter;

import dpsmeter.RiftTracker.RiftRecap;

typedef WeaponInfo = {kind:String, rarity:String, level:Int, upgrade:Int};
typedef PlayerInfo = {
    uid:String, name:String, isMe:Bool, className:String,
    weapon:Null<WeaponInfo>, classSkills:Array<String>, weaponSkills:Array<String>
};
typedef DamageEvent = {
    time:Float, source:String, amount:Float, critical:Bool, kill:Bool, effect:Int, skill:String,
    target:String, bossKind:String, bossFlags:Int, bossLevel:Int, bossFoeId:Int, ?bossName:String, ?summoned:Bool
};

class SkillStats {
    public var damage:Float = 0;
    public var hits:Int = 0;
    public var crits:Int = 0;
    public var kills:Int = 0;
    public var casts:Int = 0;
    public var lastHit:Float = -1;
    public function new() {}
    public function add(e:DamageEvent):Void {
        damage += e.amount;
        hits++;
        if (e.critical) crits++;
        if (e.kill) kills++;
        // The original estimates casts from per-player/per-skill hit gaps.
        if (lastHit < 0 || e.time - lastHit > 0.350) casts++;
        lastHit = e.time;
    }
    public function json(id:String, duration:Float):Dynamic {
        return {id: id, damage: rounded(damage, 0), casts: casts, hits: hits, crits: crits, kills: kills,
            dps: rounded(damage / duration, 1), dmg_per_cast: rounded(casts == 0 ? 0 : damage / casts, 0)};
    }
    public static function rounded(value:Float, digits:Int):Float {
        var scale = Math.pow(10, digits);
        return Math.fround(value * scale) / scale;
    }
}

class PlayerStats {
    public var damage:Float = 0;
    public var heal:Float = 0;
    public var hits:Int = 0;
    public var crits:Int = 0;
    public var kills:Int = 0;
    public var skills:Map<String, SkillStats> = [];
    public var weapons:Array<WeaponInfo> = [];
    public var info:PlayerInfo;
    public function new(info:PlayerInfo) this.info = info;
    public function add(e:DamageEvent, info:PlayerInfo):Void {
        this.info = info;
        if (e.effect == 1) heal += e.amount; else damage += e.amount;
        hits++;
        if (e.critical) crits++;
        if (e.kill) kills++;
        if (info.weapon != null) {
            var found = false;
            for (w in weapons) if (w.kind == info.weapon.kind && w.rarity == info.weapon.rarity
                && w.level == info.weapon.level && w.upgrade == info.weapon.upgrade) found = true;
            if (!found) weapons.push(info.weapon);
        }
        if (e.effect != 1 && e.skill != "") {
            if (!skills.exists(e.skill)) skills[e.skill] = new SkillStats();
            skills[e.skill].add(e);
        }
    }
    public function json(duration:Float):Dynamic {
        var skillIds = [for (id in skills.keys()) id];
        skillIds.sort((a, b) -> skills[a].damage > skills[b].damage ? -1 : skills[a].damage < skills[b].damage ? 1 : Reflect.compare(a, b));
        var result:Dynamic = {uid: info.uid, name: info.name, is_me: info.isMe,
            total_damage: SkillStats.rounded(damage, 0), dps: SkillStats.rounded(damage / duration, 1),
            heal: SkillStats.rounded(heal, 0), hits: hits, crits: crits, kills: kills};
        Reflect.setField(result, "class", info.className);
        if (info.weapon != null) Reflect.setField(result, "weapon", info.weapon);
        if (weapons.length > 0) Reflect.setField(result, "weapons_seen", weapons);
        if (info.classSkills.length > 0 || info.weaponSkills.length > 0) {
            var equipped:Dynamic = {weapon: info.weaponSkills};
            Reflect.setField(equipped, "class", info.classSkills);
            Reflect.setField(result, "skills_equipped", equipped);
        }
        if (skillIds.length > 0) Reflect.setField(result, "skills", [for (id in skillIds) skills[id].json(id, duration)]);
        return result;
    }
}

class Fight {
    public var players:Map<String, PlayerStats> = [];
    public var participants:Map<String, Bool> = [];
    public var targets:Map<String, Bool> = [];
    public var start:Float;
    public var last:Float;
    public var closed:Float = 0;
    public var defeated:Bool = false;
    public var isBoss:Bool = true;
    public var phase:String = "";
    public var bossKind:String = "";
    public var bossName:String = "";
    public var bossUid:String = "";
    public var bossLevel:Int = 0;
    public var bossFoeId:Int = 0;
    public var difficulty:Int = -1;
    public var activityId:String = "";
    public var me:String = "";
    public function new(now:Float) { start = now; last = now; }
    public function add(e:DamageEvent, info:PlayerInfo):Void {
        if (!players.exists(e.source)) players[e.source] = new PlayerStats(info);
        players[e.source].add(e, info);
        if (e.effect != 1 && e.target != "") targets[e.target] = true;
        last = e.time;
    }
    public function duration(?now:Float):Float {
        return Math.max(0.001, (closed > 0 || now == null ? last : now) - start);
    }
    public function ranked():Array<PlayerStats> {
        var list = [for (p in players) p];
        list.sort((a, b) -> a.damage > b.damage ? -1 : a.damage < b.damage ? 1 : Reflect.compare(a.info.name, b.info.name));
        return list;
    }
    public function copy():Fight {
        var result = new Fight(start);
        result.last = last; result.closed = closed; result.defeated = defeated;
        result.isBoss = isBoss; result.phase = phase;
        result.bossKind = bossKind; result.bossName = bossName; result.bossUid = bossUid; result.bossLevel = bossLevel;
        result.bossFoeId = bossFoeId; result.difficulty = difficulty; result.activityId = activityId;
        result.me = me; result.participants = participants.copy(); result.targets = targets.copy();
        for (id => p in players) {
            var next = new PlayerStats(p.info);
            next.damage = p.damage; next.heal = p.heal; next.hits = p.hits;
            next.crits = p.crits; next.kills = p.kills; next.weapons = p.weapons.copy();
            for (name => skill in p.skills) {
                var s = new SkillStats();
                s.damage = skill.damage; s.hits = skill.hits; s.crits = skill.crits;
                s.kills = skill.kills; s.casts = skill.casts; s.lastHit = skill.lastHit;
                next.skills[name] = s;
            }
            result.players[id] = next;
        }
        return result;
    }
    public function reportKey():String {
        return phase == RiftTracker.GATES_PHASE ? activityId + "-rift" : bossKind;
    }
    public function json(timestamp:String, pid:Int):Dynamic {
        var seconds = duration();
        var result:Dynamic = {session_id: reportKey() + "-" + timestamp + "-" + pid,
            duration_sec: SkillStats.rounded(seconds, 3), is_boss: isBoss, boss_kind: bossKind,
            difficulty: difficulty, activity_id: activityId, boss_level: bossLevel, boss_foe_id: bossFoeId,
            players: [for (p in ranked()) if (p.info.name != "") p.json(seconds)]};
        if (phase != "") Reflect.setField(result, "phase", phase);
        return result;
    }
}

/** Encounter tracking and report data. */
class CombatModel {
    // Damage and the replicated combat entry can arrive in either order.
    // Buffer opening hits without running a clock before combat is confirmed.
    static inline var ENTRY_DAMAGE_SECONDS:Float = 0.5;
    public var profiles:Map<String, PlayerInfo> = [];
    public var party:Map<String, Bool> = [];
    public var me:String = "";
    public var current:Null<Fight>;
    public var lastCombat:Null<Fight>;
    public var session:Fight;
    public var boss:Null<Fight>;
    public var lastBoss:Null<Fight>;
    public var completed:Array<Fight> = [];
    public var recaps:Array<RiftRecap> = [];
    public var difficulty:Int = -1;
    public var activityId:String = "";
    var lastKillSource:String = "";
    var lastKillAmount:Float = -1;
    var lastKillTarget:String = "";
    var lastKillTime:Float = -1;
    public var inCombat(default, null):Bool = false;
    var awaitingExitState:Bool = false;
    var pendingFight:Null<Fight>;
    var rift:Null<RiftTracker>;
    public function new(now:Float) session = new Fight(now);
    public function reset(now:Float):Void {
        if (rift != null) rift.drain(now, completed, recaps, true);
        rift = null;
        profiles = []; party = []; me = ""; current = null; lastCombat = null;
        session = new Fight(now); boss = null; lastBoss = null;
        lastKillSource = ""; lastKillAmount = -1; difficulty = -1; activityId = "";
        lastKillTarget = ""; lastKillTime = -1;
        inCombat = false; awaitingExitState = false; pendingFight = null;
        // Completed reports and recaps remain queued across character/zone changes.
    }
    public function update(now:Float, localInCombat:Bool):Void {
        // Poll only the local hero as a backup for native entry/exit callbacks.
        // A native exit runs before the game's flag is stored. A stale true
        // must not undo that exit; first observe false, or a new native entry.
        if (!localInCombat) {
            if (inCombat) onCombatExit(me, now);
            awaitingExitState = false;
        } else if (!inCombat && !awaitingExitState) onCombatEnter(me, now);
        if (rift != null) {
            rift.drain(now, completed, recaps);
            return;
        }
        expirePendingFight(now);
        if (boss != null && now - boss.last > 8) {
            boss.closed = now; lastBoss = boss; boss = null;
        }
    }
    public function onCombatEnter(heroUid:String, now:Float):Void {
        if (me == "" || heroUid != me) return;
        if (inCombat) return;
        inCombat = true;
        awaitingExitState = false;
        if (rift != null) return;
        expirePendingFight(now);
        // Entry alone never starts the clock. Retain an opening hit if its
        // damage notification preceded entry; otherwise wait for first damage.
        current = pendingFight;
        if (current != null) current.closed = 0;
        pendingFight = null;
    }
    public function displayedFight():Null<Fight> {
        if (current != null) return current;
        // One-shots may never produce a replicated combat-entry transition.
        // Show the confirmed kill immediately, with an already-frozen clock.
        return hasLocalKill(pendingFight) ? pendingFight : lastCombat;
    }
    public function onCombatExit(heroUid:String, now:Float):Void {
        // The local character's exit is an encounter boundary even if another
        // party member still has a combat flag, or we re-enter between polls.
        if (me == "" || heroUid != me) return;
        inCombat = false;
        awaitingExitState = true;
        if (rift != null) return;
        finishPendingFight();
        if (current != null) finishCurrent(now);
    }
    function hasLocalKill(fight:Null<Fight>):Bool {
        return fight != null && fight.players.exists(me) && fight.players[me].kills > 0;
    }
    public function enableRift():Void {
        if (rift != null) return;
        rift = new RiftTracker();
        current = null; lastCombat = null; pendingFight = null;
        boss = null; lastBoss = null;
    }
    public function updateRiftState(now:Float, bossSpawned:Bool, bossDefeated:Bool, bossKind:String):Void {
        if (rift == null) return;
        rift.updateState(now, bossSpawned, bossDefeated, bossKind);
        current = rift.current;
        lastCombat = rift.last;
    }
    function finishPendingFight():Void {
        if (hasLocalKill(pendingFight)) lastCombat = pendingFight;
        pendingFight = null;
    }
    function expirePendingFight(now:Float):Void {
        // Bound the whole buffer, so remote party damage while resting cannot
        // accumulate indefinitely and get imported into the next encounter.
        if (pendingFight != null && now - pendingFight.start > ENTRY_DAMAGE_SECONDS) finishPendingFight();
    }
    function addToFight(fight:Fight, e:DamageEvent, info:PlayerInfo):Void {
        fight.add(e, info);
        if (e.effect != 1 && (e.bossFlags & 0x38) != 0) {
            fight.bossKind = e.bossKind;
            fight.bossName = e.bossName != null && e.bossName != "" ? e.bossName : e.bossKind;
        }
    }
    function finishCurrent(now:Float):Void {
        // Freeze the same elapsed time used by the live view, including time
        // spent dodging or waiting in combat. Boss reports use a separate Fight.
        current.last = Math.max(current.start, now);
        current.closed = now;
        if (current.players.iterator().hasNext()) lastCombat = current;
        current = null;
    }
    public function record(e:DamageEvent):Void {
        if (!Math.isFinite(e.amount) || e.amount <= 0 || e.source == "" || e.source == "0") return;
        if (e.kill) {
            // Equal lethal hits against different mobs (or in a later fight)
            // are distinct events, not duplicate notifications of one kill.
            if (e.source == lastKillSource && e.amount == lastKillAmount && e.target == lastKillTarget
                && e.time >= lastKillTime && e.time - lastKillTime <= 0.1) return;
            lastKillSource = e.source; lastKillAmount = e.amount;
            lastKillTarget = e.target; lastKillTime = e.time;
        }
        var info = profiles[e.source];
        if (info == null) return;
        var member = party.exists(e.source) || e.source == me;
        if (member) {
            session.add(e, info);
            if (rift != null) {
                rift.record(e, info, difficulty, activityId, me);
                current = rift.current;
                lastCombat = rift.last;
                return;
            }
            if (inCombat) {
                if (current == null && e.effect != 1) current = new Fight(e.time);
                if (current != null) addToFight(current, e, info);
            } else if (e.effect != 1) {
                expirePendingFight(e.time);
                if (e.kill && lastCombat != null && e.target != "" && lastCombat.targets.exists(e.target)
                    && e.time >= lastCombat.closed && e.time - lastCombat.closed <= ENTRY_DAMAGE_SECONDS) {
                    // Unit.receiveDamage handles death before sending its damage
                    // RPC. Reconcile that final blow if exit arrived first, while
                    // retaining the finished duration and not reopening the clock.
                    var end = lastCombat.last;
                    addToFight(lastCombat, e, info);
                    lastCombat.last = end;
                } else {
                    if (pendingFight == null) pendingFight = new Fight(e.time);
                    addToFight(pendingFight, e, info);
                    pendingFight.closed = e.time;
                }
            }
        }
        if (rift != null) return;
        // Match the DLL's target.inf.flags mask, including world/elite bosses.
        var bossHit = e.effect != 1 && (e.bossFlags & 0x38) != 0;
        if (bossHit && member && (boss == null || (boss.bossKind != e.bossKind && e.time - boss.last > 15))) {
            var previous = lastBoss;
            var resume = previous != null && previous.me == me && previous.bossKind == e.bossKind
                && previous.bossLevel == e.bossLevel && previous.bossFoeId == e.bossFoeId
                && ((e.target != "" && previous.bossUid == e.target
                    && e.time - previous.closed <= (previous.defeated ? 15 : 120))
                    || (!previous.defeated && e.time - previous.closed <= 30));
            // Completed reports may still be waiting for the end-of-frame writer.
            // A resumed phase must never mutate a report already queued for export.
            boss = resume ? previous.copy() : new Fight(e.time);
            boss.closed = 0; boss.defeated = false; boss.me = me;
            boss.bossKind = e.bossKind == "" ? "Boss" : e.bossKind;
            boss.bossUid = e.target; boss.bossLevel = e.bossLevel; boss.bossFoeId = e.bossFoeId;
            boss.difficulty = difficulty; boss.activityId = activityId;
        }
        if (boss == null || e.effect == 1) return;
        if (bossHit && (e.target == boss.bossUid || e.bossKind == boss.bossKind)) boss.participants[e.source] = true;
        // After a player has hit the boss, their add damage is part of this encounter too.
        if (!boss.participants.exists(e.source)) return;
        boss.add(e, info);
        if (e.kill && bossHit && e.target != "" && e.target == boss.bossUid) {
            boss.defeated = true; boss.closed = e.time;
            completed.push(boss); lastBoss = boss; boss = null;
        }
    }
}
