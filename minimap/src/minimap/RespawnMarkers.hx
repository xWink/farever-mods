package minimap;

import minimap.GameAccess as G;

/** Respawn unlocks use the same character progress check as native respawning. */
class RespawnMarkers {
    public static function unlocked(inf:Dynamic, progress:Dynamic):Bool {
        var id = G.text(G.field(inf, "id"));
        if (progress == null || id == "") return false;
        // Merely having a discovery entry is insufficient: the respawn point
        // must be activated/completed. This query never creates progress.
        return G.call("st.player.Progress", "hasElementCompleted", progress, [id]) == true;
    }

    public static function name(unlocked:Bool):String
        return unlocked ? "Respawn Point" : "Respawn Point (Undiscovered)";
}
