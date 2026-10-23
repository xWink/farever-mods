package minimap;

typedef MapSubfilter = {key:String, label:String};
typedef MapFilterCategory = {key:String, label:String, icon:String, items:Array<MapSubfilter>};

/** Saved category/subtype filters, optionally shared between both maps. */
class MainMapFilters {
    public static final CATEGORIES:Array<MapFilterCategory> = [
        category("ore", "Ore", "ore", ["copper", "iron", "tin", "tungstene"], ["Copper", "Iron", "Tin", "Tungstene"]),
        category("plants", "Plants", "plant", ["madrigold", "lavendula", "ancientThyme", "zealotus"], ["Madrigold", "Lavendula", "Ancient Thyme", "Zealotus"]),
        category("enemies", "Enemies", "enemy", ["regular", "boss", "targetDummy", "completed", "mastered"],
            ["Regular enemies", "Bosses and elites", "Target dummies", "Codex partially completed", "Codex mastery completed"]),
        category("companions", "Companions", "companion", ["regular", "sparkling", "collected"], ["Regular companions", "Sparkling companions", "Collected companions"]),
        category("activities", "Activities", "activity", ["activity", "ascension", "dungeon", "rifts", "soulstone", "completed"],
            ["Activities", "Ascensions", "Dungeons", "Rifts", "Soulstones", "Completed activities"]),
        category("players", "Players", "player", ["regular", "party", "friends"], ["Players", "Party members", "Friends"]),
        category("npcs", "NPCs", "npc", ["obelisk", "respawn", "factionMerchant", "station"],
            ["Obelisks", "Respawns", "Faction merchants", "Stations"]),
        category("chests", "Chests", "chest", [], []),
        category("secretOrbs", "Secret orbs", "secretOrb", [], [])
    ];
    var source:MinimapSettings;
    var saved:Array<String>;
    var hidden:Map<String, Bool> = [];
    var derived:MinimapSettings;
    var hudDerived:MinimapSettings;
    var travelDerived:MinimapSettings;
    var hudMarkerScale:Float = Math.NaN;
    var markerScale:Float = Math.NaN;
    var save:Void->Void;
    var minimap:Bool;
    public var revision(default, null):Int = 0;

    public function new(?save:Void->Void, minimap:Bool = false) {
        this.save = save; this.minimap = minimap;
    }

    static function category(key:String, label:String, icon:String, keys:Array<String>, labels:Array<String>):MapFilterCategory
        return {key:key, label:label, icon:icon, items:[for (i in 0...keys.length) {key:keys[i], label:labels[i]}]};

    public static function prepare(config:MinimapSettings):Void {
        if (config.useSameMapFilters == null) config.useSameMapFilters = true;
        if (config.mainMapHiddenFilters == null) config.mainMapHiddenFilters = ["activities:completed", "companions:collected", "enemies:mastered"];
        // Apply the new player default once, including existing installations.
        if (config.mainMapPlayerFiltersInitialized != true) {
            config.mainMapHiddenFilters = config.mainMapHiddenFilters.copy();
            if (config.mainMapHiddenFilters.indexOf("players:regular") < 0) config.mainMapHiddenFilters.push("players:regular");
            config.mainMapPlayerFiltersInitialized = true;
        }
        // Sharing always takes the main map as the authority. Unlink by copying
        // so subsequent edits cannot mutate the other map's saved preferences.
        if (config.useSameMapFilters) config.minimapHiddenFilters = config.mainMapHiddenFilters;
        else if (config.minimapHiddenFilters == null || config.minimapHiddenFilters == config.mainMapHiddenFilters)
            config.minimapHiddenFilters = config.mainMapHiddenFilters.copy();
    }

    public function bind(config:MinimapSettings):Void {
        prepare(config);
        var next = minimap ? config.minimapHiddenFilters : config.mainMapHiddenFilters;
        if (source == config && saved == next) return;
        source = config;
        saved = next;
        hidden = [];
        for (key in saved) if (key != null) hidden[key] = true;
        derived = null;
        hudDerived = null;
        travelDerived = null;
        revision++;
    }

    public function enabled(category:String, ?item:String):Bool return !hidden.exists(category + (item == null ? "" : ":" + item));

    public function setEnabled(category:String, item:Null<String>, value:Bool):Void {
        if (source == null) return;
        bind(source);
        if (enabled(category, item) == value) return;
        var key = category + (item == null ? "" : ":" + item);
        if (value) hidden.remove(key); else hidden[key] = true;
        saved = [for (key in hidden.keys()) key];
        saved.sort(Reflect.compare);
        if (minimap && !source.useSameMapFilters) source.minimapHiddenFilters = saved;
        else source.mainMapHiddenFilters = saved;
        if (source.useSameMapFilters) source.minimapHiddenFilters = saved;
        derived = null;
        hudDerived = null;
        travelDerived = null;
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

    /** Preserve HUD size and alerts while applying this map's visibility rules. */
    public function minimapSettings():MinimapSettings {
        if (hudDerived == null || hudMarkerScale != source.markerScale) {
            hudMarkerScale = source.markerScale;
            hudDerived = applyFilters(Reflect.copy(source));
        }
        return hudDerived;
    }

    /** Travel destinations must remain usable even when their map filter is off. */
    public function travelSettings():MinimapSettings {
        var normal = settings();
        if (travelDerived == null || travelDerived.markerScale != normal.markerScale) {
            travelDerived = Reflect.copy(normal);
            travelDerived.showObelisks = true;
        }
        return travelDerived;
    }

    function applyFilters(config:MinimapSettings):MinimapSettings {
        config.showPlayers = enabled("players");
        config.showObelisks = enabled("npcs") && enabled("npcs", "obelisk");
        config.showRespawnPoints = enabled("npcs") && enabled("npcs", "respawn");
        config.showSoulstoneCircles = enabled("activities") && enabled("activities", "soulstone");
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
        config.hideAscensions = !enabled("activities", "ascension");
        config.hideDungeons = !enabled("activities") || !enabled("activities", "dungeon");
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
        case "activity", "ascension", "dungeon", "soulstone": enabled("activities") && enabled("activities", point.kind);
        case "inactiveRift", "nextRift", "upcomingRift", "riftPortal": enabled("activities") && enabled("activities", "rifts");
        case "obelisk", "respawn": enabled("npcs") && enabled("npcs", point.kind);
        case "demon", "pilgrim", "glory": enabled("npcs") && enabled("npcs", "factionMerchant");
        case "craft", "upgrade", "recycler", "infusion", "soulWell": enabled("npcs") && enabled("npcs", "station");
        default: true;
    };
}
