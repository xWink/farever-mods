package modupdatealerts;

/** Loading screens must not exhaust a permanent popup-attempt limit. */
class PopupRetry {
    var owner:Dynamic;
    var failures=0;
    var retryAt:Float=0;
    var lastError="";
    public function new() {}
    public function ready(ui:Dynamic, now:Float):Bool {
        if(owner!=ui) {
            owner=ui;
            succeeded(); // A new menu/game UI gets a fresh attempt immediately.
        }
        return now>=retryAt;
    }
    public function failed(now:Float, error:String):Bool {
        failures++;
        retryAt=now+Math.min(2,0.25*Math.pow(2,Math.min(failures-1,3)));
        // UI resources usually settle within a few frames. Report an actual
        // failure immediately, without repeating it on every short retry.
        var report=error!=lastError;
        if(report) lastError=error;
        return report;
    }
    public function succeeded():Void {
        failures=0;retryAt=0;lastError="";
    }
}
