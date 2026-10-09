package minimap;

typedef MenuItem = {
    var key:String;
    var label:String;
}

typedef MenuShortcut = {
    var id:String;
    var label:String;
    var color:Int;
    var masters:Array<String>;
    var items:Array<MenuItem>;
}

/** Category toggles and the checkbox rows each one opens. Sliders stay in the settings window. */
class MinimapMenu {
    public static function shortcuts():Array<MenuShortcut> return [
        shortcut("players", "Players", 0x70d8ff, ["showPlayers"], [
            item("showPlayers", "Show other players"),
            item("hideNonPartyPlayers", "Hide players outside your party"),
            item("partyDirectionArrows", "Party direction arrows")
        ]),
        shortcut("resources", "Resources", 0x77df81, ["showOre", "showPlants"], [
            item("showOre", "Show ore"),
            item("hideCopper", "Hide Copper"),
            item("hideIron", "Hide Iron"),
            item("hideTin", "Hide Tin"),
            item("hideTungstene", "Hide Tungstene"),
            item("showPlants", "Show plants"),
            item("hideMadrigold", "Hide Madrigold"),
            item("hideLavendula", "Hide Lavendula"),
            item("hideAncientThyme", "Hide Ancient Thyme"),
            item("hideZealotus", "Hide Zealotus")
        ]),
        shortcut("enemies", "Enemies", 0xff6860, ["showEnemies"], [
            item("showEnemies", "Show enemies"),
            item("alwaysShowEliteEnemies", "Always show elite enemies"),
            item("hideMasteredCodexEnemies", "Hide mastered Codex enemies"),
            item("hideCompletedCodexEnemies", "Hide partially completed Codex enemies"),
            item("hideTargetDummies", "Hide target dummies")
        ]),
        shortcut("companions", "Companions", 0x5dce8a, ["showCompanions"], [
            item("showCompanions", "Show companions"),
            item("hideCollectedCompanions", "Hide collected companions"),
            item("sparklingCompanionAlerts", "Sparkling companion alerts")
        ]),
        shortcut("chests", "Chests", 0xffa044, ["showChests"], [
            item("showChests", "Show chests")
        ]),
        shortcut("orbs", "Orbs", 0xffd24a, ["showSecretOrbs"], [
            item("showSecretOrbs", "Show secret orbs")
        ]),
        shortcut("npcs", "NPCs", 0xffdf78, ["showNpcs"], [
            item("showNpcs", "Show NPCs")
        ]),
        shortcut("landmarks", "Landmarks", 0xb7bcc7, ["showRespawnPoints", "showObelisks", "showSoulstoneCircles"], [
            item("showRespawnPoints", "Show respawn points"),
            item("showObelisks", "Show obelisks"),
            item("showSoulstoneCircles", "Show soulstone summoning circles"),
            item("hideVerticallyDistantMarkers", "Hide vertically distant markers")
        ]),
        shortcut("activities", "Activities", 0x7f3e91, ["showActivities"], [
            item("showActivities", "Show activities"),
            item("hideCompletedActivities", "Hide completed activities"),
            item("hideAscensions", "Hide ascensions"),
            item("hideDungeons", "Hide dungeons"),
            item("hideInactiveRifts", "Hide inactive Rift locations")
        ])
    ];

    public static function find(id:String):MenuShortcut {
        for (shortcut in shortcuts()) if (shortcut.id == id) return shortcut;
        return null;
    }

    /** A category reads as on when any of its main switches is on. */
    public static function lit(config:Dynamic, keys:Array<String>):Bool {
        for (key in keys) if (Reflect.field(config, key) == true) return true;
        return false;
    }

    /** Left-click turns every main switch on, or all of them off when any is on. */
    public static function masterValues(config:Dynamic, keys:Array<String>):Map<String, Bool> {
        var on = !lit(config, keys);
        return [for (key in keys) key => on];
    }

    public static function checked(config:Dynamic, key:String):Bool
        return Reflect.field(config, key) == true;

    static function shortcut(id:String, label:String, color:Int, masters:Array<String>, items:Array<MenuItem>):MenuShortcut
        return {id: id, label: label, color: color, masters: masters, items: items};

    static function item(key:String, label:String):MenuItem
        return {key: key, label: label};
}
