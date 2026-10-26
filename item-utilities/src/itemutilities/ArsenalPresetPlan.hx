package itemutilities;

typedef ArsenalChoice = {
    var weapon:String;
    var skills:Array<String>;
}

/** Arsenal active skills and passives share the native per-weapon selection. */
class ArsenalPresetPlan {
    public static function saved(choices:Array<ArsenalChoice>):Array<ArsenalChoice>
        return [for (choice in choices) {weapon:Std.string(choice.weapon),
            skills:[for (skill in choice.skills) Std.string(skill)]}];

    public static function decode(value:Dynamic):Array<ArsenalChoice> {
        if (!Std.isOfType(value, Array)) throw "Invalid saved arsenal selections. Press Set to re-save this preset.";
        var result:Array<ArsenalChoice> = [];
        var seen:Map<String, Bool> = [];
        for (record in (cast value:Array<Dynamic>)) {
            var weapon:Dynamic = record == null ? null : Reflect.field(record, "weapon");
            var skills:Dynamic = record == null ? null : Reflect.field(record, "skills");
            if (!Std.isOfType(weapon, String) || weapon == "" || seen.exists(weapon)
                || !Std.isOfType(skills, Array)) throw "Invalid or duplicate saved arsenal weapon.";
            seen.set(weapon, true);
            var selected:Array<String> = [];
            for (skill in (cast skills:Array<Dynamic>)) {
                if (!Std.isOfType(skill, String) || skill == "" || selected.indexOf(skill) >= 0)
                    throw "Invalid or duplicate saved arsenal skill.";
                selected.push(skill);
            }
            result.push({weapon:weapon, skills:selected});
        }
        return result;
    }

    public static function fromPreset(preset:Dynamic):Array<ArsenalChoice>
        return Reflect.hasField(preset, "arsenals") ? decode(Reflect.field(preset, "arsenals")) : [];

    public static function same(a:Array<String>, b:Array<String>):Bool {
        if (a == null || b == null || a.length != b.length) return false;
        for (i in 0...a.length) if (a[i] != b[i]) return false;
        return true;
    }
}
