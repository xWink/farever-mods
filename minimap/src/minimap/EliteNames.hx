package minimap;

/** World elites. Unit ids are checked first; the English display name is the fallback. */
class EliteNames {
    static var names:Map<String, Bool>;
    static var ids:Map<String, Bool>;

    public static function hasId(id:String):Bool {
        if (id == null || id == "") return false;
        ensure();
        return ids.exists(id);
    }

    public static function has(name:String):Bool {
        if (name == null || name == "") return false;
        ensure();
        return names.exists(key(name));
    }

    public static function key(name:String):String {
        var out = new StringBuf();
        var i = 0;
        while (i < name.length) {
            var code = name.charCodeAt(i);
            if (code >= 65 && code <= 90) code += 32;
            if ((code >= 97 && code <= 122) || (code >= 48 && code <= 57)) out.addChar(code);
            i++;
        }
        return out.toString();
    }

    static function ensure():Void {
        if (names != null) return;
        names = [];
        ids = [];
        for (id in [
            "Bee_Z1W_E", "Boar_Z1W_E", "Boar_Z2W_E", "Boar_Z4W_E", "Crab_Z1W_E", "Crab_Z2W_E",
            "Crawler_Z1W_E", "Crimson_Z1W_Captain_E", "Crimson_Z2W_Captain_E", "Crimson_Z2W_Peasant_E",
            "Crimson_Z3W_Caster_E", "Crimson_Z3W_Daggers_E", "Crimson_Z3W_GA_E", "Crimson_Z3W_Sword_E",
            "Demon_Z3W_Claws_E", "Demon_Z3W_Spear_E", "Dog_Z3W_E", "FaerieBee_Z1W_Claws_E",
            "FaerieBee_Z1W_GreatMace_E", "FaerieBee_Z2W_Champ_E", "FaerieBee_Z2W_GreatMace_E",
            "FaerieDemon_Z3W_Caster_E", "Golem_Z1W_Earth_E", "Golem_Z2W_E", "Golem_Z2W_FireExplosive_E",
            "OgreHuman_Z2W_Peasant_E", "OgreHuman_Z3W_GM_E", "OgreManfish_Z2W_Claws_E",
            "Slime_Demonic_Z3W_E", "Slime_Z1W_E", "Spirit_Z2W_Claws_E", "Spirit_Z3W_Claws_E",
            "Sprout_Rice_Z2W_E", "Wolf_Z1W_E"
        ]) ids.set(id, true);
        for (name in [
            "Ariana Grandemon", "Asmodeaf", "Baphometal", "Bartlebee", "Beelial", "Beet the Maul",
            "Belzebeat", "Belzebubbles", "Blaze Rascal", "Blob Dylan", "Boar Burnham",
            "Captain Druss", "Captain Ramshackle", "Captain Wolfram", "Carcinos the Proud",
            "Celeryman Pumpkintaro", "Charles Cabbage", "Crimson Captain Agamemnon", "Crimson Captain Alex",
            "Crimson Captain Arthur", "Crimson Captain Ben", "Crimson Captain Carmine", "Crimson Captain Clover",
            "Crimson Captain Cynthia", "Crimson Captain Hector", "Crimson Captain Joseph", "Crimson Captain Katy",
            "Crimson Captain Roger", "Crimson Captain Sensabille", "da'Lida", "da'Mascus", "da'Rius",
            "Draculag, aspiring Nightgod", "Fangandog", "Fiddle Crabstro", "Garlic Hooper", "Gilliver",
            "Golatea", "Goledeneye", "Grill Arson", "Gruffy", "Heraclette", "Honey Mucha", "Honey Zucca",
            "Jared Lettuce", "Jelly Lewis", "Jimmy Crater", "Knight Slime", "Kraba the Sorceress", "Krabby Jacob",
            "Kristian Belial", "Lady Borgild", "Lady Zaster", "Lilithium", "Luciferrari", "Mortalkombaal",
            "Niels Boar", "Nightling Deathbringer", "Nightling Ruinbringer", "Nightling Warbringer",
            "Nightlord Asmoderator", "Nightlord Diabloot", "Nightlord Naamahs'tea", "Notorious Bee",
            "Pastor Ramen", "Ram Page", "Ram Stein, the Janitor", "Ramface", "Right Wing", "Scummy BlackGill",
            "Seed Barrett", "Seed Vicious", "Skuttle Goldengill", "Smeagolem", "Turnip Arker",
            "Ugly Naked Guy", "Venerer's Hog"
        ]) names.set(key(name), true);
    }
}
