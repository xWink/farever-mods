package minimap;

typedef MapSubfilter = {key:String, label:String};
typedef MapFilterCategory = {key:String, label:String, icon:String, items:Array<MapSubfilter>};

/** Main-map preferences never change the HUD's filter settings. */
class MainMapFilters {
    public static final CATEGORIES:Array<MapFilterCategory> = [
        category("ore", "Ore", "ore", ["copper", "iron", "tin", "tungstene"], ["Copper", "Iron", "Tin", "Tungstene"]),
        category("plants", "Plants", "plant", ["madrigold", "lavendula", "ancientThyme", "zealotus"], ["Madrigold", "Lavendula", "Ancient Thyme", "Zealotus"]),
        category("enemies", "Enemies", "enemy", ["regular", "boss", "targetDummy", "completed", "mastered"],
            ["Regular enemies", "Bosses and elites", "Target dummies", "Codex XP reward completed", "Codex mastery completed"]),
        category("companions", "Companions", "companion", ["regular", "sparkling", "collected"], ["Regular companions", "Sparkling companions", "Collected companions"]),
        category("activities", "Activities", "activity", ["activity", "ascension", "dungeon", "rifts", "inactiveRifts", "completed"],
            ["Activities", "Ascensions", "Dungeons", "Rifts", "Inactive rifts", "Completed activities"]),
        category("npcs", "NPCs", "npc", ["npc", "bank", "demon", "recycler", "upgrade", "craft", "glory", "infusion", "soulWell"],
            ["NPCs", "Guild merchants", "Demon huntresses", "Spark recyclers", "Weapon upgrades", "Crafting stations", "Glory merchants", "Infusion crucibles", "Soul wells"]),
        category("chests", "Chests", "chest", ["chest", "vaultChest", "recipeChest"], ["Chests", "Vault chests", "Recipe chests"]),
        category("secretOrbs", "Secret orbs", "secretOrb", ["uncollected"], ["Uncollected secret orbs"])
    ];
    var source:MinimapSettings;
    var saved:Array<String>;
    var hidden:Map<String, Bool> = [];
    var derived:MinimapSettings;
    var markerScale:Float = Math.NaN;
    var save:Void->Void;
    public var revision(default, null):Int = 0;

    public function new(?save:Void->Void) this.save = save;

    static function category(key:String, label:String, icon:String, keys:Array<String>, labels:Array<String>):MapFilterCategory
        return {key:key, label:label, icon:icon, items:[for (i in 0...keys.length) {key:keys[i], label:labels[i]}]};

    public function bind(config:MinimapSettings):Void {
        if (source == config && saved == config.mainMapHiddenFilters) return;
        source = config;
        if (config.mainMapHiddenFilters == null) config.mainMapHiddenFilters = ["activities:completed", "companions:collected"];
        saved = config.mainMapHiddenFilters;
        hidden = [];
        for (key in saved) if (key != null) hidden[key] = true;
        derived = null;
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
        revision++;
        if (save != null) save();
    }

    public function settings():MinimapSettings {
        if (derived != null && markerScale == source.markerScale) return derived;
        derived = Reflect.copy(source);
        markerScale = source.markerScale;
        derived.showPlayers = derived.showObelisks = derived.showRespawnPoints = derived.showSoulstoneCircles = true;
        derived.hideVerticallyDistantMarkers = false;
        derived.sparklingCompanionAlerts = false;
        derived.showOre = enabled("ore"); derived.showPlants = enabled("plants");
        derived.showEnemies = enabled("enemies"); derived.showCompanions = enabled("companions");
        derived.showActivities = enabled("activities"); derived.showNpcs = enabled("npcs");
        derived.showChests = enabled("chests"); derived.showSecretOrbs = enabled("secretOrbs") && enabled("secretOrbs", "uncollected");
        derived.hideCopper = !enabled("ore", "copper"); derived.hideIron = !enabled("ore", "iron");
        derived.hideTin = !enabled("ore", "tin"); derived.hideTungstene = !enabled("ore", "tungstene");
        derived.hideMadrigold = !enabled("plants", "madrigold"); derived.hideLavendula = !enabled("plants", "lavendula");
        derived.hideAncientThyme = !enabled("plants", "ancientThyme"); derived.hideZealotus = !enabled("plants", "zealotus");
        derived.hideCompletedCodexEnemies = !enabled("enemies", "completed");
        derived.hideMasteredCodexEnemies = !enabled("enemies", "mastered");
        derived.hideTargetDummies = !enabled("enemies", "targetDummy");
        derived.hideCollectedCompanions = !enabled("companions", "collected");
        derived.hideCompletedActivities = !enabled("activities", "completed");
        derived.hideAscensions = !enabled("activities", "ascension"); derived.hideDungeons = !enabled("activities", "dungeon");
        derived.hideInactiveRifts = !enabled("activities", "inactiveRifts");
        return derived;
    }

    /** Subtypes not covered by the minimap's existing collection flags. */
    public function accepts(point:MapPoint):Bool return switch point.kind {
        case "enemy": enabled("enemies", "regular");
        case "boss", "targetDummy": enabled("enemies", point.kind);
        case "companion": enabled("companions", point.sparkling == true ? "sparkling" : "regular");
        case "activity", "ascension", "dungeon": enabled("activities", point.kind);
        case "inactiveRift", "nextRift", "upcomingRift", "riftPortal": enabled("activities", "rifts");
        case "chest", "vaultChest", "recipeChest": enabled("chests", point.kind);
        default: NpcMarkers.KINDS.indexOf(point.kind) < 0 || enabled("npcs", point.kind);
    };
}
