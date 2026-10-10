package bettermodsettings;

import modinput.Hotkey;

/** Receives assignment input before hxd.Key can publish it to any key poller. */
class KeyCaptureInput {
    var state = new KeyCaptureState();
    var held:Map<Int, Bool> = new Map();
    var heldCount:Int = 0;
    var pendingKey:Dynamic = 0;
    var heldBinding:Dynamic = 0;
    var bindingReleaseKey:Int = -1;
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
        clearSelection();
        this.allowModifiers = allowModifiers;
        activityFrame = null;
        state.begin();
    }

    public function finish():Void {
        clearSelection();
        state.finish();
    }

    public function reset():Void {
        clearHeld();
        clearSelection();
        activityFrame = null;
        state.reset();
    }

    function clearHeld():Void {
        held.clear();
        heldCount = 0;
    }

    function clearSelection():Void {
        pendingKey = 0;
        heldBinding = 0;
        bindingReleaseKey = -1;
        modifierCandidate = 0;
    }

    // Heaps emits generic modifiers plus a second event with LOC_LEFT/LOC_RIGHT.
    static function modifierCode(key:Int):Int return switch key {
        case 272, 528: 16;
        case 273, 529: 17;
        case 274, 530: 18;
        default: key;
    };

    function isHeld(key:Int):Bool {
        return held.exists(key) || (Hotkey.isModifier(key)
            && (held.exists(key | 256) || held.exists(key | 512)));
    }

    function press(key:Int, frame:Int, pulse:Bool = false):Void {
        activityFrame = frame;
        var code = allowModifiers ? modifierCode(key) : key;
        if (!held.exists(key) && capturing && !Hotkey.isBound(pendingKey) && code >= 0 && code < 512
            && (!Hotkey.isBound(heldBinding) || code == 27)) {
            if (allowModifiers && Hotkey.isModifier(code)) {
                // Wait for the main key. A modifier tapped alone is still assignable.
                modifierCandidate = code;
            } else {
                var binding:Dynamic = allowModifiers ? Hotkey.capture(code, isHeld) : code;
                if (Hotkey.isBound(binding)) {
                    modifierCandidate = 0;
                    if (!allowModifiers || pulse || code == 27) {
                        // Wheel pulses have no release; Escape cancels immediately.
                        heldBinding = 0;
                        bindingReleaseKey = -1;
                        pendingKey = binding;
                    } else {
                        // Remember the modifier now, even if it is released first.
                        heldBinding = binding;
                        bindingReleaseKey = key;
                    }
                }
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
                if (held.remove(key)) heldCount--;
                if (capturing && !Hotkey.isBound(pendingKey)) {
                    if (key == bindingReleaseKey && Hotkey.isBound(heldBinding)) {
                        pendingKey = heldBinding;
                        heldBinding = 0;
                        bindingReleaseKey = -1;
                    } else if (!Hotkey.isBound(heldBinding) && modifierCandidate != 0
                        && modifierCode(key) == modifierCandidate && !isHeld(modifierCandidate)) {
                        pendingKey = modifierCandidate;
                        modifierCandidate = 0;
                    }
                }
                activityFrame = frame;
            case "EWheel":
                press(key, frame, true);
            case "EFocusLost", "EReleaseOutside":
                clearHeld();
                clearSelection();
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
