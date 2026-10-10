package dpsmeter;

/** Match health replication to the following heal notification, without polling units.
    NetworkHost.beforeRPC flushes properties before sending the RPC. The client
    does not receive an explicit overheal field. Never use post-heal missing HP
    as the effective amount, or reuse a health change for two healers. */
class HealingObservation {
    var changes:Map<String, {delta:Float, ambiguous:Bool, batch:Int}> = [];
    var batch:Int = 0;
    public function new() {}
    public function clear():Void changes = [];
    public function nextBatch():Void {
        // A property update and its RPC may be split across network deliveries.
        // Keep a tombstone: forgetting the gain would falsely call the later
        // heal a full overheal when the target is now at maximum health.
        batch++; // No per-packet scan of units or stored observations.
    }
    public function invalidate(uid:String):Void changes.remove(uid);
    public function health(uid:String, before:Float, after:Float):Void {
        if (uid == "" || !Math.isFinite(before) || !Math.isFinite(after)) return;
        var delta = after - before;
        if (delta == 0) return;
        var prior = changes[uid];
        // Several unrelated changes in one replication interval cannot be
        // assigned confidently to one skill/player.
        changes[uid] = {delta: delta, ambiguous: prior != null || delta < 0, batch: batch};
    }
    public function consume(uid:String, output:Float, health:Float, maximum:Float):Null<Float> {
        var change = changes[uid]; changes.remove(uid);
        if (change != null) {
            if (change.ambiguous || change.batch != batch || change.delta > output + .01) return null;
            return Math.max(0, Math.min(output, change.delta));
        }
        // Full overheals do not dirty the health property, so there is no delta.
        if (Math.isFinite(health) && Math.isFinite(maximum) && maximum > 0 && health >= maximum) return 0;
        return null;
    }
}
