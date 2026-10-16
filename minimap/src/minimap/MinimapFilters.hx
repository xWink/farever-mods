package minimap;

/** HUD buttons edit the existing BMS preferences; extra subtypes have their own
    minimap-only list. Neither path touches the main-map filter list. */
class MinimapFilters implements MapFilterPreferences {
    static final FLAGS:Map<String, String> = [
        "ore" => "showOre", "plants" => "showPlants", "enemies" => "showEnemies",
        "companions" => "showCompanions", "activities" => "showActivities",
        "npcs" => "showNpcs", "chests" => "showChests", "secretOrbs" => "showSecretOrbs",
        "ore:copper" => "hideCopper", "ore:iron" => "hideIron", "ore:tin" => "hideTin", "ore:tungstene" => "hideTungstene",
        "plants:madrigold" => "hideMadrigold", "plants:lavendula" => "hideLavendula",
        "plants:ancientThyme" => "hideAncientThyme", "plants:zealotus" => "hideZealotus",
        "enemies:completed" => "hideCompletedCodexEnemies", "enemies:mastered" => "hideMasteredCodexEnemies",
        "enemies:targetDummy" => "hideTargetDummies", "companions:collected" => "hideCollectedCompanions",
        "activities:completed" => "hideCompletedActivities", "activities:ascension" => "hideAscensions",
        "activities:dungeon" => "hideDungeons", "activities:inactiveRifts" => "hideInactiveRifts"
    ];
    var source:MinimapSettings;
    var hidden:Map<String, Bool> = [];
    var save:Void->Void;
    public var revision(default, null):Int = 0;

    public function new(?save:Void->Void) this.save = save;
    public function bind(config:MinimapSettings):Void {
        if (config == source) return;
        source = config;
        hidden = [];
        if (config.minimapHiddenFilters != null) for (key in config.minimapHiddenFilters) hidden[key] = true;
        revision++;
    }
    public function enabled(category:String, ?item:String):Bool {
        if (source == null) return true;
        var key = category + (item == null ? "" : ":" + item), flag = FLAGS[key];
        if (flag == null) return !hidden.exists(key);
        var value = Reflect.field(source, flag);
        return StringTools.startsWith(flag, "hide") ? value != true : value != false;
    }
    public function setEnabled(category:String, item:Null<String>, value:Bool):Void {
        if (source == null || enabled(category, item) == value) return;
        var key = category + (item == null ? "" : ":" + item), flag = FLAGS[key];
        if (flag != null) Reflect.setField(source, flag, StringTools.startsWith(flag, "hide") ? !value : value);
        else {
            if (value) hidden.remove(key); else hidden[key] = true;
            source.minimapHiddenFilters = [for (key in hidden.keys()) key];
            source.minimapHiddenFilters.sort(Reflect.compare);
        }
        revision++;
        if (save != null) save();
    }
    public function accepts(point:MapPoint):Bool return switch point.kind {
        case "enemy": enabled("enemies", "regular");
        case "boss": enabled("enemies", "boss");
        case "companion": enabled("companions", point.sparkling == true ? "sparkling" : "regular");
        case "activity": enabled("activities", "activity");
        case "inactiveRift", "nextRift", "upcomingRift", "riftPortal": enabled("activities", "rifts");
        default: true;
    };
}
