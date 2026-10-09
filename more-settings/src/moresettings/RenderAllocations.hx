package moresettings;

/** Process-wide HL allocation deltas across outer Engine.render calls.
    These counters are NOT GC duration/count or GPU memory measurements. */
class RenderAllocations {
    public var samples(default, null) = 0;
    public var bytes(default, null):Float = 0;
    public var allocations(default, null):Float = 0;
    public var heapBytes(default, null):Float = 0;
    var started = false;
    var firstBytes:Float = 0;
    var firstCount:Float = 0;
    public function new() {}
    public function reset():Void { samples = 0; bytes = allocations = heapBytes = 0; started = false; }
    public function sample(begin:Bool, total:Float, count:Float, memory:Float):Void {
        if (begin) { firstBytes = total; firstCount = count; started = true; return; }
        if (!started) return;
        started = false;
        // Ignore a reset/unavailable counter instead of manufacturing a delta.
        if (total < firstBytes || count < firstCount || memory < 0) return;
        bytes += total - firstBytes; allocations += count - firstCount;
        heapBytes = memory; samples++;
    }
    public function read(begin:Bool):Void {
        #if hl
        var total = 0.0, count = 0.0, memory = 0.0;
        // Direct native counters avoid the object allocated by hl.Gc.stats().
        stats(total, count, memory);
        sample(begin, total, count, memory);
        #end
    }
    #if hl
    @:hlNative("std", "gc_stats")
    static function stats(total:hl.Ref<Float>, count:hl.Ref<Float>, memory:hl.Ref<Float>):Void {}
    #end
    public function copyFrom(other:RenderAllocations):Void {
        reset(); samples = other.samples; bytes = other.bytes;
        allocations = other.allocations; heapBytes = other.heapBytes;
    }
    public function describe():String {
        if (samples == 0) return "render-alloc={samples=0 allocated-KiB=unknown allocations=unknown heap-MiB=unknown}";
        return 'render-alloc={samples=$samples allocated-KiB=${Math.round(bytes / 1024)}'
            + ' allocations=$allocations heap-MiB=${Math.round(heapBytes / 1048576)}}';
    }
}
