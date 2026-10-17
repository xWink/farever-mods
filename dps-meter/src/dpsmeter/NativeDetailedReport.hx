package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;
import dpsmeter.CombatTimeline.TimelineEvent;
import dpsmeter.CombatModel.SkillStats;
import dpsmeter.FightHistory.HistoryRequest;

/** Bounded native rows; filtering and graph calculation stay on the worker. */
class NativeDetailedReport {
    static inline var INK = 0x543f34;
    static inline var MUTED = 0x806c60;
    static inline var GRAPH_Y = 0;
    static inline var GRAPH_H = 206;
    static inline var PLOT_TOP = 74;
    static inline var PLOT_BOTTOM = 182;
    static inline var FILTER_Y = GRAPH_Y + GRAPH_H + 12;
    static inline var LIST_Y = FILTER_Y + 78;
    public var object(default, null):Dynamic;
    public var filter:String = "";
    public var search:String = "";
    public var metric:String = "outgoing";
    var root:Dynamic;
    var filterBox:HistoryDropdown;
    var sourceBox:HistoryDropdown;
    var targetBox:HistoryDropdown;
    public var source:String = "";
    public var target:String = "";
    var metricBox:HistoryDropdown;
    var searchBox:Dynamic;
    var input:Dynamic;
    var searchAt:Float = -1;
    var graphLabel:Dynamic;
    var graphic:Dynamic;
    var graphLine:Dynamic;
    var cursor:Dynamic;
    var graphInput:Dynamic;
    var graphTexts:Array<Dynamic> = [];
    var headingTexts:Array<Dynamic> = [];
    var list:Dynamic;
    var empty:Dynamic;
    var rows:Array<Dynamic> = [];
    var previous:Dynamic;
    var next:Dynamic;
    var pages:Dynamic;
    var laneNext:Dynamic;
    var lanePrevious:Dynamic;
    var laneIcons:Array<Dynamic> = [];
    var statusMetadata:Map<String, {kind:String, hidden:Bool}>;
    var requestedPageSize:Int = 0;
    var showTargets:Bool = true;
    var showAmounts:Bool = true;
    var lanePage:Int = 0;
    var request:(Int, Null<Float>)->Void;
    var data:Dynamic;
    var width:Int = 0;
    var height:Int = 0;
    var tiles:Map<String, Dynamic> = [];
    var layoutPending:Bool = false;
    var fontState:Array<Dynamic> = [];
    var graphFontState:Array<Dynamic> = [];
    var fontCheckAt:Float = 0;

    public function new(parent:Dynamic, request:(Int, Null<Float>)->Void) {
        this.request = request;
        statusMetadata = NativeCombatMetadata.statusCatalog();
        root = node("flow", parent, [], "dpsDetailedReport", "vertical");
        object = G.field(root, "obj"); padding(object, 0);
        // Draw the card before its controls so its fill never tints native buttons.
        graphic = G.create("h2d.Graphics", [object]);
        graphLine = G.create("h2d.Graphics", [object]);
        // Supersample only the plotted line, keeping text and controls crisp.
        // Screen-relative resolution also follows the meter's UI scale.
        var antialias = G.create("h2d.filter.Nothing", []);
        G.set(antialias, "smooth", true); G.set(antialias, "boundsExtend", 1.0);
        G.call("h2d.filter.Filter", "set_useScreenResolution", antialias, [true]);
        G.call("h2d.filter.Filter", "set_resolutionScale", antialias, [4.0]);
        G.call("h2d.Object", "set_filter", graphLine, [antialias]);
        cursor = G.create("h2d.Graphics", [object]);
        graphInput = G.create("h2d.Interactive", [100.0, 102.0, object, null]);
        filterBox = new HistoryDropdown(root, "dpsEventFilter", [
            {value:"", name:"All events"}, {value:"outgoing", name:"Damage dealt"}, {value:"incoming", name:"Damage taken"},
            {value:"actions", name:"Skill used"}, {value:"healing", name:"Healing"}, {value:"shield", name:"Shields"},
            {value:"buffs", name:"Buffs"}, {value:"debuffs", name:"Debuffs"},
            {value:"defense", name:"Dodges / blocks"}, {value:"health", name:"Health / deaths"}], "",
            value -> { filter = value; request(0, null); });
        sourceBox = new HistoryDropdown(root, "dpsEventSource", [{value:"", name:"All sources"}], "",
            value -> { source = value; request(0, null); });
        targetBox = new HistoryDropdown(root, "dpsEventTarget", [{value:"", name:"All targets"}], "",
            value -> { target = value; request(0, null); });
        metricBox = new HistoryDropdown(root, "dpsEventGraph", [
            {value:"outgoing", name:"Damage dealt"}, {value:"incoming", name:"Damage taken"},
            {value:"healing", name:"Healing given"}, {value:"shield", name:"Shields given"},
            {value:"buffs", name:"Buff uptime"}, {value:"debuffs", name:"Debuff uptime"}], metric,
            value -> { metric = value; lanePage = 0; request(0, null); });
        searchBox = G.field(node("input-box", root, [], "dpsEventSearch"), "obj");
        input = G.field(searchBox, "input");
        style(input, "color", 0xf5f0e8);
        G.call("ui.comp.InputBox", "set_hintText", searchBox, ["Search events..."]);
        G.set(searchBox, "onChange", () -> { search = G.text(G.field(input, "text")); searchAt = haxe.Timer.stamp() + .25; });
        graphLabel = makeLabel(root, "", false, MUTED);
        G.set(graphInput, "onPush", (event:Dynamic) -> {
            G.set(event, "propagate", false);
            var time = graphTime(G.number(G.field(event, "relX")));
            if (time != null) request(0, time);
        });
        G.set(graphInput, "onMove", (event:Dynamic) -> hoverGraph(G.number(G.field(event, "relX"))));
        G.set(graphInput, "onOut", (_:Dynamic) -> { G.call("h2d.Graphics", "clear", cursor); graphCaption(); });
        for (name in ["Time", "Event", "Target", "Amount"])
            headingTexts.push(makeLabel(root, name, true, MUTED));
        list = node("flow", root, [], "dpsEventList", "vertical");
        padding(G.field(list, "obj"), 0); flow(list, "set_verticalSpacing", 3); style(G.field(list, "obj"), "vspacing", 3);
        var scroll = G.enumeration("h2d.FlowOverflow", "Limit");
        flow(list, "set_overflow", scroll); style(G.field(list, "obj"), "overflow", scroll);
        for (i in 0...DetailedReport.MAX_PAGE_SIZE) {
            var dom = node("flow", list, [], "dpsEventRow" + i, "vertical");
            var obj = G.field(dom, "obj"); padding(obj, 0);
            var row:Dynamic = {obj:obj, bg:G.create("h2d.Graphics", [obj]), time:makeLabel(dom, "", false, MUTED),
                icon:G.create("h2d.Bitmap", [null, obj]), fallback:makeLabel(dom, "", true), title:makeLabel(dom, "", true),
                subtitle:makeLabel(dom, "", false, MUTED), target:makeLabel(dom, ""), source:makeLabel(dom, "", false, MUTED),
                detail:makeLabel(dom, "", false, MUTED), amount:makeLabel(dom, "", true), toggle:makeLabel(dom, "+", false, MUTED),
                event:null, expanded:false, hovered:false, index:i, click:G.create("h2d.Interactive", [100.0, 54.0, obj, null])};
            G.set(row.click, "onPush", (event:Dynamic) -> {
                G.set(event, "propagate", false);
                var expand = row.expanded != true;
                for (other in rows) other.expanded = false;
                row.expanded = expand; layoutRows();
            });
            G.set(row.click, "onOver", (_:Dynamic) -> { row.hovered = true; rowBackground(row); });
            G.set(row.click, "onOut", (_:Dynamic) -> { row.hovered = false; rowBackground(row); });
            for (c in [row.bg, row.time, row.icon, row.fallback, row.title, row.subtitle, row.target, row.source,
                row.detail, row.amount, row.toggle, row.click]) absolute(obj, c);
            rows.push(row); show(obj, false);
        }
        empty = makeLabel(root, "No events match these filters.", false, MUTED); show(empty, false);
        previous = button(root, "Previous", "dpsEventPrev", () -> { if (data != null) request(Std.int(data.page) - 1, null); });
        next = button(root, "Next", "dpsEventNext", () -> { if (data != null) request(Std.int(data.page) + 1, null); });
        pages = makeLabel(root, "", false, MUTED);
        lanePrevious = button(root, "<", "dpsUptimePrevious", () -> { if (lanePage > 0) { lanePage--; drawGraph(); } });
        laneNext = button(root, ">", "dpsUptimeNext", () -> { lanePage++; drawGraph(); });
        for (i in 0...3) { var icon = G.create("h2d.Bitmap", [null, object]); absolute(object, icon); laneIcons.push(icon); show(icon, false); }
        for (c in [filterBox.object, sourceBox.object, targetBox.object, metricBox.object, searchBox, graphLabel, graphic, graphLine, cursor, graphInput,
            G.field(list, "obj"), empty, previous, next, pages, laneNext, lanePrevious].concat(headingTexts)) absolute(object, c);
        show(object, false);
    }
    static function color(t:Dynamic, value:Int):Void {
        style(t, "color", value);
        var tint = G.field(t, "color");
        if (tint != null) for (channel in ["x", "y", "z"]) G.set(tint, channel, 1.0);
        G.call("h2d.HtmlText", "set_textColor", t, [value]);
    }
    static function makeLabel(parent:Dynamic, value:String, bold:Bool = false, tint:Int = INK):Dynamic {
        var t = label(parent, value);
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", t, [left]); style(t, "text-align", left);
        G.call("ui.comp.FmtText", "set_textMultiline", t, [false]);
        G.call("h2d.Text", "set_lineBreak", t, [false]);
        G.call("ui.comp.FmtText", "set_useEllipsis", t, [false]);
        if (bold) G.call("domkit.Properties", "addClass", G.field(t, "dom"), ["bold-14"]);
        color(t, tint); return t;
    }
    /** Measure native glyphs; fit one line without destructive ellipsis or wrapping. */
    static function fit(t:Dynamic, x:Float, y:Float, w:Float, h:Float, align:String = "left"):Void {
        G.call("ui.comp.FmtText", "set_maxWidthText", t, [null]);
        G.call("h2d.Text", "set_maxWidth", t, [null]);
        G.call("ui.comp.FmtText", "updateScale", t);
        var tw = G.number(G.call("h2d.Text", "get_textWidth", t));
        var th = G.number(G.call("h2d.Text", "get_textHeight", t));
        var scale = Math.min(1, Math.min(Math.max(1, w) / Math.max(1, tw), h / Math.max(1, th)));
        G.call("h2d.Object", "setScale", t, [scale]);
        position(t, x + (align == "right" ? w - tw * scale : align == "center" ? (w - tw * scale) / 2 : 0), y + (h - th * scale) / 2);
    }
    public function configureRequest(r:HistoryRequest):Void {
        r.eventSource = source; r.eventTarget = target;
        r.eventFilter = filter; r.eventSkill = ""; r.eventSearch = search; r.graphMetric = metric;
        r.eventPageSize = capacity(); requestedPageSize = r.eventPageSize; r.statusMetadata = statusMetadata;
        r.skillNames = ["ConsumeFlask" => NativeCombatMetadata.skillName("ConsumeFlask")];
        r.includeGraph = data == null || data.graph == null || G.text(data.graph.metric) != metric;
    }
    public function reset():Void {
        close(); search = ""; source = ""; target = ""; lanePage = 0; data = null;
        sourceBox.setChoices([{value:"", name:"All sources"}], "");
        targetBox.setChoices([{value:"", name:"All targets"}], "");
        G.call("h2d.TextInput", "set_text", input, [""]); searchAt = -1;
    }
    public function visible(value:Bool):Void { show(object, value); if (!value) close(); }
    public function loading():Void {
        setText(pages, "Loading events...");
        fit(pages, 112, height - 28, width - 224, 24, "center");
    }
    public function display(value:Dynamic):Void {
        var newGraph = value.graph != null;
        if (!newGraph && data != null) { value.graph = data.graph; value.lanes = data.lanes; }
        data = value;
        sourceBox.setChoices(cast data.sources, source); targetBox.setChoices(cast data.targets, target);
        setText(pages, "Page " + (data.page + 1) + " of " + data.pages + "  ·  " + data.total + " events");
        show(previous, data.page > 0); show(next, data.page + 1 < data.pages);
        var events:Array<TimelineEvent> = cast data.rows;
        showTargets = Lambda.exists(events, e -> e.target != "");
        showAmounts = Lambda.exists(events, e -> e.amount != null);
        show(empty, events.length == 0);
        for (i in 0...rows.length) {
            var row = rows[i]; row.event = i < events.length ? events[i] : null; row.expanded = false; row.hovered = false;
            show(row.obj, row.event != null);
            if (row.event != null) populate(row);
        }
        flow(list, "set_scrollPosY", 0.0);
        layoutTable();
        if (newGraph) { layoutGraph(); drawGraph(); }
    }
    static function sentence(value:String):String return value == "" ? "" : value.substr(0, 1).toUpperCase() + value.substr(1).toLowerCase();
    function populate(row:Dynamic):Void {
        var e:TimelineEvent = row.event;
        setText(row.time, DetailedReport.timestamp(e.time));
        var name = e.skillName != null && e.skillName != "" ? e.skillName : e.skill;
        var item = e.item == null ? "" : e.item;
        if (item != "") name = e.itemName != null && e.itemName != "" ? e.itemName : NativeCombatMetadata.itemName(item);
        else if (e.skill == "ConsumeItem") name = "Use item";
        if (name == "") name = e.kind == "health_loss" ? "Health change" : sentence(DetailedReport.label(e));
        setText(row.title, name);
        var tags = [sentence(DetailedReport.label(e))];
        if (e.damageType != null && e.damageType != "") tags.push(sentence(e.damageType));
        if (e.stacks != null) tags.push(e.stacks + " stack" + (e.stacks == 1 ? "" : "s"));
        if (e.duration != null && e.duration >= 0) tags.push(SkillStats.rounded(e.duration, 1) + "s");
        if (e.hits != null && e.hits > 1) tags.push("Hit #" + e.hits);
        if (e.lethal == true) tags.push("Lethal");
        setText(row.subtitle, tags.join(" · "));
        color(row.subtitle, e.critical == true ? 0x975919 : MUTED);
        var source = e.source == "" ? "" : e.source == data.me ? "You" : G.text(e.sourceName, "Unknown");
        var target = e.target == "" ? "" : e.target == data.me ? "You" : G.text(e.targetName, "Unknown");
        setText(row.target, target);
        setText(row.source, source == "" ? "" : "From " + source);
        var details:Array<String> = [];
        if (source != "" || target != "") details.push((source == "" ? "Unknown source" : source) + (target == "" ? "" : " → " + target));
        var outcome = DetailedReport.outcome(e);
        if (outcome != "") details.push("Outcome: " + outcome);
        var amount = DetailedReport.displayedAmount(e, data.me);
        if (amount != null) details.push("Amount: " + amount + (e.estimated == true ? " (estimated)" : ""));
        details.push(tags.join(" · "));
        if (e.before != null && e.after != null) details.push("Before / after: " + e.before + " → " + e.after);
        if (e.cause != null && e.cause != "") details.push("Cause: " + e.cause);
        if (e.useDuration != null) details.push("Use duration: " + SkillStats.rounded(e.useDuration, 3) + "s");
        if (e.origin != null && e.origin != "" && e.origin != e.skill) details.push("Origin: " + NativeCombatMetadata.skillName(e.origin));
        if (e.related != null) details.push("Related event: #" + e.related);
        details.push("Event #" + e.seq);
        setText(row.detail, details.join("\n"));
        setText(row.amount, amount == null ? "" : (e.estimated == true ? "≈" : "") + (amount < 0 ? "−" : "") + compact(Math.abs(amount)));
        var tileKey = item == "" ? e.skill : "item:" + item;
        if (!tiles.exists(tileKey)) tiles[tileKey] = item != "" ? NativeCombatMetadata.itemIcon(item)
            : e.skill == "" ? null : NativeCombatMetadata.skillIcon(e.skill);
        var tile = tiles[tileKey];
        if (tile == null && e.origin != null && e.origin != "") {
            if (!tiles.exists(e.origin)) tiles[e.origin] = NativeCombatMetadata.skillIcon(e.origin);
            tile = tiles[e.origin];
        }
        row.tile = tile;
        G.call("h2d.Bitmap", "set_tile", row.icon, [tile]); show(row.icon, tile != null); show(row.fallback, tile == null);
        setText(row.fallback, e.kind == "heal" ? "+" : StringTools.startsWith(e.kind, "proc_") ? "!" : "·");
        if (tile != null) G.call("h2d.Object", "setScale", row.icon, [34 / Math.max(1,
            Math.max(G.number(G.field(tile, "width")), G.number(G.field(tile, "height"))))]);
        color(row.amount, eventColor(e));
    }
    function eventColor(e:TimelineEvent):Int return e.kind == "heal" ? 0x397b50
        : StringTools.startsWith(e.kind, "shield_") ? 0x3d7b98
        : StringTools.startsWith(e.kind, "proc_") ? 0x9c6b1e
        : e.kind == "death" || e.kind == "health_loss" || (e.kind == "damage" && e.target == data.me) ? 0xac4c40
        : e.critical == true ? 0x975919 : e.damageType == "magical" ? 0x765898 : INK;
    public function resize(w:Int, h:Int):Void {
        if (w == width && h == height) return;
        width = w; height = h; layout(); layoutPending = true;
        if (data != null && data.pageSize != capacity() && requestedPageSize != capacity())
            request(Std.int(data.page * data.pageSize / capacity()), null);
    }
    function capacity():Int return height <= 0 ? DetailedReport.PAGE_SIZE : DetailedReport.pageCapacity(height - LIST_Y - 44);
    function layout():Void {
        if (width < 100) return;
        var w = width, h = height; size(object, w, h);
        var filterWidth = Std.int((w - 24) * .25);
        filterBox.resize(filterWidth); position(filterBox.object, 0, FILTER_Y);
        sourceBox.resize(filterWidth); position(sourceBox.object, filterWidth + 8, FILTER_Y);
        targetBox.resize(filterWidth); position(targetBox.object, filterWidth * 2 + 16, FILTER_Y);
        var searchX = filterWidth * 3 + 24;
        padding(searchBox, 0); size(searchBox, w - searchX, 42); position(searchBox, searchX, FILTER_Y);
        style(input, "width", Math.max(40, w - searchX - 24));
        // The native text input and its hint share the dropdowns' 42px row.
        absolute(searchBox, input); position(input, 12, 10);
        var hint = G.field(searchBox, "inputHint");
        if (hint != null) { absolute(searchBox, hint); position(hint, 12, 10); }
        layoutGraph(); layoutTable(); drawGraph();
    }
    function layoutGraph():Void {
        if (width < 100) return;
        var w = width;
        var metricWidth = Std.int(Math.min(284, w * .44));
        metricBox.resize(metricWidth); position(metricBox.object, 12, GRAPH_Y + 8);
        position(graphic, 0, GRAPH_Y); position(graphLine, 0, GRAPH_Y); position(cursor, 0, GRAPH_Y);
        position(graphInput, plotLeft(), GRAPH_Y + PLOT_TOP);
        G.set(graphInput, "width", plotWidth()); G.set(graphInput, "height", PLOT_BOTTOM - PLOT_TOP + 18.0);
        HistoryButtons.singleLine(lanePrevious, 32, 28); position(lanePrevious, w - 84, GRAPH_Y + 12);
        HistoryButtons.singleLine(laneNext, 32, 28); position(laneNext, w - 44, GRAPH_Y + 12);
    }
    function layoutTable():Void {
        if (width < 100) return;
        var w = width, h = height;
        var rw = rowWidth(), target = targetX(), amount = amountX();
        show(headingTexts[2], showTargets); show(headingTexts[3], showAmounts);
        fit(headingTexts[0], 12, LIST_Y - 26, 82, 18);
        fit(headingTexts[1], 100, LIST_Y - 26, titleEnd() - 112, 18);
        fit(headingTexts[2], target, LIST_Y - 26, amount - target - 12, 18);
        fit(headingTexts[3], amount, LIST_Y - 26, rw - amount - 28, 18, "right");
        position(G.field(list, "obj"), 0, LIST_Y); size(G.field(list, "obj"), w, Std.int(Math.max(40, h - LIST_Y - 44)));
        fit(empty, 12, LIST_Y + 22, w - 24, 20, "center");
        HistoryButtons.singleLine(previous, 100, 32); position(previous, 0, h - 32);
        HistoryButtons.singleLine(next, 100, 32); position(next, w - 100, h - 32);
        fit(pages, 112, h - 28, w - 224, 24, "center");
        layoutRows();
    }
    function rowWidth():Int return Std.int(Math.max(100, width));
    function targetX():Int return showTargets ? Std.int(rowWidth() * (showAmounts ? .65 : .72)) : amountX();
    function amountX():Int return rowWidth() - (showAmounts ? 112 : 28);
    function titleEnd():Int return showTargets ? targetX() : amountX();
    function layoutRows():Void {
        var w = rowWidth(), target = targetX(), amount = amountX();
        var selected = -1, count = 0;
        for (i in 0...rows.length) if (rows[i].event != null && i < capacity()) {
            count++; if (rows[i].expanded == true) selected = i;
        }
        var range = DetailedReport.expansionRange(count, selected);
        for (i in 0...rows.length) {
            var r = rows[i];
            var visible = r.event != null && i < capacity() && (selected < 0 || i == selected || i < range.first || i > range.last);
            show(r.obj, visible); if (!visible) continue;
            fit(r.time, 12, 18, 80, 17);
            position(r.icon, 100, 10); fit(r.fallback, 100, 10, 34, 34, "center");
            fit(r.title, 146, 8, titleEnd() - 160, 19);
            fit(r.subtitle, 146, 30, titleEnd() - 160, 15);
            show(r.target, showTargets); show(r.source, showTargets); show(r.amount, showAmounts);
            if (showTargets) {
                fit(r.target, target, 9, amount - target - 14, 18);
                fit(r.source, target, 30, amount - target - 14, 15);
            }
            if (showAmounts) fit(r.amount, amount, 16, w - amount - 28, 22, "right");
            setText(r.toggle, r.expanded == true ? "−" : "+"); fit(r.toggle, w - 21, 18, 14, 17, "center");
            var h = DetailedReport.ROW_HEIGHT;
            show(r.detail, r.expanded == true);
            if (r.expanded == true) {
                // Use the next two rows when possible, then borrow only the
                // missing space from above. Other rows stay visible and in order.
                var slots = Std.int(Math.min(3, capacity()));
                h = slots * DetailedReport.ROW_HEIGHT + (slots - 1) * DetailedReport.ROW_GAP;
                G.call("ui.comp.FmtText", "set_maxWidthText", r.detail, [null]);
                G.call("h2d.Text", "set_lineBreak", r.detail, [true]);
                G.call("h2d.Text", "set_maxWidth", r.detail, [(w - 28) / .9]);
                var textHeight = G.number(G.call("h2d.Text", "get_textHeight", r.detail));
                var scale = Math.min(.9, Math.max(1, h - 76) / Math.max(1, textHeight));
                G.call("h2d.Object", "setScale", r.detail, [scale]); position(r.detail, 14, 64);
            }
            r.rowHeight = h; size(r.obj, w, h); G.set(r.click, "width", w); G.set(r.click, "height", h);
            rowBackground(r);
        }
        flow(list, "set_needReflow", true);
    }
    function rowBackground(r:Dynamic):Void {
        if (r.event == null || r.rowHeight == null) return;
        var g = r.bg, w = rowWidth(), h:Float = r.rowHeight;
        G.call("h2d.Graphics", "clear", g);
        rounded(g, 0xfff6e9, r.expanded == true ? .82 : r.hovered == true ? .72 : r.index % 2 == 0 ? .46 : .26, 0, 0, w, h, 5);
        if (r.tile == null) rounded(g, eventColor(r.event), .12, 100, 10, 34, 34, 5);
        fill(g, 0x8d7260, .14, 10, h - 1, w - 20, 1);
        if (r.expanded == true) fill(g, 0x8d7260, .2, 14, 55, w - 28, 1);
    }
    function graphMetric():String return data == null ? metric : G.text(data.graph.metric, metric);
    function uptime():Bool return graphMetric() == "buffs" || graphMetric() == "debuffs";
    function plotLeft():Int return uptime() ? Std.int(Math.min(330, width * .48)) : 60;
    function plotWidth():Float return Math.max(1, width - plotLeft() - 18);
    function graphTime(x:Float):Null<Float> {
        if (data == null || width < 100) return null;
        return Math.max(0, Math.min(data.graph.end, x / plotWidth() * data.graph.end));
    }
    function graphCaption():Void {
        if (data == null || width < 100) return;
        var mode = graphMetric();
        setText(graphLabel, uptime() ? "Page " + (lanePage + 1) + " of " + lanePages() : data.graph.step + "s buckets · Hover to inspect · Click to jump");
        fitGraphCaption();
    }
    function fitGraphCaption():Void {
        var x = Math.min(284, width * .44) + 26;
        fit(graphLabel, x, GRAPH_Y + 15, width - x - (uptime() ? 96 : 16), 18, "right");
    }
    function hoverGraph(x:Float):Void {
        var time = graphTime(x); if (time == null) return;
        var mode = graphMetric();
        var bins:Array<Float> = cast data.graph.bins;
        var index = Std.int(Math.max(0, Math.min(bins.length - 1, Math.floor(time / data.graph.step))));
        setText(graphLabel, DetailedReport.timestamp(time) + (uptime() ? " · Click to jump" : "  ·  "
            + (mode == "health" && data.graph.knownHp[index] != true ? "Unknown" : compact(bins[index]))
            + (mode == "health" ? " HP" : " / sec") + "  ·  Click to jump"));
        fitGraphCaption();
        G.call("h2d.Graphics", "clear", cursor);
        fill(cursor, 0x614c3e, .5, plotLeft() + Math.max(0, Math.min(plotWidth(), x)), PLOT_TOP, 1, PLOT_BOTTOM - PLOT_TOP);
    }
    static function fill(g:Dynamic, color:Int, alpha:Float, x:Float, y:Float, w:Float, h:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color, alpha]);
        G.call("h2d.Graphics", "drawRect", g, [x,y,w,h]); G.call("h2d.Graphics", "endFill", g);
    }
    static function rounded(g:Dynamic, color:Int, alpha:Float, x:Float, y:Float, w:Float, h:Float, radius:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color, alpha]);
        G.call("h2d.Graphics", "drawRoundedRect", g, [x,y,w,h,radius,null]); G.call("h2d.Graphics", "endFill", g);
    }
    function graphText(index:Int, value:String, x:Float, y:Float, w:Float, align:String = "left", textHeight:Int = 14, tint:Int = MUTED):Void {
        while (graphTexts.length <= index) {
            var t = makeLabel(root, "", false, MUTED); absolute(object, t); graphTexts.push(t);
        }
        var t = graphTexts[index]; setText(t, value); color(t, tint); show(t, true); fit(t, x, y + GRAPH_Y, w, textHeight, align);
    }
    function lanePages():Int return data == null ? 1 : Std.int(Math.max(1, Math.ceil((cast data.lanes:Array<Dynamic>).length / 3)));
    function drawGraph():Void {
        G.call("h2d.Graphics", "clear", graphic); G.call("h2d.Graphics", "clear", cursor);
        G.call("h2d.Graphics", "clear", graphLine);
        for (t in graphTexts) show(t, false);
        show(laneNext, false); show(lanePrevious, false);
        for (icon in laneIcons) show(icon, false);
        if (width < 100) return;
        rounded(graphic, 0x896e5a, .22, 0, 0, width, GRAPH_H, 7);
        rounded(graphic, 0xfff6e9, .72, 1, 1, width - 2, GRAPH_H - 2, 6);
        if (data == null) return;
        var end:Float = data.graph.end, left = plotLeft(), pw = plotWidth();
        var mode = graphMetric();
        graphCaption();
        graphText(20, "0:00", left, PLOT_BOTTOM + 4, 68, "left", 17, INK);
        graphText(21, duration(end), width - 88, PLOT_BOTTOM + 4, 70, "right", 17, INK);
        if (uptime()) {
            var lanes:Array<Dynamic> = cast data.lanes;
            var count = lanePages(); lanePage = Std.int(Math.max(0, Math.min(lanePage, count - 1)));
            var visible = lanes.slice(lanePage * 3, (lanePage + 1) * 3);
            for (i in 0...visible.length) {
                var lane = visible[i]; var y = PLOT_TOP + i * 36;
                if (!tiles.exists(lane.skill)) tiles[lane.skill] = NativeCombatMetadata.skillIcon(lane.skill);
                var tile = tiles[lane.skill], icon = laneIcons[i];
                G.call("h2d.Bitmap", "set_tile", icon, [tile]); show(icon, tile != null);
                if (tile != null) {
                    G.call("h2d.Object", "setScale", icon, [26 / Math.max(1, Math.max(G.number(G.field(tile, "width")), G.number(G.field(tile, "height"))))]);
                    position(icon, 12, GRAPH_Y + y + 4);
                }
                graphText(i * 2, lane.name, 46, y - 1, left - 58, "left", 21, INK);
                graphText(i * 2 + 1, lane.target, 46, y + 20, left - 58, "left", 15, INK);
                rounded(graphic, 0x765b41, .1, left, y + 9, pw, 16, 3);
                for (span in (cast lane.intervals:Array<Dynamic>)) rounded(graphic, mode == "debuffs" ? 0xae6557 : 0x5c885c, .82,
                    left + span.start / end * pw, y + 9,
                    Math.max(1, (span.end - span.start) / end * pw), 16, 2);
            }
            show(lanePrevious, lanePage > 0); show(laneNext, lanePage + 1 < count); graphCaption();
            if (lanes.length == 0) graphText(0, mode == "debuffs" ? "No debuffs recorded" : "No buffs recorded", left, PLOT_TOP + 30, pw, "center", 18);
            return;
        }
        var max:Float = Math.max(1, data.graph.max);
        var bins:Array<Float> = cast data.graph.bins;
        var tint = mode == "healing" ? 0x518565 : mode == "shield" ? 0x4a8eac : mode == "incoming" ? 0xb96352 : mode == "health" ? 0x598866 : 0x80639d;
        for (i in 0...3) {
            var y = PLOT_TOP + i * (PLOT_BOTTOM - PLOT_TOP) / 2;
            fill(graphic, 0x806a58, i == 2 ? .25 : .14, left, y, pw, 1);
            graphText(i, compact(max * (1 - i / 2)), 8, y - 7, left - 18, "right");
        }
        G.call("h2d.Graphics", "lineStyle", graphLine, [2.0, tint, .95]);
        for (line in ReportGraph.lines(bins, data.graph.step, end, max, mode == "health" ? cast data.graph.knownHp : null)) {
            for (i in 0...line.length) {
                var point = line[i];
                G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", graphLine,
                    [left + point.x * pw, PLOT_TOP + point.y * (PLOT_BOTTOM - PLOT_TOP)]);
            }
        }
        G.call("h2d.Graphics", "lineStyle", graphLine, [0.0, tint, 0.0]);
        graphText(22, duration(end / 2), left + pw / 2 - 36, PLOT_BOTTOM + 4, 72, "center", 17, INK);
        if (mode == "health" && data.graph.hasHp != true)
            graphText(4, "No recorded health samples", left, PLOT_TOP + 28, pw, "center");
    }
    public function update(now:Float):Void {
        if (searchAt >= 0 && now >= searchAt) { searchAt = -1; request(0, null); }
        // CSS fonts settle after DOM creation. Refit only when metrics change.
        if (now >= fontCheckAt) {
            fontCheckAt = now + .25;
            var state = currentFonts();
            var changed = state.length != fontState.length;
            for (i in 0...state.length) if (state[i] != fontState[i]) changed = true;
            var graphState = currentGraphFonts();
            var graphChanged = graphState.length != graphFontState.length;
            for (i in 0...graphState.length) if (graphState[i] != graphFontState[i]) graphChanged = true;
            if (layoutPending) { layoutPending = false; layout(); }
            else {
                if (changed) layoutTable();
                if (graphChanged) { layoutGraph(); drawGraph(); }
            }
            fontState = currentFonts(); graphFontState = currentGraphFonts();
        }
        if (G.staticCall("hxd.Key", "isPressed", [0]) != true) return;
        var scene = G.field(G.current("ui.BaseUI", "current"), "s2d");
        if (scene != null) for (c in [filterBox, sourceBox, targetBox, metricBox])
            c.closeOutside(G.number(G.call("h2d.Scene", "get_mouseX", scene)), G.number(G.call("h2d.Scene", "get_mouseY", scene)));
    }
    function currentFonts():Array<Dynamic> {
        var state:Array<Dynamic> = [];
        for (t in [headingTexts[0], rows[0].time, rows[0].title, rows[0].detail]) {
            // Fitted scales change with each row's text. They are layout output,
            // not a CSS font change, and must not trigger graph redraws on paging.
            state.push(G.field(t, "font"));
        }
        return state;
    }
    function currentGraphFonts():Array<Dynamic> {
        var state:Array<Dynamic> = [G.field(graphLabel, "font")];
        for (t in graphTexts) state.push(G.field(t, "font"));
        return state;
    }
    public function closeOpen():Bool {
        var found = false;
        for (c in [filterBox, sourceBox, targetBox, metricBox]) if (c.isOpen()) { c.close(); found = true; }
        return found;
    }
    public function close():Void { closeOpen(); searchAt = -1; }
}
