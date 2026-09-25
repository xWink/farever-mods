package moresettings;

import moresettings.GameAccess as G;

private typedef QueueCursor = {
    var worker:Dynamic;
    var queue:Dynamic;
    var head:Int;
}

/** Drain large native queues by index, then move the remaining tail only once. */
class WorkerQueue {
    // Native shifts are cheap for short arrays; avoid reflection overhead there.
    public static inline var MIN_BATCH:Int = 256;
    var cursors:Array<QueueCursor> = [];
    var clock:Void->Float;

    public function new(?clock:Void->Float) this.clock = clock == null ? haxe.Timer.stamp : clock;

    function cursor(worker:Dynamic):QueueCursor {
        for (value in cursors) if (value.worker == worker) return value;
        return null;
    }

    public function active(worker:Dynamic):Bool return cursor(worker) != null;

    public function isEmpty(worker:Dynamic, original:Bool):Bool {
        var value = cursor(worker);
        if (value == null) return original;
        return value.head >= G.integer(G.field(value.queue, "length"))
            && G.field(worker, "lastThreadedBlocking") != true;
    }

    public function run(worker:Dynamic):Bool {
        var value = cursor(worker);
        var outer = value == null;
        var queue = G.field(worker, "mainThreadJobs");
        if (outer && (queue == null || G.integer(G.field(queue, "length")) < MIN_BATCH)) return false;
        var budget = G.number(G.field(worker, G.field(worker, "inLoading") == true
            ? "MAX_FRAME_BUDGET_LOADING" : "MAX_FRAME_BUDGET"), Math.NaN);
        if (!Math.isFinite(budget) || budget < 0) return false;
        if (outer) {
            value = {worker: worker, queue: queue, head: 0};
            cursors.push(value);
        }
        var started = clock();
        try {
            while (value.head < G.integer(G.field(queue, "length"))) {
                var job:Void->Void = G.call("hl.types.ArrayObj", "getDyn", queue, [value.head]);
                // Clear consumed references promptly, just like native shift().
                G.call("hl.types.ArrayObj", "setDyn", queue, [value.head, null]);
                value.head++;
                if (job == null) break; // Preserve the native null-job sentinel.
                job();
                if (clock() - started >= budget) break;
            }
        } catch (e:Dynamic) {
            if (outer) finish(value);
            throw e;
        }
        if (outer) finish(value);
        G.set(worker, "lastTime", started);
        return true;
    }

    function finish(value:QueueCursor):Void {
        var remaining = G.integer(G.field(value.queue, "length")) - value.head;
        // addJob() still appends to the same native array. New jobs remain after
        // older jobs, including jobs submitted by a callback during this pass.
        if (remaining > 0 && value.head > 0)
            G.call("hl.types.ArrayObj", "blit", value.queue, [0, value.queue, value.head, remaining]);
        G.call("hl.types.ArrayObj", "resize", value.queue, [remaining]);
        cursors.remove(value);
    }
}
