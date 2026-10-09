import moresettings.ClassColors;
import moresettings.SettingsData;

class ClassColorsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        eq(SettingsData.defaults().classColoredNames, true, "class colored names start enabled");
        eq(ClassColors.fromId("Warrior_Slash"), "warrior", "warrior skills map to warrior");
        eq(ClassColors.fromId("Priest_Heal"), "cleric", "priest skills use the cleric color");
        eq(ClassColors.fromId("Mage_Bolt"), "mage", "mage skills map to mage");
        eq(ClassColors.fromId("Rogue_Stab"), "rogue", "rogue skills map to rogue");
        eq(ClassColors.fromId("Class_Warrior"), "warrior", "replicated hero kind is the class");
        eq(ClassColors.fromId("Class_Priest"), "cleric", "priest hero kind uses the cleric color");
        eq(ClassColors.fromId("Class_Mage"), "mage", "mage hero kind maps to mage");
        eq(ClassColors.fromId("Class_Rogue"), "rogue", "rogue hero kind maps to rogue");
        eq(ClassColors.fromId("Mount_Dash"), "", "unrelated ids are not a class");
        eq(ClassColors.identify(["Mount_Dash", "Skill_Mage_Fire"], ""), "mage", "the first class skill wins");
        eq(ClassColors.identify([], "Skin_Rogue_01"), "rogue", "hero kind is the fallback");
        eq(ClassColors.color("warrior"), 0xc95846, "warrior matches the DPS meter");
        eq(ClassColors.color("cleric"), 0xd9b054, "cleric matches the DPS meter");
        eq(ClassColors.color("mage"), 0x62b2c2, "mage matches the DPS meter");
        eq(ClassColors.color("rogue"), 0xa370be, "rogue matches the DPS meter");
        eq(ClassColors.color(""), -1, "unknown classes keep the native name color");
        Sys.println('Class color tests passed ($checks checks)');
    }
}
