package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.HistoryCatalog;

/** Read the running game's definitions, including inherited activities and skill references. */
class NativeCombatMetadata {
    static var activityTypes:Map<String, Int> = [];
    static var observed:Map<String, String> = [];
    static var observedBosses:Map<String, String> = [];
    static var dungeonBosses:Map<String, String> = [];
    static var warned:Bool = false;
    static var dummyGroup:Null<Int>;
    static var enchantItemSource:Dynamic;
    static var enchantItemCount:Int = -1;
    static var enchantItems:Map<String, Dynamic> = [];
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
            // Honeyzabeth remains the encounter owner when miniboss goals
            // replicate too, or arrive before her own KillBoss objective.
            var queen = G.text(G.field(activity, "bossId")) == "Cleodora" || bosses.indexOf("Cleodora") >= 0
                || dungeonBosses[id] == "Cleodora";
            var result = HistoryCategory.fromObjectives(false, true, ready || queen, clearFoes);
            if (queen) dungeonBosses[id] = "Cleodora";
            else if (bosses.length == 1) dungeonBosses[id] = bosses[0];
            else if (bosses.length > 1) dungeonBosses.remove(id);
            if (result != HistoryCategory.OTHER) observed[id] = result;
            for (boss in bosses) HistoryCategory.observeBoss(observedBosses, boss, result);
            return observed.exists(id) ? observed[id] : result;
        } catch (e:Dynamic) { warn(e); return HistoryCategory.OTHER; }
    }
    /** Exact replicated dungeon objective, independent of translated names. */
    public static function dungeonBoss(id:String):String {
        var kind = dungeonBosses[id];
        return kind == null ? "" : kind;
    }
    public static function dungeonBossDefeated(player:Dynamic, activity:Dynamic, boss:String):Bool {
        if (activity == null) return false;
        try {
            var context = G.call("st.Player", "getActivityContext", player, [activity]);
            var contexts = [context], global = G.field(activity, "globalCtx");
            if (global != context) contexts.push(global);
            for (ctx in contexts) for (objective in G.array(G.field(ctx, "objectives"), true)) {
                if (G.text(G.field(objective, "kind")) != "KillBoss") continue;
                var target = G.field(objective, "target");
                if (target != null && Type.enumConstructor(target) == "Unit"
                    && G.text(Type.enumParameters(target)[0]) == boss
                    && G.call("st.Objective", "isCompleted", objective) == true) return true;
            }
        } catch (e:Dynamic) warn(e);
        return false;
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
        if (id == "ConsumeItem") return "Use item";
        // Names live directly in texts.name. Do not manufacture a native
        // SkillSpec (with typed mastery arrays) just to read a display string:
        // a bridge/type failure there used to discard even simple valid names.
        return SkillNames.resolve(id, key -> {
            if (key == "ConsumeFlask") {
                // This unnamed consumable references Pilgrim's Stride for its
                // rank tooltip. The reference names a bonus buff, not the heal.
                var name = G.text(G.field(G.field(skillItem(key), "texts"), "name"));
                return {name:name == "" ? "Hess'tuss Flask" : name, nameRef:"", source:""};
            }
            var inf = skillDefinition(key);
            if (inf == null) {
                var item = itemDefinition(key);
                if (item != null) return {name:itemName(key), nameRef:"", source:""};
            }
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
    static function skillItem(id:String):Dynamic {
        if (id != "ConsumeFlask") return null;
        return itemDefinition("RefillableFlask");
    }
    static function itemDefinition(id:String):Dynamic {
        var items = G.field(G.current("Data", "item"), "byId");
        if (items == null) return null;
        try return G.call("haxe.ds.StringMap", "get", items, [id])
        catch (e:Dynamic) { warn(e); return null; }
    }
    public static function itemName(id:String):String {
        var name = G.text(G.field(G.field(itemDefinition(id), "texts"), "name"));
        return name != "" ? name : StringTools.replace(id, "_", " ");
    }
    public static function itemIcon(id:String):Dynamic {
        var gfx = G.field(itemDefinition(id), "gfx");
        if (gfx == null) return null;
        try return G.staticCall("ui.BaseUI", "getTile", [gfx, null, null])
        catch (e:Dynamic) { warn(e); return null; }
    }
    /** Same Debuff tag used by HSkill.isDebuff; all other statuses are buffs. */
    public static function statusMetadata(id:String):Null<{kind:String, hidden:Bool}> {
        var inf = skillDefinition(id);
        return inf == null ? null : statusInfo(inf);
    }
    static function statusInfo(inf:Dynamic):{kind:String, hidden:Bool} {
        var debuff = false;
        for (tag in G.array(G.field(G.field(G.field(inf, "props"), "status"), "types")))
            if (G.text(G.field(tag, "type")) == "Debuff") debuff = true;
        return {kind:debuff ? "debuff" : "buff", hidden:(G.integer(G.field(inf, "flags")) & 4096) != 0};
    }
    /** Detached fallback for older recordings that predate status classification. */
    public static function statusCatalog():Map<String, {kind:String, hidden:Bool}> {
        var result:Map<String, {kind:String, hidden:Bool}> = [];
        for (inf in G.array(G.field(G.current("Data", "skill"), "all"))) {
            var id = G.text(G.field(inf, "id"));
            if (id != "") result[id] = statusInfo(inf);
        }
        return result;
    }
    public static function skillIcon(id:String):Dynamic {
        try {
            var inf = skillDefinition(id);
            if (inf == null && itemDefinition(id) != null) return itemIcon(id);
            var gfx = id == "ConsumeFlask" ? G.field(skillItem(id), "gfx") : G.field(inf, "gfx");
            var source:Dynamic = null;
            if (gfx == null && id != "ConsumeFlask") {
                source = G.staticCall("HSkill", "getSkillRef", [id]);
                gfx = G.field(source, "gfx");
            }
            if (gfx != null) return G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
            var tile = enchantIcon(id);
            return tile != null ? tile : enchantIcon(G.text(G.field(source, "id")));
        } catch (e:Dynamic) { warn(e); return null; }
    }
    static function enchantIcon(id:String):Dynamic {
        if (!StringTools.startsWith(id, "Enchant_")) return null;
        var all = G.field(G.current("Data", "item"), "all");
        var count = G.integer(G.field(all, "length"));
        if (all == null || count == 0) return null;
        if (enchantItemSource != all || enchantItemCount != count) {
            var items:Map<String, Dynamic> = [];
            var types = G.field(G.current("Data", "itemType"), "byId");
            if (types == null) return null;
            for (item in G.array(all)) {
                var skills = [for (entry in G.array(G.field(item, "skills"))) G.text(G.field(entry, "skill"))];
                skills = skills.filter(key -> StringTools.startsWith(key, "Enchant_"));
                if (skills.length == 0) continue;
                var type = G.call("haxe.ds.StringMap", "get", types, [G.text(G.field(item, "type"))]);
                // Match the scroll's inherited item type, not weapons carrying
                // the same passive or translated item names.
                if (type == null || G.staticCall("HItem", "isSameType", [type, "Augment"]) != true) continue;
                for (key in skills) if (!items.exists(key)) items[key] = item;
            }
            enchantItems = items; enchantItemSource = all; enchantItemCount = count;
        }
        var item = enchantItems[id];
        // Native item rendering also resolves inherited/default scroll artwork.
        return item == null ? null : G.staticCall("HItem", "getGfx", [item]);
    }
    static function warn(error:Dynamic):Void {
        if (warned) return;
        warned = true;
        trace("[DPS Meter] Combat metadata unavailable: " + Std.string(error));
    }
}
