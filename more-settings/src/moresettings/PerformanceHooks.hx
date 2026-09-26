package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;

/** Opt-in fixes for audited client queues and terrain rendering. */
class PerformanceHooks {
    public static var enabled(default, set):Bool = false;
    static var queue = new WorkerQueue();
    static var terrain = new TerrainGlobalsCache();
    static var pacing = new TerrainPacing();
    static var appearances = new AppearanceJobs();
    static var combatText = new CombatTextPool();
    static var app:Dynamic;
    static var pacingFailed:Bool = false;
    static var appearanceFailed:Bool = false;
    static var textFailed:Bool = false;
    static var forwardingDamageAnimation:Bool = false;
    static var queueFailed:Bool = false;
    static var feedFailed:Bool = false;
    static var terrainFailed:Bool = false;

    static function set_enabled(value:Bool):Bool {
        if (!value) { terrain.clear(); pacing.clear(); combatText.clear(); }
        return enabled = value;
    }

    public static function update(instance:Dynamic):Void {
        app = instance;
        // Also closes an unfinished scope if a native update threw last frame.
        pacing.clear();
        try appearances.recoverWorker() catch (e:Dynamic) appearanceError(e);
        if (enabled && !textFailed) try combatText.sweep() catch (e:Dynamic) textError(e);
    }

    public static function dispose():Void {
        app = null; pacing.clear(); terrain.clear(); appearances.dispose(); combatText.clear();
    }

    static function textError(e:Dynamic):Void {
        if (!textFailed) trace("[More Settings] Performance combat-text reuse disabled: " + Std.string(e));
        textFailed = true;
        try combatText.clear() catch (_:Dynamic) {}
    }

    static function schedulingError(e:Dynamic):Void {
        if (!pacingFailed) trace("[More Settings] Performance terrain pacing disabled: " + Std.string(e));
        pacingFailed = true; pacing.clear();
    }

    @:hlx.prefix(world.terrain.Terrain.updateChunkLoad)
    static function beginTerrain(instance:Dynamic, position:Dynamic, context:Dynamic):HlxPrefixResult<Void> {
        if (enabled && !pacingFailed) try {
            var worker = G.staticCall("lib.Workers", "get", []);
            pacing.begin(instance, G.number(G.call("world.terrain.Terrain", "getLoadingBudget", instance)),
                G.field(app, "hero") != null && G.field(worker, "inLoading") == false);
        } catch (e:Dynamic) schedulingError(e);
        return Continue;
    }

    @:hlx.postfix(world.terrain.Terrain.updateChunkLoad)
    static function finishTerrain(instance:Dynamic, position:Dynamic, context:Dynamic, result:Void):Void pacing.clear();

    @:hlx.prefix(world.terrain.Terrain.unloadFarChunks)
    static function beginUnload(instance:Dynamic):HlxPrefixResult<Void> { pacing.unloading(instance, true); return Continue; }

    @:hlx.postfix(world.terrain.Terrain.unloadFarChunks)
    static function endUnload(instance:Dynamic, result:Void):Void pacing.unloading(instance, false);

    @:hlx.prefix(world.terrain.Terrain.removeChunkObject)
    static function removeChunk(instance:Dynamic, chunk:Dynamic):HlxPrefixResult<Void>
        return pacing.deferRemoval(instance) ? Skip : Continue;

    @:hlx.prefix(world.terrain.ChunkObject.updateQuality)
    static function quality(instance:Dynamic, feature:Int, value:Int):HlxPrefixResult<Void> {
        try if (pacing.deferQuality(instance, feature, value)) return Skip catch (e:Dynamic) schedulingError(e);
        return Continue;
    }

    @:hlx.prefix(client.UnitView.clearWeapon)
    static function clearWeapon(instance:Dynamic, slot:Int, index:Int):HlxPrefixResult<Void> {
        // Outstanding jobs must still be invalidated after the toggle is disabled.
        appearances.cancel(instance, slot, index);
        return Continue;
    }

    @:hlx.prefix(client.UnitView.addWeaponAsync)
    static function weapon(instance:Dynamic, path:String, prefab:Dynamic, slot:Int, index:Int):HlxPrefixResult<Void> {
        if (enabled && !appearanceFailed) try {
            if (appearances.schedule(instance, path, prefab, slot, index)) return Skip;
        } catch (e:Dynamic) {
            appearanceError(e);
        }
        return Continue;
    }

    @:hlx.prefix(client.UnitView.checkReady)
    static function ready(instance:Dynamic):HlxPrefixResult<Void>
        return enabled && !appearanceFailed && appearances.deferReady(instance) ? Skip : Continue;

    @:hlx.postfix(lib.Workers.work)
    static function afterWorker(instance:Dynamic, result:Void):Void {
        try appearances.finishWorker() catch (e:Dynamic) appearanceError(e);
    }

    static function appearanceError(e:Dynamic):Void {
        if (!appearanceFailed) trace("[More Settings] Performance appearance scheduling disabled: " + Std.string(e));
        appearanceFailed = true;
    }

    @:hlx.prefix(ui.comp.DamageDisplay.display)
    static function damageDisplay(damage:Dynamic, position:Dynamic):HlxPrefixResult<Dynamic> {
        if (enabled && !textFailed) try {
            var reused = combatText.reuse(damage, position);
            if (reused != null) return SkipWith(reused);
        } catch (e:Dynamic) textError(e);
        return Continue;
    }

    @:hlx.prefix(ui.UIElement.bindUpdate)
    static function damageAnimation(instance:Dynamic, callback:Float->Void):HlxPrefixResult<Void> {
        // HLX uses this declaration as the native receiver signature. bindUpdate
        // takes a closure by value; hl.Ref here corrupts even unrelated UI calls.
        if (forwardingDamageAnimation || !enabled || textFailed || !G.isA(instance, "ui.comp.DamageDisplay")) return Continue;
        var bind:Array<Dynamic>->Dynamic;
        var wrapped:Float->Void;
        try {
            bind = G.bind("ui.UIElement", "bindUpdate");
            wrapped = combatText.capture(instance, callback);
        } catch (e:Dynamic) { textError(e); return Continue; }
        if (wrapped == callback) return Continue;

        // Forward the wrapped closure through the native method once. The
        // guard lets the nested dispatch reach the original implementation.
        forwardingDamageAnimation = true;
        try bind([instance, wrapped]) catch (e:Dynamic) {
            forwardingDamageAnimation = false;
            textError(e);
            // Native bindUpdate can fail after registering its callback. Do not
            // bind it twice; detach this failed visual and let its widget expire.
            try G.call("h2d.Object", "remove", instance) catch (_:Dynamic) {}
            return Skip;
        }
        forwardingDamageAnimation = false;
        return Skip;
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
        appearances.beginWorker();
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
