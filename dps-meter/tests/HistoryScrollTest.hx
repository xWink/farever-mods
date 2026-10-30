import dpsmeter.HistoryScroll;
import dpsmeter.FightHistory;
#if !hl
import dpsmeter.FightHistoryStore;
#end
import dpsmeter.DetailedReport;
import dpsmeter.CombatTimeline;

#if !hl
@:access(HistoryTest)
#end
class HistoryScrollTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        viewport(); events();
        // Archive IO runs in the interpreter suite; the isolated native runner
        // has no fmt module (used by the archive's legacy-ID digest).
        #if !hl
        history();
        #end
        Sys.println('Continuous history and events: $checks checks passed');
    }
    static function viewport():Void {
        var scroll = new HistoryScroll(57, 3, 114), total = 100000;
        scroll.accept(0, [for (i in 0...128) i], total);
        for (index in [0, 20, 125, 50000, 99999, 250, 1]) {
            scroll.offset = index * 57.0;
            scroll.offset = scroll.clamp(400);
            var range = scroll.visible(400);
            check(range.end - range.first <= 13, "Visible card count stays bounded in a 100,000-event log");
            if (scroll.needsRead(400)) {
                var next = HistoryScroll.bounds(scroll.readStart(), HistoryScroll.WINDOW, total);
                scroll.accept(next.start, [for (i in next.start...next.end) i], total);
            }
            check(!scroll.needsRead(400), "One bounded read fills the viewport after a distant thumb drag");
            for (i in range.first...range.end) check(scroll.get(i) == i, "Scrolling in either direction cannot lose or duplicate rows");
        }
        scroll.expanded = 250;
        check(scroll.y(251) == 251 * 57 + 114 && scroll.y(250) == 250 * 57, "Expansion pushes later events down without hiding them");
        check(scroll.indexAt(scroll.y(250) + 130) == 250 && scroll.indexAt(scroll.y(251)) == 251, "Hit range includes the expanded event's whole card");
        scroll.offset = scroll.y(250) + 100;
        check(scroll.visible(300).first <= 250 && scroll.visible(300).end > 251, "Scrolling through expanded details preserves surrounding events");
        scroll.reset(); check(scroll.total == 0 && scroll.offset == 0 && scroll.expanded == -1 && scroll.items.length == 0, "Filters reset rows, scroll, and expansion together");
        check(scroll.get(-1) == null && scroll.get(0) == null, "An empty cache is safe on native HashLink");
        for (count in [-1, 0, 1, 64, 999999]) {
            var range = HistoryScroll.bounds(-50, count, 500);
            check(range.start == 0 && range.end >= 1 && range.end <= HistoryScroll.WINDOW, "Worker range sizes are always bounded");
        }
        var tail = HistoryScroll.bounds(999999, 128, 300);
        check(tail.start == 172 && tail.end == 300, "Deleting the last item can clamp a saved position to a full final window");
        check(HistoryScroll.bounds(10, 128, 0).end == 0, "An empty list has an empty worker range");
    }
    #if !hl
    static function history():Void {
        var root = HistoryTest.temp("continuous"), store = new FightHistoryStore(root, _ -> {});
        store.initialize();
        for (i in 0...300) {
            var fight = HistoryTest.sample(); fight.startedAt += i * 1000; fight.outcome = i % 2 == 0 ? "Victory" : "Defeat";
            store.save(FightHistory.encode(fight, "scroll_" + i));
        }
        var request = HistoryTest.request("fights", "The Guardian");
        request.rangeCount = 50; request.sortBy = "date"; request.ascending = false;
        var ids:Array<String> = [];
        for (start in [0, 50, 100, 150, 200, 250]) {
            request.rangeStart = start; var response = store.query(request);
            check(response.rangeStart == start && response.total == 300 && response.entries.length == 50, "History ranges share the full sorted result count");
            for (entry in response.entries) ids.push(entry.id);
        }
        check(ids.join(",") == [for (i in 0...300) "scroll_" + (299 - i)].join(","), "Continuous newest-first history contains every attempt exactly once");
        request.rangeStart = 999999; request.outcome = "Victory"; request.ascending = true;
        var filtered = store.query(request);
        check(filtered.total == 150 && filtered.rangeStart == 100 && filtered.entries[0].id == "scroll_200", "Filtering and sorting happen before a restored scroll range is clamped");
        check(filtered.entries.filter(e -> e.outcome != "Victory").length == 0, "No previous-filter entries leak into the new window");
        var groups = HistoryTest.request("groups"); groups.rangeStart = 0; groups.rangeCount = 128;
        check(store.query(groups).groups.length == 1, "Encounter folders support the same continuous range API");
        HistoryTest.remove(root);
    }
    #end
    static function events():Void {
        var events = [for (i in 0...500) {
            var e = CombatTimeline.event("damage", "me", "boss", i % 2 == 0 ? "Strike" : "Fireball");
            e.time = i * .1; e.seq = i + 1; e.amount = i; e;
        }];
        events.reverse();
        var data:Dynamic = {me:"me", duration:50., initial:[], events:events};
        var request:HistoryRequest = {id:1, action:"detailed", group:"", page:0, fightId:"test", rangeStart:0, rangeCount:50, includeGraph:false};
        var sequence:Array<Int> = [];
        for (start in [0, 50, 100, 150, 200, 250, 300, 350, 400, 450]) {
            request.rangeStart = start; var response = DetailedReport.query(data, request);
            check(response.total == 500 && response.rows.length == 50 && response.graph == null, "Scroll reads remain bounded and reuse the graph");
            for (event in (cast response.rows:Array<TimelineEvent>)) sequence.push(event.seq);
        }
        check(sequence.join(",") == [for (i in 1...501) i].join(","), "Events remain chronological across every window boundary");
        request.jumpTime = 37.5; var jumped = DetailedReport.query(data, request);
        check(jumped.jumpIndex == 375 && jumped.rangeStart <= 375 && jumped.rangeStart + jumped.rows.length > 375, "Graph clicks fetch a window containing the exact jump event");
        request.jumpTime = null; request.eventSearch = "Fireball"; request.rangeStart = 999999;
        var filtered = DetailedReport.query(data, request);
        check(filtered.total == 250 && filtered.rows.length == 50 && filtered.rangeStart == 200, "Search resets the scroll range against filtered events");
        for (event in (cast filtered.rows:Array<TimelineEvent>)) check(event.skill == "Fireball", "Scrolling retains search constraints");
        request.eventSearch = "nothing-matches"; request.jumpTime = 50;
        var empty = DetailedReport.query(data, request);
        check(empty.total == 0 && empty.rows.length == 0 && empty.rangeStart == 0, "Jumping in an empty filter is safe");
    }
}
