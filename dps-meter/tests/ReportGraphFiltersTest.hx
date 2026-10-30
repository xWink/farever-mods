import dpsmeter.ReportGraphFilters;
import dpsmeter.DetailedReport;
import dpsmeter.FightHistory;
import dpsmeter.CombatTimeline;

class ReportGraphFiltersTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    public static function run():Void {
        presets(); uptime(); Sys.println('Report graph presets and uptime: $checks checks passed');
    }
    static function event(seq:Int, kind:String, source:String, target:String, status = ""):TimelineEvent {
        var e = CombatTimeline.event(kind, source, target, "Test"); e.seq = seq; e.time = seq * .1;
        e.statusType = status; e.instance = "instance_" + seq; return e;
    }
    static function presets():Void {
        var events = [event(1,"damage","me","boss"), event(2,"damage","boss","me"), event(3,"damage","ally","boss"),
            event(4,"heal","me","ally"), event(5,"heal","ally","me"),
            event(6,"shield_applied","me","ally"), event(7,"shield_applied","ally","me"),
            event(8,"status_applied","ally","me","buff"), event(9,"status_applied","ally","ally","buff"),
            event(10,"status_applied","me","boss","debuff"), event(11,"status_applied","boss","me","debuff")];
        var data:Dynamic = {me:"me", duration:10., initial:[], events:events};
        var request:HistoryRequest = {id:1, action:"detailed", group:"", page:0, fightId:"test", rangeStart:0, includeGraph:false};
        var cases = [
            {metric:"outgoing", filter:"outgoing", source:"@me", target:"", ids:"1"},
            {metric:"incoming", filter:"incoming", source:"", target:"@me", ids:"2"},
            {metric:"healing", filter:"healing", source:"@me", target:"", ids:"4"},
            {metric:"shield", filter:"shield", source:"@me", target:"", ids:"6"},
            {metric:"buffs", filter:"buffs", source:"", target:"@me", ids:"8"},
            {metric:"debuffs", filter:"debuffs", source:"", target:"", ids:"10,11"}
        ];
        for (c in cases) {
            var preset = ReportGraphFilters.preset(c.metric);
            check(preset.filter == c.filter && preset.source == c.source && preset.target == c.target, "Graph preset matches requested dropdown selections: " + c.metric);
            request.graphMetric = c.metric; request.eventFilter = preset.filter; request.eventSource = preset.source; request.eventTarget = preset.target;
            var response = DetailedReport.query(data, request);
            check([for(e in (cast response.rows:Array<TimelineEvent>)) e.seq].join(",") == c.ids, "Preset produces the matching events: " + c.metric);
        }
        request.graphMetric = "healing"; request.eventFilter = "healing"; request.eventSource = ""; request.eventTarget = "";
        check(DetailedReport.query(data, request).total == 2, "Manual event dropdown changes are preserved after a graph preset");
        request.eventFilter = "outgoing"; request.eventSource = "@me"; data.me = "ally";
        check(DetailedReport.query(data, request).rows[0].seq == 3, "You refers to the recorded player's identity");
        data.me = ""; check(DetailedReport.query(data, request).total == 0, "Missing identity does not silently turn You into All");
        var choices = ReportGraphFilters.choices([{value:"", name:"All sources"}, {value:"me", name:"You"}, {value:"ally", name:"Other"}], "me");
        check(choices.length == 3 && choices[1].value == "@me" && choices[1].name == "You" && choices[2].value == "ally", "Actor choices keep You selected when worker options arrive");
        choices = ReportGraphFilters.choices([{value:"", name:"All targets"}], "me");
        check(choices.length == 2 && choices[1].value == "@me", "You remains selectable even if no events have that actor");
    }
    static function uptime():Void {
        var events:Array<TimelineEvent> = [], seq = 0;
        function span(start:Float, stop:Float, id:String, target = "boss", type = "debuff"):Void {
            var begin = event(++seq,"status_applied","me",target,type); begin.time = start; begin.instance = id; begin.targetName = "Crabgantua";
            var end:TimelineEvent = Reflect.copy(begin); end.seq = ++seq; end.kind = "status_removed"; end.time = stop;
            events.push(begin); events.push(end);
        }
        span(-4, 1, "lead-in"); span(.5, 2, "stack"); span(4, 5, "later"); span(11, 20, "after-fight");
        var data:Dynamic = {me:"me", duration:10., initial:[], events:events};
        var request:HistoryRequest = {id:1, action:"detailed", group:"", page:0, fightId:"test", graphMetric:"debuffs"};
        var result = DetailedReport.query(data, request), lane:Dynamic = result.lanes[0];
        var percent:Float = lane.uptime;
        check(percent == 30 && lane.intervals.length == 2, "Uptime merges overlaps, preserves gaps, and excludes time outside the fight");
        check(DetailedReport.uptimeLabel(lane.target, percent) == "Crabgantua • Uptime: 30%", "Target label matches the requested format");
        events = []; span(-1, 15, "whole-fight", "me", "buff"); span(2, 8, "stack", "me", "buff");
        data.events = events; request.graphMetric = "buffs"; result = DetailedReport.query(data, request);
        percent = result.lanes[0].uptime;
        check(percent == 100 && result.lanes[0].target == "You", "Overlapping buff stacks cannot exceed 100% uptime");
        events = []; span(0, .125, "fraction"); data.events = events; data.duration = 1.; request.graphMetric = "debuffs";
        result = DetailedReport.query(data, request); percent = result.lanes[0].uptime;
        check(percent == 12.5 && DetailedReport.uptimeLabel("Enemy", percent) == "Enemy • Uptime: 12.5%", "Fractional durations remain accurate on native HashLink");
        events = []; span(0, 9, "before-gap"); var gap = event(++seq,"recording_gap","me",""); gap.time = 3; events.push(gap);
        span(6, 8, "after-gap"); data.events = events; data.duration = 10.; result = DetailedReport.query(data, request);
        percent = result.lanes[0].uptime;
        check(percent == 50, "Unknown recording gaps are not counted as active time");
    }
}
