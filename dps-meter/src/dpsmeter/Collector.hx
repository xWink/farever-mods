package dpsmeter;

import dpsmeter.MeterConfig.MeterSettings;
import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

class Collector {
    public var model:CombatModel;
    var config:MeterSettings;
    var hero:Dynamic;
    var layer:Dynamic;
    var lastRoster:Float = -1;
    var lastGroupSeen:Float = -1;
    var groupMembers:Map<String, Bool> = [];
    var profileRefresh:Map<String, Float> = [];
    var profileWeapons:Map<String, Dynamic> = [];
    var phrixes:Dynamic;
    public function new(config:MeterSettings) {
        this.config = config;
        model = new CombatModel(haxe.Timer.stamp());
    }
    public function update(app:Dynamic, now:Float):Void {
        var nextHero = G.field(app, "hero");
        var nextLayer = G.field(nextHero, "layer");
        if (hero != nextHero || layer != nextLayer) {
            model.reset(now); hero = nextHero; layer = nextLayer;
            groupMembers = []; lastGroupSeen = -1; lastRoster = -1;
            profileRefresh = []; profileWeapons = [];
            phrixes = null;
        }
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
        if (inRift) updateRiftState(player, now);
        refreshPhrixes(now);
        // Encounter timing must not depend on optional lobby/report metadata.
        model.update(now, G.field(hero, "isInCombat") == true);
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
    public function combatEnter(uid:String, now:Float):Void {
        if (uid == model.me) refreshPhrixes(now);
        model.onCombatEnter(uid, now);
    }
    public function combatExit(uid:String, now:Float):Void {
        if (uid == model.me) refreshPhrixes(now);
        model.onCombatExit(uid, now);
    }
    function refreshPhrixes(now:Float, observedHit:Bool = false):Void {
        if (phrixes == null) return;
        var uid = G.uid(phrixes);
        if (!observedHit && !model.trackingPhrixes(uid)) { phrixes = null; return; }
        var phase = G.integer(G.field(phrixes, "phase"));
        var dead = G.call("ent.GameObject", "isDead", phrixes) == true;
        // Native Phrixes phases 2/3 cover the transformation and bridge. At
        // phase 1's lethal hit the server holds health at 1 before advancing.
        var transition = phase == 2 || phase == 3 || (phase == 1
            && (G.call("ent.Unit", "isAtDeathDoor", phrixes) == true
                || G.number(G.call("ent.Unit", "get_health", phrixes), 2) <= 1));
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
            if (G.text(G.field(objective, "kind")) != "KillBoss") continue;
            bossDefeated = G.call("st.Objective", "isCompleted", objective) == true;
            var target = G.field(objective, "target");
            if (target != null && Type.enumConstructor(target) == "Unit")
                bossKind = G.text(Type.enumParameters(target)[0]);
            break;
        }
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
    public function damage(target:Dynamic, damage:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || damage == null) return;
        // Blocked hits retain their calculated amount even though no damage is dealt.
        var blocker = G.text(G.field(damage, "blocker"));
        if (blocker == "InvulnerableHit" || blocker == "DamageDodge") return;
        var source:Dynamic = G.call("st.skill.DamageResult", "get_source", damage);
        var skill = gamecompat.HitSkill.read(damage, G.field);
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
            // A newly arrived player's hit can precede the next roster refresh.
            if (G.field(source, "layer") == layer) model.party[uid] = true;
        }
        var skillId = G.text(G.field(skill, "kind"));
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
        // Prefer class skill IDs: Hero.kind / HeroData.kind can identify a skin.
        var className = "";
        for (id in classSkills) { className = inferClass(id); if (className != "") break; }
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
            isMe: G.field(player, "isMe") == true || (config.me != "" && config.me.toLowerCase() == name.toLowerCase()),
            className: className, weapon: w, classSkills: classSkills, weaponSkills: weaponSkills};
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
