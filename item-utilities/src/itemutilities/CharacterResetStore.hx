package itemutilities;

enum abstract CharacterResetKind(String) {
    var Locks = "resetLocks";
    var Equipment = "resetEquipmentPresets";
    var Talent = "resetTalentPresets";
    var Skill = "resetSkillPresets";
    var Appearance = "resetAppearancePresets";
}

/** Reset one category for one exact character ID, preserving all other data. */
class CharacterResetStore {
    public static function fields(kind:CharacterResetKind):Array<String> {
        return switch kind {
            case Locks: ["lockedItems"];
            // Equipment keeps its original storage names for compatibility.
            case Equipment: ["weaponPresets", "selectedWeaponPresets", "weaponPresetNames"];
            case Talent: ["talentPresets", "selectedTalentPresets", "talentPresetNames"];
            case Skill: ["skillPresets", "selectedSkillPresets", "skillPresetNames"];
            case Appearance: ["appearancePresets", "selectedAppearancePresets", "appearancePresetNames"];
        };
    }

    public static function label(kind:CharacterResetKind):String {
        return switch kind {
            case Locks: "Item locks";
            case Equipment: "Equipment presets";
            case Talent: "Talent presets";
            case Skill: "Skill presets";
            case Appearance: "Appearance presets";
        };
    }

    /** Copy first so a failed save cannot erase the running mod's records. */
    public static function cleared(values:Dynamic, characterId:String, kind:CharacterResetKind):Dynamic {
        requireCharacter(characterId);
        if (values == null || !Reflect.isObject(values) || Std.isOfType(values, String)
            || Std.isOfType(values, Array)) throw "Item Utilities configuration must be a JSON object.";
        var result:Dynamic = {};
        for (key in Reflect.fields(values))
            Reflect.setField(result, key, Reflect.field(values, key));
        for (key in fields(kind))
            Reflect.setField(result, key, withoutCharacter(Reflect.field(values, key), characterId));
        return result;
    }

    /** Also filters live lock records without losing other characters' runtime identities. */
    public static function withoutCharacter(values:Dynamic, characterId:String):Array<Dynamic> {
        requireCharacter(characterId);
        if (values == null) return [];
        if (!Std.isOfType(values, Array)) throw "Character record storage must be an array.";
        var entries:Array<Dynamic> = cast values;
        return entries.filter(function(entry:Dynamic):Bool {
            // Keep unrecognized records; only an exact character ID permits deletion.
            return entry == null || !Reflect.isObject(entry) || Std.isOfType(entry, String)
                || Std.isOfType(entry, Array) || Reflect.field(entry, "characterId") != characterId;
        });
    }

    static function requireCharacter(characterId:String):Void {
        if (characterId == null || StringTools.trim(characterId).length == 0)
            throw "A current character is required to reset saved data.";
    }
}
