package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.RiftTracker.RiftRecap;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One dismissible native window containing both finalized rift charts. */
class NativeRiftRecapWindow {
    static inline var HEADER_HEIGHT = 60;
    public static var constructing:Bool = false;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var snapshotButton:Dynamic;
    var modeButton:MeterModeButton;
    var healing:Bool = false;
    var copying:Bool = false;
    var statusUntil:Float = 0;
    var body:Dynamic;
    var container:Dynamic;
    var recapHeading:Dynamic;
    var recapInfo:Dynamic;
    var headingStyle:Dynamic;
    var summaryStyle:Dynamic;
    var snapshotLayout:Bool = false;
    var displayedRecap:Null<RiftRecap>;
    var wrappers:Array<Dynamic> = [];
    var charts:NativeRiftRecapCharts;
    var width:Int = 0;
    var height:Int = 0;
    var retryAt:Float = 0;

    public function new() {}
    public function toggleMode():Void setHealing(!healing);
    function setHealing(value:Bool):Void {
        if (copying) return;
        healing = value;
        if (modeButton != null) modeButton.setHealing(value);
        if (charts != null) charts.setHealing(value);
        if (recapInfo != null && displayedRecap != null)
            G.call("h2d.Text", "set_text", recapInfo, [value ? HealingDisplay.recapDetail(displayedRecap) : FightHistory.recapDetail(displayedRecap)]);
    }

    public function update(model:CombatModel, enabled:Bool, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!enabled) { model.recaps = []; dispose(); return; }
        if (!active || ui == null) { dispose(); return; }
        if (window != null && !chartBodyIntact(body, container)) {
            // Retry the same finalized UI snapshot; completed combat reports
            // and uploads are separate and must not be queued again.
            if (model.recaps.length == 0 && displayedRecap != null)
                model.recaps.push(displayedRecap);
            dispose();
        }
        if (model.recaps.length > 0 && now >= retryAt) {
            dispose();
            try {
                build(ui, model.recaps[model.recaps.length - 1]);
                displayedRecap = model.recaps[model.recaps.length - 1];
                model.recaps = [];
            } catch (_:Dynamic) {
                constructing = false; dispose(); retryAt = now + 10;
                return;
            }
        }
        refresh(now);
    }

    function refresh(now:Float):Void {
        if (window == null) return;
        if (statusUntil > 0 && now >= statusUntil) {
            setText(title, "Rift Recap");
            statusUntil = 0;
        }
        layout();
        charts.update(now);
        alignLabels();
    }

    function build(ui:Dynamic, result:RiftRecap):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        // Place the recap above the game UI without pausing or closing menus.
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        windowContent = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            frameBackground = child;
            absolute(window, frameBackground);
            break;
        }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Rift Recap");
        title = G.field(header, "headerTitle");
        setText(title, "Rift Recap");
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]);
        style(title, "text-align", left);
        show(title, true);
        absolute(header, title);
        close = G.field(header, "closeBtn");
        show(close, true);
        absolute(header, close);
        // This HUD is outside BaseUI.windows; remove it directly with the native X.
        G.call("ui.UIElement", "set_onClick", close, [() -> dispose()]);
        snapshotButton = HistoryButtons.snapshot(G.field(header, "dom"), copySnapshot, "dpsRiftRecapSnapshot");
        absolute(header, snapshotButton);
        modeButton = new MeterModeButton(G.field(header, "dom"), "dpsRiftRecapMode", setHealing, healing);
        absolute(header, modeButton.object);

        body = node("options-content", dom, [0], "dpsRiftRecapBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        for (object in [window, frameBackground, windowContent, header, bodyObject, options, container]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]);
            style(object, "overflow", limit);
        }
        absolute(window, header);
        absolute(window, windowContent);
        absolute(windowContent, bodyObject);
        absolute(bodyObject, options);
        absolute(options, container);
        buildSummary(result);
        charts = new NativeRiftRecapCharts(G.field(container, "dom"), "dpsRiftCharts");
        absolute(container, charts.object);
        charts.setRecap(result);
        charts.setHealing(healing);
        layout();
    }

    function buildSummary(result:RiftRecap):Void {
        var dom = G.field(container, "dom");
        // Match history's native body font and enlarged bold heading. Literal
        // text keeps player names from being interpreted as game formatting.
        summaryStyle = label(dom, "");
        headingStyle = label(dom, "");
        G.call("domkit.Properties", "addClass", G.field(headingStyle, "dom"), ["bold-14"]);
        show(summaryStyle, false); show(headingStyle, false);
        recapHeading = G.create("h2d.Text", [G.field(summaryStyle, "font"), container]);
        recapInfo = G.create("h2d.Text", [G.field(summaryStyle, "font"), container]);
        G.call("h2d.Text", "set_text", recapHeading, ["Rift Recap"]);
        G.call("h2d.Text", "set_text", recapInfo, [healing ? HealingDisplay.recapDetail(result) : FightHistory.recapDetail(result)]);
        G.call("h2d.Text", "set_textColor", recapHeading, [0x8a5f46]);
        G.call("h2d.Text", "set_textColor", recapInfo, [0x5b4334]);
        for (text in [recapHeading, recapInfo]) {
            G.call("h2d.Text", "set_lineBreak", text, [false]);
            absolute(container, text);
        }
    }

    function copySnapshot():Void {
        if (copying || displayedRecap == null || charts == null) return;
        copying = true;
        var message = "Snapshot copied to clipboard.";
        var scrolls = charts.snapshotScrolls();
        try {
            setText(title, "Rift Recap");
            layout(true);
            refreshSnapshotCharts();
            charts.restoreScrolls([0, 0]);
            NativeFightSnapshot.copyBody(window, width, height, [header]);
        } catch (error:Dynamic) {
            message = Std.string(error);
            trace("[DPS Meter] Rift recap snapshot: " + message);
        }
        // Restore the live window even when image allocation/readback fails.
        try {
            layout(); refreshSnapshotCharts();
            charts.restoreScrolls(scrolls);
        } catch (error:Dynamic) {
            message = Std.string(error);
            trace("[DPS Meter] Restore recap after snapshot: " + message);
        }
        copying = false;
        setText(title, message);
        statusUntil = haxe.Timer.stamp() + 5;
    }

    function refreshSnapshotCharts():Void {
        NativeFightSnapshot.reflow(window);
        charts.update(haxe.Timer.stamp());
        NativeFightSnapshot.reflow(window);
        alignLabels();
    }

    function layout(snapshot:Bool = false):Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.min(980, bottom.x - top.x - 40));
        var columns = RiftRecapLayout.columns(w - 48);
        var h = Std.int(Math.min((columns ? 540 : 680) + SnapshotLayout.RECAP_SUMMARY_HEIGHT, bottom.y - top.y - 80));
        var chartHeights = snapshot ? charts.chartHeights() : [];
        if (snapshot) {
            h = SnapshotLayout.recapHeight(columns, chartHeights, h);
            SnapshotLayout.imageSize(w, h);
        }
        // Unequal stacked phases may fit inside the existing outer size.
        // Still relayout their individual panels for capture and restoration.
        if (copying || width != w || height != h) {
            snapshotLayout = snapshot;
            width = w; height = h;
            size(window, width, height);
            if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
            size(header, width - 2, HEADER_HEIGHT);
            position(header, 0, 0);
            size(close, 36, 36);
            position(close, width - 52, 12);
            size(snapshotButton, HistoryButtons.SNAPSHOT_SIZE, HistoryButtons.SNAPSHOT_SIZE);
            modeButton.resize(HistoryButtons.SNAPSHOT_SIZE);
            G.call("ui.comp.FmtText", "set_maxWidthText", title, [width - 252]);
            var contentTop = snapshot ? 8 : HEADER_HEIGHT;
            var bodyHeight = height - contentTop - 8;
            size(windowContent, width - 16, bodyHeight);
            position(windowContent, 8, contentTop);
            for (object in wrappers) { size(object, width - 16, bodyHeight); position(object, 0, 0); }
            // The live window already has its title in the native header.
            // Put a title in the body only while that header is omitted from capture.
            show(recapHeading, snapshot);
            var summaryHeight = snapshot ? SnapshotLayout.RECAP_SNAPSHOT_SUMMARY_HEIGHT : SnapshotLayout.RECAP_SUMMARY_HEIGHT;
            var chartsHeight = bodyHeight - summaryHeight;
            charts.resize(width - 48, chartsHeight - 24, snapshot);
            position(charts.object, 16, summaryHeight + 12);
        }
        position(window, top.x + (bottom.x - top.x - width) / 2, top.y + (bottom.y - top.y - height) / 2);
    }

    function alignLabels():Void {
        G.call("ui.comp.FmtText", "updateScale", title);
        position(title, (width - textWidth(title)) / 2, (HEADER_HEIGHT - textHeight(title)) / 2);
        // Native styles can settle after construction. Center the styled controls
        // on the title's header row, with snapshot first and the mode toggle second.
        var snapshotHeight = G.number(G.call("h2d.Flow", "get_outerHeight", snapshotButton), HistoryButtons.SNAPSHOT_SIZE);
        var modeHeight = G.number(G.call("h2d.Flow", "get_outerHeight", modeButton.object), HistoryButtons.SNAPSHOT_SIZE);
        position(snapshotButton, 24, (HEADER_HEIGHT - snapshotHeight) / 2);
        position(modeButton.object, 66, (HEADER_HEIGHT - modeHeight) / 2);
        fitSummary(recapHeading, headingStyle, 1.75);
        fitSummary(recapInfo, summaryStyle, 1);
        position(recapHeading, 16, 16 + (34 - textHeight(recapHeading)) / 2);
        position(recapInfo, 16, snapshotLayout ? 68 : 12);
        charts.alignLabels();
    }
    function fitSummary(text:Dynamic, reference:Dynamic, factor:Float):Void {
        G.call("ui.comp.FmtText", "updateScale", reference);
        var font = G.field(reference, "font");
        if (font != null && font != G.field(text, "font")) G.call("h2d.Text", "set_font", text, [font]);
        var natural = G.number(G.call("h2d.Text", "get_textWidth", text));
        var desired = G.number(G.field(reference, "scaleX"), 1) * factor;
        G.call("h2d.Object", "setScale", text, [natural <= 0 ? desired : Math.min(desired, Math.max(1, width - 48) / natural)]);
    }
    function textWidth(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textWidth", text)) * G.number(G.field(text, "scaleX"), 1);
    function textHeight(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }
    public function closeFromEscape(ui:Dynamic):Bool {
        if (window == null || owner != ui || G.field(window, "removed") == true || G.field(window, "parent") == null) return false;
        dispose();
        return true;
    }
    public function dispose():Void {
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; charts = null; wrappers = []; frameBackground = null;
        body = null; container = null; displayedRecap = null;
        recapHeading = null; recapInfo = null; headingStyle = null; summaryStyle = null; snapshotLayout = false;
        snapshotButton = null; modeButton = null; copying = false; statusUntil = 0;
        width = 0; height = 0;
    }
}
