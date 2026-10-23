package moresettings;

import modinput.Hotkey;

typedef MoreSettingsConfig = {
    var hideFriendConnectionNotifications:Bool;
    var enableMissingSlashCommands:Bool;
    var sendingMessageClosesChat:Bool;
    var enableFriendNotes:Bool;
    var rebindSocialInteract:Bool;
    var socialInteractKey:Dynamic;
    var showSelfChatBubbles:Bool;
    var addMessageTimestamps:Bool;
    var fancyDamageNumbers:Bool;
    var damageNumberScale:Int;
    var damageNumberOpacity:Int;
    var damageNumberLimit:Int;
    var beeVisualLimit:Int;
    var bombletVisualLimit:Int;
    var showEnemyDistance:Bool;
    var holdSkillRepeat:Bool;
    var showSkillIconNextToDamageNumber:Bool;
    var obviousSkillProcs:Bool;
    var skillProcAlertSize:Int;
    var skillProcAlertPosition:String;
    var buffStackNumberOutline:Bool;
    // Legacy flag used once to migrate the removed checkbox.
    var disableDamageNumbers:Bool;
    var crabgantuaRockfallWarnings:Bool;
    var hideAlliedMinionHealthBars:Bool;
    var disableProfanityFilter:Bool;
    var showBossHealth:Bool;
    var performanceOptimization:Bool;
    var performanceDiagnostics:Bool;
    var preventCtrlFFullscreen:Bool;
    var waitForParty:Bool;
    var leaveDungeonButton:Bool;
    var leaveRiftButton:Bool;
    var hideUiKey:Dynamic;
    var fieldOfView:Int;
    var riftHideAllyAttacks:Bool;
    var riftHideAllyBuffs:Bool;
    var riftHideAllies:Bool;
    var riftHideOwnAttacks:Bool;
    var riftHideOwnBuffs:Bool;
    var dungeonHideAllyAttacks:Bool;
    var dungeonHideAllyBuffs:Bool;
    var dungeonHideAllies:Bool;
    var dungeonHideOwnAttacks:Bool;
    var dungeonHideOwnBuffs:Bool;
    var overworldHideAllyAttacks:Bool;
    var overworldHideAllyBuffs:Bool;
    var overworldHideAllies:Bool;
    var overworldHideOwnAttacks:Bool;
    var overworldHideOwnBuffs:Bool;
}

class SettingsData {
    public static function defaults():MoreSettingsConfig return {
        hideFriendConnectionNotifications: false,
        enableMissingSlashCommands: true,
        sendingMessageClosesChat: true,
        enableFriendNotes: true,
        rebindSocialInteract: false,
        socialInteractKey: 0, // Unassigned until the player chooses a key.
        showSelfChatBubbles: false,
        addMessageTimestamps: false,
        fancyDamageNumbers: false,
        damageNumberScale: 100,
        damageNumberOpacity: 100,
        damageNumberLimit: 20,
        beeVisualLimit: 100,
        bombletVisualLimit: 100,
        showEnemyDistance: false,
        holdSkillRepeat: false,
        showSkillIconNextToDamageNumber: false,
        obviousSkillProcs: false,
        skillProcAlertSize: 100,
        skillProcAlertPosition: "Right",
        buffStackNumberOutline: true,
        disableDamageNumbers: false,
        crabgantuaRockfallWarnings: true,
        hideAlliedMinionHealthBars: false,
        disableProfanityFilter: true,
        showBossHealth: false,
        performanceOptimization: false,
        performanceDiagnostics: false,
        preventCtrlFFullscreen: false,
        waitForParty: true,
        leaveDungeonButton: true,
        leaveRiftButton: true,
        fieldOfView: 100,
        hideUiKey: 113, // hxd.Key.F2
        riftHideAllyAttacks: false, riftHideAllyBuffs: false, riftHideAllies: false,
        riftHideOwnAttacks: false, riftHideOwnBuffs: false,
        dungeonHideAllyAttacks: false, dungeonHideAllyBuffs: false, dungeonHideAllies: false,
        dungeonHideOwnAttacks: false, dungeonHideOwnBuffs: false,
        overworldHideAllyAttacks: false, overworldHideAllyBuffs: false, overworldHideAllies: false,
        overworldHideOwnAttacks: false, overworldHideOwnBuffs: false
    };

    public static function normalize(config:MoreSettingsConfig):Void {
        // Preserve legacy keys and validate Farever-style modifier bindings.
        config.fieldOfView = Std.int(Math.max(50, Math.min(150, config.fieldOfView)));
        config.hideUiKey = Hotkey.normalize(config.hideUiKey, 113);
        config.socialInteractKey = Hotkey.normalize(config.socialInteractKey);
        config.skillProcAlertSize = Std.int(Math.max(50, Math.min(200, config.skillProcAlertSize)));
        config.damageNumberScale = percent(Reflect.field(config,"damageNumberScale"),50,150,100);
        config.damageNumberOpacity = percent(Reflect.field(config,"damageNumberOpacity"),0,100,100);
        config.damageNumberLimit = percent(Reflect.field(config,"damageNumberLimit"),0,200,20);
        config.beeVisualLimit = percent(Reflect.field(config,"beeVisualLimit"),0,100,100);
        config.bombletVisualLimit = percent(Reflect.field(config,"bombletVisualLimit"),0,100,100);
        if (config.disableDamageNumbers) {
            config.damageNumberLimit = 0; // Migrate the old checkbox once.
            config.disableDamageNumbers = false;
        }
        if (["Left", "Right", "Below"].indexOf(config.skillProcAlertPosition) < 0)
            config.skillProcAlertPosition = "Right";
    }
    static function percent(value:Dynamic,min:Int,max:Int,fallback:Int):Int {
        if(value==null)return fallback;
        var parsed=Std.parseFloat(Std.string(value));
        return !Math.isFinite(parsed)?fallback:Std.int(Math.max(min,Math.min(max,parsed)));
    }
}
