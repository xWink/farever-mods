import modinput.Hotkey;
import haxe.Json;

class HotkeyTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function down(keys:Array<Int>):Int->Bool return key -> keys.indexOf(key) >= 0;

    static function main():Void {
        for (key in [0, 1, 5, 6, 16, 17, 18, 49, 113, 511])
            eq(Hotkey.normalize(key), key, "legacy integer bindings survive");
        var invalid:Array<Dynamic> = [null, -1, 27, 512, "49", 49.5, [], {},
            {code:49,modifier:3}, {code:49,modifier:-1}, {code:49,modifier:"0"},
            {code:27,modifier:0}, {code:32,modifier:0}, {code:49.5,modifier:0}];
        for (value in invalid) {
            eq(Hotkey.normalize(value), 0, "malformed binding is unassigned");
            eq(Hotkey.normalize(value, 113), 113, "caller-specific fallback is retained");
        }
        eq(Hotkey.normalize({code:49,modifier:null}), 49, "native unmodified record accepts legacy form");
        for (key in [48,57,96,105,65,90,112,135,13,9,37,40,0,1])
            eq(Hotkey.supportsModifier(key), true, "Farever modifier allowlist");
        for (key in [2,3,4,5,6,16,17,18,27,32,47,58,91,106,111,136,511])
            eq(Hotkey.supportsModifier(key), false, "keys outside Farever allowlist");
        for (modifier in 0...3) {
            var key = Hotkey.modifierKey(modifier);
            var binding = Hotkey.normalize(Json.parse(Json.stringify({code:49,modifier:modifier})));
            eq(Hotkey.code(binding), 49, "base key survives JSON round trip");
            eq(Hotkey.modifier(binding), modifier, "modifier survives JSON round trip");
            eq(Hotkey.matches(binding, down([key])), true, "matching modified action fires");
            eq(Hotkey.matches(binding, down([])), false, "plain key does not fire modified action");
            eq(Hotkey.matches(49, down([key])), false, "modified key does not fire plain action");
            var wrong = Hotkey.modifierKey((modifier + 1) % 3);
            eq(Hotkey.matches(binding, down([wrong])), false, "wrong modifier does not activate");
            var captured = Hotkey.capture(49, down([key]));
            eq(Hotkey.modifier(captured), modifier, "capture stores native modifier value");
        }
        eq(Hotkey.matches(49, down([])), true, "plain action still fires normally");
        eq(Hotkey.matches(0, down([])), false, "unbound is never activated by left click");
        eq(Hotkey.currentModifier(down([16,17,18])), 0, "native Ctrl priority with multiple modifiers");
        eq(Hotkey.currentModifier(down([16,18])), 1, "native Shift priority over Alt");
        eq(Hotkey.matches({code:49,modifier:1}, down([16,17])), false, "strict native priority respected");
        eq(Hotkey.matches({code:49,modifier:1}, down([16,17]), false), true, "native non-strict actions only require assigned modifier");
        eq(Hotkey.matches(49, down([17]), false), true, "native non-strict plain actions retain their rules");
        eq(Hotkey.capture(32, down([17])), 32, "unsupported key does not acquire a modifier");
        eq(Hotkey.matches(32, down([17])), true, "unsupported keys retain native unmodified behavior");
        var click = Hotkey.normalize(Hotkey.capture(0, down([17])));
        eq(Hotkey.isBound(click), true, "modified left click can be bound");
        eq(Hotkey.code(click), 0, "modified left click retains its native code");
        eq(Hotkey.matches(click, down([17])), true, "modified left click activates");
        eq(Hotkey.label(click, code -> code == 0 ? "Mouse Left" : "?"), "Ctrl+Mouse Left", "modified mouse label");
        for (modifier in 0...3)
            eq(Hotkey.label({code:113,modifier:modifier}, _ -> "F2"), ["Ctrl+F2","Shift+F2","Alt+F2"][modifier], "readable binding label");
        eq(Hotkey.label(113, _ -> "F2"), "F2", "legacy label");
        eq(Hotkey.label(0, _ -> "Mouse Left"), "Not set", "unbound label");
        Sys.println('Hotkeys: $checks checks passed.');
    }
}
