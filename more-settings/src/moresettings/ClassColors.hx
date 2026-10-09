package moresettings;

/** Class names and colors shared with the DPS meter palette. */
class ClassColors {
    public static function identify(ids:Array<String>, kind:String):String {
        for (id in ids) {
            var name = fromId(id);
            if (name != "") return name;
        }
        return fromId(kind);
    }

    public static function fromId(id:String):String {
        if (id == null || id == "") return "";
        id = id.toLowerCase();
        for (name in ["warrior", "cleric", "mage", "rogue"]) if (id.indexOf(name) >= 0) return name;
        return id.indexOf("priest") >= 0 ? "cleric" : "";
    }

    /** Same RGB values as the DPS meter's class colors. Unknown classes return -1. */
    public static function color(className:String):Int return switch (className) {
        case "warrior": 0xc95846;
        case "cleric": 0xd9b054;
        case "mage": 0x62b2c2;
        case "rogue": 0xa370be;
        default: -1;
    }
}
