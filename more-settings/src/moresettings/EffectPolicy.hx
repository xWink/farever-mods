package moresettings;

import moresettings.SettingsData.MoreSettingsConfig;

typedef RegionFilters = { var attacks:Bool; var buffs:Bool; var models:Bool; }

class EffectPolicy {
    public static function region(isRift:Bool, isDungeon:Bool, isOverworld:Bool):String
        return isRift ? "rift" : isDungeon ? "dungeon" : isOverworld ? "overworld" : "";

    public static function filters(config:MoreSettingsConfig, region:String):RegionFilters return switch region {
        case "rift": {attacks: config.riftHideAllyAttacks, buffs: config.riftHideAllyBuffs, models: config.riftHideAllies};
        case "dungeon": {attacks: config.dungeonHideAllyAttacks, buffs: config.dungeonHideAllyBuffs, models: config.dungeonHideAllies};
        case "overworld": {attacks: config.overworldHideAllyAttacks, buffs: config.overworldHideAllyBuffs, models: config.overworldHideAllies};
        default: {attacks: false, buffs: false, models: false};
    };

    public static function hideEffect(isOwn:Bool, isAlly:Bool, beneficial:Bool, filters:RegionFilters):Bool
        return !isOwn && isAlly && (beneficial ? filters.buffs : filters.attacks);
}
