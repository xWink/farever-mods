package dpsmeter;

/** One report mode for the meter, history, and rift recap, including closed windows. */
class ReportMode {
    public var healing(default, null) = false;
    final listeners:Array<Bool->Void> = [];
    public function new() {}
    public function subscribe(listener:Bool->Void):Void {
        listeners.push(listener);
        listener(healing);
    }
    public function toggle():Void setHealing(!healing);
    public function setHealing(value:Bool):Void {
        if (healing == value) return;
        healing = value;
        for (listener in listeners) listener(value);
    }
}
