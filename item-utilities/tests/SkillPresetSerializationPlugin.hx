import SkillPresetSerializationHost.SkillPresetStringFixture;
import itemutilities.SkillPresetPlan;
import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetRules;
import itemutilities.ArsenalPresetPlan;
import itemutilities.NativeArsenal;
import itemutilities.InspectAccess as G;

class SkillPresetSerializationPlugin {
    @:hlNative("std", "sys_resolve_type")
    static function resolveType(type:hl.Type, companionType:hl.Type):Dynamic return null;

    static function check(value:Bool, message:String):Void {
        if (!value) throw message;
    }

    static function main():Void {
        var companion:hl.BaseType = cast SkillPresetStringFixture;
        var host = resolveType(companion.__type__, hl.Type.getDynamic(companion));
        check(host != null, "Host fixture must be available.");
        var skill:String = cast Reflect.field(host, "skill");
        var firstRune:String = cast Reflect.field(host, "firstRune");
        var secondRune:String = cast Reflect.field(host, "secondRune");
        var otherRune:String = cast Reflect.field(host, "otherRune");
        var owners:Map<String, String> = [];
        owners.set(firstRune, skill);
        owners.set(secondRune, skill);
        owners.set(otherRune, cast Reflect.field(host, "otherSkill"));
        check(Type.getClass(skill) != String && Type.getClass(firstRune) != String,
            "Fixture must use foreign skill and rune String classes.");
        var rules:SkillPresetRules = {
            skills: [skill => [firstRune, secondRune]],
            unlockedSlots: [true, true, true, true], maxRunes: 2
        };

        for (runes in [[], [firstRune], [secondRune], [firstRune, secondRune]]) {
            var current:SkillPresetState = {slots: [skill, null, null, null], runes: runes.concat([otherRune])};
            var encoded = SkillPresetPlan.saved(current, owners);
            // Applying immediately and applying after a login use different paths.
            var immediate = SkillPresetPlan.decode(encoded);
            var restored = SkillPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(encoded)));
            for (target in [immediate, restored]) {
                check(target[0].skill == "ClassSkill_Test", "Preserve the skill ID.");
                check(target[0].runes.join(",") == runes.join(","), "Preserve the exact rune selection.");
                check(Std.isOfType(target[0].skill, String), "Save a local skill String.");
                for (rune in target[0].runes) check(Std.isOfType(rune, String), "Save local rune Strings.");
                for (slot in target.slice(1))
                    check(slot.skill == null && slot.runes.length == 0, "Keep empty slots null.");
                SkillPresetPlan.validate(target, rules);
                check(SkillPresetPlan.build(current, target, rules, owners).length == 0,
                    "An unchanged native skill/rune selection sends no requests.");
            }
            check(Type.getClass(current.slots[0]) != String, "Saving leaves the game-owned state intact.");
        }

        var current:SkillPresetState = {slots: [skill, null, null, null], runes: [firstRune, otherRune]};
        var target = SkillPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(
            SkillPresetPlan.saved({slots: current.slots, runes: [secondRune, otherRune]}, owners))));
        var changes = SkillPresetPlan.build(current, target, rules, owners);
        check(changes.length == 2, "Changing only a rune requires exactly two requests.");
        check(changes[0].slot == -1 && !changes[0].enable && changes[0].rune == firstRune,
            "Remove the previous rune before enabling the saved rune.");
        check(changes[1].slot == -1 && changes[1].enable && changes[1].rune == secondRune,
            "Enable the saved replacement rune without changing skill slots.");
        check(SkillPresetPlan.same(changes[1].after,
            {slots: current.slots, runes: [secondRune, otherRune]}),
            "Preserve rune preferences belonging to unequipped skills.");

        var signature:String = cast Reflect.field(host, "signature");
        var signatureRune1:String = cast Reflect.field(host, "signatureRune1");
        var signatureRune2:String = cast Reflect.field(host, "signatureRune2");
        owners.set(signatureRune1, signature); owners.set(signatureRune2, signature);
        rules.signatures = [signature => [signatureRune1, signatureRune2]];
        check(Type.getClass(signature) != String && Type.getClass(signatureRune1) != String,
            "Signature fixture must use game-owned string identities too.");
        var before:SkillPresetState = {slots:current.slots, runes:[firstRune, signatureRune1, otherRune]};
        for (selection in [[], [signatureRune1], [signatureRune2], [signatureRune1, signatureRune2]]) {
            var desired:SkillPresetState = {slots:before.slots, runes:[firstRune, otherRune].concat(selection)};
            var savedSignatures = SkillPresetPlan.savedSignatures(desired, owners, rules);
            for (target in [SkillPresetPlan.decodeSignatures(savedSignatures),
                SkillPresetPlan.decodeSignatures(haxe.Json.parse(haxe.Json.stringify(savedSignatures)))]) {
                check(target.length == 1 && Std.isOfType(target[0].skill, String),
                    "Save the signature skill ID as a local JSON string.");
                check(target[0].skill == "Priest_Sig_DivineIntervention" && target[0].runes.join(",") == selection.join(","),
                    "Keep the exact signature rune selection, including empty and multiple selections.");
                for (rune in target[0].runes) check(Std.isOfType(rune, String), "Signature runes are local strings.");
                var classSlots = SkillPresetPlan.saved(desired, owners);
                var changes = SkillPresetPlan.build(before, classSlots, rules, owners, target);
                for (change in changes) check(change.slot == -1 && change.skill == signature,
                    "Signature selections produce only normal rune requests, never slot assignments.");
                var after = changes.length == 0 ? before : changes[changes.length - 1].after;
                check(SkillPresetPlan.same(after, desired), "Apply signature runes without changing other skills/runes.");
            }
        }
        var conduit:String = cast Reflect.field(host, "conduit");
        check(Type.getClass(conduit) != String, "Conduit fixture must be game-owned.");
        var conduitState:SkillPresetState = {slots:current.slots, runes:current.runes, conduits:[conduit,null,conduit]};
        var savedConduits = SkillPresetPlan.savedConduits(conduitState);
        for (choices in [savedConduits, haxe.Json.parse(haxe.Json.stringify(savedConduits))]) {
            var decoded = SkillPresetPlan.decodeConduits(choices,3);
            check(Std.isOfType(decoded[0],String) && decoded[0]=="Mage_Conduit_Projectile" && decoded[1]==null,
                "Conduit IDs save as local strings, immediately and across login sessions.");
            check(SkillPresetPlan.build(conduitState, SkillPresetPlan.saved(conduitState,owners), rules, owners,
                null, decoded).length==0, "Foreign native conduit IDs compare correctly against restored choices.");
        }
        var weapon:String = cast Reflect.field(host, "arsenalWeapon");
        var weaponSkill:String = cast Reflect.field(host, "arsenalSkill");
        var passive:String = cast Reflect.field(host, "arsenalPassive");
        var nativeSelection:Dynamic = Reflect.field(host, "arsenalSkills");
        check(Type.getClass(weapon) != String && Type.getClass(passive) != String,
            "Arsenal fixture uses game-owned weapon and passive IDs.");
        var arsenalSaved = ArsenalPresetPlan.saved([{weapon:weapon, skills:[weaponSkill, passive]}]);
        for (target in [ArsenalPresetPlan.decode(arsenalSaved),
            ArsenalPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(arsenalSaved)))]) {
            check(Std.isOfType(target[0].weapon, String) && Std.isOfType(target[0].skills[1], String),
                "Arsenal IDs save as strings both immediately and across login sessions.");
            check(target[0].weapon == "Weapon_Bow" && target[0].skills.join(",") == "Bow_Shot,Bow_Passive",
                "Arsenal weapon, active skill and passive are preserved exactly.");
            G.data = {item:{byId:(["Weapon_Bow" => {id:weapon, valid:[weaponSkill,passive]}]:Map<String,Dynamic>)},
                skill:{byId:(["Bow_Shot" => {id:weaponSkill}, "Bow_Passive" => {id:passive}]:Map<String,Dynamic>)}};
            var specialization:Dynamic = {arsenals:(["Weapon_Bow" => nativeSelection]:Map<String,Dynamic>)};
            var hero:Dynamic = {specialization:specialization, limit:2};
            NativeArsenal.apply(hero, target[0]);
            var request:Dynamic = specialization.request;
            check(Reflect.callMethod(host, Reflect.field(host, "acceptArsenalRequest"),
                [request.weapon, request.skills]) == true,
                "Native arsenal RPC receives the host module's array and string types.");
            check(ArsenalPresetPlan.same(NativeArsenal.current(specialization, weapon), [passive]),
                "Request construction never changes the original game-owned selection.");
        }
        Sys.println("Skill and arsenal preset cross-module serialization passed.");
    }
}
