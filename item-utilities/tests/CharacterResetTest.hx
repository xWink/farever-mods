import haxe.Json;
import itemutilities.CharacterResetStore;
import itemutilities.CharacterResetStore.CharacterResetKind;
import itemutilities.ItemLockState;

class CharacterResetTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function same(actual:Dynamic, expected:Dynamic, message:String):Void {
        check(Json.stringify(actual) == Json.stringify(expected), message);
    }
    static function rejects(action:Void->Void, message:String):Void {
        var rejected = false;
        try action() catch (_:Dynamic) rejected = true;
        check(rejected, message);
    }

    static function main():Void {
        var cases:Array<{kind:CharacterResetKind, keys:Array<String>, section:String}> = [
            {kind: Locks, keys: ["lockedItems"], section: "Locking"},
            {kind: Equipment, keys: ["weaponPresets", "selectedWeaponPresets"], section: "Equipment Presets"},
            {kind: Talent, keys: ["talentPresets", "selectedTalentPresets"], section: "Talent Presets"},
            {kind: Skill, keys: ["skillPresets", "selectedSkillPresets"], section: "Skill Presets"},
            {kind: Appearance, keys: ["appearancePresets", "selectedAppearancePresets"], section: "Appearance Presets"}
        ];
        var values:Dynamic = {
            enabled: false, preset1Hotkey: 49, talentPreset1Hotkey: 50,
            skillPreset1Hotkey: 51, appearancePreset1Hotkey: 52,
            showLockVisuals: true, sortingIgnoresLockedItems: true,
            futureOption: {preserve: "exactly"}
        };
        for (c in cases) for (key in c.keys) {
            Reflect.setField(values, key, [
                {characterId: "db:1", preset: 0, classId: "Warrior", payload: key + " first"},
                {characterId: "db:10", preset: 0, classId: "Warrior", payload: key + " other"},
                {characterId: "db:1", preset: 1, classId: "Warrior", payload: key + " second"},
                {characterId: "db:100", preset: 2, classId: "Warrior", payload: key + " another"},
                {characterId: "db:1", preset: 2, classId: "Warrior", payload: key + " third"},
                {characterId: "db:1", preset: 3, classId: "Warrior", payload: key + " fourth"},
                {characterId: "db:1", preset: 4, classId: "Warrior", payload: key + " fifth"}
            ]);
        }
        // Use real lock shapes, including duplicate identities and an unresolved lock.
        values.lockedItems = Json.parse('[{"characterId":"db:1","uid":"a","fingerprint":"net"},{"characterId":"db:10","uid":"a","fingerprint":"net"},{"characterId":"db:1","uid":"a","fingerprint":"net"},{"characterId":"db:100","uid":"b","fingerprint":"net"},{"characterId":"db:1","uid":"unresolved","fingerprint":"missing"}]');
        var original = Json.stringify(values);
        for (c in cases) {
            var result = CharacterResetStore.cleared(values, "db:1", c.kind);
            same(values, Json.parse(original), "reset never mutates original config before a save");
            for (key in Reflect.fields(values)) {
                var source:Dynamic = Reflect.field(values, key);
                same(Reflect.field(result, key), c.keys.indexOf(key) >= 0 ? [source[1], source[3]] : source,
                    c.section + " reset preserves other categories/characters: " + key);
            }
            var reloaded = Json.parse(Json.stringify(result));
            same(CharacterResetStore.cleared(reloaded, "db:1", c.kind), reloaded, "repeat reset after reload stays cleared");
            same(CharacterResetStore.cleared(values, "db:unknown", c.kind), values, "unknown character cannot delete other data");
            for (id in [null, "", "   "])
                rejects(function() CharacterResetStore.cleared(values, id, c.kind), "missing character is never a global reset");
            var malformed = Json.parse(original);
            Reflect.setField(malformed, c.keys[0], "bad records");
            rejects(function() CharacterResetStore.cleared(malformed, "db:1", c.kind), "malformed target category cannot be overwritten");
            var unknown = CharacterResetStore.withoutCharacter(Json.parse('[null,{},"unknown",[],{"characterId":null}]'), "db:1");
            same(unknown, Json.parse('[null,{},"unknown",[],{"characterId":null}]'), "records with unknown ownership are preserved");
        }

        // Restored locks keep live object identity, unlike the serialized config.
        var activeItem:Dynamic = {};
        var otherItem:Dynamic = {};
        var active:Dynamic = {characterId: "db:1", uid: "a", fingerprint: "net", item: activeItem, restored: true, known: ["a"]};
        var other:Dynamic = {characterId: "db:10", uid: "b", fingerprint: "net", item: otherItem, restored: true, known: ["b"]};
        var unresolved:Dynamic = {characterId: "db:1", uid: "old", fingerprint: "net", item: null, restored: false, known: []};
        var live = CharacterResetStore.withoutCharacter([active, other, unresolved], "db:1");
        check(live.length == 1 && live[0] == other && live[0].item == otherItem && live[0].restored,
            "other character retains confirmed lock object and state");
        var tracked:Dynamic = {characterId: "db:1", uid: "a", fingerprint: "net", item: activeItem, location: "inventory", index: 0};
        var current:Map<String, Dynamic> = ["a" => tracked];
        check(!ItemLockState.reconcile(live, current, "db:1", true) && live.length == 1,
            "later reconciliation cannot resurrect a deleted lock");
        var afterSave = Json.parse(Json.stringify({lockedItems: live}));
        check(afterSave.lockedItems.length == 1 && afterSave.lockedItems[0].characterId == "db:10",
            "later save cannot resurrect deleted runtime locks");
        check(ItemLockState.setLocked(live, current, tracked, true) && live.length == 2,
            "user can explicitly lock an item again after reset");
        check(live[0] == other, "locking again preserves the other character");

        // Exercise the actual descriptors so missing warnings or wrong sections fail CI.
        var configs:Array<Dynamic> = Json.parse(sys.io.File.getContent("configFormats.json")).configs;
        var section = "";
        var found:Map<String, Bool> = new Map();
        for (index in 0...configs.length) {
            var definition = configs[index];
            if (definition.type == "title") section = definition.label;
            if (definition.type != "button") continue;
            var matched = false;
            for (c in cases) if (definition.key == Std.string(c.kind)) {
                check(!found.exists(definition.key), "one button per reset action");
                found.set(definition.key, true);
                matched = true;
                check(section == c.section, "reset belongs to the correct category");
                check(index == configs.length - 1 || configs[index + 1].type == "title", "reset is the last control in its section");
                check(definition.colour == "red" && definition.buttonText == "Reset", "reset button style is consistent");
                check(definition.warning.enabled == true && definition.warning.warningText.indexOf("current character") >= 0,
                    "reset requires a warning describing its character scope");
            }
            check(matched, "descriptor action has a registered reset category");
        }
        check([for (key in found.keys()) key].length == 5, "all five category reset buttons exist");
        trace("Character resets: " + checks + " checks passed");
    }
}
