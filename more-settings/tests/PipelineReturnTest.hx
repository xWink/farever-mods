import moresettings.DiagnosticHooks;
import moresettings.StallMetrics;
import sys.thread.Lock;
import sys.thread.Thread;

/** Runs the production hook's generated receiver through a native pointer caller. */
class PipelineReturnTest {
    static var checks = 0;
    @:hlNative("pipeline_pointer_test", "create")
    public static function create():hl.Abstract<"dx_resource"> return null;
    @:hlNative("pipeline_pointer_test", "check_return")
    static function checkReturn(receiver:Dynamic, shader:Dynamic, builder:Dynamic, expectNull:Bool):Bool return false;

    // Same broken ABI as the unmarked production hook, retained as a negative control.
    static function boxedReceiver(shader:Dynamic, builder:Dynamic):Dynamic return create();

    static function check(value:Bool, label:String):Void {
        checks++;
        if (!value) throw label;
    }
    static function roundTrip(label:String):Void {
        HlxRuntime.nullResult = false;
        check(checkReturn(HlxRuntime.receiver, HlxRuntime.shader, HlxRuntime.builder, false), label + ": native handle");
        HlxRuntime.nullResult = true;
        check(checkReturn(HlxRuntime.receiver, HlxRuntime.shader, HlxRuntime.builder, true), label + ": null handle");
    }
    static function main():Void {
        // Retain/type the real DiagnosticHooks, without initializing a game or GPU.
        DiagnosticHooks.update(null, false);
        check(HlxRuntime.receiver != null, "production makePipeline receiver registered");
        check(!checkReturn(boxedReceiver, null, null, false), "negative control detects boxed pointer corruption");
        roundTrip("diagnostics disabled at startup");
        StallMetrics.configure(true);
        roundTrip("enabled before first frame");
        StallMetrics.beginFrame();
        StallMetrics.context(true, true, true);
        roundTrip("enabled during gameplay");
        StallMetrics.endFrame();
        var done = new Lock();
        var error:Dynamic = null;
        Thread.create(() -> {
            try roundTrip("background pipeline creation") catch (e:Dynamic) error = e;
            done.release();
        });
        check(done.wait(5), "background test completed");
        if (error != null) throw error;
        StallMetrics.configure(false);
        roundTrip("disabled after gameplay");
        check(HlxRuntime.prefixCalls == 10 && HlxRuntime.postfixCalls == 10, "production prefix and postfix ran for each call");
        Sys.println('Pipeline native return: $checks checks passed.');
    }
}
