import haxe.Json;
import itemutilities.PresetSlots;

class PresetSlotsTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function same(actual:Dynamic, expected:Dynamic, message:String):Void
        check(Json.stringify(actual) == Json.stringify(expected), message);

    static function main():Void {
        var config:Dynamic = {weaponPresets: [{characterId: "db:1", preset: 2, weapons: []}],
            selectedWeaponPresets: [{characterId: "db:1", preset: 2}]};
        var prefixes = ["preset", "talentPreset", "skillPreset", "appearancePreset"];
        var descriptors:Array<Dynamic> = Json.parse(sys.io.File.getContent("configFormats.json")).configs;
        for (index in 0...prefixes.length) {
            var prefix = prefixes[index];
            var legacy = [49 + index * 10, 50 + index * 10, 51 + index * 10];
            for (slot in 0...3) Reflect.setField(config, prefix + (slot + 1) + "Hotkey", legacy[slot]);
            same(PresetSlots.hotkeys(config, prefix), [legacy[0], legacy[1], legacy[2], 0, 0],
                "legacy bindings survive and new slots are unbound");
            var keys = legacy.concat([52 + index * 10, 53 + index * 10]);
            PresetSlots.saveHotkeys(config, prefix, keys);
            config = Json.parse(Json.stringify(config));
            same(PresetSlots.hotkeys(config, prefix), keys, "all five bindings survive save/reload");
            for (other in 0...index)
                same(PresetSlots.hotkeys(config, prefixes[other]), [for (n in 49...54) n + other * 10],
                    "saving one category preserves other categories");
            for (slot in 0...5) {
                var key = prefix + (slot + 1) + "Hotkey";
                var matching = descriptors.filter(d -> d.key == key && d.type == "keybinding");
                check(matching.length == 1, "each slot has exactly one BMS hotkey setting");
            }
        }
        same(config.weaponPresets, [{characterId: "db:1", preset: 2, weapons: []}], "legacy presets are untouched");
        same(config.selectedWeaponPresets, [{characterId: "db:1", preset: 2}], "legacy selection is untouched");
        same([for (i in 0...PresetSlots.COUNT) PresetSlots.label(i)],
            ["Preset 1", "Preset 2", "Preset 3", "Preset 4", "Preset 5"], "dropdown labels are exact");
        for (slot in 0...5) check(PresetSlots.valid(slot), "all five saved slot indexes are accepted");
        check(!PresetSlots.valid(-1) && !PresetSlots.valid(5), "out-of-range saved slots are rejected");
        same(PresetSlots.hotkeys({preset1Hotkey: "bad", preset2Hotkey: -1}, "preset"), [0, 0, 0, 0, 0],
            "invalid or missing hotkeys stay unbound");
        trace('Preset slots: $checks checks passed');
    }
}
