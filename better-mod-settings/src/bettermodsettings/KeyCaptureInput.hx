package bettermodsettings;

import modinput.Hotkey;

/** Receives assignment input before hxd.Key can publish it to any key poller. */
class KeyCaptureInput {
    var state = new KeyCaptureState();
    var held:Map<Int, Bool> = new Map();
    var heldCount:Int = 0;
    var pendingKey:Dynamic = 0;
    var allowModifiers:Bool = false;
    var modifierCandidate:Int = 0;
    var activityFrame:Null<Int> = null;

    public var blocking(get, never):Bool;
    inline function get_blocking():Bool return state.blocking;
    public var capturing(get, never):Bool;
    inline function get_capturing():Bool return state.capturing;

    public function new() {}

    public function begin(alreadyHeld:Array<Int>, allowModifiers:Bool = false):Void {
        // A second picker can open while the previous input is still draining.
        if (!blocking) clearHeld();
        for (key in alreadyHeld) {
            // Heaps stores wheel pulses as positive values, but they have no key-up.
            if (key != 5 && key != 6 && !held.exists(key)) {
                held.set(key, true);
                heldCount++;
            }
        }
        pendingKey = 0;
        modifierCandidate = 0;
        this.allowModifiers = allowModifiers;
        activityFrame = null;
        state.begin();
    }

    public function finish():Void {
        pendingKey = 0;
        modifierCandidate = 0;
        state.finish();
    }

    public function reset():Void {
        clearHeld();
        pendingKey = 0;
        modifierCandidate = 0;
        activityFrame = null;
        state.reset();
    }

    function clearHeld():Void {
        held.clear();
        heldCount = 0;
    }

    function press(key:Int, frame:Int, pulse:Bool = false):Void {
        activityFrame = frame;
        if (!held.exists(key) && capturing && !Hotkey.isBound(pendingKey) && key >= 0 && key < 512) {
            if (allowModifiers && Hotkey.isModifier(key)) {
                // Wait for the main key. A modifier tapped alone is still assignable.
                modifierCandidate = key;
            } else {
                pendingKey = allowModifiers ? Hotkey.capture(key, held.exists) : key;
                if (Hotkey.isBound(pendingKey)) modifierCandidate = 0;
            }
        }
        if (!pulse && !held.exists(key)) {
            held.set(key, true);
            heldCount++;
        }
    }

    /** True means skip the native hxd.Key.onEvent writer entirely. */
    public function consume(kind:String, key:Int, frame:Int):Bool {
        if (!blocking) return false;
        switch (kind) {
            case "EKeyDown", "EPush":
                press(key, frame);
            case "EKeyUp", "ERelease":
                if (capturing && !Hotkey.isBound(pendingKey) && key == modifierCandidate) {
                    pendingKey = key;
                    modifierCandidate = 0;
                }
                if (held.remove(key)) heldCount--;
                activityFrame = frame;
            case "EWheel":
                press(key, frame, true);
            case "EFocusLost", "EReleaseOutside":
                clearHeld();
                pendingKey = 0;
                modifierCandidate = 0;
                activityFrame = frame;
            default:
                return false;
        }
        return true;
    }

    public function takePressedKey():Dynamic {
        var key = pendingKey;
        pendingKey = 0;
        return key;
    }

    public function update(frame:Int):Void {
        state.update(frame, heldCount > 0 || activityFrame == frame);
        if (!blocking) reset();
    }
}
