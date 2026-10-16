package minimap;

typedef MinimapSettings = {
    /** Shared category/subfilter exclusions; retain the key to preserve saved main-map choices. */
    var ?mainMapHiddenFilters:Array<String>;
    var ?mainMapMarkerScale:Float;
    var ?mainMapMovement:Bool;
    var enabled:Bool;
    var transparency:Int;
    var zoom:Float;
    var size:Int;
    var markerScale:Float;
    var rotateMap:Bool;
    var followCamera:Bool;
    var circular:Bool;
    /** Legacy import only; converted to xOffset and removed before saving. */
    var ?leftCorner:Bool;
    var showNorthIndicator:Bool;
    var clockTimerMode:String;
    // Retained only to import older configs; no longer exposed as a setting.
    var showRiftTimer:Bool;
    var riftAlerts:Bool;
    var xOffset:Float;
    var yOffset:Float;
    var showPlayers:Bool;
    var showPlants:Bool;
    var showOre:Bool;
    var showEnemies:Bool;
    var hideCompletedCodexEnemies:Bool;
    var hideMasteredCodexEnemies:Bool;
    var hideTargetDummies:Bool;
    var showCompanions:Bool;
    var hideCollectedCompanions:Bool;
    var sparklingCompanionAlerts:Bool;
    var showRespawnPoints:Bool;
    var showObelisks:Bool;
    var showSoulstoneCircles:Bool;
    var showNpcs:Bool;
    var showChests:Bool;
    var showSecretOrbs:Bool;
    var hideVerticallyDistantMarkers:Bool;
    var verticallyDistantThreshold:Float;
    var showActivities:Bool;
    var hideCompletedActivities:Bool;
    var hideAscensions:Bool;
    var hideDungeons:Bool;
    var hideInactiveRifts:Bool;
    var hideCopper:Bool;
    var hideIron:Bool;
    var hideTin:Bool;
    var hideTungstene:Bool;
    var hideMadrigold:Bool;
    var hideLavendula:Bool;
    var hideAncientThyme:Bool;
    var hideZealotus:Bool;
}
