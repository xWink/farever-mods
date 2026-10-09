package moresettings;

typedef MoreSettingsConfig = {
    var hideFriendConnectionNotifications:Bool;
    var enableMissingSlashCommands:Bool;
    var sendingMessageClosesChat:Bool;
    var enableFriendNotes:Bool;
    var rebindSocialInteract:Bool;
    var socialInteractKey:Int;
    var fancyDamageNumbers:Bool;
    var classColoredNames:Bool;
    var showNameplateWeapons:Bool;
    var disableDamageNumbers:Bool;
    var crabgantuaRockfallWarnings:Bool;
    var hideAlliedMinionHealthBars:Bool;
    var disableProfanityFilter:Bool;
    var showBossHealth:Bool;
    var performanceOptimization:Bool;
    var performanceDiagnostics:Bool;
    var waitForParty:Bool;
    var leaveDungeonButton:Bool;
    var hideUiKey:Int;
    var riftHideAllyAttacks:Bool;
    var riftHideAllyBuffs:Bool;
    var riftHideAllies:Bool;
    var dungeonHideAllyAttacks:Bool;
    var dungeonHideAllyBuffs:Bool;
    var dungeonHideAllies:Bool;
    var overworldHideAllyAttacks:Bool;
    var overworldHideAllyBuffs:Bool;
    var overworldHideAllies:Bool;
}

class SettingsData {
    public static function defaults():MoreSettingsConfig return {
        hideFriendConnectionNotifications: false,
        enableMissingSlashCommands: true,
        sendingMessageClosesChat: true,
        enableFriendNotes: true,
        rebindSocialInteract: false,
        socialInteractKey: 0, // Unassigned until the player chooses a key.
        fancyDamageNumbers: false,
        classColoredNames: true,
        showNameplateWeapons: true,
        disableDamageNumbers: false,
        crabgantuaRockfallWarnings: true,
        hideAlliedMinionHealthBars: false,
        disableProfanityFilter: true,
        showBossHealth: false,
        performanceOptimization: false,
        performanceDiagnostics: false,
        waitForParty: true,
        leaveDungeonButton: true,
        hideUiKey: 113, // hxd.Key.F2
        riftHideAllyAttacks: false, riftHideAllyBuffs: false, riftHideAllies: false,
        dungeonHideAllyAttacks: false, dungeonHideAllyBuffs: false, dungeonHideAllies: false,
        overworldHideAllyAttacks: false, overworldHideAllyBuffs: false, overworldHideAllies: false
    };

    public static function normalize(config:MoreSettingsConfig):Void {
        // Same single-key range as Better Mod Settings; zero means unassigned.
        if (config.hideUiKey < 0 || config.hideUiKey >= 512 || config.hideUiKey == 27) config.hideUiKey = 113;
        if (config.socialInteractKey < 0 || config.socialInteractKey >= 512 || config.socialInteractKey == 27) config.socialInteractKey = 0;
    }
}
