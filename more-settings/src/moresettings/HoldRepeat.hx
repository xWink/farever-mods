package moresettings;

/** Repeat native binding presses while held, without bypassing skill legality. */
class HoldRepeat {
    var next:Float = -1;
    public function new() {}
    public function reset():Void next = -1;
    public function sample(enabled:Bool, held:Bool, allowed:Bool, now:Float, original:Bool):Bool {
        if (!enabled || !held || !allowed || !Math.isFinite(now)) {
            reset(); return original;
        }
        if (original || next < 0 || now < next - 0.1) {
            next = now + 0.1;
            return original;
        }
        if (now < next) return original;
        next = now + 0.1;
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
