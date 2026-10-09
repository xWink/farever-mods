package moresettings;

private class SlowFrame {
    public var at:Float = 0;
    public var body:Float = 0;
    public var gap:Float = 0;
    public var outside:Float = 0;
    public var combat = false;
    public var optimized = false;
    public var incomplete = false;
    public var bufferTrims = 0;
    public var cleanup = new CleanupSample();
    public var renderStages = new RenderStages();
    public var renderAllocations = new RenderAllocations();
    public var total:Array<Float> = [for (_ in 0...FrameMetrics.COUNT) 0.0];
    public var maximum:Array<Float> = [for (_ in 0...FrameMetrics.COUNT) 0.0];
    public var calls:Array<Int> = [for (_ in 0...FrameMetrics.COUNT) 0];
    public function new() {}
}

/** Bounded wall-clock timings. No formatting, file I/O or record allocation while collecting. */
class FrameMetrics {
    public static inline var UPDATE = 0;
    public static inline var RENDER = 1;
    public static inline var PRESENT = 2;
    public static inline var WORKERS = 3;
    public static inline var SKIN = 4;
    public static inline var CHARACTER_PART = 5;
    public static inline var SHADER_SOURCE = 6;
    public static inline var PIPELINE_REPLAY = 7;
    public static inline var GRAPHICS_CLEANUP = 8;
    public static inline var FRAME_WAIT = 9;
    public static inline var FLUSH_FRAME = 10;
    public static inline var PIPELINE_SAVE = 11;
    public static inline var BEGIN_FRAME = 12;
    public static inline var DLSS_STATE = 13;
    public static inline var DLSS_MODE = 14;
    public static inline var DRIVER_RESET = 15;
    public static inline var FRAME_SETUP = 16;
    public static inline var BUFFER_RESET = 17;
    public static inline var FRAME_RECYCLE = 18;
    public static inline var FRAME_QUERIES = 19;
    public static inline var FRAME_TAIL = 20;
    public static inline var CLEANUP_HOOK = 21;
    public static inline var CLEANUP_MEMORY = 22;
    public static inline var CLEANUP_JOIN = 23;
    public static inline var CLEANUP_PUBLISH = 24;
    public static inline var RECYCLE_NATIVE = 25;
    public static inline var ENGINE_BEGIN = 26;
    public static inline var ENGINE_END = 27;
    public static inline var SCENE_3D = 28;
    public static inline var SCENE_2D = 29;
    public static inline var RENDER_PASSES = 30;
    public static inline var PIPELINE_CREATE = 31;
    public static inline var PBR_BEGIN = 32;
    public static inline var PBR_END = 33;
    public static inline var LIGHTING = 34;
    public static inline var DLSS_RENDER = 35;
    public static inline var RESERVED_MEMORY = 36;
    public static inline var COUNT = 37;
    public static inline var CAPACITY = 32;
    public static inline var THRESHOLD = 0.500;
    static inline var QUIET_SECONDS = 2.0;
    static var labels = ["update", "render", "present", "workers", "skin", "character-part",
        "shader-source", "pipeline-replay", "graphics-cleanup", "frame-wait", "flush-frame",
        "pso-save", "begin-frame", "dlss-state", "dlss-mode", "driver-reset",
        "frame-setup", "buffer-reset", "frame-recycle", "frame-queries", "frame-tail",
        "cleanup-hook", "cleanup-memory", "cleanup-join", "cleanup-publish", "recycle-native",
        "engine-begin", "engine-end", "scene-3d", "scene-2d", "render-passes", "pipeline-create",
        "pbr-begin", "pbr-end", "lighting", "dlss-render", "reserved-memory"];

    var clock:Void->Float;
    var epoch:Float;
    var origin:Float;
    var started:Float = 0;
    var lastEnd:Float = -1;
    var gap:Float = 0;
    var eligible = false;
    var previousEligible = false;
    var combat = false;
    var optimized = false;
    var contextSeen = false;
    var eligibleSince:Float = -1;
    var quietSince:Float = -1;
    var nextReport:Float = 0;
    var phaseDepth = 0;
    var phaseStart:Float = 0;
    var phaseTotal:Float = 0;
    var driverStage = -1;
    var driverIncomplete = false;
    var bufferTrims = 0;
    var cleanup = new CleanupSample();
    var renderStages = new RenderStages();
    var renderAllocations = new RenderAllocations();
    var starts:Array<Float> = [for (_ in 0...COUNT) 0.0];
    var depth:Array<Int> = [for (_ in 0...COUNT) 0];
    var totals:Array<Float> = [for (_ in 0...COUNT) 0.0];
    var maxima:Array<Float> = [for (_ in 0...COUNT) 0.0];
    var counts:Array<Int> = [for (_ in 0...COUNT) 0];
    var records:Array<SlowFrame> = [for (_ in 0...CAPACITY) new SlowFrame()];
    var head = 0;
    public var pending(default, null) = 0;
    public var overwritten(default, null) = 0;
    public var interrupted(default, null) = 0;
    public var active(default, null) = false;

    public function new(?clock:Void->Float, ?epoch:Float) {
        this.clock = clock == null ? haxe.Timer.stamp : clock;
        origin = this.clock();
        this.epoch = epoch == null ? Date.now().getTime() : epoch;
    }

    public function beginFrame():Void {
        var now = clock();
        // A native exception may bypass a postfix. Never carry an open scope or
        // attribute the aborted frame to the following frame's event-loop gap.
        if (active) { interrupted++; lastEnd = -1; eligibleSince = -1; }
        gap = lastEnd < 0 ? 0 : Math.max(0, now - lastEnd);
        started = now;
        contextSeen = false;
        eligible = false;
        phaseDepth = 0;
        phaseTotal = 0;
        driverStage = -1;
        driverIncomplete = false;
        bufferTrims = 0;
        cleanup.reset();
        renderStages.reset();
        renderAllocations.reset();
        for (i in 0...COUNT) { depth[i] = 0; totals[i] = 0; maxima[i] = 0; counts[i] = 0; }
        active = true;
    }

    public function context(gameplay:Bool, inCombat:Bool, optimization:Bool):Void {
        if (!active) return;
        contextSeen = true;
        eligible = gameplay;
        combat = inCombat;
        optimized = optimization;
    }

    public function begin(id:Int):Void {
        if (!active) return;
        if (depth[id]++ != 0) return; // Count recursive scopes once, inclusively.
        var now = clock();
        starts[id] = now;
        if (id <= PRESENT && phaseDepth++ == 0) phaseStart = now;
    }

    public function end(id:Int):Void {
        if (!active || depth[id] == 0 || --depth[id] != 0) return;
        var now = clock();
        var elapsed = Math.max(0, now - starts[id]);
        totals[id] += elapsed;
        if (elapsed > maxima[id]) maxima[id] = elapsed;
        counts[id]++;
        if (id <= PRESENT && --phaseDepth == 0) phaseTotal += now - phaseStart;
    }

    public function beginRender():Void {
        if (!active) return;
        begin(RENDER);
        if (depth[RENDER] == 1) renderAllocations.read(true);
    }
    public function endRender():Void {
        if (!active || depth[RENDER] == 0) return;
        if (depth[RENDER] == 1) renderAllocations.read(false);
        end(RENDER);
    }
    public function beginScene():Void {
        if (!active) return;
        begin(SCENE_3D);
        renderStages.beginScene(clock());
    }
    public function sceneMark(name:String):Void {
        if (active && renderStages.depth > 0) renderStages.mark(name, clock());
    }
    public function endScene():Void {
        if (!active || depth[SCENE_3D] == 0) return;
        renderStages.endScene(clock());
        end(SCENE_3D);
    }

    /** Checkpoints partition beginFrame without replacing any native graphics work. */
    public function beginDriverFrame():Void {
        if (!active) return;
        begin(BEGIN_FRAME);
        if (depth[BEGIN_FRAME] != 1) { driverIncomplete = true; return; }
        driverStage = FRAME_SETUP;
        begin(driverStage);
    }

    public function driverStep(expected:Int, next:Int, trim:Bool = false):Void {
        // These methods also run independently of beginFrame. Ignore those calls.
        if (!active || depth[BEGIN_FRAME] == 0) return;
        if (depth[BEGIN_FRAME] != 1 || driverStage != expected) { driverIncomplete = true; return; }
        if (expected == FRAME_RECYCLE) end(RECYCLE_NATIVE);
        end(driverStage);
        driverStage = next;
        begin(driverStage);
        if (next == BUFFER_RESET && trim) bufferTrims++;
    }

    /** Remainder of the native recycle section after our cleanup callback returns. */
    public function driverRecycleReady():Void {
        if (active && depth[BEGIN_FRAME] == 1 && driverStage == FRAME_RECYCLE && depth[RECYCLE_NATIVE] == 0)
            begin(RECYCLE_NATIVE);
    }

    public function cleanupEvent(id:Int, count:Int = 0):Void { if (active) cleanup.event(id, count); }
    public function cleanupQueue(count:Int, pending:Int):Void { if (active) cleanup.queue(count, pending); }
    public function cleanupMemory(free:Float, budget:Float):Void { if (active) cleanup.memory(free, budget); }

    public function endDriverFrame():Void {
        if (!active || depth[BEGIN_FRAME] == 0) return;
        if (depth[BEGIN_FRAME] == 1) {
            if (driverStage != FRAME_TAIL) driverIncomplete = true;
            end(RECYCLE_NATIVE);
            if (driverStage >= 0) end(driverStage);
            driverStage = -1;
        }
        end(BEGIN_FRAME);
    }

    public function endFrame():Void {
        if (!active) return;
        var now = clock();
        active = false;
        var body = Math.max(0, now - started);
        if (!contextSeen || !eligible) {
            eligibleSince = -1;
            quietSince = -1;
            previousEligible = false;
            lastEnd = now;
            return;
        }
        if (eligibleSince < 0) eligibleSince = now;
        var incomplete = driverIncomplete || renderStages.depth != 0;
        for (d in depth) if (d != 0) incomplete = true;
        // Require stable, focused gameplay; loading and returning from Alt-Tab
        // should not fill the diagnostic buffer with expected long frames.
        var capture = previousEligible && now - eligibleSince >= QUIET_SECONDS
            && (body >= THRESHOLD || gap >= THRESHOLD);
        if (capture) {
            var record = records[(head + pending) % CAPACITY];
            if (pending == CAPACITY) { head = (head + 1) % CAPACITY; overwritten++; }
            else pending++;
            record.at = now;
            record.body = body;
            record.gap = gap;
            record.outside = Math.max(0, body - phaseTotal);
            record.combat = combat;
            record.optimized = optimized;
            record.incomplete = incomplete;
            record.bufferTrims = bufferTrims;
            record.cleanup.copyFrom(cleanup);
            record.renderStages.copyFrom(renderStages);
            record.renderAllocations.copyFrom(renderAllocations);
            for (i in 0...COUNT) {
                record.total[i] = totals[i]; record.maximum[i] = maxima[i]; record.calls[i] = counts[i];
            }
        }
        if (combat || body >= 0.050 || gap >= 0.050 || incomplete) quietSince = -1;
        else if (quietSince < 0) quietSince = now;
        previousEligible = true;
        lastEnd = now;
    }

    public function canReport():Bool {
        if (active || pending == 0 || !contextSeen || !eligible || combat || quietSince < 0) return false;
        var now = clock();
        return now - quietSince >= QUIET_SECONDS && now >= nextReport;
    }

    static function ms(value:Float):String return Std.string(Math.round(value * 1000));

    /** Only called after a quiet, out-of-combat frame; at most one record per second. */
    public function report():Null<String> {
        if (!canReport()) return null;
        var record = records[head];
        var at = Date.fromTime(epoch + (record.at - origin) * 1000).toString();
        var parts = [for (i in 0...COUNT) if (record.calls[i] > 0)
            labels[i] + "=" + ms(record.total[i]) + "ms(max=" + ms(record.maximum[i]) + ",n=" + record.calls[i] + ")"];
        var line = '[More Settings] Freeze metrics v5: at=$at frame=${ms(record.body)}ms gap=${ms(record.gap)}ms'
            + ' outside-phases=${ms(record.outside)}ms combat=${record.combat} optimization=${record.optimized}'
            + ' incomplete=${record.incomplete} overwritten=$overwritten interrupted=$interrupted buffer-trims=${record.bufferTrims}; '
            + parts.join(" ") + "; " + record.cleanup.describe()
            + "; " + record.renderStages.describe() + "; " + record.renderAllocations.describe()
            + "; timings are inclusive wall time, not GPU or GC attribution; allocation counters are process-wide.";
        head = (head + 1) % CAPACITY;
        pending--;
        return line;
    }

    /** Exclude our own deferred formatting/output from the next inter-frame gap. */
    public function reported():Void {
        lastEnd = clock();
        nextReport = lastEnd + 1;
    }

    /** World changes must not connect unrelated frames; keep captured records. */
    public function suspend():Void {
        active = false;
        lastEnd = -1;
        contextSeen = false;
        eligible = previousEligible = false;
        eligibleSince = quietSince = -1;
    }
}
