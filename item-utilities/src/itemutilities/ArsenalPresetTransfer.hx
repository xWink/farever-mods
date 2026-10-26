package itemutilities;

import itemutilities.ArsenalPresetPlan.ArsenalChoice;

/** The native setter has no callback; wait for replicated selections after each RPC. */
class ArsenalPresetTransfer {
    public var active(default, null):Bool = false;
    public var error(default, null):String = "";
    var context:Dynamic;
    var choices:Array<ArsenalChoice> = [];
    var position:Int = 0;
    var before:Array<String>;
    var deadline:Float = 0;

    public function new() {}
    public function start(context:Dynamic, choices:Array<ArsenalChoice>):Void {
        cancel();
        this.context = context;
        this.choices = ArsenalPresetPlan.saved(choices);
        active = context != null && choices.length > 0;
    }
    public function weapon():String return active ? choices[position].weapon : null;

    public function next(context:Dynamic, now:Float, current:Array<String>):ArsenalChoice {
        if (!active) return null;
        if (context != this.context) {
            cancel("Equipment preset stopped because the character changed.");
            return null;
        }
        var choice = choices[position];
        if (ArsenalPresetPlan.same(current, choice.skills)) {
            before = null;
            if (++position == choices.length) cancel();
            return null;
        }
        if (before != null) {
            if (!ArsenalPresetPlan.same(current, before))
                cancel("Equipment preset stopped because the arsenal selection changed during application.");
            else if (now >= deadline)
                cancel("Equipment preset stopped while waiting for the server's arsenal selection.");
            return null;
        }
        before = current.copy();
        deadline = now + 5;
        return choice;
    }

    public function cancel(message:String = ""):Void {
        active = false;
        error = message;
        context = null;
        choices = [];
        position = 0;
        before = null;
    }
}
