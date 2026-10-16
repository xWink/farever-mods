import dpsmeter.CombatTimeline;
import dpsmeter.TimelineStore;
import dpsmeter.DetailedReport;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.CombatModel;
import dpsmeter.LogUploader;
import sys.FileSystem;
import sys.io.File;

@:access(dpsmeter.FightHistoryStore)
@:access(dpsmeter.LogUploader)
class TimelineTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function request():HistoryRequest return {id:1, action:"detailed", group:"", page:0, fightId:"fight"};
    static function remove(path:String):Void {
        if (!FileSystem.exists(path)) return;
        if (FileSystem.isDirectory(path)) { for (file in FileSystem.readDirectory(path)) remove(path + "/" + file); FileSystem.deleteDirectory(path); }
        else FileSystem.deleteFile(path);
    }
    static function main():Void {
        var dir = "build/timeline-test-" + Std.random(0x3fffffff); FileSystem.createDirectory(dir);
        var store = new TimelineStore(dir);
        var sizes:Array<Int> = [];
        var trace = new CombatTimeline("session", 100, b -> { sizes.push(b.events.length); store.append(b); });
        trace.append(CombatTimeline.event("recording_started", "me"), 100);
        var buff = CombatTimeline.event("status_applied", "ally", "me", "Chaincast");
        buff.instance = "buff1"; buff.stacks = 2; buff.duration = 30;
        trace.append(buff, 100); trace.flush(101);
        var use = CombatTimeline.event("skill_use", "me", "boss", "GapingWound"); trace.append(use, 109.9);
        var hit = CombatTimeline.event("damage", "me", "boss", "GapingWound"); hit.amount = 100; trace.append(hit, 110);
        var swing = CombatTimeline.event("damage", "me", "boss", "BasicAttack"); swing.amount = 200; trace.append(swing, 110.4);
        // Healing can reconcile later but must retain its original observation position.
        var order = trace.reserve(110.45);
        var tick = CombatTimeline.event("damage", "me", "boss", "GapingWoundTick"); tick.amount = 50; tick.origin = "GapingWound";
        trace.append(tick, 110.5);
        var heal = CombatTimeline.event("heal", "me", "me", "Potion"); heal.seq = order.seq; heal.time = order.time; heal.amount = 80;
        trace.append(heal, 110.8);
        var dodge = CombatTimeline.event("dodge_use", "me", "", "Dash"); trace.append(dodge, 110.5);
        var loss = CombatTimeline.event("health_loss", "", "me"); loss.before = 900; loss.after = 850; loss.amount = 50;
        trace.append(loss, 110.6);
        var shield = CombatTimeline.event("shield_applied", "me", "me", "Barrier"); shield.amount = 200; trace.append(shield, 110.7);
        var end = CombatTimeline.event("status_removed", "ally", "me", "Chaincast"); end.instance = "buff1"; trace.append(end, 111);
        var nextFight = CombatTimeline.event("damage", "me", "nextBoss", "NextFight"); nextFight.amount = 999;
        trace.append(nextFight, 112.1);
        trace.flush(112);
        var rec:Dynamic = {_timeline:trace.span(110, 112, "me")}; store.archive(rec, dir + "/fight.json");
        var data = TimelineStore.read(dir + "/fight.json");
        var events:Array<TimelineEvent> = data.events;
        check(events.length == 9, "All individual actions, ticks, healing and health observations survive archiving");
        check(!Lambda.exists(events, e -> e.skill == "NextFight"), "Events past the finalized end cannot leak in from a new fight");
        check(events[0].kind == "skill_use" && events[0].time < 0, "Pre-impact skill use is retained as lead-in");
        check(events[3].kind == "heal" && events[4].skill == "GapingWoundTick", "Delayed healing retains original ordering");
        check(events[4].time == events[5].time && events[4].seq < events[5].seq, "Sequence resolves equal timestamps");
        var initial:Array<TimelineEvent> = data.initial;
        var statuses = initial.filter(e -> e.kind == "status_present");
        check(statuses.length == 1 && statuses[0].skill == "Chaincast" && statuses[0].stacks == 2, "Initial buffs preserve identity and stacks");
        check(statuses[0].duration == 22, "Initial buff duration accounts for elapsed time");
        var r = request(); r.eventFilter = "outgoing";
        var report = DetailedReport.query(data, r);
        check(report.total == 3, "Damage view includes each direct hit and DoT tick");
        var bins:Array<Float> = report.graph.bins;
        check(bins[0] == 350 && bins[1] == 0, "Damage graph includes zeros and excludes healing, shields and observed HP loss");
        r.graphMetric = "healing"; report = DetailedReport.query(data, r); bins = report.graph.bins;
        check(bins[0] == 80, "Healing graph uses healing output only");
        r.graphMetric = "shield"; report = DetailedReport.query(data, r); bins = report.graph.bins;
        check(bins[0] == 200, "Shielding is graphed independently from healing");
        r.eventSkill = "GapingWound"; report = DetailedReport.query(data, r);
        check(report.total == 2, "Selecting a skill includes its originating DoT effects");
        r.eventSkill = ""; r.eventFilter = ""; r.eventSearch = "potion";
        check(DetailedReport.query(data, r).total == 1, "Search finds a skill without requiring a damage event");
        r.eventSearch = ""; report = DetailedReport.query(data, r);
        var lanes:Array<Dynamic> = report.lanes;
        check(lanes.length == 1 && lanes[0].intervals[0].start == 0 && lanes[0].intervals[0].end == 1,
            "Uptime uses initial state and observed removal");
        var reopened = TimelineStore.read(dir + "/fight.json");
        check(reopened.count == events.length, "Self-contained sidecar reopens without the original process");
        check(TimelineStore.read(dir + "/legacy.json") == null, "Legacy records have explicit unavailable detail");
        check(DetailedReport.timestamp(61.007) == "01:01.007", "Millisecond display is stable");
        check(DetailedReport.timestamp(-.1) == "−00:00.100", "Lead-in timestamps remain negative");
        // Long encounters flush bounded chunks without truncating the event stream.
        for (i in 0...10000) { var e = CombatTimeline.event("damage", "me", "boss", "Tick"); e.amount = 1; trace.append(e, 200 + i * .001); }
        trace.flush(211);
        check(sizes.length > 30, "Large recordings stream multiple batches");
        for (n in sizes) check(n <= CombatTimeline.BATCH_SIZE, "No active batch exceeds the bound");
        var long:Dynamic = {_timeline:trace.span(200, 210, "me")}; store.archive(long, dir + "/long.json");
        var longer = TimelineStore.read(dir + "/long.json");
        check(longer.count == 10000, "Every long-fight tick is retained");
        r = request(); r.page = 500000; report = DetailedReport.query(longer, r);
        check(report.rows.length <= DetailedReport.PAGE_SIZE && report.page == report.pages - 1, "UI response stays bounded and page clamps");
        r.jumpTime = 5; report = DetailedReport.query(longer, r);
        check(report.rows[0].time <= 5 && report.rows[report.rows.length - 1].time >= 5, "Graph jump selects the containing event page");
        store.finish("session");
        check(!FileSystem.exists(dir + "/timeline-spool/session"), "Closed streams release temporary chunks after successful archiving");
        check(TimelineStore.read(dir + "/long.json").count == 10000, "Self-contained reports survive temporary chunk cleanup");
        pairedStorage(dir + "/paired");
        workerOrdering(dir + "/worker");
        gaps();
        presentation();
        tidalTotems();
        remove(dir);
        Sys.println('Detailed timeline: $checks checks passed');
    }
    static function gaps():Void {
        var buff = CombatTimeline.event("status_applied", "ally", "me", "Buff"); buff.instance = "b";
        var stop = CombatTimeline.event("recording_stopped", "me"); stop.time = 2;
        var start = CombatTimeline.event("recording_started", "me"); start.time = 4;
        var hp = CombatTimeline.event("health_loss", "", "me"); hp.after = 200; hp.time = 1;
        var report = DetailedReport.query({me:"me", initial:[], events:[buff, hp, stop, start], duration:6}, request());
        check(report.incomplete == true && report.lanes[0].intervals[0].end == 2,
            "Uptime stops at recording gaps instead of claiming the buff stayed active");
        var r = request(); r.graphMetric = "health"; r.eventSkill = "Buff";
        report = DetailedReport.query({me:"me", initial:[], events:[buff, hp], duration:3}, r);
        check(report.graph.knownHp[0] == false && report.graph.knownHp[1] == true && report.graph.bins[1] == 200,
            "Health graphs distinguish unknown HP from zero and stay independent of skill filtering");
    }
    static function presentation():Void {
        var r = request();
        var buff = CombatTimeline.event("status_applied", "ally", "me", "Barrier");
        buff.seq = 1; buff.instance = "buff"; buff.statusType = "buff";
        var debuff = CombatTimeline.event("status_applied", "me", "boss", "Poison");
        debuff.seq = 2; debuff.instance = "debuff"; debuff.statusType = "debuff";
        var hidden = CombatTimeline.event("status_applied", "me", "boss", "Dose");
        hidden.seq = 3; hidden.instance = "hidden"; hidden.statusType = "debuff"; hidden.hiddenStatus = true;
        var unknown = CombatTimeline.event("status_applied", "me", "boss", "Unknown");
        unknown.seq = 4; unknown.instance = "unknown";
        var data:Dynamic = {me:"me", initial:[], events:[buff, debuff, hidden, unknown], duration:10};
        r.eventFilter = "buffs"; r.graphMetric = "buffs";
        var report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].skill == "Barrier" && report.lanes.length == 1 && report.lanes[0].skill == "Barrier",
            "Buff filter and graph use native classification, not source/target alignment");
        r.eventFilter = "debuffs"; r.graphMetric = "debuffs"; report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].skill == "Poison" && report.lanes.length == 1,
            "Debuffs are separate and hidden dose trackers are excluded");
        check(data.events.length == 4, "Presentation never deletes hidden events from recorded data");
        debuff.statusType = null; hidden.statusType = null; hidden.hiddenStatus = null;
        r.statusMetadata = ["Poison" => {kind:"debuff", hidden:false}, "Dose" => {kind:"debuff", hidden:true}];
        report = DetailedReport.query(data, r);
        check(report.total == 1 && report.lanes.length == 1, "Older recordings use detached native status metadata");
        buff.statusType = "buff"; r.statusMetadata["Barrier"] = {kind:"debuff", hidden:false};
        check(DetailedReport.statusCategory(buff, r.statusMetadata) == "buff", "Recorded classification takes precedence over newer definitions");
        var use = CombatTimeline.event("skill_use", "me", "", "Shot"); use.seq = 10; use.instance = "skill"; use.time = 1;
        var context = CombatTimeline.event("skill_context", "me", "boss", "Shot"); context.seq = 11; context.related = 10; context.time = 1.01; context.targetName = "Boss";
        var end = CombatTimeline.event("skill_end", "me", "boss", "Shot"); end.seq = 12; end.related = 10; end.time = 1.75; end.useDuration = .75;
        data.events = [use, context, end]; r = request(); r.eventFilter = "actions";
        report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].target == "boss" && report.rows[0].targetName == "Boss", "Uses receive the native resolved target without a separate context row");
        check(report.rows[0].useDuration == .75 && report.rows[0].time == 1, "Use duration attaches to the original timestamp");
        check(use.target == "" && use.useDuration == null, "Query enrichment never mutates archived events");
        r.eventFilter = ""; report = DetailedReport.query(data, r);
        check(report.total == 1, "Lifecycle endings do not appear as extra table actions");
        var use2 = CombatTimeline.event("skill_use", "me", "", "Shot"); use2.seq = 13; use2.instance = "skill"; use2.time = 1.5;
        end.related = null; end.instance = "skill"; end.useDuration = null; end.outcome = "Start";
        data.events = [use, use2, end]; report = DetailedReport.query(data, r);
        check(report.rows[0].useDuration == .75 && report.rows[1].useDuration == null, "Older restart endings attach to the previous use");
        var damage = CombatTimeline.event("damage", "boss", "me", "Attack"); damage.amount = 450; damage.hits = 3;
        check(DetailedReport.displayedAmount(damage, "me") == -450, "Incoming damage shows a negative amount, never multiplied by hit index");
        damage.target = "boss"; damage.source = "me";
        check(DetailedReport.displayedAmount(damage, "me") == 450 && damage.amount == 450, "Outgoing values and underlying totals stay positive");
        var charge = CombatTimeline.event("charge_update"); charge.outcome = "Server charge increase; reset/correction cause unavailable";
        check(DetailedReport.outcome(charge) == "Charge increase", "Legacy uncertain-cause text is concise");
        data.events = [for (i in 0...23) { var e = CombatTimeline.event("damage", "me", "boss", "Hit"); e.seq = i + 1; e.time = i; e.amount = i; e; }];
        data.duration = 24; r.eventPageSize = 4;
        var ids:Array<Int> = [];
        for (page in 0...6) {
            r.page = page; report = DetailedReport.query(data, r);
            check(report.rows.length <= 4 && report.pages == 6, "Page requests honor the visible row capacity");
            for (e in (cast report.rows:Array<TimelineEvent>)) ids.push(e.seq);
        }
        check(ids.join(",") == [for (i in 1...24) i].join(","), "Paging omits and duplicates no events");
        r.jumpTime = 17; report = DetailedReport.query(data, r);
        check(report.page == 4 && report.rows[0].seq == 17, "Graph jumping uses the current page capacity");
        for (h in [54, 110, 111, 167, 338, 395, 620, 900]) {
            var n = DetailedReport.pageCapacity(h);
            check(n * DetailedReport.ROW_HEIGHT + (n - 1) * DetailedReport.ROW_GAP <= h, "Only complete rows fit on a page");
        }
        var sample = CombatTimeline.event("health_sample", "", "me"); sample.after = 800;
        var loss = CombatTimeline.event("health_loss", "", "me"); loss.before = 900; loss.after = 800; loss.amount = 100;
        var death = CombatTimeline.event("death", "", "me");
        sample.seq = 1; loss.seq = 2; death.seq = 3;
        data.events = [sample, loss, death]; r = request();
        for (filter in ["", "health"]) {
            r.eventFilter = filter; report = DetailedReport.query(data, r);
            check(report.total == 2 && report.rows[0].kind == "health_loss" && report.rows[1].kind == "death",
                "Internal HP snapshots are hidden without hiding actual health loss or deaths: " + filter);
        }
        check(sample.after == 800 && data.events.length == 3, "Browsing leaves raw health snapshots intact");
        var flask = CombatTimeline.event("heal", "me", "me", "ConsumeFlask");
        flask.skillName = "Pilgrim's Stride"; flask.amount = 500; flask.seq = 17;
        data.events = [flask]; r = request(); r.skillNames = ["ConsumeFlask" => "Hess'tuss Flask"]; r.eventSearch = "hess";
        report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].skillName == "Hess'tuss Flask"
            && report.rows[0].amount == 500 && report.rows[0].seq == 17, "Existing flask recordings display and search under the corrected name");
        check(flask.skillName == "Pilgrim's Stride", "Name corrections never rewrite archived events");
        for (fixture in [{selected:0, first:0, last:2}, {selected:2, first:2, last:4},
            {selected:3, first:3, last:5}, {selected:4, first:3, last:5}, {selected:5, first:3, last:5}]) {
            var range = DetailedReport.expansionRange(6, fixture.selected);
            check(range.first == fixture.first && range.last == fixture.last,
                "Expansion uses available rows below before borrowing space above: " + fixture.selected);
        }
        var bounded = true;
        for (count in 1...17) for (selected in 0...count) {
            var range = DetailedReport.expansionRange(count, selected);
            var visible = [for (i in 0...count) if (i == selected || i < range.first || i > range.last) i];
            var slots = Std.int(Math.min(3, count));
            var card = slots * DetailedReport.ROW_HEIGHT + (slots - 1) * DetailedReport.ROW_GAP;
            var total = card + (visible.length - 1) * (DetailedReport.ROW_HEIGHT + DetailedReport.ROW_GAP);
            if (range.first < 0 || range.last >= count || range.first > selected || range.last < selected
                || visible.length != count - slots + 1 || visible.indexOf(selected) < 0
                || total != count * DetailedReport.ROW_HEIGHT + (count - 1) * DetailedReport.ROW_GAP) bounded = false;
        }
        check(bounded, "Every row expansion preserves its selection and neighbors within the original page height");
        check(DetailedReport.expansionRange(0, -1).first == -1 && DetailedReport.expansionRange(6, -1).first == -1,
            "Empty and collapsed pages have no hidden row range");
        data.events = [for (i in 0...10) {
            var e = CombatTimeline.event("damage", "me", "boss", "Hit"); e.seq = i + 1; e.time = i; e.amount = i; e;
        }];
        r = request(); r.page = 1; r.eventPageSize = 4;
        var full = DetailedReport.query(data, r);
        r.includeGraph = false; report = DetailedReport.query(data, r);
        check(!Reflect.hasField(report, "graph") && !Reflect.hasField(report, "lanes"),
            "Event-only requests omit graph rebuilding and transfer");
        check(haxe.Json.stringify(report.rows) == haxe.Json.stringify(full.rows) && report.total == full.total && report.pages == full.pages,
            "Graph reuse leaves event page content, counts and navigation unchanged");
        r.includeGraph = true; r.graphMetric = "incoming";
        check(DetailedReport.query(data, r).graph.metric == "incoming", "Changing graph selection still requests fresh graph data");
        var consume = CombatTimeline.event("skill_use", "me", "", "ConsumeItem"); consume.seq = 1;
        var context = CombatTimeline.event("skill_context", "me", "", "ConsumeItem"); context.seq = 2; context.related = 1;
        context.item = "SparkCube"; context.itemName = "Spark Cube";
        data.events = [consume, context]; r = request(); r.eventSearch = "spark cube";
        report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].item == "SparkCube" && report.rows[0].itemName == "Spark Cube"
            && report.rows[0].skill == "ConsumeItem", "Item identity resolved at start attaches to the original searchable use");
        check(consume.item == null && DetailedReport.label(cast report.rows[0]) == "ITEM USED", "Item display enrichment retains raw archived data and a distinct action label");
        data.events = [consume]; r.eventSearch = ""; report = DetailedReport.query(data, r);
        check(report.rows[0].item == null, "Older generic item uses never invent a specific consumed item");
    }
    static function tidalTotems():Void {
        function event(seq:Int, target:String, name:String, ?kind:String):TimelineEvent {
            var e = CombatTimeline.event("damage", "me", target, "Hit");
            e.seq = seq; e.time = seq; e.targetName = name; e.targetKind = kind; e.amount = seq * 10;
            return e;
        }
        var events = [event(1, "totem1", "Totem de maree", "Totem_Tidal"),
            event(2, "totem2", "Tidal Totem", "Totem_Tidal"), event(3, "totem3", "Tidal Totem"),
            event(4, "totem4", "Totem_Tidal"), event(5, "totem1", ""),
            event(6, "foe1", "Enemy", "Goblin"), event(7, "foe2", "Enemy", "Goblin"),
            event(8, "otherTotem", "Light Totem", "Totem_Light"), event(9, "impostor", "Tidal Totem", "Goblin")];
        events[4].source = "ally";
        var use = CombatTimeline.event("skill_use", "me", "", "Cast"); use.seq = 10; use.time = 10;
        var context = CombatTimeline.event("skill_context", "me", "totem5", "Cast"); context.seq = 11; context.time = 10.1;
        context.related = 10; context.targetName = "Tidal Totem"; context.targetKind = "Totem_Tidal";
        events.push(use); events.push(context);
        var data:Dynamic = {me:"me", initial:[], events:events, duration:12};
        var original = haxe.Json.stringify(data);
        var r = request(); r.eventPageSize = 16;
        var report = DetailedReport.query(data, r);
        var choices:Array<Dynamic> = report.targets;
        var group = choices.filter(c -> c.value == "@unit:Totem_Tidal");
        check(group.length == 1 && choices.length == 6, "Every Tidal Totem shares one choice; other targets keep separate identities");
        check(!Lambda.exists(choices, c -> ["totem1", "totem2", "totem3", "totem4", "totem5"].indexOf(c.value) >= 0),
            "No individual totem entries remain in the target dropdown");
        check(Lambda.exists(choices, c -> c.value == "foe1" && c.name == "Enemy (1)")
            && Lambda.exists(choices, c -> c.value == "foe2" && c.name == "Enemy (2)"), "Other same-name enemies remain distinct");
        var allGraph = haxe.Json.stringify(report.graph);
        r.eventTarget = group[0].value; report = DetailedReport.query(data, r);
        var rows:Array<TimelineEvent> = report.rows;
        check(report.total == 6 && [for (e in rows) e.seq].join(",") == "1,2,3,4,5,10",
            "The combined target finds all summons, old recordings, unnamed events and resolved skill uses in order");
        check(rows[0].target == "totem1" && rows[1].target == "totem2" && rows[5].targetKind == "Totem_Tidal",
            "Presentation retains original entity IDs and attaches target kind to the skill-use row");
        check(rows[0].amount == 10 && rows[1].amount == 20 && rows[2].amount == 30 && rows[3].amount == 40,
            "Grouping targets neither merges damage events nor changes their values");
        check(haxe.Json.stringify(report.graph) == allGraph, "Target grouping does not change full-fight graph totals");
        r.eventSource = "ally";
        check(DetailedReport.query(data, r).total == 1, "Source filters combine with the grouped target");
        r.eventSource = ""; r.eventSearch = "tidal totem";
        check(DetailedReport.query(data, r).total == 6, "Searching the group name also finds translated and unnamed totem events");
        r.eventSearch = ""; r.eventFilter = "actions";
        check(DetailedReport.query(data, r).total == 1, "Event-category filters still apply to all grouped totems");
        r.eventFilter = ""; r.eventPageSize = 2;
        var paged:Array<Int> = [];
        for (page in 0...3) {
            r.page = page; report = DetailedReport.query(data, r);
            for (e in (cast report.rows:Array<TimelineEvent>)) paged.push(e.seq);
        }
        check(paged.join(",") == "1,2,3,4,5,10", "Paging the combined target loses or duplicates no events");
        check(haxe.Json.stringify(data) == original, "Target grouping never rewrites the saved timeline");

        var initial = event(20, "totem1", "Tidal Totem"); initial.kind = "status_present";
        initial.skill = "Buff"; initial.instance = "one"; initial.time = -1;
        var second:TimelineEvent = Reflect.copy(initial); second.target = "totem2"; second.instance = "two"; second.time = 1;
        var firstEnd:TimelineEvent = Reflect.copy(initial); firstEnd.kind = "status_removed"; firstEnd.time = 2;
        var secondEnd:TimelineEvent = Reflect.copy(second); secondEnd.kind = "status_removed"; secondEnd.time = 3;
        var later:TimelineEvent = Reflect.copy(initial); later.target = "totem3"; later.instance = "three"; later.time = 5;
        var other:TimelineEvent = Reflect.copy(initial); other.target = "foe1"; other.targetName = "Enemy"; other.instance = "other";
        data.initial = [initial, other]; data.events = [second, firstEnd, secondEnd, later]; data.duration = 6;
        r = request(); report = DetailedReport.query(data, r);
        var lanes:Array<Dynamic> = report.lanes;
        var totemLane = lanes.filter(l -> l.target == "Tidal Totem");
        check(lanes.length == 2 && totemLane.length == 1, "Tidal Totems share one status lane while other targets remain separate");
        var spans:Array<Dynamic> = totemLane[0].intervals;
        check(spans.length == 2 && spans[0].start == 0 && spans[0].end == 3 && spans[1].start == 5 && spans[1].end == 6,
            "Grouped status uptime joins overlaps while preserving gaps and each instance's removal");
        data.initial = []; data.events = [event(1, "me", "Tidal Totem"), event(2, "", "Tidal Totem")];
        r.eventTarget = "@none"; report = DetailedReport.query(data, r);
        check(report.total == 1 && report.rows[0].target == "", "No-target events retain their own filter");
        choices = report.targets;
        check(Lambda.exists(choices, c -> c.value == "me" && c.name == "You")
            && !Lambda.exists(choices, c -> c.value == "@unit:Totem_Tidal"), "The player and missing targets cannot be grouped as summons");
    }
    static function pairedStorage(root:String):Void {
        var fail = false;
        var store = new FightHistoryStore(root, _ -> {}, path -> {
            if (fail && StringTools.endsWith(path, ".timeline")) throw "Simulated sidecar recycle failure";
            FileSystem.deleteFile(path);
        });
        var stream = new CombatTimeline("pair", 0, store.timeline.append);
        var event = CombatTimeline.event("damage", "me", "boss", "Strike"); event.amount = 10;
        stream.append(event, 10); stream.flush(12);
        var fight = new Fight(10); fight.last = 12; fight.closed = 12; fight.me = "me";
        fight.bossName = "Test Boss"; fight.category = "World Bosses";
        var record:Dynamic = FightHistory.encode(fight, "pair"); record._timeline = stream.span(10, 12, "me");
        store.save(record);
        var path = store.paths["pair"];
        check(path != null && FileSystem.exists(path + ".timeline"), "Summary and detailed sidecar save together");
        var r = request(); r.fightId = "pair";
        check(store.query(r).record.count == 1, "Detailed history reads its paired timeline");
        r.action = "delete"; fail = true; var rejected = false;
        try store.query(r) catch (_:Dynamic) rejected = true;
        check(rejected && FileSystem.exists(path) && FileSystem.exists(path + ".timeline"),
            "A failed sidecar recycle restores both reports");
        // Simulate a crash between OS recycling and removing the backups.
        File.copy(path, path + ".tmp"); File.copy(path + ".timeline", path + ".timeline.tmp");
        FileSystem.deleteFile(path); FileSystem.deleteFile(path + ".timeline");
        store = new FightHistoryStore(root, _ -> {}, p -> FileSystem.deleteFile(p));
        r.action = "detailed";
        check(store.query(r).record.count == 1, "Restart recovers both summary and detailed deletion backups");
        r.action = "delete"; store.query(r);
        check(!FileSystem.exists(path) && !FileSystem.exists(path + ".timeline"), "Successful deletion recycles both files");
        store = new FightHistoryStore(root, _ -> {});
        r.action = "fights"; r.group = "Test Boss";
        check(store.query(r).total == 0, "Deleted paired reports do not reappear after restart");
    }
    static function workerOrdering(root:String):Void {
        var uploader = new LogUploader(root);
        var storage = new InterleavedTimelineStore(root); uploader.history.timeline = storage;
        var batches:Array<TimelineBatch> = [];
        var stream = new CombatTimeline("interleaved", 0, b -> batches.push(b));
        stream.append(CombatTimeline.event("skill_use", "me", "boss", "First"), 10); stream.flush(10);
        stream.append(CombatTimeline.event("damage", "me", "boss", "Second"), 11); stream.flush(11);
        var fight = new Fight(10); fight.last = 12; fight.closed = 12; fight.me = "me";
        fight.bossName = "Interleaved Boss"; fight.category = "World Bosses";
        var record:Dynamic = FightHistory.encode(fight, "interleaved"); record._timeline = stream.span(10, 12, "me");
        // Deterministically emulate the game thread handing off the last chunk,
        // archive and shutdown while the worker writes an earlier chunk.
        storage.duringAppend = () -> {
            uploader.recordTimeline(batches[1]); uploader.archive(record); uploader.finishTimeline(stream.stream);
        };
        uploader.recordTimeline(batches[0]); uploader.flush(); uploader.flush();
        var r = request(); r.fightId = "interleaved";
        var detail = uploader.history.query(r).record;
        check(detail.count == 2, "Worker interleaving cannot archive before its final queued chunk");
        check(!FileSystem.exists(root + "/timeline-spool/interleaved"), "Completion follows every queued archive before cleanup");
    }
}

private class InterleavedTimelineStore extends TimelineStore {
    public var duringAppend:Void->Void;
    override public function append(batch:TimelineBatch):Void {
        super.append(batch);
        var callback = duringAppend; duringAppend = null;
        if (callback != null) callback();
    }
}
