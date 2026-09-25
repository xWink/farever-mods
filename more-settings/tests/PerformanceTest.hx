import moresettings.WorkerQueue;
import moresettings.FeedBacklog;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class PerformanceTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw '$message: expected $b, got $a';
    }
    static function nativeArray(items:Array<Dynamic>):Dynamic return {items: items, length: items.length};
    static function push(array:Dynamic, value:Dynamic):Void {
        array.items.push(value); array.length = array.items.length;
    }
    static function worker(jobs:Array<Dynamic>, budget:Float = 1):Dynamic return {
        mainThreadJobs: nativeArray(jobs), MAX_FRAME_BUDGET: budget, MAX_FRAME_BUDGET_LOADING: budget * 2,
        inLoading: false, lastThreadedBlocking: false, lastTime: -1.0
    };

    static function main():Void {
        eq(SettingsData.defaults().performanceOptimization, false, "existing installations stay opt-in");
        workQueue(); feed();
        Sys.println('Performance optimization: $checks checks passed.');
    }

    static function workQueue():Void {
        var batch = WorkerQueue.MIN_BATCH;
        var now = 0.0;
        var queue = new WorkerQueue(() -> now);
        var order:Array<Int> = [];
        var jobs:Array<Dynamic> = [for (i in 0...batch * 2) () -> { order.push(i); now += 0.25; }];
        var w = worker(jobs);
        var original = w.mainThreadJobs;
        G.blitCalls = 0; G.blitElements = 0;
        eq(queue.run(w), true, "large queue optimized");
        eq(order.join(","), "0,1,2,3", "native deadline and FIFO order retained");
        eq(w.lastTime, 0.0, "native start timestamp retained");
        eq(w.mainThreadJobs, original, "native array identity retained");
        eq(w.mainThreadJobs.length, batch * 2 - 4, "only executed jobs consumed");
        eq(G.blitCalls, 1, "one tail copy per pass");
        eq(G.blitElements, batch * 2 - 4, "tail copied once instead of shifting after every job");
        w.inLoading = true;
        queue.run(w);
        eq(order.length, 12, "native loading budget used");
        eq(order[11], 11, "next pass resumes exactly once");

        var small = worker([() -> { throw "small queue must use native work"; }]);
        eq(queue.run(small), false, "small queues use the original implementation");
        eq(small.mainThreadJobs.length, 1, "fallback does not consume jobs");
        var invalid = worker([for (_ in 0...batch) () -> {}]);
        invalid.MAX_FRAME_BUDGET = Math.NaN;
        eq(queue.run(invalid), false, "unavailable budget falls back before any mutation");

        order = []; now = 0;
        var append = worker([], 100);
        for (i in 0...batch) {
            var n = i;
            push(append.mainThreadJobs, () -> {
                order.push(n);
                if (n == 0) push(append.mainThreadJobs, () -> order.push(batch));
                if (n == batch - 1) eq(queue.isEmpty(append, false), false, "appended work prevents empty result");
            });
        }
        queue.run(append);
        eq(order.join(","), [for (i in 0...batch + 1) i].join(","), "callback-submitted job runs after older work");
        eq(append.mainThreadJobs.length, 0, "complete drain releases every native reference");
        eq(queue.active(append), false, "cursor removed after pass");

        var nested = worker([], 100);
        order = [];
        for (i in 0...batch) {
            var n = i;
            push(nested.mainThreadJobs, () -> {
                order.push(n);
                if (n == 0) queue.run(nested);
                if (n == batch - 1) {
                    eq(queue.isEmpty(nested, false), true, "empty during last callback accounts for cursor");
                    nested.lastThreadedBlocking = true;
                    eq(queue.isEmpty(nested, false), false, "threaded work remains authoritative");
                }
            });
        }
        queue.run(nested);
        eq(order.length, batch, "nested drains never repeat a job");
        eq(nested.mainThreadJobs.length, 0, "outermost pass compacts nested progress");

        order = [];
        var errors = worker([for (i in 0...batch) {
            var n = i;
            () -> { order.push(n); if (n == 2) throw "job failed"; };
        }], 100);
        var caught = false;
        try queue.run(errors) catch (e:Dynamic) { caught = true; eq(e, "job failed", "job error returned to hook"); }
        eq(caught, true, "exception ends current pass");
        eq(errors.mainThreadJobs.length, batch - 3, "throwing job consumed, remaining jobs preserved");
        eq(queue.active(errors), false, "exception clears cursor for native fallback");
        var remaining:Void->Void = errors.mainThreadJobs.items[0]; remaining();
        eq(order.join(","), "0,1,2,3", "fallback resumes after failed job");

        var sentinel = worker([for (i in 0...batch) i == 1 ? null : () -> {}], 100);
        queue.run(sentinel);
        eq(sentinel.mainThreadJobs.length, batch - 2, "null sentinel is consumed and ends pass like native shift");
    }

    static function row(kind:String, elapsed:Float):Dynamic return {
        elapsed: elapsed, elt: {parent: {}, dom: {classes: [kind]}}
    };

    static function addNative(feed:Dynamic, kind:String):Dynamic {
        FeedBacklog.trim(feed);
        var elapsed = 0.0;
        for (line in (cast feed.activeLines.items:Array<Dynamic>))
            elapsed = Math.min(elapsed, line.elapsed - 0.15);
        var line = row(kind, elapsed);
        push(feed.activeLines, line);
        return line;
    }

    static function feed():Void {
        var feed:Dynamic = {activeLines: nativeArray([])};
        var notification = addNative(feed, "game-beat");
        var transition = addNative(feed, "combat");
        G.removedElements = 0;
        for (i in 0...1000) addNative(feed, i % 2 == 0 ? "damage" : "heal");
        eq(feed.activeLines.length, 32, "large burst cannot accumulate numeric rows indefinitely");
        eq(notification.elt.parent != null, true, "game-beat notification preserved");
        eq(transition.elt.parent != null, true, "combat transition preserved");
        eq(G.removedElements, 970, "removed numeric elements leave the scene graph");
        var min = 0.0;
        for (line in (cast feed.activeLines.items:Array<Dynamic>)) min = Math.min(min, line.elapsed);
        eq(min >= -4.66, true, "tail delay is bounded, not 150 seconds after 1000 hits");

        var important = [for (_ in 0...40) row("game-beat", 0)];
        var messages:Dynamic = {activeLines: nativeArray(important)};
        for (_ in 0...50) addNative(messages, "damage");
        eq(messages.activeLines.length, 41, "message-only overflow is preserved; numeric rows remain bounded");
        for (line in important) eq(line.elt.parent != null, true, "important message never dropped");

        var low = row("damage", -0.3);
        var normal:Dynamic = {activeLines: nativeArray([low])};
        FeedBacklog.trim(normal);
        eq(low.elapsed, -0.3, "ordinary feed timing stays native");
        eq(low.elt.parent != null, true, "ordinary feed elements stay attached");

        // Enabling with an existing backlog requires no prior tracking state.
        var backlog = [for (i in 0...100) row("damage", -0.15 * i)];
        var existing:Dynamic = {activeLines: nativeArray(backlog)};
        FeedBacklog.trim(existing);
        eq(existing.activeLines.length, 31, "existing backlog makes room for next native line");
        eq(existing.activeLines.items[30].elapsed >= -4.51, true, "existing delayed tail catches up");
    }
}
