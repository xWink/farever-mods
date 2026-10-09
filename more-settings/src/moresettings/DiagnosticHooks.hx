package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;
import moresettings.FrameMetrics as M;

/** Frame/stage boundaries and rare pipeline creation; never per hit, entity update or draw. */
class DiagnosticHooks {
    public static function update(app:Dynamic, optimization:Bool):Void {
        if (!StallMetrics.enabled) return;
        try {
            var hero = G.field(app, "hero");
            var window = G.field(G.field(app, "engine"), "window");
            var gameplay = hero != null && window != null && G.call("GameApp", "get_isLoading", app) == false
                && G.call("hxd.Window", "get_isFocused", window) == true;
            StallMetrics.context(gameplay, G.field(hero, "isInCombat") == true, optimization);
        } catch (_:Dynamic) StallMetrics.context(false, false, optimization);
        StallMetrics.begin(M.UPDATE);
    }

    @:hlx.prefix(hxd.System.mainLoop)
    static function beforeFrame():HlxPrefixResult<Void> { StallMetrics.beginFrame(); return Continue; }
    @:hlx.postfix(hxd.System.mainLoop)
    static function afterFrame(result:Void):Void StallMetrics.endFrame();

    @:hlx.postfix(GameApp.update)
    static function afterUpdate(instance:Dynamic, dt:Float, result:Void):Void StallMetrics.end(M.UPDATE);

    @:hlx.prefix(h3d.Engine.render)
    static function beforeRender(instance:Dynamic, object:Dynamic):HlxPrefixResult<Bool> {
        StallMetrics.beginRender(); return Continue;
    }
    @:hlx.postfix(h3d.Engine.render)
    static function afterRender(instance:Dynamic, object:Dynamic, result:Bool):Bool {
        StallMetrics.endRender(); return result;
    }

    @:hlx.prefix(h3d.scene.Scene.render)
    static function beforeScene(instance:Dynamic, engine:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.beginScene(); return Continue;
    }
    @:hlx.postfix(h3d.scene.Scene.render)
    static function afterScene(instance:Dynamic, engine:Dynamic, result:Void):Void StallMetrics.endScene();

    // Scene.mark is a callback field, not a method. Its default callback forwards
    // to this real client renderer method, including the sync/emit boundaries.
    @:hlx.prefix(client.Renderer.mark)
    static function beforeSceneMark(instance:Dynamic, name:String):HlxPrefixResult<Void> {
        StallMetrics.sceneMark(name); return Continue;
    }
    @:hlx.prefix(h3d.scene.Renderer.process)
    static function beforePasses(instance:Dynamic, passes:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.sceneMark("renderer-setup");
        StallMetrics.begin(M.RENDER_PASSES); return Continue;
    }
    @:hlx.postfix(h3d.scene.Renderer.process)
    static function afterPasses(instance:Dynamic, passes:Dynamic, result:Void):Void {
        StallMetrics.end(M.RENDER_PASSES);
        StallMetrics.sceneMark("scene-tail");
    }

    // A cache-miss-only static method. Do not hook flushPipeline/compileShader:
    // those are hot paths even when every pipeline/shader is already cached.
    // makePipeline returns a native dx_resource, not a Haxe object. Dispatch
    // boxes that handle as Dynamic; rawReturn unwraps it at the generated
    // receiver boundary so DX12 receives the handle rather than the box address.
    // This is required even when diagnostics are disabled or still at startup.
    @:hlx.rawReturn
    @:hlx.prefix(h3d.impl.DX12Driver.makePipeline)
    static function beforePipeline(shader:Dynamic, builder:Dynamic):HlxPrefixResult<Dynamic> {
        StallMetrics.begin(M.PIPELINE_CREATE); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.makePipeline)
    static function afterPipeline(shader:Dynamic, builder:Dynamic, result:Dynamic):Dynamic {
        StallMetrics.end(M.PIPELINE_CREATE); return result;
    }

    @:hlx.prefix(h3d.Engine.begin)
    static function beforeEngineBegin(instance:Dynamic):HlxPrefixResult<Bool> {
        StallMetrics.begin(M.ENGINE_BEGIN); return Continue;
    }
    @:hlx.postfix(h3d.Engine.begin)
    static function afterEngineBegin(instance:Dynamic, result:Bool):Bool {
        StallMetrics.end(M.ENGINE_BEGIN); return result;
    }

    @:hlx.prefix(h3d.Engine.end)
    static function beforeEngineEnd(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.ENGINE_END); return Continue;
    }
    @:hlx.postfix(h3d.Engine.end)
    static function afterEngineEnd(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.ENGINE_END);
    }

    @:hlx.prefix(h2d.Scene.render)
    static function beforeUiRender(instance:Dynamic, engine:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.SCENE_2D); return Continue;
    }
    @:hlx.postfix(h2d.Scene.render)
    static function afterUiRender(instance:Dynamic, engine:Dynamic, result:Void):Void {
        StallMetrics.end(M.SCENE_2D);
    }

    @:hlx.prefix(client.Renderer.beginPbr)
    static function beforePbrBegin(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.PBR_BEGIN); return Continue;
    }
    @:hlx.postfix(client.Renderer.beginPbr)
    static function afterPbrBegin(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.PBR_BEGIN);
    }

    @:hlx.prefix(client.Renderer.endPbr)
    static function beforePbrEnd(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.PBR_END); return Continue;
    }
    @:hlx.postfix(client.Renderer.endPbr)
    static function afterPbrEnd(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.PBR_END);
    }

    @:hlx.prefix(client.Renderer.lighting)
    static function beforeLighting(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.LIGHTING); return Continue;
    }
    @:hlx.postfix(client.Renderer.lighting)
    static function afterLighting(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.LIGHTING);
    }

    @:hlx.prefix(client.Renderer.dlss)
    static function beforeDlss(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.DLSS_RENDER); return Continue;
    }
    @:hlx.postfix(client.Renderer.dlss)
    static function afterDlss(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.DLSS_RENDER);
    }

    @:hlx.prefix(client.Renderer.updateReservedMem)
    static function beforeReservedMemory(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.begin(M.RESERVED_MEMORY); return Continue;
    }
    @:hlx.postfix(client.Renderer.updateReservedMem)
    static function afterReservedMemory(instance:Dynamic, result:Void):Void {
        StallMetrics.end(M.RESERVED_MEMORY);
    }

    @:hlx.prefix(h3d.impl.DX12Driver.present)
    static function beforePresent(instance:Dynamic):HlxPrefixResult<Void> { StallMetrics.begin(M.PRESENT); return Continue; }
    @:hlx.postfix(h3d.impl.DX12Driver.present)
    static function afterPresent(instance:Dynamic, result:Void):Void StallMetrics.end(M.PRESENT);

    // Presentation includes cache serialization/file writes and command/frame
    // preparation as well as the platform Present call. Measure these separately.
    @:hlx.prefix(h3d.impl.DX12Driver.flushFrame)
    static function beforeFlush(instance:Dynamic, reset:hl.Ref<Bool>):HlxPrefixResult<Void> {
        StallMetrics.begin(M.FLUSH_FRAME); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.flushFrame)
    static function afterFlush(instance:Dynamic, reset:hl.Ref<Bool>, result:Void):Void StallMetrics.end(M.FLUSH_FRAME);

    @:hlx.prefix(h3d.impl.PSOConfigCache.save)
    static function beforeCacheSave(instance:Dynamic):HlxPrefixResult<Void> { StallMetrics.begin(M.PIPELINE_SAVE); return Continue; }
    @:hlx.postfix(h3d.impl.PSOConfigCache.save)
    static function afterCacheSave(instance:Dynamic, result:Void):Void StallMetrics.end(M.PIPELINE_SAVE);

    @:hlx.prefix(h3d.impl.DX12Driver.beginFrame)
    static function beforeBeginFrame(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.beginDriverFrame();
        PerformanceHooks.beginResourceFrame(instance);
        return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.beginFrame)
    static function afterBeginFrame(instance:Dynamic, result:Void):Void {
        PerformanceHooks.endResourceFrame(instance);
        StallMetrics.endDriverFrame();
    }

    // Two frame-level boundaries split command reset, buffer reset, resource
    // recycling, query readback and the remaining target/descriptor/DLSS setup.
    // No hooks on per-resource release, per-draw state or allocation hot paths.
    @:hlx.prefix(h3d.impl.BufferAllocator.reset)
    static function beforeBufferReset(instance:Dynamic, trim:hl.Ref<Bool>):HlxPrefixResult<Void> {
        if (StallMetrics.enabled) StallMetrics.driverStep(M.FRAME_SETUP, M.BUFFER_RESET, trim != null && trim.get());
        return Continue;
    }
    @:hlx.postfix(h3d.impl.BufferAllocator.reset)
    static function afterBufferReset(instance:Dynamic, trim:hl.Ref<Bool>, result:Void):Void {
        StallMetrics.driverStep(M.BUFFER_RESET, M.FRAME_RECYCLE);
        PerformanceHooks.recycleResources(instance);
        StallMetrics.driverRecycleReady();
    }
    @:hlx.prefix(h3d.impl.DX12Driver.beginQueries)
    static function beforeQueries(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.driverStep(M.FRAME_RECYCLE, M.FRAME_QUERIES); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.beginQueries)
    static function afterQueries(instance:Dynamic, result:Void):Void {
        StallMetrics.driverStep(M.FRAME_QUERIES, M.FRAME_TAIL);
    }

    @:hlx.prefix(h3d.impl.DX12Driver.refreshDLSSGState)
    static function beforeDLSSState(instance:Dynamic):HlxPrefixResult<Bool> { StallMetrics.begin(M.DLSS_STATE); return Continue; }
    @:hlx.postfix(h3d.impl.DX12Driver.refreshDLSSGState)
    static function afterDLSSState(instance:Dynamic, result:Bool):Bool { StallMetrics.end(M.DLSS_STATE); return result; }

    @:hlx.prefix(h3d.impl.DX12Driver.setDLSSGMode)
    static function beforeDLSSMode(instance:Dynamic, mode:Dynamic, frames:hl.Ref<Int>, force:hl.Ref<Bool>):HlxPrefixResult<Bool> {
        StallMetrics.begin(M.DLSS_MODE); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.setDLSSGMode)
    static function afterDLSSMode(instance:Dynamic, mode:Dynamic, frames:hl.Ref<Int>, force:hl.Ref<Bool>, result:Bool):Bool {
        StallMetrics.end(M.DLSS_MODE); return result;
    }

    // compileShader is also called for cache hits; compileSource only runs when
    // native code needs source loading/compilation for a newly compiled shader.
    @:hlx.prefix(h3d.impl.DX12Driver.compileSource)
    static function beforeSource(instance:Dynamic, shader:Dynamic, model:String, root:String):HlxPrefixResult<Dynamic> {
        StallMetrics.begin(M.SHADER_SOURCE); return Continue;
    }
    @:hlx.postfix(h3d.impl.DX12Driver.compileSource)
    static function afterSource(instance:Dynamic, shader:Dynamic, model:String, root:String, result:Dynamic):Dynamic {
        StallMetrics.end(M.SHADER_SOURCE); return result;
    }

    @:hlx.prefix(h3d.impl.DX12Driver.waitForFrame)
    static function beforeWait(instance:Dynamic, index:Int):HlxPrefixResult<Void> { StallMetrics.begin(M.FRAME_WAIT); return Continue; }
    @:hlx.postfix(h3d.impl.DX12Driver.waitForFrame)
    static function afterWait(instance:Dynamic, index:Int, result:Void):Void StallMetrics.end(M.FRAME_WAIT);

    // garbage is a per-instance callback field, not a hookable method. Time the
    // real texture-cleanup method it calls; this is not HashLink's implicit GC.
    @:hlx.prefix(h3d.impl.MemoryManager.cleanTextures)
    static function beforeCleanup(instance:Dynamic, force:hl.Ref<Bool>):HlxPrefixResult<Bool> {
        StallMetrics.begin(M.GRAPHICS_CLEANUP); return Continue;
    }
    @:hlx.postfix(h3d.impl.MemoryManager.cleanTextures)
    static function afterCleanup(instance:Dynamic, force:hl.Ref<Bool>, result:Bool):Bool {
        StallMetrics.end(M.GRAPHICS_CLEANUP); return result;
    }
}
