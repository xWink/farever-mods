package minimap;

typedef MapSubfilter = {key:String, label:String};
typedef MapFilterCategory = {key:String, label:String, icon:String, items:Array<MapSubfilter>};

/** One saved set of category/subtype filters, with map-specific presentation. */
class MainMapFilters {
    public static final CATEGORIES:Array<MapFilterCategory> = [
        category("ore", "Ore", "ore", ["copper", "iron", "tin", "tungstene"], ["Copper", "Iron", "Tin", "Tungstene"]),
        category("plants", "Plants", "plant", ["madrigold", "lavendula", "ancientThyme", "zealotus"], ["Madrigold", "Lavendula", "Ancient Thyme", "Zealotus"]),
        category("enemies", "Enemies", "enemy", ["regular", "boss", "targetDummy", "completed", "mastered"],
            ["Regular enemies", "Bosses and elites", "Target dummies", "Codex XP reward completed", "Codex mastery completed"]),
        category("companions", "Companions", "companion", ["regular", "sparkling", "collected"], ["Regular companions", "Sparkling companions", "Collected companions"]),
        category("activities", "Activities", "activity", ["activity", "ascension", "completed"],
            ["Activities", "Ascensions", "Completed activities"]),
        category("npcs", "NPCs", "npc", [], []),
        category("chests", "Chests", "chest", [], []),
        category("secretOrbs", "Secret orbs", "secretOrb", [], []),
        category("players", "Players", "player", ["regular", "party", "friends"], ["Players", "Party members", "Friends"])
    ];
    var source:MinimapSettings;
    var saved:Array<String>;
    var hidden:Map<String, Bool> = [];
    var derived:MinimapSettings;
    var hudDerived:MinimapSettings;
    var hudMarkerScale:Float = Math.NaN;
    var markerScale:Float = Math.NaN;
    var save:Void->Void;
    public var revision(default, null):Int = 0;

    public function new(?save:Void->Void) this.save = save;

    static function category(key:String, label:String, icon:String, keys:Array<String>, labels:Array<String>):MapFilterCategory
        return {key:key, label:label, icon:icon, items:[for (i in 0...keys.length) {key:keys[i], label:labels[i]}]};

    public function bind(config:MinimapSettings):Void {
        if (source == config && saved == config.mainMapHiddenFilters) return;
        source = config;
        if (config.mainMapHiddenFilters == null) config.mainMapHiddenFilters = ["activities:completed", "companions:collected", "enemies:mastered"];
        // Apply the new player default once, including existing installations.
        if (config.mainMapPlayerFiltersInitialized != true) {
            config.mainMapHiddenFilters = config.mainMapHiddenFilters.copy();
            if (config.mainMapHiddenFilters.indexOf("players:regular") < 0) config.mainMapHiddenFilters.push("players:regular");
            config.mainMapPlayerFiltersInitialized = true;
        }
        saved = config.mainMapHiddenFilters;
        hidden = [];
        for (key in saved) if (key != null) hidden[key] = true;
        derived = null;
        hudDerived = null;
        revision++;
    }

    public function enabled(category:String, ?item:String):Bool return !hidden.exists(category + (item == null ? "" : ":" + item));

    public function setEnabled(category:String, item:Null<String>, value:Bool):Void {
        if (source == null || enabled(category, item) == value) return;
        var key = category + (item == null ? "" : ":" + item);
        if (value) hidden.remove(key); else hidden[key] = true;
        saved = [for (key in hidden.keys()) key];
        saved.sort(Reflect.compare);
        source.mainMapHiddenFilters = saved;
        derived = null;
        hudDerived = null;
        revision++;
        if (save != null) save();
    }

    public function settings():MinimapSettings {
        var scale = source.mainMapMarkerScale == null ? 100. : source.mainMapMarkerScale;
        if (derived != null && markerScale == scale) return derived;
        derived = Reflect.copy(source);
        markerScale = scale;
        derived.markerScale = scale;
        derived.sparklingCompanionAlerts = false;
        return applyFilters(derived);
    }

    /** Preserve HUD size and alerts; visibility rules are shared with the main map. */
    public function minimapSettings():MinimapSettings {
        if (hudDerived == null || hudMarkerScale != source.markerScale) {
            hudMarkerScale = source.markerScale;
            hudDerived = applyFilters(Reflect.copy(source));
        }
        return hudDerived;
    }

    function applyFilters(config:MinimapSettings):MinimapSettings {
        // These categories have no toggle on either map. Ignore legacy hidden
        // preferences while still applying the shared height filter afterward.
        config.showPlayers = enabled("players");
        config.showObelisks = config.showRespawnPoints = config.showSoulstoneCircles = true;
        config.showOre = enabled("ore"); config.showPlants = enabled("plants");
        config.showEnemies = enabled("enemies"); config.showCompanions = enabled("companions");
        config.showActivities = enabled("activities"); config.showNpcs = enabled("npcs");
        // Retired subfilter keys in older configs must not hide
        // markers after their controls have been removed.
        config.showChests = enabled("chests"); config.showSecretOrbs = enabled("secretOrbs");
        config.hideCopper = !enabled("ore", "copper"); config.hideIron = !enabled("ore", "iron");
        config.hideTin = !enabled("ore", "tin"); config.hideTungstene = !enabled("ore", "tungstene");
        config.hideMadrigold = !enabled("plants", "madrigold"); config.hideLavendula = !enabled("plants", "lavendula");
        config.hideAncientThyme = !enabled("plants", "ancientThyme"); config.hideZealotus = !enabled("plants", "zealotus");
        config.hideCompletedCodexEnemies = !enabled("enemies", "completed");
        config.hideMasteredCodexEnemies = !enabled("enemies", "mastered");
        config.hideTargetDummies = !enabled("enemies", "targetDummy");
        config.hideCollectedCompanions = !enabled("companions", "collected");
        config.hideCompletedActivities = !enabled("activities", "completed");
        config.hideAscensions = !enabled("activities", "ascension"); config.hideDungeons = false;
        config.hideInactiveRifts = false;
        return config;
    }

    /** Subtypes not covered by the minimap's existing collection flags. */
    public function accepts(point:MapPoint):Bool return switch point.kind {
        // Party membership takes precedence when a party member is also a friend.
        case "player": enabled("players") && enabled("players", point.partyMember == true ? "party" : point.friend == true ? "friends" : "regular");
        case "enemy": enabled("enemies", "regular");
        case "boss", "targetDummy": enabled("enemies", point.kind);
        case "companion": enabled("companions", point.sparkling == true ? "sparkling" : "regular");
        case "activity", "ascension": enabled("activities", point.kind);
        case "dungeon", "inactiveRift", "nextRift", "upcomingRift", "riftPortal": true;
        default: true;
    };
}
