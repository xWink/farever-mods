package moresettings;

import moresettings.SettingsData.MoreSettingsConfig;

typedef RegionFilters = {
    var attacks:Bool; var buffs:Bool; var models:Bool;
    var ownAttacks:Bool; var ownBuffs:Bool;
}

class EffectPolicy {
    public static function region(isRift:Bool, isDungeon:Bool, isOverworld:Bool):String
        return isRift ? "rift" : isDungeon ? "dungeon" : isOverworld ? "overworld" : "";

    public static function filters(config:MoreSettingsConfig, region:String):RegionFilters return switch region {
        case "rift": {attacks: config.riftHideAllyAttacks, buffs: config.riftHideAllyBuffs, models: config.riftHideAllies,
            ownAttacks: config.riftHideOwnAttacks, ownBuffs: config.riftHideOwnBuffs};
        case "dungeon": {attacks: config.dungeonHideAllyAttacks, buffs: config.dungeonHideAllyBuffs, models: config.dungeonHideAllies,
            ownAttacks: config.dungeonHideOwnAttacks, ownBuffs: config.dungeonHideOwnBuffs};
        case "overworld": {attacks: config.overworldHideAllyAttacks, buffs: config.overworldHideAllyBuffs, models: config.overworldHideAllies,
            ownAttacks: config.overworldHideOwnAttacks, ownBuffs: config.overworldHideOwnBuffs};
        default: {attacks: false, buffs: false, models: false, ownAttacks: false, ownBuffs: false};
    };

    public static function effectsActive(filters:RegionFilters):Bool
        return filters.attacks || filters.buffs || filters.ownAttacks || filters.ownBuffs;

    public static function hideEffect(isOwn:Bool, isAlly:Bool, beneficial:Bool, filters:RegionFilters):Bool
        return isOwn ? (beneficial ? filters.ownBuffs : filters.ownAttacks)
            : isAlly && (beneficial ? filters.buffs : filters.attacks);
}
