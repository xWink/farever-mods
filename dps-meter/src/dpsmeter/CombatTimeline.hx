package dpsmeter;

/** Only primitive, detached data crosses the recording/worker boundary. */
typedef TimelineEvent = {
    seq:Int, time:Float, kind:String, source:String, target:String, skill:String,
    ?sourceName:String, ?targetName:String, ?skillName:String, ?origin:String, ?instance:String,
    ?amount:Float, ?before:Float, ?after:Float, ?critical:Bool, ?lethal:Bool, ?damageType:String,
    ?outcome:String, ?stacks:Int, ?duration:Float, ?estimated:Bool, ?hits:Int,
    ?cause:String, ?related:Int, ?statusType:String, ?hiddenStatus:Bool, ?useDuration:Float,
    ?item:String, ?itemName:String
};
typedef TimelineBatch = {
    stream:String, index:Int, first:Float, last:Float,
    initial:Array<TimelineEvent>, events:Array<TimelineEvent>
};
typedef TimelineSpan = {stream:String, start:Float, end:Float, me:String, through:Int};

/** Append-only event journal. Completed batches are handed off, never copied each frame. */
class CombatTimeline {
    public static inline var BATCH_SIZE = 256;
    public final stream:String;
    public final epoch:Float;
    public var sequence(default, null):Int = 0;
    public var onBatch:TimelineBatch->Void;
    var index:Int = 0;
    var events:Array<TimelineEvent> = [];
    var active:Map<String, TimelineEvent> = [];
    var initial:Array<TimelineEvent> = [];
    var lastFlush:Float;
    public function new(stream:String, epoch:Float, onBatch:TimelineBatch->Void) {
        this.stream = stream; this.epoch = epoch; this.onBatch = onBatch; lastFlush = epoch;
    }
    public static function event(kind:String, source:String = "", target:String = "", skill:String = ""):TimelineEvent
        return {seq:0, time:0, kind:kind, source:source, target:target, skill:skill};
    public function reserve(now:Float):{seq:Int, time:Float} return {seq:++sequence, time:now - epoch};
    public function append(e:TimelineEvent, now:Float):Void {
        if (events.length == 0) initial = [for (v in active) Reflect.copy(v)];
        if (e.seq == 0) { var order = reserve(now); e.seq = order.seq; e.time = order.time; }
        if (!Math.isFinite(e.time)) return;
        events.push(e);
        applyState(active, e);
        if (events.length >= BATCH_SIZE) flush(now);
    }
    public static function stateKey(e:TimelineEvent):String
        return e.kind.indexOf("proc_") == 0 ? "proc:" + e.source + ":" + e.skill : "status:" + e.instance;
    public static function applyState(active:Map<String, TimelineEvent>, e:TimelineEvent):Void {
        if (e.kind == "health_sample" || e.kind == "health_loss") {
            var sample:TimelineEvent = Reflect.copy(e); sample.kind = "health_sample";
            sample.amount = null; sample.before = null; sample.outcome = "Last observed HP";
            active["health:" + e.target] = sample; return;
        }
        if (e.kind == "recording_started" || e.kind == "recording_stopped") {
            active["recording:" + e.source] = Reflect.copy(e); return;
        }
        if (e.kind.indexOf("status_") != 0 && e.kind.indexOf("proc_") != 0) return;
        var key = stateKey(e);
        if (e.kind == "status_removed" || e.kind == "proc_ended" || e.kind == "proc_used") active.remove(key);
        else if (e.kind != "proc_reset" && e.kind != "proc_reduction") {
            var state:TimelineEvent = active.exists(key) ? Reflect.copy(active[key]) : Reflect.copy(e);
            for (field in Reflect.fields(e)) Reflect.setField(state, field, Reflect.field(e, field));
            active[key] = state;
        }
    }
    public function update(now:Float):Void { if (now - lastFlush >= 1) flush(now); }
    public function flush(now:Float):Void {
        lastFlush = now;
        if (events.length == 0) return;
        var batch = events; events = [];
        var first = batch[0].time, last = first;
        for (e in batch) { first = Math.min(first, e.time); last = Math.max(last, e.time); }
        onBatch({stream:stream, index:++index, first:first, last:last, initial:initial, events:batch});
        initial = [];
    }
    public function span(start:Float, end:Float, me:String):TimelineSpan
        return {stream:stream, start:start - epoch, end:end - epoch, me:me, through:sequence};
    public function clearState():Void active = [];
}
