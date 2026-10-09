import moresettings.FrameMetrics as M;
import moresettings.StallMetrics;
import moresettings.CleanupSample as C;
import sys.thread.Thread;
import sys.thread.Lock;

@:access(moresettings.StallMetrics)
@:access(moresettings.FrameMetrics)
class FrameMetricsTest {
    static var checks = 0;
    static var now:Float = 0;
    static var reads = 0;
    static function clock():Float { reads++; return now; }
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ': expected $expected, got $actual';
    }
    static function has(text:String, value:String, label:String):Void eq(text != null && text.indexOf(value) >= 0, true, label);
    static function fresh():M { now = 0; reads = 0; return new M(clock, 0); }
    static function frame(m:M, duration = 0.016, combat = true, eligible = true, gap = 0.001):Void {
        now += gap; m.beginFrame(); m.context(eligible, combat, true); now += duration; m.endFrame();
    }
    static function warm(m:M):Void for (_ in 0...140) frame(m);
    static function quiet(m:M):Void for (_ in 0...140) frame(m, 0.016, false);
    static function take(m:M):String { var line = m.report(); m.reported(); return line; }

    static function timings():Void {
        var m = fresh(); warm(m);
        now += 0.001; m.beginFrame(); m.context(true, true, true);
        now += 0.002; m.begin(M.UPDATE); m.begin(M.WORKERS); m.begin(M.SKIN);
        now += 0.500; m.end(M.SKIN); m.end(M.WORKERS);
        now += 0.020; m.end(M.UPDATE);
        m.begin(M.RENDER); now += 0.050; m.end(M.RENDER);
        m.begin(M.PRESENT); m.begin(M.FRAME_WAIT); now += 0.040;
        m.end(M.FRAME_WAIT); now += 0.005; m.end(M.PRESENT); m.endFrame();
        eq(m.pending, 1, "one slow frame");
        eq(m.report(), null, "no report during combat");
        for (_ in 0...500) frame(m);
        eq(m.report(), null, "time alone never enables output in combat");
        quiet(m);
        var line = take(m);
        for (part in ["frame=617ms", "update=520ms", "workers=500ms", "skin=500ms", "render=50ms", "present=45ms", "frame-wait=40ms"])
            has(line, part, "snapshot retains measured duration: " + part);
        has(line, "outside-phases=2ms", "nested timings are not summed as root phases");
        has(line, "combat=true optimization=true", "context belongs to captured frame, not report");
        eq(m.pending, 0, "drains the captured frame");
        eq(m.report(), null, "no empty records");
    }

    static function presentationBreakdown():Void {
        var m = fresh(); warm(m);
        m.beginFrame(); m.context(true, true, true);
        m.begin(M.UPDATE); now += 0.001; m.end(M.UPDATE);
        m.begin(M.RENDER); now += 0.005; m.end(M.RENDER);
        m.begin(M.PRESENT);
        m.begin(M.FLUSH_FRAME); m.begin(M.PIPELINE_SAVE); now += 2.000;
        m.end(M.PIPELINE_SAVE); now += 0.001; m.end(M.FLUSH_FRAME);
        now += 0.040; // Uninstrumented platform presentation / markers.
        m.begin(M.DLSS_STATE); now += 0.001; m.end(M.DLSS_STATE);
        m.begin(M.FRAME_WAIT); m.end(M.FRAME_WAIT);
        m.begin(M.BEGIN_FRAME); now += 0.005; m.end(M.BEGIN_FRAME);
        m.end(M.PRESENT); m.endFrame(); quiet(m);
        var line = take(m);
        for (part in ["Freeze metrics v5", "frame=2053ms", "present=2047ms", "flush-frame=2001ms",
            "pso-save=2000ms", "begin-frame=5ms", "frame-wait=0ms", "dlss-state=1ms", "outside-phases=0ms"])
            has(line, part, "nested presentation detail: " + part);

        // An equally long presentation with a fast save must not accuse cache I/O.
        m.beginFrame(); m.context(true, true, true); m.begin(M.PRESENT);
        m.begin(M.FLUSH_FRAME); m.begin(M.PIPELINE_SAVE); m.end(M.PIPELINE_SAVE); m.end(M.FLUSH_FRAME);
        now += 2;
        m.begin(M.DLSS_MODE); m.begin(M.DRIVER_RESET); now += 0.010;
        m.end(M.DRIVER_RESET); m.end(M.DLSS_MODE); m.end(M.PRESENT); m.endFrame(); quiet(m);
        line = take(m);
        for (part in ["present=2010ms", "pso-save=0ms", "flush-frame=0ms", "dlss-mode=10ms", "driver-reset=10ms"])
            has(line, part, "uncategorized presentation time stays separate: " + part);
    }

    static function driverFrame(m:M, slowStage:Int = -1, trim = false):Void {
        m.beginDriverFrame(); now += slowStage == M.FRAME_SETUP ? 1.960 : 0.001;
        m.driverStep(M.FRAME_SETUP, M.BUFFER_RESET, trim); now += slowStage == M.BUFFER_RESET ? 1.960 : 0.001;
        m.driverStep(M.BUFFER_RESET, M.FRAME_RECYCLE); now += slowStage == M.FRAME_RECYCLE ? 1.960 : 0.001;
        m.driverStep(M.FRAME_RECYCLE, M.FRAME_QUERIES); now += slowStage == M.FRAME_QUERIES ? 1.960 : 0.001;
        m.driverStep(M.FRAME_QUERIES, M.FRAME_TAIL); now += slowStage == M.FRAME_TAIL ? 1.960 : 0.001;
        m.endDriverFrame();
    }

    static function beginFrameBreakdown():Void {
        var m = fresh(); warm(m);
        var labels = ["frame-setup", "buffer-reset", "frame-recycle", "frame-queries", "frame-tail"];
        for (stage in M.FRAME_SETUP...(M.FRAME_TAIL + 1)) {
            m.beginFrame(); m.context(true, true, true); m.begin(M.PRESENT);
            driverFrame(m, stage, stage == M.BUFFER_RESET);
            m.end(M.PRESENT); m.endFrame(); quiet(m);
            var line = take(m);
            has(line, labels[stage - M.FRAME_SETUP] + "=1960ms", "locates the slow preparation step");
            has(line, "begin-frame=1964ms", "parent retains inclusive total");
            has(line, "outside-phases=0ms", "preparation is not subtracted twice");
            has(line, "incomplete=false", "all checkpoints observed");
            has(line, "buffer-trims=" + (stage == M.BUFFER_RESET ? 1 : 0), "trim flag retained and cleared between frames");
        }
        m.beginFrame(); m.context(true, true, true);
        var before = reads;
        m.driverStep(M.FRAME_SETUP, M.BUFFER_RESET, true);
        m.driverStep(M.BUFFER_RESET, M.FRAME_RECYCLE);
        eq(reads, before, "standalone buffer resets do not create driver checkpoints");
        m.beginDriverFrame(); now += 0.510; m.endDriverFrame(); m.endFrame(); quiet(m);
        has(take(m), "incomplete=true", "missing checkpoints cannot masquerade as complete detail");

        m.beginFrame(); m.context(true, true, true); m.beginDriverFrame();
        m.driverStep(M.FRAME_RECYCLE, M.FRAME_QUERIES); now += 0.510;
        m.endDriverFrame(); m.endFrame(); quiet(m);
        has(take(m), "incomplete=true", "out-of-order checkpoints identified");

        m.beginFrame(); m.context(true, true, true); m.beginDriverFrame();
        m.beginDriverFrame(); m.endDriverFrame(); now += 0.510;
        m.endDriverFrame(); m.endFrame(); quiet(m);
        has(take(m), "incomplete=true", "recursive driver preparation is flagged");

        m.beginFrame(); m.context(true, true, true); m.beginDriverFrame(); now += 0.510;
        m.endFrame(); quiet(m);
        has(take(m), "incomplete=true", "interrupted preparation is flagged");
        m.beginFrame(); m.context(true, true, true); driverFrame(m, M.FRAME_TAIL); m.endFrame(); quiet(m);
        has(take(m), "incomplete=false", "checkpoints recover after missing postfix");
    }

    static function cleanupBreakdown():Void {
        var m = fresh(); warm(m);
        for (slow in [M.CLEANUP_MEMORY, M.CLEANUP_JOIN, M.RECYCLE_NATIVE]) {
            m.beginFrame(); m.context(true, true, true); m.begin(M.PRESENT); m.beginDriverFrame();
            m.driverStep(M.FRAME_SETUP, M.BUFFER_RESET); m.driverStep(M.BUFFER_RESET, M.FRAME_RECYCLE);
            m.cleanupEvent(C.ACTIVE); m.cleanupQueue(4, 2);
            m.begin(M.CLEANUP_HOOK); m.begin(M.CLEANUP_MEMORY);
            now += slow == M.CLEANUP_MEMORY ? 1.957 : 0.001;
            m.end(M.CLEANUP_MEMORY); m.cleanupMemory(100.0 * 1048576, 8192.0 * 1048576);
            m.cleanupEvent(C.LOW_MEMORY); m.cleanupEvent(C.PRESSURE_JOIN);
            m.begin(M.CLEANUP_JOIN); now += slow == M.CLEANUP_JOIN ? 1.957 : 0.001; m.end(M.CLEANUP_JOIN);
            m.end(M.CLEANUP_HOOK); m.driverRecycleReady();
            now += slow == M.RECYCLE_NATIVE ? 1.957 : 0.001;
            m.driverStep(M.FRAME_RECYCLE, M.FRAME_QUERIES); m.driverStep(M.FRAME_QUERIES, M.FRAME_TAIL);
            m.endDriverFrame(); m.end(M.PRESENT); m.endFrame();
            quiet(m); // Must not replace the frozen frame's outcome with later empty frames.
            var line = take(m);
            var name = slow == M.CLEANUP_MEMORY ? "cleanup-memory" : slow == M.CLEANUP_JOIN ? "cleanup-join" : "recycle-native";
            for (part in [name + "=1957ms", "frame-recycle=1959ms", "incomplete=false",
                "events=active|low-memory|pressure-join", "queued=4 staged=0 submitted=0 pending-max=2",
                "memory-reads=1 last-free-MiB=100 last-budget-MiB=8192"])
                has(line, part, "cleanup outcome and timings retained: " + part);
        }
        // Multiple beginFrame calls aggregate all outcomes, not just the last queue.
        m.beginFrame(); m.context(true, true, true);
        m.cleanupQueue(3, 1); m.cleanupEvent(C.STAGED, 3); m.cleanupEvent(C.SUBMITTED, 3);
        m.cleanupQueue(0, 4); m.cleanupEvent(C.EMPTY); now += 0.510; m.endFrame(); quiet(m);
        var line = take(m);
        has(line, "events=empty|staged|submitted", "all outcomes in one frame survive");
        has(line, "queued=3 staged=3 submitted=3 pending-max=4", "queue totals and high-water pending count");
        has(line, "memory-reads=0 last-free-MiB=unknown", "unqueried memory is not stale");
        frame(m, 0.510); quiet(m); line = take(m);
        has(line, "events=unobserved queued=0 staged=0 submitted=0 pending-max=unknown", "new frame resets cleanup state");
        m.cleanupEvent(C.ERROR); eq(m.cleanup.events, 0, "events outside a frame ignored");
    }

    static function renderBreakdown():Void {
        var m = fresh(); warm(m);
        m.beginFrame(); m.context(true, true, true); m.beginRender();
        m.begin(M.ENGINE_BEGIN); now += 0.002; m.end(M.ENGINE_BEGIN);
        m.beginScene(); now += 0.001; m.sceneMark("sync"); now += 0.003;
        m.sceneMark("emit"); now += 0.001; m.sceneMark("renderer-setup");
        m.begin(M.RENDER_PASSES); m.begin(M.PBR_BEGIN); now += 0.002; m.end(M.PBR_BEGIN);
        m.sceneMark("chara"); m.begin(M.PIPELINE_CREATE); now += 0.750; m.end(M.PIPELINE_CREATE);
        m.sceneMark("water"); now += 0.010; m.end(M.RENDER_PASSES);
        m.sceneMark("scene-tail"); now += 0.001; m.endScene();
        m.begin(M.ENGINE_END); now += 0.001; m.end(M.ENGINE_END); m.endRender();
        m.endFrame(); quiet(m);
        var line = take(m);
        for (part in ["frame=771ms", "render=771ms", "scene-3d=768ms", "render-passes=762ms",
            "pipeline-create=750ms", "engine-begin=2ms", "engine-end=1ms", "pbr-begin=2ms",
            "chara=750ms(max=750,n=1)", "water=10ms", "outside-phases=0ms", "incomplete=false"])
            has(line, part, "separates pipeline creation, markers and outer render: " + part);
        has(line, "render-stages={observed=7 dropped=0", "stage snapshot survives quiet frames");

        // A slow UI or renderer subsystem must not be called a pipeline stall.
        for (id in [M.SCENE_2D, M.DLSS_RENDER, M.LIGHTING, M.RESERVED_MEMORY, M.PBR_END]) {
            m.beginFrame(); m.context(true, true, true); m.beginRender();
            m.begin(id); now += 0.750; m.end(id); m.endRender(); m.endFrame(); quiet(m);
            line = take(m);
            has(line, M.labels[id] + "=750ms", "locates other rendering work");
            eq(line.indexOf("pipeline-create="), -1, "unused pipeline scope is absent");
            has(line, "render-stages={observed=0", "no stale named stages");
        }
        // Nested scene previews/reflections pause their parent's named interval.
        m.beginFrame(); m.context(true, true, true); m.beginRender(); m.beginScene();
        m.sceneMark("parent"); now += 0.010; m.beginScene(); m.sceneMark("child");
        now += 0.600; m.endScene(); now += 0.020; m.endScene(); m.endRender();
        m.endFrame(); quiet(m); line = take(m);
        has(line, "child=600ms(max=600,n=1)", "nested scene measured");
        has(line, "parent=30ms(max=20,n=2)", "nested child not charged to parent's marker");
        has(line, "scene-3d=630ms(max=630,n=1)", "recursive scene total is inclusive only once");
        has(line, "incomplete=false", "nested scenes close cleanly");

        m.beginFrame(); m.context(true, true, true); m.beginScene(); now += 0.600;
        m.endFrame(); quiet(m); has(take(m), "incomplete=true", "missing scene postfix flagged");
        var before = reads; m.sceneMark("outside"); m.endScene();
        eq(reads, before, "markers outside scenes do not read clocks");
        frame(m, 0.600); quiet(m); has(take(m), "render-stages={observed=0", "interrupted stage cleared");

        var stages = new moresettings.RenderStages(); stages.beginScene(0);
        for (i in 0...100) stages.mark("stage" + i, i + 1);
        stages.endScene(102);
        eq(stages.used, moresettings.RenderStages.CAPACITY, "distinct marker storage bounded");
        eq(stages.dropped > 0, true, "marker overflow visible");
        eq(stages.names.length, moresettings.RenderStages.CAPACITY, "marker array never grows");
        stages.reset();
        for (i in 0...12) stages.beginScene(i);
        for (i in 0...12) stages.endScene(20 + i);
        eq(stages.depth, 0, "nested overflow recovers"); eq(stages.dropped > 0, true, "nested overflow visible");
        stages.reset(); eq(stages.dropped, 0, "overflow resets each frame");
    }

    static function allocationCounters():Void {
        var a = new moresettings.RenderAllocations();
        a.sample(false, 1000, 2, 1048576); eq(a.samples, 0, "missing allocation baseline ignored");
        a.sample(true, 1000, 2, 1048576); a.sample(false, 2024, 5, 2097152);
        a.sample(true, 3000, 7, 2097152); a.sample(false, 4024, 9, 2097152);
        eq(a.bytes, 2048.0, "separate renders sum deltas, excluding work between renders");
        eq(a.allocations, 5.0, "allocation count deltas"); eq(a.samples, 2, "paired samples counted");
        var snapshot = new moresettings.RenderAllocations(); snapshot.copyFrom(a); a.reset();
        has(snapshot.describe(), "allocated-KiB=2 allocations=5 heap-MiB=2", "snapshot retained");
        has(a.describe(), "allocated-KiB=unknown", "absent counters do not pretend to be zero");
        a.sample(true, 1000, 10, 0); a.sample(false, 100, 2, 0);
        eq(a.samples, 0, "reset counters ignored");
        #if hl
        a.read(true);
        var bytes = haxe.io.Bytes.alloc(4096); bytes.set(0, 42);
        a.read(false);
        eq(a.samples, 1, "native counter API available");
        eq(a.bytes >= 4096, true, "native allocation burst observed");
        eq(a.allocations > 0, true, "native allocation count observed");
        eq(bytes.get(0), 42, "sampling preserves native allocations");
        #end
        var m = fresh(); warm(m);
        m.beginFrame(); m.context(true, true, true); m.beginRender(); m.beginRender();
        now += 0.600; m.endRender(); m.endRender(); m.endFrame(); quiet(m);
        var line = take(m);
        has(line, "render=600ms(max=600,n=1)", "nested render only timed once");
        #if hl
        has(line, "render-alloc={samples=1", "nested render only samples outer pair");
        #else
        has(line, "render-alloc={samples=0", "non-HL counters explicitly unavailable");
        #end
        frame(m, 0.499); eq(m.pending, 0, "still suppresses sub-500 ms frames");
    }

    static function overlapAndMissingPostfix():Void {
        var m = fresh(); warm(m);
        m.beginFrame(); m.context(true, true, false); m.begin(M.UPDATE);
        m.begin(M.RENDER); m.begin(M.RENDER); now += 0.510; m.end(M.RENDER); m.end(M.RENDER);
        m.end(M.UPDATE); m.endFrame(); quiet(m);
        var line = take(m);
        has(line, "outside-phases=0ms", "overlapping phases use their union");
        has(line, "render=510ms(max=510,n=1)", "recursive scope counted once");
        has(line, "optimization=false", "supports optimization comparison");
        frame(m); m.beginFrame(); m.context(true, true, true); m.begin(M.SKIN);
        now += 0.510; m.endFrame(); quiet(m);
        has(take(m), "incomplete=true", "missing postfix identified");
        eq(m.depth[M.SKIN], 0, "scope depth resets next frame");
        m.beginFrame(); m.context(true, true, true); m.begin(M.SKIN); now += 1;
        m.beginFrame(); m.context(true, true, true); now += 0.016; m.endFrame();
        eq(m.interrupted, 1, "whole-frame exception invalidates previous scope");
        eq(m.pending, 0, "interrupted frame not mislabeled as a new gap");
    }

    static function gatingAndGaps():Void {
        var m = fresh(); frame(m, 1, true, false); frame(m, 1);
        eq(m.pending, 0, "loading and first gameplay frame excluded");
        warm(m); frame(m, 0.016, true, true, 0.800);
        eq(m.pending, 1, "stall between frames recorded");
        quiet(m); var line = take(m);
        has(line, "frame=16ms gap=800ms", "event loop/unknown gap separated from frame body");
        frame(m, 1, false, false); frame(m, 0.016, false, true, 2.0);
        eq(m.pending, 0, "returning from Alt-Tab not a freeze report");
        warm(m); frame(m, 0.510); m.suspend();
        eq(m.pending, 1, "world exit retains captured diagnostic");
        eq(m.report(), null, "world exit does not force disk output");
        frame(m, 0.016, false, true, 5); quiet(m); line = take(m);
        has(line, "frame=510ms", "record reported after next quiet session");
        eq(m.pending, 0, "session boundary not recorded as a five-second gap");
    }

    static function boundedOutput():Void {
        var m = fresh(); warm(m);
        for (_ in 0...100) frame(m, 0.510);
        eq(m.pending, M.CAPACITY, "buffer bounded during prolonged combat");
        eq(m.overwritten, 100 - M.CAPACITY, "overwritten entries counted");
        var first = m.records[m.head];
        quiet(m); var line = m.report(); has(line, "overwritten=68", "reports buffer pressure");
        now += 0.9; m.reported(); frame(m, 0.016, false);
        eq(m.pending, M.CAPACITY - 1, "own logging delay excluded");
        eq(m.report(), null, "at most one output per second");
        for (_ in 0...65) frame(m, 0.016, false);
        eq(m.canReport(), true, "next record available after rate limit");
        eq(m.records[(m.head + M.CAPACITY - 1) % M.CAPACITY] == first, true, "ring record storage reused");
        var pending = m.pending; frame(m, 0.510, false);
        eq(m.pending, pending + 1, "new real slow frame still captured");
        eq(m.canReport(), false, "slow out-of-combat frame restarts quiet interval");
    }

    static function threadsAndDisabled():Void {
        StallMetrics.configure(true);
        var m = fresh(); StallMetrics.metrics = m;
        StallMetrics.beginFrame(); StallMetrics.context(true, true, false);
        var before = reads; var done = new Lock();
        Thread.create(() -> {
            StallMetrics.begin(M.SHADER_SOURCE); StallMetrics.end(M.SHADER_SOURCE);
            StallMetrics.beginRender(); StallMetrics.beginScene(); StallMetrics.sceneMark("foreign");
            StallMetrics.endScene(); StallMetrics.endRender();
            StallMetrics.beginDriverFrame();
            StallMetrics.driverStep(M.FRAME_SETUP, M.BUFFER_RESET, true); StallMetrics.endDriverFrame();
            StallMetrics.driverRecycleReady(); StallMetrics.cleanupEvent(C.ERROR);
            StallMetrics.cleanupQueue(42, 10); StallMetrics.cleanupMemory(1, 2);
            StallMetrics.context(false, false, false); StallMetrics.endFrame(); done.release();
        });
        eq(done.wait(3), true, "background test completed");
        eq(reads, before, "background hooks do not sample clocks");
        eq(m.active, true, "background hook cannot end main frame");
        eq(m.renderStages.used, 0, "background marker collection excluded");
        eq(m.renderAllocations.samples, 0, "background allocation sampling excluded");
        eq(m.eligible, true, "background hook cannot change context");
        eq(m.cleanup.events, 0, "background hook cannot change cleanup outcome");
        eq(m.cleanup.queued, 0, "background hook cannot change cleanup counts");
        eq(m.cleanup.memoryReads, 0, "background hook cannot change memory sample");
        now += 0.016; StallMetrics.endFrame(); StallMetrics.configure(false); before = reads;
        StallMetrics.beginFrame(); StallMetrics.begin(M.RENDER); StallMetrics.end(M.RENDER);
        StallMetrics.beginRender(); StallMetrics.beginScene(); StallMetrics.sceneMark("disabled");
        StallMetrics.endScene(); StallMetrics.endRender();
        StallMetrics.beginDriverFrame(); StallMetrics.driverStep(M.FRAME_SETUP, M.BUFFER_RESET); StallMetrics.endDriverFrame();
        StallMetrics.context(true, true, true); StallMetrics.endFrame();
        StallMetrics.driverRecycleReady(); StallMetrics.cleanupEvent(C.ERROR);
        StallMetrics.cleanupQueue(42, 10); StallMetrics.cleanupMemory(1, 2);
        eq(reads, before, "disabled diagnostics do not read the clock");
        eq(StallMetrics.metrics, null, "disabling releases diagnostic buffer");
    }

    static function benchmark():Void {
        var m = new M(); var start = haxe.Timer.stamp(); var frames = 100000;
        var markers = [for (i in 0...30) "stage" + i];
        for (_ in 0...frames) {
            m.beginFrame(); m.context(true, true, true);
            m.begin(M.UPDATE); m.begin(M.WORKERS); m.end(M.WORKERS); m.end(M.UPDATE);
            m.beginRender(); m.beginScene();
            for (name in markers) m.sceneMark(name);
            m.endScene(); m.endRender();
            m.begin(M.PRESENT);
            m.begin(M.FLUSH_FRAME); m.begin(M.PIPELINE_SAVE); m.end(M.PIPELINE_SAVE); m.end(M.FLUSH_FRAME);
            m.begin(M.DLSS_STATE); m.end(M.DLSS_STATE);
            m.begin(M.FRAME_WAIT); m.end(M.FRAME_WAIT);
            m.beginDriverFrame(); m.driverStep(M.FRAME_SETUP, M.BUFFER_RESET);
            m.driverStep(M.BUFFER_RESET, M.FRAME_RECYCLE);
            m.cleanupEvent(C.ACTIVE); m.cleanupQueue(4, 0); m.begin(M.CLEANUP_HOOK);
            m.begin(M.CLEANUP_MEMORY); m.end(M.CLEANUP_MEMORY); m.cleanupMemory(4e9, 8e9);
            m.cleanupEvent(C.STAGED, 4); m.end(M.CLEANUP_HOOK); m.driverRecycleReady();
            m.driverStep(M.FRAME_RECYCLE, M.FRAME_QUERIES);
            m.driverStep(M.FRAME_QUERIES, M.FRAME_TAIL); m.endDriverFrame(); m.end(M.PRESENT);
            m.endFrame(); m.canReport();
        }
        var elapsed = haxe.Timer.stamp() - start;
        Sys.println('Timing-buffer microbenchmark: ${elapsed * 1000000 / frames} us/frame ($frames frames; excludes HLX hooks/native context reads).');
    }
    static function main():Void {
        timings(); presentationBreakdown(); beginFrameBreakdown(); cleanupBreakdown(); renderBreakdown(); allocationCounters(); overlapAndMissingPostfix(); gatingAndGaps(); boundedOutput(); threadsAndDisabled();
        eq(moresettings.SettingsData.defaults().performanceDiagnostics, false, "diagnostics opt-in");
        Sys.println('Frame metrics: $checks checks passed.');
        if (Sys.args().indexOf("--bench") >= 0) benchmark();
    }
}
