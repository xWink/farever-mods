package moresettings;

import sys.thread.Thread;

/** Thread gate around the pure timing buffer; background compilation is never touched. */
class StallMetrics {
    public static var enabled(default, null) = false;
    static var metrics:FrameMetrics;
    static var mainThread:Null<Thread>;

    public static function configure(value:Bool):Void {
        if (enabled == value) return;
        enabled = value;
        metrics = value ? new FrameMetrics() : null;
    }
    static inline function onMain():Bool return enabled && mainThread != null && Thread.current() == mainThread;
    public static function beginFrame():Void {
        if (!enabled) return;
        if (mainThread == null) mainThread = Thread.current();
        if (onMain()) metrics.beginFrame();
    }
    public static function context(gameplay:Bool, combat:Bool, optimization:Bool):Void {
        if (onMain()) metrics.context(gameplay, combat, optimization);
    }
    public static function begin(id:Int):Void { if (onMain()) metrics.begin(id); }
    public static function end(id:Int):Void { if (onMain()) metrics.end(id); }
    public static function beginRender():Void { if (onMain()) metrics.beginRender(); }
    public static function endRender():Void { if (onMain()) metrics.endRender(); }
    public static function beginScene():Void { if (onMain()) metrics.beginScene(); }
    public static function sceneMark(name:String):Void { if (onMain()) metrics.sceneMark(name); }
    public static function endScene():Void { if (onMain()) metrics.endScene(); }
    public static function beginDriverFrame():Void { if (onMain()) metrics.beginDriverFrame(); }
    public static function driverStep(expected:Int, next:Int, trim:Bool = false):Void {
        if (onMain()) metrics.driverStep(expected, next, trim);
    }
    public static function endDriverFrame():Void { if (onMain()) metrics.endDriverFrame(); }
    public static function driverRecycleReady():Void { if (onMain()) metrics.driverRecycleReady(); }
    public static function cleanupEvent(id:Int, count:Int = 0):Void { if (onMain()) metrics.cleanupEvent(id, count); }
    public static function cleanupQueue(count:Int, pending:Int):Void { if (onMain()) metrics.cleanupQueue(count, pending); }
    public static function cleanupMemory(free:Float, budget:Float):Void { if (onMain()) metrics.cleanupMemory(free, budget); }
    public static function endFrame():Void {
        if (!onMain()) return;
        metrics.endFrame();
        if (!metrics.canReport()) return;
        // No disk writes, formatting, stack walks or telemetry while in combat.
        try {
            var line = metrics.report();
            if (line != null) trace(line);
        } catch (_:Dynamic) {
            // Diagnostics must never turn an output failure into a game failure.
            enabled = false;
        }
        metrics.reported();
    }
    public static function suspend():Void { if (onMain()) metrics.suspend(); }
}
