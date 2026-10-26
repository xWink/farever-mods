// A separate HashLink module owns these strings, just as the game does.
@:keep
class SkillPresetStringFixture {
    public static var skill:String;
    public static var firstRune:String;
    public static var secondRune:String;
    public static var otherSkill:String;
    public static var otherRune:String;
    public static var signature:String;
    public static var signatureRune1:String;
    public static var signatureRune2:String;
    public static var conduit:String;
    public static var arsenalWeapon:String;
    public static var arsenalSkill:String;
    public static var arsenalPassive:String;
    public static var arsenalSkills:Array<String>;
    public static var acceptArsenalRequest:Dynamic;
}

class SkillPresetSerializationHost {
    @:hlNative("std", "sys_load_plugin")
    static function loadPlugin(path:hl.Bytes):Bool return false;

    static function main():Void {
        SkillPresetStringFixture.skill = "ClassSkill_Test";
        SkillPresetStringFixture.firstRune = "ClassSkill_Test_Rune1";
        SkillPresetStringFixture.secondRune = "ClassSkill_Test_Rune2";
        SkillPresetStringFixture.otherSkill = "ClassSkill_Other";
        SkillPresetStringFixture.otherRune = "ClassSkill_Other_Rune1";
        SkillPresetStringFixture.signature = "Priest_Sig_DivineIntervention";
        SkillPresetStringFixture.signatureRune1 = "Priest_Judgment_M1";
        SkillPresetStringFixture.signatureRune2 = "Priest_Judgment_M2";
        SkillPresetStringFixture.conduit = "Mage_Conduit_Projectile";
        SkillPresetStringFixture.arsenalWeapon = "Weapon_Bow";
        SkillPresetStringFixture.arsenalSkill = "Bow_Shot";
        SkillPresetStringFixture.arsenalPassive = "Bow_Passive";
        SkillPresetStringFixture.arsenalSkills = [SkillPresetStringFixture.arsenalPassive];
        SkillPresetStringFixture.acceptArsenalRequest = function(weapon:String, skills:Array<String>):Bool {
            return weapon == SkillPresetStringFixture.arsenalWeapon
                && Type.getClass(skills) == Type.getClass(SkillPresetStringFixture.arsenalSkills)
                && skills.length == 2 && skills[0] == SkillPresetStringFixture.arsenalSkill
                && skills[1] == SkillPresetStringFixture.arsenalPassive;
        };
        if (!loadPlugin(@:privateAccess "build/skill-serialization-plugin.hl".bytes))
            throw "Unable to load skill serialization test plugin.";
    }
}
