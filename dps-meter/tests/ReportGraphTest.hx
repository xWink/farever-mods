import dpsmeter.ReportGraph;

class ReportGraphTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void {
        checks++;
        if (!ok) throw message;
    }
    static function main():Void {
        var lines = ReportGraph.lines([0., 100., 50.], 1, 2.5, 100);
        check(lines.length == 1 && lines[0].length == 5, "Rates form a connected line with domain endpoints");
        var p = lines[0];
        check(p[0].x == 0 && p[0].y == 1 && p[1].x == .2, "Zero values stay on the baseline");
        check(p[2].x == .6 && p[2].y == 0, "Peak uses the real bucket time and graph maximum");
        check(p[3].x == .9 && p[3].y == .5 && p[4].x == 1, "Partial final bucket keeps correct time spacing");
        lines = ReportGraph.lines([12.], 1, .25, 12);
        check(lines[0][0].x == 0 && lines[0][2].x == 1, "A single bucket draws a visible horizontal line");
        lines = ReportGraph.lines([0., 25., 0., 75.], 1, 4, 100, [false, true, false, true]);
        check(lines.length == 2, "Unknown health gaps are not joined or treated as zero");
        check(lines[0][0].x == .25 && lines[0][2].x == .5 && lines[1][0].x == .75, "Known health spans end at their bucket boundaries");
        check(ReportGraph.lines([0.], 1, 1, 0)[0][1].y == 1, "An empty damage bucket avoids division by zero");
        check(ReportGraph.lines([], 1, 1, 1).length == 0, "Empty series draw no line");
        check(ReportGraph.lines([1.], 1, 1, 1, [false]).length == 0, "Fully unknown health draws no line");
        check(ReportGraph.lines([1.], 0, 1, 1).length == 0, "Invalid bucket widths draw no line");
        lines = ReportGraph.lines([-10., 200.], 1, 2, 100);
        check(lines[0][1].y == 1 && lines[0][2].y == 0, "Values stay within plot bounds");
        Sys.println('Report line graph: ' + checks + ' checks passed.');
    }
}
