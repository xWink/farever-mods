package moresettings;

import hlx.runtime.HlxPrefixResult;

/** Opt-in fixes for audited client queues and terrain rendering. */
class PerformanceHooks {
    public static var enabled(default, set):Bool = false;
    static var queue = new WorkerQueue();
    static var terrain = new TerrainGlobalsCache();
    static var queueFailed:Bool = false;
    static var feedFailed:Bool = false;
    static var terrainFailed:Bool = false;

    static function set_enabled(value:Bool):Bool {
        if (!value) terrain.clear();
        return enabled = value;
    }

    static function terrainError(e:Dynamic):Void {
        terrain.clear();
        if (!terrainFailed) trace("[More Settings] Performance terrain reuse disabled: " + Std.string(e));
        terrainFailed = true;
    }

    @:hlx.prefix(world.terrain.Terrain.updateGlobals)
    static function beforeTerrainGlobals(instance:Dynamic, context:Dynamic):HlxPrefixResult<Void> {
        if (enabled && !terrainFailed) try {
            if (terrain.reuse(instance, context)) return Skip;
        } catch (e:Dynamic) terrainError(e);
        return Continue;
    }

    @:hlx.postfix(world.terrain.Terrain.updateGlobals)
    static function afterTerrainGlobals(instance:Dynamic, context:Dynamic, result:Void):Void {
        if (enabled && !terrainFailed)
            try terrain.remember(instance, context) catch (e:Dynamic) terrainError(e);
    }

    @:hlx.prefix(world.terrain.ChunkGround.refresh)
    static function beforeGroundRefresh(instance:Dynamic):HlxPrefixResult<Void> {
        if (enabled && !terrainFailed) terrain.invalidate(moresettings.GameAccess.field(instance, "terrain"));
        return Continue;
    }

    @:hlx.prefix(world.terrain.Terrain.dispose)
    static function beforeTerrainDispose(instance:Dynamic):HlxPrefixResult<Void> {
        terrain.forget(instance);
        return Continue;
    }

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
