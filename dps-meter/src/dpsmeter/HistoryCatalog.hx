package dpsmeter;

/** Plain data shared with the archive worker; no native objects cross threads. */
typedef HistoryCatalog = {
    activities:Map<String, String>,
    names:Map<String, String>,
    bosses:Map<String, Bool>,
    ?bossCategories:Map<String, String>,
    ?difficulties:Map<Int, String>
};

class HistoryCategory {
    public static inline var BOSS = "Boss Dungeons";
    public static inline var DUNGEON = "Classic Dungeons";
    public static inline var WORLD = "World Bosses";
    public static inline var OTHER = "Other";
    public static function all():Array<String> return [BOSS, DUNGEON, WORLD, OTHER];
    public static inline var VERSION = 2;
    /** Recognized encounters and dummy practice save; existing files remain browsable. */
    public static function canArchive(record:Dynamic, catalog:Null<HistoryCatalog> = null):Bool {
        if (record.targetDummy == true) return true;
        if (record.categoryVersion == VERSION && FightHistory.text(record.category) == OTHER) return false;
        return resolve(record, catalog) != OTHER;
    }
    /** The server adds the clearing objective only when dungeon foes exist.
        A populated KillBoss target is required before interpreting its absence. */
    public static function fromObjectives(rift:Bool, dungeon:Bool, bossReady:Bool, clearFoes:Bool):String
        return rift ? WORLD : !dungeon ? OTHER : clearFoes ? DUNGEON : bossReady ? BOSS : OTHER;
    public static function legacyBoss(kind:String):String return switch (kind) {
        // Confirmed older encounters whose logs predate objective metadata.
        // Chakram's internal unit ID is Phrixes. New fights use objectives.
        case "Ratsar", "Phrixes": BOSS;
        case "RobinHoof": DUNGEON;
        default: OTHER;
    };
    public static function observeBoss(categories:Map<String, String>, kind:String, category:String):Void {
        if (kind == "" || (category != BOSS && category != DUNGEON)) return;
        // A reused boss ID can appear in both dungeon formats. Ambiguous
        // evidence must never override an encounter's actual activity context.
        if (!categories.exists(kind)) categories[kind] = category;
        else if (categories[kind] != category) categories[kind] = OTHER;
    }
    public static function resolve(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var stored = FightHistory.text(record.category);
        // Practice stays under Other even if its area later hosts a boss event.
        if (stored == OTHER && record.targetDummy == true) return OTHER;
        var phase = FightHistory.text(record.phase);
        var name = FightHistory.text(record.name);
        if (StringTools.startsWith(phase, "Rift:") || StringTools.startsWith(name, "Rift:")) return WORLD;
        var activity = FightHistory.text(record.activityId);
        if (catalog != null && catalog.activities[activity] == WORLD) return WORLD;
        // Version 1 inferred these labels from implementation inheritance,
        // which does not describe whether a dungeon has a clearing phase.
        if (record.categoryVersion == VERSION && all().indexOf(stored) >= 0 && stored != OTHER) return stored;
        var boss = FightHistory.text(record.bossKind);
        if (boss == "" && catalog != null) {
            // First-release imports sometimes saved only the display name.
            // Accept an exact, unique known-boss name; never substring-match.
            if (catalog.bosses[name] == true) boss = name;
            else for (id => label in catalog.names) if (label == name && catalog.bosses[id] == true) {
                if (boss != "") return OTHER;
                boss = id;
            }
        }
        if (boss == "" || (catalog != null && catalog.bosses.exists(boss) && !catalog.bosses[boss])) return OTHER;
        if (catalog != null && activity != "" && catalog.activities.exists(activity)) {
            var category = catalog.activities[activity];
            if (category != OTHER) return category;
        }
        if (catalog != null && catalog.bossCategories != null && catalog.bossCategories.exists(boss))
            return catalog.bossCategories[boss];
        return legacyBoss(boss);
    }
    public static function displayName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = FightHistory.text(record.name);
        if (catalog == null) return name;
        if (catalog.names.exists(name)) return catalog.names[name];
        if (StringTools.startsWith(name, "Rift: ")) {
            var id = name.substr(6);
            if (catalog.names.exists(id)) return "Rift: " + catalog.names[id];
        }
        return name;
    }
    public static function encounterName(record:Dynamic, catalog:Null<HistoryCatalog>):String {
        var name = displayName(record, catalog);
        var difficulty = FightHistory.difficulty(record.difficulty);
        if (difficulty >= 0) {
            var label = catalog != null && catalog.difficulties != null ? catalog.difficulties[difficulty] : null;
            if (label == null || label == "") label = switch (difficulty) {
                case 0: "Normal"; case 1: "Hard"; case 2: "Heroic";
                default: "Difficulty " + difficulty;
            };
            return name + " - " + label;
        }
        var category = resolve(record, catalog);
        return name + (category == BOSS || category == DUNGEON ? " - Unknown difficulty" : "");
    }
}
