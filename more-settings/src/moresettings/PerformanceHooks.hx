package moresettings;

import hlx.runtime.HlxPrefixResult;

/** Opt-in fixes for audited client queues; no gameplay work is discarded. */
class PerformanceHooks {
    public static var enabled:Bool = false;
    static var queue = new WorkerQueue();
    static var queueFailed:Bool = false;
    static var feedFailed:Bool = false;

    @:hlx.prefix(lib.Workers.work)
    static function work(instance:Dynamic):HlxPrefixResult<Void> {
        // A nested work() must use the current cursor even if a job toggles us off.
        if ((!enabled || queueFailed) && !queue.active(instance)) return Continue;
        try return queue.run(instance) ? Skip : Continue catch (e:Dynamic) {
            // run() compacts the consumed prefix on failure. Do not dispatch the
            // original in the same pass and accidentally rerun a failing job.
            if (!queueFailed) trace("[More Settings] Performance worker queue disabled: " + Std.string(e));
            queueFailed = true;
            return Skip;
        }
    }

    @:hlx.postfix(lib.Workers.isEmpty)
    static function isEmpty(instance:Dynamic, result:Bool):Bool
        return queue.isEmpty(instance, result);

    @:hlx.prefix(ui.hud.EffectsFeed.addLine)
    static function beforeFeedLine(instance:Dynamic, text:String):HlxPrefixResult<Dynamic> {
        if (enabled && !feedFailed) try FeedBacklog.trim(instance) catch (e:Dynamic) {
            feedFailed = true;
            trace("[More Settings] Performance feed limit disabled: " + Std.string(e));
        }
        return Continue;
    }
}
