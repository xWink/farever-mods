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
    /** Native skill-input polling covers dodges, item shortcuts and mounts,
        not just class/weapon abilities. Keep those commands edge-triggered. */
    public static function repeatableSkillAction(action:String):Bool {
        if (action == null || action == "") return false;
        var key=action.toLowerCase();
        for (part in ["item", "consum", "potion", "flask", "dodge", "dash",
            "mount", "riding", "ride", "evade", "glider"]) {
            if (key.indexOf(part) >= 0) return false;
        }
        // Explicitly exclude non-skill movement and UI commands that can
        // reach the generic unit input reader on some client builds.
        return ["jump", "roll", "interact", "block", "inventory", "menu",
            "targetlock", "sprint", "autoattack", "use", "emote"].indexOf(key) < 0;
    }
    public static function blockFullscreen(enabled:Bool, action:String, ctrl:Bool, f:Bool):Bool
        return enabled && action == "Fullscreen" && ctrl && f;
}
