package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

class Collector {
    public var model:CombatModel;
    var config:MeterConfig;
    var hero:Dynamic;
    var layer:Dynamic;
    var lastRoster:Float = -1;
    var lastGroupSeen:Float = -1;
    var groupMembers:Map<String, Bool> = [];
    var profileRefresh:Map<String, Float> = [];
    var profileWeapons:Map<String, Dynamic> = [];
    public function new(config:MeterConfig) {
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
        }
        if (hero == null) return;
        if (now - lastRoster < 0.25) return;
        lastRoster = now;
        var mine = profile(hero);
        if (mine == null) return;
        model.me = mine.uid;
        var player = G.field(hero, "player");
        var group = G.field(player, "group");
        var roster:Array<Dynamic> = [];
        if (group != null) roster = G.array(G.field(group, "players"), true);
        var members:Map<String, Bool> = [];
        var hasMe = false;
        var anyCombat = G.field(hero, "isInCombat") == true;
        for (p in roster) {
            if (p == player || G.field(p, "isMe") == true) hasMe = true;
            var h = G.field(p, "hero");
            var info = profile(h);
            if (info == null) continue;
            members[info.uid] = true;
            if (G.field(h, "isInCombat") == true) anyCombat = true;
        }
        if (hasMe) { groupMembers = members; lastGroupSeen = now; }
        else if (now - lastGroupSeen > 5) groupMembers = [];
        model.party = groupMembers.copy();
        model.party[mine.uid] = true;
        if (!hasMe && now - lastGroupSeen > 5) {
            var names = [for (s in config.group.split(",")) StringTools.trim(s).toLowerCase()];
            for (p in model.profiles) if (names.indexOf(p.name.toLowerCase()) >= 0) model.party[p.uid] = true;
        }
        var layerConfig = G.field(layer, "config");
        model.difficulty = G.integer(G.field(layerConfig, "difficulty"), -1);
        model.activityId = G.text(G.field(layerConfig, "activityID"));
        if (model.activityId == "") model.activityId = G.text(G.field(G.field(layer, "mainActivity"), "kind"));
        if (group != null && model.activityId != "" && model.difficulty < 0) {
            // Never assign a stale lobby from another dungeon to an open-world boss.
            var lobbies = G.array(G.field(group, "instanceLobbies"), true);
            for (lobby in lobbies) {
                var activity = G.text(G.field(lobby, "activityId"));
                if (activity != model.activityId) continue;
                model.difficulty = G.integer(G.field(lobby, "difficulty"), -1);
            }
        }
        model.update(now, anyCombat);
    }
    public function damage(target:Dynamic, damage:Dynamic, now:Float):Void {
        if (!config.enabled || hero == null || damage == null) return;
        var source:Dynamic = G.call("st.skill.DamageResult", "get_source", damage);
        var info = profile(source);
        // weakSource is the attribution used by the original collector. Do not
        // silently remap an NPC/summon to a different player account.
        var uid = G.text(G.field(damage, "weakSource"));
        if (uid == "" || uid == "0") uid = G.uid(source);
        if (info == null && !model.profiles.exists(uid)) return;
        var skill = G.field(damage, "baseSkill");
        var inf = G.field(target, "inf");
        var kind = G.text(G.field(target, "kind"));
        if (kind == "") kind = G.text(G.field(inf, "id"));
        model.record({time: now, source: uid, amount: G.number(G.field(damage, "_amount")),
            critical: G.field(damage, "_critical") == true, kill: G.field(damage, "_kill") == true,
            effect: G.integer(G.field(damage, "effect")), skill: G.text(G.field(skill, "kind")),
            target: G.uid(target), bossKind: kind, bossFlags: G.integer(G.field(inf, "flags")),
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
        var id = G.text(G.field(skill, "kind"));
        if (id != "" && list.indexOf(id) < 0) list.push(id);
    }
    public static function inferClass(id:String):String {
        id = id.toLowerCase();
        for (name in ["warrior", "cleric", "mage", "rogue"]) if (id.indexOf(name) >= 0) return name;
        return id.indexOf("priest") >= 0 ? "cleric" : "";
    }
}
