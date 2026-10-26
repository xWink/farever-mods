package moresettings;

/** Repeat native binding presses while held, without bypassing skill legality. */
class HoldRepeat {
    public static inline var DEFAULT_DELAY:Float = 0.7;
    static inline var REPEAT_INTERVAL:Float = 0.1;
    var delay:Float;
    var next:Float = -1;
    var lastSample:Float = -1;
    public function new(delay:Float = DEFAULT_DELAY) {this.delay = delay;}
    public static function normalizeDelay(value:Dynamic):Float {
        if (value == null) return DEFAULT_DELAY;
        var parsed = Std.parseFloat(Std.string(value));
        return !Math.isFinite(parsed) ? DEFAULT_DELAY : Math.round(Math.max(0, Math.min(2, parsed)) * 10) / 10;
    }
    public function reset():Void {next = -1;lastSample = -1;}
    public function sample(enabled:Bool, held:Bool, allowed:Bool, now:Float, original:Bool):Bool {
        if (!enabled || !held || !allowed || !Math.isFinite(now)) {
            reset(); return original;
        }
        var start = original || next < 0 || now < lastSample;
        // Zero delay still permits only one synthetic press per input sample.
        if (!start && now == lastSample) return original;
        lastSample = now;
        if (start) {
            next = now + delay;
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
