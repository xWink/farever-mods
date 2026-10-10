import bettermodsettings.KeyCaptureInput;
import modinput.Hotkey;

class KeyCaptureInputTest {
    static var checks = 0;
    static var input:KeyCaptureInput;
    static var published:Map<Int, Int>;
    static var nativeWrites = 0;

    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function fresh():Void {
        input = new KeyCaptureInput();
        published = new Map();
        nativeWrites = 0;
    }

    static function begin(modifiers:Bool = false):Void {
        var held = [for (key => value in published) if (value > 0) key];
        published = new Map(); // BMS replaces keyPressed with a native empty slice.
        input.begin(held, modifiers);
    }

    // Models the native key-state writer. No isPressed/isDown/isReleased hooks
    // or cooperative checks in consumers: consumption must happen before writing.
    static function event(kind:String, key:Int, frame:Int):Void {
        if (input.consume(kind, key, frame)) return;
        switch (kind) {
            case "EKeyDown", "EPush", "EWheel":
                published.set(key, frame); nativeWrites++;
            case "EKeyUp", "ERelease":
                published.set(key, -frame); nativeWrites++;
            case "EReleaseOutside": published.clear(); nativeWrites++;
            default:
        }
    }

    static function rawPressed(key:Int, frame:Int):Bool return published.get(key) == frame - 1;
    static function rawReleased(key:Int, frame:Int):Bool return published.get(key) == -(frame - 1);
    static function rawDown(key:Int):Bool {
        var value = published.get(key);
        return value != null && value > 0;
    }

    static function main():Void {
        fresh();
        event("EKeyDown", 49, 10);
        eq(rawPressed(49, 11), true, "ordinary preset key reaches native polling");
        event("EKeyUp", 49, 11);
        eq(rawReleased(49, 12), true, "ordinary release reaches native polling");

        begin();
        nativeWrites = 0;
        event("EKeyDown", 50, 20);
        eq(rawPressed(50, 21), false, "draw before config save cannot see assigned key");
        eq(rawDown(50), false, "direct held-key polling cannot see assigned key");
        var assignedKey = input.takePressedKey();
        eq(assignedKey, 50, "only picker receives the assigned key");
        input.finish();
        eq(rawPressed(assignedKey, 21), false, "draw after live binding reload cannot activate new preset");
        eq(input.takePressedKey(), 0, "assignment is consumed once");
        for (frame in 21...81) {
            event("EKeyDown", 50, frame); // OS key repeat
            input.update(frame);
            eq(rawPressed(50, frame + 1), false, "repeat never reaches another mod");
            eq(input.blocking, true, "holding assignment retains protection");
        }
        event("EKeyUp", 50, 81);
        input.update(81);
        eq(rawReleased(50, 82), false, "release is never published either");
        input.update(82); input.update(82);
        eq(input.blocking, true, "duplicate updates cannot end quiet-frame protection");
        eq(nativeWrites, 0, "no assignment/hold/release event reached native key state");
        input.update(83);
        eq(input.blocking, false, "protection ends after release and quiet frame");
        eq(rawDown(50), false, "ending capture does not replay held input");
        event("EKeyDown", 50, 84);
        eq(rawPressed(50, 85), true, "next deliberate press activates normally");

        fresh();
        event("EKeyDown", 49, 1); event("EPush", 0, 1);
        begin();
        eq(rawDown(49), false, "opening picker consumes an existing held preset key");
        eq(rawDown(0), false, "opening click is not exposed as a held mouse hotkey");
        event("EKeyDown", 49, 2);
        eq(input.takePressedKey(), 0, "repeat of pre-held key cannot assign itself");
        event("EKeyDown", 27, 3);
        eq(input.takePressedKey(), 27, "Escape reaches picker cancellation");
        input.finish();
        event("EKeyUp", 27, 4); event("ERelease", 0, 4);
        input.update(5); input.update(6);
        eq(input.blocking, true, "pre-held key must still be released after cancellation");
        event("EKeyUp", 49, 7);
        input.update(8); input.update(9);
        eq(input.blocking, false, "cancellation cannot leave a stuck native key");

        fresh(); begin();
        event("EKeyDown", 49, 1); input.takePressedKey(); input.finish();
        begin();
        event("EKeyDown", 49, 2);
        eq(input.takePressedKey(), 0, "second picker preserves previously held key tracking");
        event("EKeyUp", 49, 3); event("EKeyDown", 49, 4);
        eq(input.takePressedKey(), 49, "same key can be assigned after a fresh press");
        input.finish();
        event("EReleaseOutside", -1, 5);
        input.update(6); input.update(7);
        eq(input.blocking, false, "native release-outside reset cannot strand capture");

        fresh(); begin();
        event("EKeyDown", 50, 1); event("EFocusLost", -1, 1);
        eq(input.takePressedKey(), 0, "focus loss discards an unfinished key selection");
        input.finish(); input.update(2); input.update(3);
        eq(input.blocking, false, "focus loss clears private held-key tracking");

        fresh(); event("EWheel", 6, 1); begin();
        event("EWheel", 5, 2);
        eq(input.takePressedKey(), 5, "wheel pulse remains assignable");
        input.finish(); input.update(2); input.update(3); input.update(4);
        eq(input.blocking, false, "wheel input never waits for a nonexistent release");
        fresh(); begin();
        event("EPush", 0, 1);
        eq(input.takePressedKey(), 0, "left click remains reserved for Not set");
        event("EPush", 1, 2);
        eq(input.takePressedKey(), 1, "assignable mouse buttons still work");
        eq(input.consume("EMove", 0, 3), false, "mouse movement is not consumed");
        eq(input.consume("ETextInput", 0, 3), false, "text event routing is unchanged");
        input.reset();
        eq(input.blocking, false, "dispose clears capture state for the next character");
        event("EKeyDown", 51, 4);
        eq(rawPressed(51, 5), true, "next session receives fresh input normally");

        fresh(); begin();
        event("EKeyDown", 49, 1); event("EKeyUp", 49, 1);
        eq(input.takePressedKey(), 49, "fast tap before update is still assignable");
        input.finish(); input.update(1);
        eq(input.blocking, true, "fast tap still consumes its entire event frame");
        input.update(2); input.update(3);
        eq(input.blocking, false, "fast tap drains without a held key");
        eq(nativeWrites, 0, "fast tap never leaks to direct polling");
        fresh(); begin();
        event("EPush", 1, 1);
        // The assignment button's onPushRight cancels capture before polling,
        // then consumes the gesture until its onRightClick clears the binding.
        input.finish(); begin(); input.finish();
        eq(input.takePressedKey(), 0, "right-click unbind cannot accidentally assign Mouse Right");
        eq(rawPressed(1, 2), false, "unbind during capture is hidden from other hotkeys");
        event("ERelease", 1, 2);
        eq(rawReleased(1, 3), false, "unbind release stays private");
        input.update(3); input.update(4);
        eq(input.blocking, false, "unbind gesture drains without sticking input");

        fresh(); event("EPush", 1, 1);
        begin(); input.finish(); // right-click unbind with no picker open
        eq(rawDown(1), false, "unbind clears already-published right button state");
        event("ERelease", 1, 2);
        input.update(3); input.update(4);
        eq(input.blocking, false, "direct unbind releases input protection");
        modifiers();
        nativeModifiers();
        Sys.println('Better Mod Settings: $checks central input checks passed.');
    }

    static function modifiers():Void {
        for (modifier in 0...3) {
            fresh(); begin(true);
            var key = Hotkey.modifierKey(modifier);
            event("EKeyDown", key, 1);
            eq(input.takePressedKey(), 0, "modifier waits for a main key across frames");
            event("EKeyDown", 49, 2);
            eq(input.takePressedKey(), 0, "main key waits for release before assigning");
            event("EKeyUp", 49, 3);
            var binding = input.takePressedKey();
            eq(Hotkey.code(binding), 49, "combo keeps main key");
            eq(Hotkey.modifier(binding), modifier, "combo keeps native modifier");
            input.finish();
            eq(rawDown(key), false, "modifier never leaks while assigning");
            eq(rawPressed(49, 3), false, "main key never leaks while assigning");
            input.update(4); input.update(5);
            eq(input.blocking, true, "modifier must also be released before capture drains");
            event("EKeyUp", key, 6); input.update(7); input.update(8);
            eq(input.blocking, false, "entire combination drained");
            eq(nativeWrites, 0, "no combination press or release reaches native polling");
            event("EKeyDown", key, 9); event("EKeyDown", 49, 10);
            eq(rawPressed(49, 11) && Hotkey.matches(binding, rawDown), true, "next deliberate combo activates");

            fresh(); begin(true);
            event("EKeyDown", key, 1); event("EKeyUp", key, 1);
            eq(input.takePressedKey(), key, "modifier tapped alone remains assignable");
        }
        fresh(); event("EKeyDown", 17, 1); event("EPush", 0, 1); begin(true);
        event("ERelease", 0, 2); event("EKeyDown", 113, 2);
        event("EKeyUp", 113, 3);
        eq(Hotkey.modifier(input.takePressedKey()), 0, "modifier held before opening picker is recognized");

        fresh(); begin(true);
        event("EKeyDown", 16, 1); event("EKeyDown", 17, 1); event("EKeyDown", 49, 1);
        event("EKeyUp", 49, 1);
        eq(Hotkey.modifier(input.takePressedKey()), 0, "multiple held modifiers use Farever priority");
        input.finish(); event("EKeyUp", 17, 2); event("EKeyUp", 16, 2);
        eq(input.takePressedKey(), 0, "modifier releases cannot replace completed combination");

        fresh(); begin(true);
        event("EKeyDown", 17, 1); event("EKeyDown", 27, 2);
        eq(input.takePressedKey(), 27, "modified Escape still cancels");
        input.finish(); event("EKeyUp", 27, 3); event("EKeyUp", 17, 3);
        input.update(4); input.update(5);
        eq(input.blocking, false, "modified cancellation fully drains");

        fresh(); begin(true);
        event("EKeyDown", 18, 1); event("EFocusLost", -1, 2); event("EKeyUp", 18, 3);
        eq(input.takePressedKey(), 0, "focus loss discards pending modifier tap");
        event("EKeyDown", 49, 4); event("EKeyUp", 49, 5);
        eq(input.takePressedKey(), 49, "focus loss cannot leave a sticky modifier");

        fresh(); begin(true);
        event("EKeyDown", 17, 1); event("EPush", 0, 2);
        eq(input.takePressedKey(), 0, "modified mouse waits for button release");
        event("ERelease", 0, 3);
        var click = input.takePressedKey();
        eq(Hotkey.code(click), 0, "modified left click uses native mouse code");
        eq(Hotkey.modifier(click), 0, "modified left click is distinct from unbound");
        input.finish(); event("EKeyUp", 17, 3);
        input.update(4); input.update(5);
        eq(input.blocking, false, "modified mouse capture drains");

        fresh(); begin(true);
        event("EKeyDown", 17, 1); event("EWheel", 5, 2);
        eq(input.takePressedKey(), 5, "wheel does not gain unsupported modifiers");
        fresh(); begin(); event("EKeyDown", 17, 1);
        eq(input.takePressedKey(), 17, "third-party single-key controls keep their original format");
    }

    // hxd.Window.onEvent emits the generic event first, then LOC_LEFT/LOC_RIGHT.
    static function modifierEvent(kind:String, key:Int, side:Int, frame:Int):Void {
        event(kind, key, frame);
        event(kind, key | side, frame);
    }

    static function nativeModifiers():Void {
        for (modifier in 0...3) for (side in [256, 512]) {
            var key = Hotkey.modifierKey(modifier);
            for (modifierFirst in [false, true]) {
                fresh(); begin(true);
                modifierEvent("EKeyDown", key, side, 1);
                input.update(2);
                eq(input.takePressedKey(), 0, "located modifier does not finish capture");
                modifierEvent("EKeyDown", key, side, 3);
                eq(input.takePressedKey(), 0, "modifier repeat does not finish capture");
                event("EKeyDown", 49, 4);
                event("EKeyDown", 49, 5);
                eq(input.takePressedKey(), 0, "held main key and repeat do not finish capture");
                if (modifierFirst) {
                    modifierEvent("EKeyUp", key, side, 6);
                    eq(input.takePressedKey(), 0, "modifier release still waits for main key");
                }
                event("EKeyUp", 49, 7);
                var binding = input.takePressedKey();
                eq(Hotkey.code(binding), 49, "native event pair preserves main key");
                eq(Hotkey.modifier(binding), modifier, "native event pair preserves modifier in either release order");
                input.finish();
                input.update(8); input.update(9);
                eq(input.blocking, !modifierFirst, "remaining modifier keeps input suppressed");
                if (!modifierFirst) modifierEvent("EKeyUp", key, side, 10);
                input.update(11); input.update(12);
                eq(input.blocking, false, "located modifier fully drains");
                eq(nativeWrites, 0, "native modifier pair never leaks to game or mod polling");
            }

            fresh(); begin(true);
            modifierEvent("EKeyDown", key, side, 1);
            eq(input.takePressedKey(), 0, "modifier-only binding waits for release");
            event("EKeyUp", key, 2);
            eq(input.takePressedKey(), 0, "generic release waits for located release");
            event("EKeyUp", key | side, 2);
            eq(input.takePressedKey(), key, "either modifier side binds the canonical key on release");
            input.finish(); input.update(3); input.update(4);
            eq(input.blocking, false, "modifier-only native pair drains");

            fresh(); modifierEvent("EKeyDown", key, side, 1); begin(true);
            modifierEvent("EKeyDown", key, side, 2);
            eq(input.takePressedKey(), 0, "pre-held modifier repeat cannot assign itself");
            event("EKeyDown", 113, 3); event("EKeyUp", 113, 4);
            eq(Hotkey.modifier(input.takePressedKey()), modifier, "pre-held native modifier works in combination");
        }

        fresh(); begin(true);
        modifierEvent("EKeyDown", 17, 256, 1);
        modifierEvent("EKeyDown", 17, 512, 2);
        modifierEvent("EKeyUp", 17, 256, 3);
        eq(input.takePressedKey(), 0, "releasing one side does not bind a modifier still held on the other side");
        event("EKeyDown", 49, 4); event("EKeyUp", 49, 5);
        eq(Hotkey.modifier(input.takePressedKey()), 0, "remaining modifier side still modifies main key");

        fresh(); begin(true);
        modifierEvent("EKeyDown", 17, 256, 1); event("EKeyDown", 49, 2);
        event("EFocusLost", -1, 3);
        event("EKeyUp", 49, 4); modifierEvent("EKeyUp", 17, 256, 4);
        eq(input.takePressedKey(), 0, "focus loss discards a combination awaiting release");
        event("EKeyDown", 50, 5); event("EKeyUp", 50, 6);
        eq(input.takePressedKey(), 50, "next plain key has no stale modifier after focus loss");

        fresh(); begin(true);
        modifierEvent("EKeyDown", 17, 256, 1); event("EKeyDown", 49, 2);
        event("EKeyDown", 27, 3);
        eq(input.takePressedKey(), 27, "Escape cancels a combination awaiting release");
        input.finish(); event("EKeyUp", 49, 4); event("EKeyUp", 27, 4);
        modifierEvent("EKeyUp", 17, 256, 4);
        input.update(5); input.update(6);
        eq(input.blocking, false, "cancelled combination drains");
        eq(input.takePressedKey(), 0, "release cannot save a cancelled combination");
    }
}
