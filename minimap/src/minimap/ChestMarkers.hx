package minimap;

import minimap.GameAccess as G;

/** Match the native map's chest families, including inherited world variants. */
class ChestMarkers {
    var kinds:Map<String, String> = [];

    public function new() {}

    public function kind(inf:Dynamic):String {
        if (inf == null) return "chest";
        var id = G.text(G.field(inf, "id"));
        if (id != "" && kinds.exists(id)) return kinds[id];
        var kind = if (G.staticCall("HElement", "isOfType", [inf, "Recipe_Chest_Root"]) == true) "recipeChest"
            else if (G.staticCall("HElement", "isOfType", [inf, "VaultChest"]) == true) "vaultChest"
            else "chest";
        if (id != "") kinds[id] = kind;
        return kind;
    }
}
