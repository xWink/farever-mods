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
    /** Artwork follows native activity ancestry, independently of filtering. */
    public static function icon(inf:Dynamic):String {
        if (inf == null) return "activity";
        for (entry in [
            {type:"Boss", icon:"boss"}, {type:"WorldElite", icon:"boss"},
            {type:"ChestOrb", icon:"orbChest"}, {type:"TimerCollectRun", icon:"orbRace"},
            {type:"ArenaChest", icon:"ambushChest"},
            {type:"WorldCamp", icon:"battle"}, {type:"FightStone", icon:"battle"}
        ]) if (G.staticCall("HActivity", "isOfType", [inf, entry.type]) == true) return entry.icon;
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
