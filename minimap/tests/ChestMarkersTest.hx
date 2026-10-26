import minimap.ChestMarkers;
import minimap.ChestIcons;
import minimap.GameAccess as G;

class ChestMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var markers = new ChestMarkers();
        G.elements["VaultChest"] = {id: "VaultChest"};
        G.elements["Recipe_Chest_Root"] = {id: "Recipe_Chest_Root"};
        G.elements["RegionalRecipe"] = {id: "RegionalRecipe", inherit: "Recipe_Chest_Root"};
        eq(markers.kind(G.elements["VaultChest"]), "vaultChest", "native vault root");
        eq(markers.kind(G.elements["Recipe_Chest_Root"]), "recipeChest", "native recipe root");
        eq(markers.kind({id: "World_123", inherit: "VaultChest", texts: {name: "Coffre"}}),
            "vaultChest", "localized world vault uses native ancestry");
        eq(markers.kind({id: "World_456", inherit: "RegionalRecipe", texts: {name: "Chest"}}),
            "recipeChest", "recipe chest follows multiple ancestors despite generic name");
        eq(markers.kind({id: "World_789", texts: {name: "Chest"}}), "chest", "generic name alone is not a recipe chest");
        eq(markers.kind({id: "VaultChest_Decoration", texts: {name: "Vault Chest"}}),
            "chest", "names and ID substrings do not misclassify chests");
        eq(markers.kind({id: "Unknown", inherit: "Unavailable"}), "chest", "unknown variants retain ordinary chest marker");
        eq(markers.kind(null), "chest", "missing definition retains ordinary chest marker");
        eq(markers.kind({inherit: "Recipe_Chest_Root"}), "recipeChest", "unnamed native recipe variant");
        eq(markers.kind({inherit: "VaultChest"}), "vaultChest", "unnamed variants do not share a cache entry");
        G.elements["LEVEL_WorldChest"] = {id:"LEVEL_WorldChest"};
        G.elements["VaultChest"].inherit = "LEVEL_WorldChest";
        G.elements["Recipe_Chest_Root"].inherit = "LEVEL_WorldChest";
        eq(markers.isWorldChest({id:"ordinary",inherit:"LEVEL_WorldChest"}),true,"Native world-chest root");
        eq(markers.isWorldChest({id:"vault",inherit:"VaultChest"}),true,"Native world vault ancestry");
        eq(markers.isWorldChest({id:"recipe",inherit:"RegionalRecipe"}),true,"World recipe ancestry follows multiple parents");
        eq(markers.isWorldChest({id:"ancient",type:2,texts:{name:"Ancient Chest"}}),false,"Generic ancient chest without world ancestry is excluded before loading");
        eq(markers.isWorldChest({id:"camp",type:2,texts:{name:"Camp Chest"}}),false,"Generic camp reward without world ancestry is excluded before loading");
        eq(markers.isWorldChest({id:"localized",type:2,texts:{name:"Coffre"}}),false,"Classification does not depend on English names");
        eq(markers.isWorldChest({id:"misleading-name",inherit:"LEVEL_WorldChest",texts:{name:"Ancient Chest"}}),true,"Native world membership takes precedence over display name");
        eq(markers.isWorldChest(null),false,"Missing definition is not evidence of a world chest");
        eq(markers.isWorldChest({id:"unknown",inherit:"Unavailable"}),false,"Unknown ancestry does not advertise a chest");
        markers.clearWorld();
        eq(markers.isWorldChest({id:"unknown",inherit:"LEVEL_WorldChest"}),true,"Reloaded world definitions refresh classification");
        // Exercise the real icon geometry: an invalid closing vertex can compile
        // successfully yet throw while drawing a marker in the game.
        var vertices = 0;
        G.nativeCall = function(type, name, object, args) {
            if (name == "moveTo" || name == "lineTo") {
                for (coordinate in args)
                    if (coordinate == null || !Math.isFinite(coordinate)) throw "Invalid chest icon vertex";
                vertices++;
            }
            return null;
        };
        for (kind in ["chest", "vaultChest", "recipeChest"]) {
            vertices = 0;
            ChestIcons.draw(null, kind, 8);
            eq(vertices > 0, true, kind + " draws finite geometry");
        }
        G.nativeCall = null;
        Sys.println('Chest marker tests passed ($checks checks)');
    }
}
