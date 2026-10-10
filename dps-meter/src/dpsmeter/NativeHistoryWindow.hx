package dpsmeter;

import dpsmeter.CombatModel.Fight;
import dpsmeter.RiftTracker.RiftRecap;
import dpsmeter.FightHistory;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;
import dpsmeter.MeterConfig.MeterSettings;

/** One native browser: categories -> encounter names -> attempts -> damage chart. */
class NativeHistoryWindow {
    public static var constructing:Bool = false;
    var requested:Bool = false;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var content:Dynamic;
    var frame:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var panel:Dynamic;
    var back:Dynamic;
    var heading:Dynamic;
    var headingStyle:Dynamic;
    var detail:Dynamic;
    var chartInfo:Dynamic;
    var options:NativeHistoryOptions;
    var list:Dynamic;
    var chartPanel:Dynamic;
    var chart:NativeDamageChart;
    var recapView:NativeRiftRecapCharts;
    var recap:Null<RiftRecap>;
    var empty:Dynamic;
    var previous:Dynamic;
    var next:Dynamic;
    var pageLabel:Dynamic;
    var footer:Dynamic;
    var folderButton:Dynamic;
    var deleteButton:Dynamic;
    var snapshotButton:Dynamic;
    var modeButton:MeterModeButton;
    var healing:Bool = false;
    var actionStatus:Dynamic;
    var selectedEntry:HistoryEntry;
    var deleting:Bool = false;
    var copying:Bool = false;
    var rows:Array<Dynamic> = [];
    var writer:RunWriter;
    var serial:Int = 0;
    var pending:Bool = false;
    var mode:String = "categories";
    var category:String = "";
    var catalog:HistoryCatalog;
    var logsPath:String;
    var headingFont:Dynamic;
    var headingBaseScale:Float = 1;
    var group:String = "";
    var groupsPage:Int = 0;
    var fightsPage:Int = 0;
    var page:Int = 0;
    var total:Int = 0;
    var fight:Fight;
    var width:Int = 0;
    var height:Int = 0;
    var lastRefresh:Float = -1;
    var config:MeterSettings;
    var dragSurface:Dynamic;
    var dragging:Bool = false;
    var startMouseX:Float = 0;
    var startMouseY:Float = 0;
    var startX:Float = 0;
    var startY:Float = 0;

    public function new(config:MeterSettings) { this.config = config; }
    public function open():Void { requested = true; }
    public function toggle():Void {
        if (requested || (window != null && G.field(window, "removed") != true && G.field(window, "parent") != null)) dispose();
        else open();
    }
    public function update(writer:RunWriter, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (!active || ui == null) { dispose(); return; }
        if (owner != null && (owner != ui || this.writer != writer)) dispose();
        if (window != null && (G.field(window, "removed") == true || !chartBodyIntact(body, container))) dispose();
        this.writer = writer;
        if (requested) {
            requested = false;
            if (window == null) {
                catalog = NativeCombatMetadata.catalog();
                logsPath = RunWriter.historyPath();
                build(ui); navigate("categories", "", 0);
            }
        }
        if (window == null) return;
        if (mode == "fights") options.update();
        var response = writer.receiveHistory();
        while (response != null) {
            if (response.id == serial) display(response);
            response = writer.receiveHistory();
        }
        updateDrag();
        layout();
        if (mode == "chart" && !pending) {
            if (recap != null) recapView.update(now);
            else if (fight != null) chart.update(fight, now);
        }
        if (now - lastRefresh >= 0.20) {
            lastRefresh = now;
            alignLabels();
        }
    }
    function navigate(mode:String, group:String, page:Int, ?entry:HistoryEntry):Void {
        recap = null; recapView.setRecap(null); show(recapView.object, false);
        this.mode = mode; this.group = group; this.page = page;
        selectedEntry = entry; deleting = false;
        status(""); show(deleteButton, false); show(snapshotButton, false); show(modeButton.object, false);
        setText(title, "Fight History" + (category == "" ? "" : " · " + category));
        fight = null; pending = true; total = 0; serial++;
        if (mode == "groups") groupsPage = page;
        if (mode == "fights") fightsPage = page;
        for (row in rows) show(row.obj, false);
        show(G.field(list, "obj"), false); show(G.field(chartPanel, "obj"), false);
        setText(empty, "Loading fight history..."); show(empty, true);
        G.call("h2d.Text", "set_text", heading, [headingText()]);
        show(detail, false);
        options.setVisible(mode == "fights");
        G.call("h2d.Text", "set_text", chartInfo, [mode == "chart" ? FightHistory.chartDetail(entry) : ""]);
        show(chartInfo, mode == "chart");
        show(footer, mode == "categories"); show(folderButton, mode == "categories");
        show(back, mode != "categories");
        show(previous, false); show(next, false); show(pageLabel, false);
        // Literal text keeps Windows paths containing brackets or other markup
        // characters intact. The whole path scales to fit instead of ellipsizing.
        G.call("h2d.Text", "set_text", footer, [logsPath]);
        writer.requestHistory({id: serial, action: mode, group: group, page: page, fightId: entry == null ? "" : entry.id,
            category: category, catalog: mode == "categories" ? catalog : null,
            sortBy: options.sortBy, ascending: options.ascending, character: options.characterKey, outcome: options.outcomeKey});
        width = 0; // Navigation changes the amount of space above the list.
        lastRefresh = -1;
    }
    function goBack():Void {
        if (mode == "chart") navigate("fights", group, fightsPage);
        else if (mode == "fights") navigate("groups", "", groupsPage);
        else { category = ""; navigate("categories", "", 0); }
    }
    function headingText():String return mode == "categories" ? "Choose a category" : mode == "groups" ? "Choose an encounter" : group;
    function display(response:HistoryResponse):Void {
        pending = false; total = response.total; page = response.page;
        if (deleting) {
            deleting = false;
            if (response.error != "") {
                status(response.error, true);
                show(deleteButton, mode == "chart"); show(snapshotButton, mode == "chart"); show(modeButton.object, mode == "chart");
                for (row in rows) show(row.deleteButton, mode == "fights" && row.entry != null);
            } else navigate("fights", group, fightsPage);
            return;
        }
        if (response.error != "") { setText(empty, response.error); show(empty, true); return; }
        if (mode == "chart") {
            try {
                if (RiftRecapHistory.isRecap(response.record)) {
                    recap = RiftRecapHistory.decode(response.record);
                    recapView.setRecap(recap);
                    G.call("h2d.Text", "set_text", chartInfo, [FightHistory.recapDetail(recap)]);
                    show(recapView.object, true);
                } else {
                    fight = FightHistory.decode(response.record);
                    show(G.field(chartPanel, "obj"), true);
                }
            } catch (e:Dynamic) {
                setText(empty, "This fight log could not be read. Choose another fight using Back.");
                show(empty, true);
                trace("[DPS Meter] Could not read chart: " + Std.string(e));
                return;
            }
            show(empty, false);
            width = 0;
            show(deleteButton, true); show(snapshotButton, true); show(modeButton.object, true);
            refreshChartDetail();
        } else {
            if (mode == "fights") options.setCharacters(response.characters);
            var names = mode == "groups" || mode == "categories";
            if (mode == "groups") groupsPage = page; else if (mode == "fights") fightsPage = page;
            var count = names ? response.groups.length : response.entries.length;
            for (i in 0...rows.length) {
                var row = rows[i]; show(row.obj, i < count);
                if (i >= count) continue;
                row.entry = mode == "fights" ? response.entries[i] : null;
                show(row.deleteButton, row.entry != null);
                row.group = names ? response.groups[i].name : "";
                var parts = names ? {before: response.groups[i].name, player: "", after: ""}
                    : FightHistory.attemptHeadingParts(row.entry);
                row.caption = parts.before; row.playerCaption = parts.player; row.suffixCaption = parts.after;
                row.description = names ? response.groups[i].count + (response.groups[i].count == 1 ? " fight" : " fights")
                    : FightHistory.attemptDetail(row.entry);
                setText(row.name, row.caption); setText(row.player, row.playerCaption); setText(row.suffix, row.suffixCaption);
                setText(row.detail, row.description);
                show(row.player, parts.player != ""); show(row.suffix, parts.after != "");
                if (!names) colorPlayerName(row, row.entry.playerClass == "" ? 0x5b4334 : classColor(row.entry.playerClass));
                row.width = 0; // Different name lengths change the inline positions.
            }
            show(G.field(list, "obj"), count > 0); show(empty, count == 0);
            setText(empty, mode == "fights" && (options.characterKey != "" || options.outcomeKey != "")
                ? "No fights match these filters." : "No fights recorded in this category yet.");
            G.set(G.field(list, "obj"), "scrollPosY", 0.0);
            flow(list, "set_needReflow", true);
            show(previous, page > 0); show(next, (page + 1) * FightHistory.PAGE_SIZE < total);
            show(pageLabel, total > 0 && mode != "categories");
            setText(pageLabel, "Page " + (page + 1) + " of " + Std.int(Math.max(1, Math.ceil(total / FightHistory.PAGE_SIZE))));
        }
        lastRefresh = -1;
    }
    function openFolder():Void {
        try { DesktopActions.openFolder(logsPath); status(""); }
        catch (error:Dynamic) status(Std.string(error), true);
    }
    function deleteLog():Void {
        if (fight != null || recap != null) deleteEntry(selectedEntry);
    }
    function deleteEntry(entry:HistoryEntry):Void {
        if (pending || copying || entry == null) return;
        pending = true; deleting = true; serial++;
        show(deleteButton, false); show(snapshotButton, false); show(modeButton.object, false);
        for (row in rows) show(row.deleteButton, false);
        status("Moving log to the Recycle Bin...");
        writer.requestHistory({id: serial, action: "delete", group: group, page: fightsPage, fightId: entry.id});
    }
    function copySnapshot():Void {
        if (pending || copying || (fight == null && recap == null) || selectedEntry == null) return;
        copying = true;
        var scrolls = recap != null ? recapView.snapshotScrolls() : [chart.snapshotScroll()];
        var message = "Snapshot copied to clipboard.";
        var failed = false;
        try {
            show(actionStatus, false);
            layout(true);
            refreshSnapshotChart(true);
            if (recap != null) recapView.restoreScrolls([0, 0]); else chart.restoreScroll(0);
            NativeFightSnapshot.copyBody(window, width, height,
                [header, back, snapshotButton, modeButton.object, deleteButton, folderButton, previous, next, pageLabel, actionStatus]);
        } catch (error:Dynamic) {
            message = Std.string(error); failed = true;
            trace("[DPS Meter] Snapshot: " + Std.string(error));
        }
        try {
            layout(); refreshSnapshotChart();
            if (recap != null) recapView.restoreScrolls(scrolls); else chart.restoreScroll(scrolls[0]);
        } catch (error:Dynamic) {
            message = Std.string(error); failed = true;
            trace("[DPS Meter] Restore history after snapshot: " + message);
        }
        copying = false;
        status(message, failed);
    }
    public function toggleMode():Void setHealing(!healing);
    function setHealing(value:Bool):Void {
        if (copying) return;
        healing = value;
        if (modeButton != null) modeButton.setHealing(value);
        if (chart != null) chart.setHealing(value);
        if (recapView != null) recapView.setHealing(value);
        if (chart != null && chartInfo != null) refreshChartDetail();
    }
    function refreshChartDetail():Void {
        var value = recap != null ? (healing ? HealingDisplay.recapDetail(recap) : FightHistory.recapDetail(recap))
            : healing ? HealingDisplay.detail(selectedEntry, fight, chart.selection()) : FightHistory.chartDetail(selectedEntry, chart.selection());
        G.call("h2d.Text", "set_text", chartInfo, [value]);
        lastRefresh = -1;
    }
    function refreshSnapshotChart(snapshot:Bool = false):Void {
        NativeFightSnapshot.reflow(window);
        if (recap != null) recapView.update(haxe.Timer.stamp());
        else chart.update(fight, haxe.Timer.stamp());
        NativeFightSnapshot.reflow(window);
        alignLabels(snapshot);
    }
    function status(message:String, error:Bool = false):Void {
        if (actionStatus == null) return;
        G.call("h2d.Text", "set_text", actionStatus, [message]);
        G.call("h2d.Text", "set_textColor", actionStatus, [error ? 0x982c24 : 0x526b31]);
        show(actionStatus, message != ""); lastRefresh = -1;
    }
    function build(ui:Dynamic):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        // GameUI.shouldFreeCursor checks registered windows for FreeCursor.
        // Register history itself so removing a dropdown cannot relock the
        // mouse. Keep PreventCloseOther (8192) to coexist with other windows.
        var freeCursor = G.enumeration("ui.win.WindowFlags", "FreeCursor");
        if (freeCursor == null) throw "The history window's cursor flag is unavailable.";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192 | (1 << Type.enumIndex(freeCursor))]);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        // BaseUIRoot is a Flow, while displayWindow's optional parent requires
        // a UIElement. Attach first, then register with no parent override.
        G.call("ui.BaseUI", "displayWindow", ui, [window, null]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        content = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) { frame = child; absolute(window, frame); break; }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Fight History");
        title = G.field(header, "headerTitle"); setText(title, "Fight History");
        show(title, true); absolute(header, title);
        close = G.field(header, "closeBtn"); show(close, true); absolute(header, close);
        G.call("ui.UIElement", "set_onClick", close, [() -> dispose()]);
        dragSurface = G.create("h2d.Interactive", [100.0, 60.0, header, null]);
        absolute(header, dragSurface);
        G.set(dragSurface, "onPush", (event:Dynamic) -> beginDrag(event));
        G.set(dragSurface, "cursor", G.enumeration("hxd.Cursor", "Move"));
        body = node("options-content", dom, [0], "dpsHistoryBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        panel = node("flow", G.field(container, "dom"), [], "dpsHistoryPanel", "vertical");
        for (object in [window, frame, content, header, bodyObject, options, container, G.field(panel, "obj")]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(window, header); absolute(window, content); absolute(content, bodyObject);
        absolute(bodyObject, options); absolute(options, container); absolute(container, G.field(panel, "obj"));
        back = button(panel, "Back", "dpsHistoryBack", goBack);
        folderButton = HistoryButtons.folder(panel, openFolder);
        snapshotButton = HistoryButtons.snapshot(panel, copySnapshot);
        modeButton = new MeterModeButton(panel, "dpsHistoryMode", setHealing, healing);
        deleteButton = button(panel, "Delete log", "dpsHistoryDelete", deleteLog);
        HistoryButtons.red(deleteButton);
        detail = label(panel, ""); empty = label(panel, "");
        this.options = new NativeHistoryOptions(panel, () -> {
            if (mode == "fights") navigate("fights", group, 0);
        });
        chartInfo = G.create("h2d.Text", [G.field(detail, "font"), G.field(panel, "obj")]);
        G.call("h2d.Text", "set_textColor", chartInfo, [0x5b4334]);
        G.call("h2d.Text", "set_lineBreak", chartInfo, [false]);
        headingStyle = label(panel, "");
        G.call("domkit.Properties", "addClass", G.field(headingStyle, "dom"), ["bold-14"]);
        show(headingStyle, false);
        heading = G.create("h2d.Text", [G.field(detail, "font"), G.field(panel, "obj")]);
        G.call("h2d.Text", "set_textColor", heading, [0x8A5F46]);
        G.call("h2d.Text", "set_lineBreak", heading, [false]);
        list = node("flow", panel, [], "dpsHistoryList", "vertical");
        padding(G.field(list, "obj"), 0); flow(list, "set_verticalSpacing", 8); style(G.field(list, "obj"), "vspacing", 8);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        flow(list, "set_overflow", scroll); style(G.field(list, "obj"), "overflow", scroll);
        for (i in 0...FightHistory.PAGE_SIZE) makeRow(i);
        chartPanel = node("flow", panel, [], "dpsHistoryChart", "vertical");
        padding(G.field(chartPanel, "obj"), 0);
        chart = new NativeDamageChart(chartPanel, "dpsHistoryRows", "No damage recorded");
        chart.setHealing(healing);
        chart.onSelectionChanged = player -> refreshChartDetail();
        recapView = new NativeRiftRecapCharts(panel, "dpsHistoryRecap");
        recapView.setHealing(healing);
        show(recapView.object, false);
        previous = button(panel, "Previous", "dpsHistoryPrevious", () -> navigate(mode, group, page - 1));
        next = button(panel, "Next", "dpsHistoryNext", () -> navigate(mode, group, page + 1));
        pageLabel = label(panel, "");
        footer = G.create("h2d.Text", [G.field(detail, "font"), G.field(panel, "obj")]);
        G.call("h2d.Text", "set_textColor", footer, [0x5b4334]);
        G.call("h2d.Text", "set_lineBreak", footer, [false]);
        actionStatus = G.create("h2d.Text", [G.field(detail, "font"), G.field(panel, "obj")]);
        G.call("h2d.Text", "set_lineBreak", actionStatus, [false]);
        show(actionStatus, false);
        for (object in [back, heading, detail, chartInfo, empty, G.field(list, "obj"), G.field(chartPanel, "obj"), recapView.object, previous, next, pageLabel, footer,
            folderButton, snapshotButton, modeButton.object, deleteButton, actionStatus])
            absolute(G.field(panel, "obj"), object);
        for (text in [title, detail, empty, pageLabel]) {
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]); style(text, "text-align", left);
            G.call("ui.comp.FmtText", "set_useEllipsis", text, [true]);
        }
        width = 0; height = 0; layout();
    }
    function makeRow(i:Int):Void {
        var row:Dynamic = {obj: null, name: null, player: null, suffix: null, detail: null, deleteButton: null, entry: null, group: "",
            caption: "", playerCaption: "", suffixCaption: "", playerColor: -1, description: "", width: 0};
        row.obj = button(list, "", "dpsHistoryEntry" + i, () -> {
            if (pending) return;
            if (mode == "categories") { category = row.group; navigate("groups", "", 0); }
            else if (row.entry != null) navigate("chart", group, page, row.entry);
            else navigate("fights", row.group, 0);
        });
        padding(row.obj, 0);
        row.name = label(G.field(row.obj, "dom"), "");
        row.player = label(G.field(row.obj, "dom"), "");
        row.suffix = label(G.field(row.obj, "dom"), "");
        row.detail = label(G.field(row.obj, "dom"), "");
        for (text in [row.name, row.player, row.suffix, row.detail]) {
            absolute(row.obj, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]); style(text, "text-align", left);
            G.call("ui.comp.FmtText", "set_useEllipsis", text, [true]);
        }
        row.deleteButton = button(G.field(row.obj, "dom"), "Delete log", "dpsHistoryEntryDelete" + i, () -> deleteEntry(row.entry));
        HistoryButtons.red(row.deleteButton);
        // Share native hover tracking with the row while keeping button
        // presses/releases local to Delete log.
        G.set(row.deleteButton, "propagateOver", true);
        style(row.deleteButton, "propagate-over", true);
        absolute(row.obj, row.deleteButton);
        show(row.deleteButton, false);
        rows.push(row);
    }
    static function colorPlayerName(row:Dynamic, value:Int):Void {
        if (row.playerColor == value) return;
        row.playerColor = value;
        // Keep class colour local to the name. Date/party/outcome retain their
        // existing native styles. Pin CSS to prevent hover recolouring.
        style(row.player, "color", value);
        var tint = G.field(row.player, "color");
        if (tint != null) for (channel in ["x", "y", "z"]) G.set(tint, channel, 1.0);
        G.call("h2d.HtmlText", "set_textColor", row.player, [value]);
    }
    function layout(snapshot:Bool = false):Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.max(300, Math.min(940, bottom.x - top.x - 40)));
        var h = Std.int(Math.max(320, Math.min(820, bottom.y - top.y - 60)));
        if (snapshot) {
            h = SnapshotLayout.historyHeight(recap != null ? recapView.snapshotHeight() : chart.snapshotHeight(), h);
            SnapshotLayout.imageSize(w, h);
        }
        if (copying || w != width || h != height) {
            width = w; height = h;
            size(window, w, h); if (frame != null) { size(frame, w, h); position(frame, 0, 0); }
            size(header, w - 2, 60); position(header, 0, 0);
            size(close, 36, 36); position(close, w - 52, 12);
            G.set(dragSurface, "width", Math.max(1, w - 72));
            position(dragSurface, 8, 0);
            var contentTop = snapshot ? 8 : 60;
            var contentHeight = h - contentTop - 8;
            var inner = w - 48; var bodyHeight = contentHeight - 8;
            size(content, w - 16, contentHeight); position(content, 8, contentTop);
            for (object in wrappers) { size(object, w - 16, contentHeight); position(object, 0, 0); }
            size(G.field(panel, "obj"), inner, bodyHeight); position(G.field(panel, "obj"), 16, 8);
            size(back, 84, 34); position(back, 0, 8);
            size(snapshotButton, HistoryButtons.SNAPSHOT_SIZE, HistoryButtons.SNAPSHOT_SIZE);
            position(snapshotButton, inner - HistoryButtons.SNAPSHOT_SIZE, 7);
            modeButton.resize(HistoryButtons.SNAPSHOT_SIZE);
            position(modeButton.object, inner - HistoryButtons.SNAPSHOT_SIZE - 42, 7);
            size(deleteButton, 138, 34); position(deleteButton, inner - 138, bodyHeight - 50);
            G.call("h2d.Text", "set_text", heading, [headingText()]);
            position(heading, mode == "categories" ? 0 : 100, 0);
            G.call("ui.comp.FmtText", "set_maxWidthText", detail, [inner]); position(detail, 0, 60);
            position(chartInfo, 0, 60);
            var optionsBottom = this.options.layout(inner);
            var topInset = mode == "categories" || mode == "groups" ? 66 : mode == "fights" ? optionsBottom : 100;
            G.call("ui.comp.FmtText", "set_maxWidthText", empty, [inner]); position(empty, 0, topInset);
            // Only the category page reserves a folder row. Other pages need
            // room for their existing Delete or pagination controls alone.
            var footerSpace = snapshot ? 0 : mode == "chart" ? 68 : mode == "categories" ? 96 : 88;
            var chartHeight = Std.int(Math.max(30, bodyHeight - topInset - footerSpace));
            for (object in [G.field(list, "obj"), G.field(chartPanel, "obj")]) { size(object, inner, chartHeight); position(object, 0, topInset); }
            chart.resize(inner, chartHeight);
            recapView.resize(inner, chartHeight, snapshot && recap != null);
            position(recapView.object, 0, topInset);
            size(previous, 108, 34); position(previous, 0, bodyHeight - 70);
            size(next, 108, 34); position(next, inner - 108, bodyHeight - 70);
            G.call("ui.comp.FmtText", "set_maxWidthText", pageLabel, [Std.int(Math.max(1, inner - 236))]);
            G.call("ui.comp.FmtText", "set_maxWidthText", title, [w - 112]);
            lastRefresh = -1;
        }
        show(dragSurface, config.unlocked && !copying);
        var x = config.historyX == null ? top.x + (bottom.x - top.x - width) / 2 : config.historyX;
        var y = config.historyY == null ? top.y + (bottom.y - top.y - height) / 2 : config.historyY;
        if (!snapshot) {
            x = Math.max(top.x, Math.min(x, Math.max(top.x, bottom.x - width)));
            y = Math.max(top.y, Math.min(y, Math.max(top.y, bottom.y - height)));
        }
        position(window, x, y);
    }
    function beginDrag(event:Dynamic):Void {
        if (!config.unlocked || copying || G.integer(G.field(event, "button")) != 0) return;
        G.set(event, "propagate", false);
        if (options != null) options.closeOpen();
        var point = mouse(); startMouseX = point.x; startMouseY = point.y;
        startX = G.number(G.field(window, "x")); startY = G.number(G.field(window, "y"));
        dragging = true;
        G.call("h2d.Interactive", "startDrag", dragSurface, [(e:Dynamic) -> {
            G.set(e, "propagate", false);
            var kind = Type.enumConstructor(G.field(e, "kind"));
            if (kind == "ERelease" || kind == "EReleaseOutside") finishDrag();
        }, () -> finishDrag()]);
    }
    function mouse():{x:Float, y:Float} {
        var scene = G.field(owner, "s2d");
        return localPoint(G.number(G.call("h2d.Scene", "get_mouseX", scene)), G.number(G.call("h2d.Scene", "get_mouseY", scene)));
    }
    function updateDrag():Void {
        if (!dragging) return;
        if (!config.unlocked || G.staticCall("hxd.Key", "isDown", [0]) != true) { finishDrag(); return; }
        var point = mouse();
        config.historyX = startX + point.x - startMouseX;
        config.historyY = startY + point.y - startMouseY;
    }
    function finishDrag():Void {
        if (!dragging) return;
        dragging = false;
        // Save the clamped, displayed position, rather than an off-screen drag.
        config.historyX = G.number(G.field(window, "x"));
        config.historyY = G.number(G.field(window, "y"));
        if (dragSurface != null) G.call("h2d.Interactive", "stopDrag", dragSurface);
        DpsMeterMod.saveConfig();
    }
    function alignLabels(snapshot:Bool = false):Void {
        if (recap != null) recapView.alignLabels();
        G.call("ui.comp.FmtText", "updateScale", headingStyle);
        var font = G.field(headingStyle, "font");
        if (font != null && font != headingFont) { headingFont = font; G.call("h2d.Text", "set_font", heading, [font]); }
        headingBaseScale = G.number(G.field(headingStyle, "scaleX"), 1);
        var headingLeft = snapshot || mode == "categories" ? 0 : 100;
        var headingRight = !snapshot && mode == "chart" ? HistoryButtons.SNAPSHOT_SIZE + 54 : 0;
        fitLiteral(heading, width - 48 - headingLeft - headingRight, headingBaseScale * 1.75);
        position(heading, headingLeft, 8 + (34 - textHeight(heading)) / 2);
        G.call("ui.comp.FmtText", "updateScale", detail);
        var bodyFont = G.field(detail, "font");
        for (text in [footer, chartInfo, actionStatus]) if (bodyFont != null && G.field(text, "font") != bodyFont)
            G.call("h2d.Text", "set_font", text, [bodyFont]);
        var bodyScale = G.number(G.field(detail, "scaleX"), 1);
        fitLiteral(chartInfo, width - 48, bodyScale);
        if (mode == "categories") {
            fitLiteral(footer, width - 48 - 44, bodyScale);
            var folderY = height - 76 - 50;
            size(folderButton, 34, 30); position(folderButton, 0, folderY);
            position(footer, 44, folderY + (30 - textHeight(footer)) / 2);
        }
        fitLiteral(actionStatus, width - 48 - (mode == "chart" ? 152 : 0), bodyScale);
        position(actionStatus, 0, height - 76 - (mode == "chart" ? 33 : mode == "categories" ? 70 : 17) - textHeight(actionStatus) / 2);
        position(title, (width - textWidth(title)) / 2, (60 - textHeight(title)) / 2);
        position(pageLabel, (width - 48 - textWidth(pageLabel)) / 2, height - 76 - 53 - textHeight(pageLabel) / 2);
        var inner = G.integer(G.call("h2d.Flow", "get_innerWidth", G.field(list, "obj")), width - 48);
        var scrollbar = G.field(G.field(list, "obj"), "scrollBar");
        if (scrollbar != null && G.field(scrollbar, "visible") == true)
            inner -= G.integer(G.call("h2d.Flow", "get_outerWidth", scrollbar)) + 4;
        for (row in rows) {
            if (row.width == inner) continue;
            row.width = inner;
            size(row.obj, Std.int(Math.max(1, inner)), 66);
            var deleteWidth = 138;
            size(row.deleteButton, deleteWidth, 34);
            position(row.deleteButton, inner - 12 - deleteWidth, (66 - 34) / 2);
            var textSpace = inner - 24 - (row.entry == null ? 0 : deleteWidth + 12);
            // Measure each segment with the game's font, so the name is inline
            // and only the end of the heading ellipsizes at smaller widths.
            var used = 0.0;
            for (segment in [{object: row.name, caption: row.caption}, {object: row.player, caption: row.playerCaption},
                {object: row.suffix, caption: row.suffixCaption}]) {
                var available = textSpace - used;
                show(segment.object, segment.caption != "" && available > 0);
                if (segment.caption == "" || available <= 0) continue;
                G.call("ui.comp.FmtText", "set_maxWidthText", segment.object, [Std.int(Math.max(1, available))]);
                setText(segment.object, segment.caption);
                position(segment.object, 12 + used, 7);
                used += textWidth(segment.object);
            }
            G.call("ui.comp.FmtText", "set_maxWidthText", row.detail, [Std.int(Math.max(1, textSpace))]);
            setText(row.detail, row.description); position(row.detail, 12, 35);
        }
    }
    static function fitLiteral(text:Dynamic, available:Float, desiredScale:Float):Void {
        var natural = G.number(G.call("h2d.Text", "get_textWidth", text));
        var scale = natural <= 0 ? desiredScale : Math.min(desiredScale, Math.max(1, available) / natural);
        G.call("h2d.Object", "setScale", text, [scale]);
    }
    static function textWidth(text:Dynamic):Float {
        G.call("ui.comp.FmtText", "updateScale", text);
        return G.number(G.call("h2d.Text", "get_textWidth", text)) * G.number(G.field(text, "scaleX"), 1);
    }
    static function textHeight(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }
    public function closeFromEscape(ui:Dynamic):Bool {
        if (window == null || owner != ui || G.field(window, "removed") == true || G.field(window, "parent") == null) return false;
        if (options != null && options.closeOpen()) return true;
        dispose();
        return true;
    }
    public function dispose():Void {
        finishDrag();
        dragSurface = null;
        if (options != null) { options.close(); options = null; }
        requested = false; serial++;
        selectedEntry = null; deleting = false; copying = false;
        if (window != null) {
            var old = window; window = null;
            // Unregister from its actual owner, including when BaseUI.current
            // already changed during a disconnect or character switch.
            if (owner != null) G.call("ui.BaseUI", "removeWindow", owner, [old]);
            else G.call("h2d.Object", "remove", old);
        }
        owner = null; rows = []; wrappers = []; frame = null; body = null; container = null;
        chart = null; fight = null; recapView = null; recap = null; modeButton = null; width = 0; height = 0;
        mode = "categories"; category = ""; group = ""; page = 0; groupsPage = 0; fightsPage = 0;
        headingFont = null; catalog = null;
    }
}
