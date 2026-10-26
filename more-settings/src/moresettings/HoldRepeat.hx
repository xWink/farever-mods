package moresettings;

/** Repeat native binding presses while held, without bypassing skill legality. */
class HoldRepeat {
    static inline var HOLD_DELAY:Float = 1.0;
    static inline var REPEAT_INTERVAL:Float = 0.1;
    var next:Float = -1;
    var lastSample:Float = -1;
    public function new() {}
    public function reset():Void {next = -1;lastSample = -1;}
    public function sample(enabled:Bool, held:Bool, allowed:Bool, now:Float, original:Bool):Bool {
        if (!enabled || !held || !allowed || !Math.isFinite(now)) {
            reset(); return original;
        }
        var start = original || next < 0 || now < lastSample;
        lastSample = now;
        if (start) {
            next = now + HOLD_DELAY;
            return original;
        }
        if (now < next) return original;
        next = now + REPEAT_INTERVAL;
        return true;
    }
    /** Only the native weapon, class and signature skill bindings repeat.
        Unknown actions stay native, including new movement or UI bindings. */
    public static function repeatableSkillAction(action:String):Bool {
        if (action == null) return false;
        return switch action.toLowerCase() {
            // Weapon primary/secondary attacks and the four weapon skill slots.
            case "attack", "secondary", "weaponskill1", "weaponskill2",
                "weaponskill3", "weaponskill4": true;
            // Class slots and the dedicated signature skill.
            case "skill1", "skill2", "skill3", "skill4", "signatureskill": true;
            default: false;
        };
    }
    public static function blockFullscreen(enabled:Bool, action:String, ctrl:Bool, f:Bool):Bool
        return enabled && action == "Fullscreen" && ctrl && f;
}
