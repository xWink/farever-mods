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
    public static function kind(inf:Dynamic):String {
        if (inf == null) return "activity";
        if (G.staticCall("HActivity", "isOfType", [inf, "Ascension"]) == true) return "ascension";
        // Check the activity's inheritance, not its name or whether it has an
        // instance entrance: rifts also have entrances but are not dungeons.
        return G.staticCall("HActivity", "isOfType", [inf, "Dungeon"]) == true ? "dungeon" : "activity";
    }

    public static function hidden(kind:String, inf:Dynamic, progress:Dynamic, config:ActivityVisibility):Bool {
        if (!config.showActivities) return true;
        if (kind == "ascension") return config.hideAscensions;
        if (kind == "dungeon") return config.hideDungeons;
        // Repeatable destinations do not need a completion lookup at all.
        return config.hideCompletedActivities && progress != null
            && G.call("st.player.Progress", "hasActivityCompleted", progress, [G.field(inf, "id")]) == true;
    }
}
