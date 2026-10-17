package dpsmeter;

/** Normalized line segments for the report's time buckets; unknown samples leave gaps. */
class ReportGraph {
    public static function lines(bins:Array<Float>, step:Float, end:Float, maximum:Float,
        ?known:Array<Bool>):Array<Array<{x:Float, y:Float}>> {
        var result:Array<Array<{x:Float, y:Float}>> = [];
        if (bins == null || !Math.isFinite(step) || step <= 0 || !Math.isFinite(end) || end <= 0) return result;
        var scale = Math.isFinite(maximum) ? Math.max(1, maximum) : 1;
        var line:Array<{x:Float, y:Float}> = null;
        for (i in 0...bins.length) {
            var start = i * step;
            if (start >= end) break;
            if (!Math.isFinite(bins[i]) || known != null && known[i] != true) { line = null; continue; }
            var stop = Math.min(end, start + step);
            var y = 1 - Math.max(0, Math.min(1, bins[i] / scale));
            if (line == null) {
                line = [{x:start / end, y:y}];
                result.push(line);
            }
            line.push({x:(start + stop) / 2 / end, y:y});
            if (i == bins.length - 1 || stop == end || !Math.isFinite(bins[i + 1])
                || known != null && known[i + 1] != true) {
                // Include the bucket edges, including a single-sample fight.
                line.push({x:stop / end, y:y});
                line = null;
            }
        }
        return result;
    }
}
