package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.HistoryCatalog;

/** Read the running game's definitions, including inherited activities and skill references. */
class NativeCombatMetadata {
    static var activityTypes:Map<String, Int> = [];
    static var observed:Map<String, String> = [];
    static var observedBosses:Map<String, String> = [];
    static var warned:Bool = false;
    static var dummyGroup:Null<Int>;
    public static function isTargetDummy(inf:Dynamic):Bool {
        if (inf == null) return false;
        // Match Minimap's native classification, independent of translated
        // names, unit IDs, and boss flags. Retry if definitions are not ready.
        if (dummyGroup == null) {
            var value = G.current("_Data.Unit_group_Impl_", "Dummy");
            if (value != null) dummyGroup = G.integer(value);
        }
        var group = G.field(inf, "group");
        return dummyGroup != null && group != null && G.integer(group) == dummyGroup;
    }
    public static function activityCategory(id:String, isRift:Bool, player:Dynamic, activity:Dynamic):String {
        if (isRift) return HistoryCategory.WORLD;
        if (id == "") return HistoryCategory.OTHER;
        try {
            if (!activityTypes.exists(id)) {
                var inf = G.staticCall("HActivity", "getInf", [id]);
                // Retry until definitions have loaded.
                if (inf == null) return HistoryCategory.OTHER;
                activityTypes[id] = G.staticCall("HActivity", "isOfType", [inf, "Rift"]) == true ? 2
                    : G.staticCall("HActivity", "isOfType", [inf, "Dungeon"]) == true ? 1 : 0;
            }
            if (activityTypes[id] == 2) return HistoryCategory.WORLD;
            if (activityTypes[id] != 1 || activity == null) return HistoryCategory.OTHER;
            var context = G.call("st.Player", "getActivityContext", player, [activity]);
            var ready = false; var clearFoes = false;
            var bosses:Array<String> = [];
            // Personal and shared contexts can replicate at different times.
            // Scan both, including completed goals, before deciding arena vs dungeon.
            var contexts = [context]; var global = G.field(activity, "globalCtx");
            if (global != context) contexts.push(global);
            for (ctx in contexts) for (objective in G.array(G.field(ctx, "objectives"), true)) {
                var kind = G.text(G.field(objective, "kind"));
                if (kind == "KillAllDungeonFoes") clearFoes = true;
                if (kind == "KillBoss") {
                    var target = G.field(objective, "target");
                    if (target != null && Type.enumConstructor(target) == "Unit") {
                        var boss = G.text(Type.enumParameters(target)[0]);
                        if (boss != "") { ready = true; if (bosses.indexOf(boss) < 0) bosses.push(boss); }
                    }
                }
            }
            var result = HistoryCategory.fromObjectives(false, true, ready, clearFoes);
            if (result != HistoryCategory.OTHER) observed[id] = result;
            for (boss in bosses) HistoryCategory.observeBoss(observedBosses, boss, result);
            return observed.exists(id) ? observed[id] : result;
        } catch (e:Dynamic) { warn(e); return HistoryCategory.OTHER; }
    }
    static function category(inf:Dynamic):String {
        if (inf == null) return HistoryCategory.OTHER;
        if (G.staticCall("HActivity", "isOfType", [inf, "Rift"]) == true) return HistoryCategory.WORLD;
        var id = G.text(G.field(inf, "id"));
        return observed.exists(id) ? observed[id] : HistoryCategory.OTHER;
    }
    public static function catalog():HistoryCatalog {
        var result:HistoryCatalog = {activities: [], names: [], bosses: [], difficulties: [], bossCategories: observedBosses.copy()};
        // Same icon definitions and numeric values as InstanceSelectScreen.
        var difficultyIcons = ["Dungeon_Default", "Dungeon_LevelMax", "Dungeon_Heroic"];
        for (i in 0...difficultyIcons.length) try {
            var inf = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "icon"), "byId"), [difficultyIcons[i]]);
            var name = FightHistory.text(G.field(inf, "name"));
            if (name != "") result.difficulties[i] = name;
        } catch (e:Dynamic) warn(e);
        // All is intentionally unfiltered: retained logs can refer to retired
        // activities. Reading definitions does not load their maps or prefabs.
        try for (definition in G.array(G.staticCall("HActivity", "all", [null]))) {
            var inf = G.field(definition, "inf");
            var id = G.text(G.field(inf, "id"));
            if (id != "") result.activities[id] = category(inf);
        } catch (_:Dynamic) {}
        var units = G.current("Data", "unit");
        for (inf in G.array(G.field(units, "all"))) {
            var id = G.text(G.field(inf, "id"));
            if (id == "") continue;
            result.bosses[id] = (G.integer(G.field(inf, "flags")) & 0x10) != 0;
            try {
                var name = G.text(G.staticCall("HText", "unit", [inf, null]));
                if (name != "" && name != id) result.names[id] = name;
            } catch (_:Dynamic) {}
        }
        return result;
    }
    public static function skillName(id:String):String {
        // Names live directly in texts.name. Do not manufacture a native
        // SkillSpec (with typed mastery arrays) just to read a display string:
        // a bridge/type failure there used to discard even simple valid names.
        return SkillNames.resolve(id, key -> {
            var inf = skillDefinition(key);
            var texts = G.field(inf, "texts");
            var name = G.text(G.field(texts, "name"));
            var type = G.integer(G.field(inf, "type"), -1);
            if (name == "" && type >= 0 && type <= 3) {
                // item_weapon_base_attack is a function that formats a weapon
                // DAMAGE DESCRIPTION, not an ability-name string.
                name = "Base Attack";
                if (type > 0) name += " " + (type + 1);
            }
            var source = "";
            if (name == "" || StringTools.startsWith(name, "[")) try
                source = G.text(G.field(G.staticCall("HSkill", "getSkillRef", [key]), "id"))
            catch (e:Dynamic) warn(e);
            if (inf == null && source == "") return null;
            return {name: name, nameRef: G.text(G.field(G.field(texts, "refs"), "ref")), source: source};
        });
    }
    static function skillDefinition(id:String):Dynamic {
        try return G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "skill"), "byId"), [id])
        catch (e:Dynamic) { warn(e); return null; }
    }
    public static function skillIcon(id:String):Dynamic {
        try {
            var inf = skillDefinition(id);
            var gfx = G.field(inf, "gfx");
            if (gfx == null) gfx = G.field(G.staticCall("HSkill", "getSkillRef", [id]), "gfx");
            return gfx == null ? null : G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
        } catch (e:Dynamic) { warn(e); return null; }
    }
    static function warn(error:Dynamic):Void {
        if (warned) return;
        warned = true;
        trace("[DPS Meter] Combat metadata unavailable: " + Std.string(error));
    }
}
