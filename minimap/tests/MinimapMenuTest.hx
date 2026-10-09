import minimap.MinimapMenu;

class MinimapMenuTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var shortcuts = MinimapMenu.shortcuts();
        eq(shortcuts.length, 9, "one toggle for each marker category");
        var ids = [for (shortcut in shortcuts) shortcut.id];
        eq(ids.join(","), "players,resources,enemies,companions,chests,orbs,npcs,landmarks,activities",
            "toggles follow the categories on the map");
        var keys:Array<String> = [];
        for (shortcut in shortcuts) for (entry in shortcut.items) keys.push(entry.key);
        eq(keys.length, 33, "every marker checkbox is in a category dropdown");
        eq(keys.indexOf("alwaysShowEliteEnemies") >= 0, true, "elite enemies have their own toggle");
        eq(keys.indexOf("zoom") < 0 && keys.indexOf("size") < 0 && keys.indexOf("enabled") < 0, true,
            "sliders and general display options stay out of the dropdowns");
        eq(keys.indexOf("showPlayers") >= 0 && keys.indexOf("hideNonPartyPlayers") >= 0
            && keys.indexOf("partyDirectionArrows") >= 0, true, "player options stay with the player toggle");
        eq(MinimapMenu.find("resources").label, "Resources", "resources is one category");
        eq(MinimapMenu.find("missing"), null, "unknown categories do not invent a menu");

        var config = {showOre: true, showPlants: false, showPlayers: false};
        eq(MinimapMenu.lit(config, ["showOre", "showPlants"]), true, "either resource switch lights the toggle");
        var next = MinimapMenu.masterValues(config, ["showOre", "showPlants"]);
        eq(next["showOre"] == false && next["showPlants"] == false, true, "a lit category turns all of its main switches off");
        config.showOre = false;
        next = MinimapMenu.masterValues(config, ["showOre", "showPlants"]);
        eq(next["showOre"] == true && next["showPlants"] == true, true, "a dark category turns all of its main switches on");
        eq(MinimapMenu.checked(config, "showPlayers"), false, "an off checkbox stays unchecked");
        eq(MinimapMenu.checked({showChests: true}, "showChests"), true, "an on checkbox stays checked");

        trace("MinimapMenuTest passed (" + checks + " checks)");
    }
}
