import dpsmeter.MeterConfig;
import modinput.Hotkey;
import haxe.Json;

class HotkeyConfigTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function main():Void {
        var config = MeterConfig.defaults();
        var names = ["toggleHotkey", "unlockHotkey", "historyHotkey", "modeHotkey"];
        var defaults = [121,122,0,119];
        var formats:Array<Dynamic> = Json.parse(sys.io.File.getContent("configFormats.json")).configs;
        for (i in 0...names.length) {
            var name = names[i];
            eq(Reflect.field(config, name), defaults[i], "existing defaults preserved");
            eq(formats.filter(d -> d.key == name && d.modifiers == true).length, 1, "each meter hotkey allows modifiers");
            Reflect.setField(config, name, {code:113,modifier:i % 3});
        }
        config = Json.parse(Json.stringify(config));
        MeterConfig.normalize(config);
        for (i in 0...names.length) {
            var binding = Reflect.field(config, names[i]);
            eq(Hotkey.code(binding), 113, "saved meter base key survives reload");
            eq(Hotkey.modifier(binding), i % 3, "saved meter modifier survives reload");
        }
        for (name in names) Reflect.setField(config, name, 0);
        MeterConfig.normalize(config);
        for (name in names) eq(Reflect.field(config, name), 0, "unassigned keys do not revert to defaults");
        for (name in names) Reflect.setField(config, name, {code:113,modifier:99});
        MeterConfig.normalize(config);
        for (i in 0...names.length) eq(Reflect.field(config, names[i]), defaults[i], "invalid bindings use original fallback");
        Sys.println('Meter hotkey configuration: $checks checks passed.');
    }
}
