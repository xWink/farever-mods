package minimap;

import minimap.GameAccess as G;

typedef ActivityVisibility = {
    var showActivities:Bool;
    var hideCompletedActivities:Bool;
    var hideAscensions:Bool;
    var hideDungeons:Bool;
}

/** Shared classification for world activities and instanced entrances. */
class ActivityMarkers {
    static final STYLES = [
        {type:"Boss", icon:"boss"}, {type:"WorldElite", icon:"boss"},
        {type:"ChestOrb", icon:"orbChest"}, {type:"TimerCollectRun", icon:"orbRace"},
        {type:"ArenaChest", icon:"ambushChest"},
        {type:"WorldCamp", icon:"battle"}, {type:"FightStone", icon:"battle"}
    ];
    static var artwork:Map<String, String> = [];

    /** Rebuild with the activity cache; atlas coordinates may change between game versions. */
    public static function prepareIcons():Void {
        artwork = [];
        for (entry in STYLES) {
            var inf = G.staticCall("HActivity", "getInf", [entry.type]);
            var key = gfxKey(G.field(inf, "gfx"));
            if (key == "") continue;
            // A shared placeholder is not enough to identify an activity.
            if (artwork.exists(key) && artwork[key] != entry.icon) artwork[key] = "activity";
            else artwork[key] = entry.icon;
        }
    }

    static function gfxKey(gfx:Dynamic):String {
        var file = G.text(G.field(gfx, "file"));
        var size = G.number(G.field(gfx, "size"));
        if (file == "" || size <= 0) return "";
        // Include the full atlas rectangle: unrelated cells share the same file.
        return StringTools.replace(file, "\\", "/").toLowerCase() + ":"
            + G.number(G.field(gfx, "x")) * size + ":" + G.number(G.field(gfx, "y")) * size + ":"
            + G.number(G.field(gfx, "width"), 1) * size + ":" + G.number(G.field(gfx, "height"), 1) * size;
    }

    /** Match the icon used by ActivityMarker.getTile before considering ancestry. */
    public static function icon(inf:Dynamic):String {
        if (inf == null) return "activity";
        var key = gfxKey(G.field(inf, "gfx"));
        if (key != "" && artwork.exists(key)) return artwork[key];
        // Preserve existing artwork when a native icon is absent or unfamiliar.
        for (entry in STYLES)
            if (G.staticCall("HActivity", "isOfType", [inf, entry.type]) == true) return entry.icon;
        return "activity";
    }

    public static function kind(inf:Dynamic):String {
        if (inf == null) return "activity";
        if (G.staticCall("HActivity", "isOfType", [inf, "Ascension"]) == true) return "ascension";
        // Check the activity's inheritance, not its name or whether it has an
        // instance entrance: rifts also have entrances but are not dungeons.
        return G.staticCall("HActivity", "isOfType", [inf, "Dungeon"]) == true ? "dungeon" : "activity";
    }

    public static function hidden(kind:String, inf:Dynamic, progress:Dynamic, config:ActivityVisibility):Bool {
        if (kind == "dungeon") return config.hideDungeons;
        if (!config.showActivities) return true;
        if (kind == "ascension") return config.hideAscensions;
        // Repeatable destinations do not need a completion lookup at all.
        return config.hideCompletedActivities && progress != null
            // A null difficulty asks whether this activity was completed at any
            // difficulty, matching ordinary world-activity marker visibility.
            && G.call("st.player.Progress", "hasActivityCompleted", progress, [G.field(inf, "id"), null]) == true;
    }
}
