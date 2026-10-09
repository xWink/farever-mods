import hlx.runtime.PatchTargetKey;
import hlx.runtime.HlxPrefixResult;

/** Test dispatch boundary; hook discovery and diagnostic contributors are real. */
class HlxRuntime {
    public static var receiver:Dynamic;
    static var prefix:Dynamic;
    static var postfix:Dynamic;
    public static var shader:Dynamic = {id: "shader"};
    public static var builder:Dynamic = {id: "builder"};
    public static var nullResult = false;
    public static var prefixCalls = 0;
    public static var postfixCalls = 0;

    public static function registerPrefix(key:PatchTargetKey, callback:Dynamic, generated:Dynamic):Void {
        if (key.toString() != "h3d.impl.DX12Driver.makePipeline") return;
        prefix = callback; receiver = generated;
    }
    public static function registerPostfix(key:PatchTargetKey, callback:Dynamic, generated:Dynamic):Void {
        if (key.toString() != "h3d.impl.DX12Driver.makePipeline") return;
        postfix = callback; receiver = generated;
    }
    public static function dispatch(key:PatchTargetKey, args:Array<Dynamic>):Dynamic {
        if (key.toString() != "h3d.impl.DX12Driver.makePipeline" || args.length != 2
            || args[0] != shader || args[1] != builder) throw "pipeline arguments changed";
        var decision:HlxPrefixResult<Dynamic> = Reflect.callMethod(null, prefix, args);
        if (decision != Continue) throw "pipeline creation was skipped";
        prefixCalls++;
        // Like hl_dyn_call, the original native Abstract is boxed for dispatch.
        var result:Dynamic = nullResult ? null : PipelineReturnTest.create();
        args.push(result);
        var returned = Reflect.callMethod(null, postfix, args);
        if (returned != result) throw "postfix changed the pipeline handle";
        postfixCalls++;
        return returned;
    }
    // Same operation as HLX's std.hlx_unbox_ptr, provided by the test fixture.
    @:hlNative("pipeline_pointer_test", "unbox")
    public static function unboxPointer(value:Dynamic):hl.Bytes return null;
}
