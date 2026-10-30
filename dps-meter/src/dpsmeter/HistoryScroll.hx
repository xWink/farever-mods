package dpsmeter;

/** A continuous list with a bounded worker cache and a small pool of visible rows. */
class HistoryScroll {
    public static inline var WINDOW = 128;
    public static inline var PREFETCH = 32;
    public var total = 0;
    public var start = 0;
    public var items:Array<Dynamic> = [];
    public var offset = 0.0;
    public var expanded = -1;
    public final step:Int;
    public final gap:Int;
    public final expansion:Int;
    public function new(step:Int, gap:Int, expansion = 0) {
        this.step = step; this.gap = gap; this.expansion = expansion;
    }
    public function reset(offset = 0.0):Void {
        total = start = 0; items = []; expanded = -1; this.offset = Math.max(0, offset);
    }
    public function accept(start:Int, items:Array<Dynamic>, total:Int):Void {
        this.start = start; this.items = items; this.total = total;
        if (expanded >= total) expanded = -1;
    }
    public function get(index:Int):Dynamic return index < start || index >= start + items.length ? null : items[index - start];
    public function y(index:Int):Float return index * (step * 1.0) + (expanded >= 0 && index > expanded ? expansion : 0);
    public function contentHeight():Float return Math.max(0, total * (step * 1.0) - gap) + (expanded >= 0 ? expansion : 0);
    public function indexAt(y:Float):Int {
        if (expanded >= 0 && y >= (expanded + 1) * step) {
            if (y < (expanded + 1) * step + expansion) return expanded;
            y -= expansion;
        }
        return Std.int(Math.max(0, Math.floor(y / step)));
    }
    public function visible(height:Float):{first:Int, end:Int} return {
        first:Std.int(Math.min(total, Math.max(0, indexAt(offset) - 2))),
        end:Std.int(Math.min(total, indexAt(offset + height) + 3))
    };
    public function needsRead(height:Float):Bool {
        var range = visible(height);
        return range.first < start || range.end > start + items.length;
    }
    public function readStart():Int return Std.int(Math.max(0, indexAt(offset) - PREFETCH));
    public function clamp(height:Float):Float return Math.max(0, Math.min(offset, Math.max(0, contentHeight() - height)));
    public static function bounds(start:Int, count:Null<Int>, total:Int):{start:Int, end:Int} {
        var size = count == null ? WINDOW : Std.int(Math.max(1, Math.min(WINDOW, count)));
        var first = Std.int(Math.max(0, Math.min(start, Math.max(0, total - size))));
        return {start:first, end:Std.int(Math.min(total, first + size))};
    }
}
