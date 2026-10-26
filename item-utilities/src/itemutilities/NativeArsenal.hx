package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.ArsenalPresetPlan.ArsenalChoice;

/** Use ArsenalEdition's reader, validity predicate, and owned-object RPC. */
class NativeArsenal {
    static inline var SPECIALIZATION = "st.player.HeroSpecialization";

    public static function current(specialization:Dynamic, weapon:String):Array<String> {
        if (specialization == null) throw "The character's arsenal is not ready yet.";
        var values = G.call(SPECIALIZATION, "getArsenalSkills", specialization, [weapon]);
        if (values == null) throw "The character's arsenal is not ready yet.";
        return [for (value in G.array(values)) G.text(value)];
    }

    static function definition(sheet:String, id:String):Dynamic {
        var map = G.field(G.current("Data", sheet), "byId");
        return G.call("haxe.ds.StringMap", "get", map, [id]);
    }

    public static function capture(hero:Dynamic, items:Array<Dynamic>):Array<ArsenalChoice> {
        var choices:Array<ArsenalChoice> = [];
        var seen:Map<String, Bool> = [];
        for (item in items) {
            if (!G.isA(item, "st.item.Weapon")) continue;
            var weapon = G.text(G.field(item, "kind"));
            if (weapon == "" || seen.exists(weapon)) continue;
            seen.set(weapon, true);
            var inf = G.field(item, "inf");
            var hasChoices = false;
            for (entry in G.array(G.field(inf, "skills")))
                if (G.staticCall("st.item.Weapon", "isValidArsenalSkill", [inf, G.field(entry, "skill")]) == true)
                    hasChoices = true;
            if (hasChoices) choices.push({weapon:weapon,
                skills:current(G.field(hero, "specialization"), weapon)});
        }
        validate(hero, choices);
        return choices;
    }

    public static function validate(hero:Dynamic, choices:Array<ArsenalChoice>):Void {
        if (choices.length == 0) return;
        var limit = G.integer(G.call("ent.Hero", "getNbArsenalSkillSlots", hero));
        for (choice in choices) {
            var inf = definition("item", choice.weapon);
            if (inf == null) throw "A saved arsenal weapon is no longer available.";
            if (choice.skills.length > limit) throw "The saved arsenal selection requires more unlocked slots.";
            for (skill in choice.skills)
                if (G.staticCall("st.item.Weapon", "isValidArsenalSkill", [inf, skill]) != true)
                    throw "A saved arsenal skill or passive is no longer available for this weapon.";
        }
    }

    public static function apply(hero:Dynamic, choice:ArsenalChoice):Void {
        validate(hero, [choice]);
        var specialization = G.field(hero, "specialization");
        // Allocate through the game's array methods. Passing a mod-owned
        // Array<String> to the native RPC would cross incompatible HL types.
        var current = G.call(SPECIALIZATION, "getArsenalSkills", specialization, [choice.weapon]);
        var skills = G.call("hl.types.ArrayObj", "copy", current);
        G.call("hl.types.ArrayObj", "resize", skills, [0]);
        for (skill in choice.skills) {
            var nativeId = G.field(definition("skill", skill), "id");
            if (nativeId == null) throw "A saved arsenal skill is no longer available.";
            G.call("hl.types.ArrayObj", "push", skills, [nativeId]);
        }
        var weapon = G.field(definition("item", choice.weapon), "id");
        G.call(SPECIALIZATION, "setArsenalSkills", specialization, [weapon, skills]);
    }
}
