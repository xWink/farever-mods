package modupdatealerts;

import modupdatealerts.UpdateModel.AvailableUpdate;
import modupdatealerts.UpdateWorker.CheckResult;

/** Game-thread state, independent of whichever UI currently owns the popup. */
class AlertSession {
    public var updates(default,null):Array<AvailableUpdate>=[];
    public var dismissed(default,null):Map<String,String>=[];
    public var selected(default,null)=false;
    var originalDismissed:Map<String,String>=[];
    var initialized=false;
    var closed=false;

    public function new() {}

    public function accept(result:CheckResult):Void {
        if(!initialized) {
            initialized=true;
            dismissed=result.dismissed.copy();
            originalDismissed=dismissed.copy();
        }
        // A checked box only suppresses versions the player has already seen.
        // A later worker result must not inherit that choice for new updates.
        if(selected && UpdateModel.needsReminder(result.updates,dismissed)) {
            originalDismissed=dismissed.copy();
            selected=false;
        }
        updates=result.updates;
    }

    public function shouldShow():Bool
        return !closed && UpdateModel.needsReminder(updates,dismissed);

    public function select(value:Bool):Map<String,String> {
        selected=value;
        dismissed=originalDismissed.copy();
        if(value) UpdateModel.dismiss(updates,dismissed);
        return dismissed.copy();
    }

    public function close():Void closed=true;
}
