package marketplace;
/** Completion-based scheduling; a rejected heartbeat never implies online status. */
class MarketPresence {
    public var next = 0.0;
    public var stopped = false;
    var failures = 0;
    public function new() {}
    public function reset():Void { next=0; stopped=false; failures=0; }
    public function due(now:Float):Bool return !stopped && now>=next;
    public function completed(status:Int, now:Float, retry:Float, jitter:Float):Void {
        if (status==401 || status==403) { stopped=true; return; }
        if (status==200) { failures=0; next=now+Math.max(60,retry)+jitter; }
        else if (status==429) next=now+Math.max(60,retry)+jitter;
        else { failures++; next=now+Math.max(retry,Math.min(900,60*Math.pow(2,Math.min(failures-1,4))))+jitter; }
    }
}
