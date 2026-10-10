package dpsmeter;

import dpsmeter.RiftTracker.RiftRecap;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Reusable recap body; its owning window supplies navigation and actions. */
class NativeRiftRecapCharts {
    public var object(default, null):Dynamic;
    var sections:Array<Dynamic> = [];
    var width:Int = 0;
    var height:Int = 0;
    var snapshotLayout:Bool = false;

    public function new(parent:Dynamic, id:String) {
        var dom = node("flow", parent, [], id, "vertical");
        object = G.field(dom, "obj");
        padding(object, 0);
        var limit = G.enumeration("h2d.FlowOverflow", "Limit");
        flow(dom, "set_overflow", limit); style(object, "overflow", limit);
        for (i in 0...2) addSection(dom, id + (i == 0 ? "Gate" : "Boss"));
    }

    public function setRecap(result:Null<RiftRecap>):Void {
        for (i in 0...sections.length) {
            var section = sections[i];
            var fight = result == null ? null : i == 0 ? result.gate : result.boss;
            section.fight = fight;
            setText(section.name, HistoryCatalog.HistoryCategory.normalizeName(i == 0 ? RiftTracker.GATES_PHASE
                : fight == null ? "Rift - Boss" : fight.phase));
            setText(section.time, fight == null ? "" : duration(fight.duration()));
        }
    }

    public function setHealing(value:Bool):Void {
        for (section in sections) (cast section.chart:NativeDamageChart).setHealing(value);
    }
    public function update(now:Float):Void {
        for (section in sections) (cast section.chart:NativeDamageChart).update(section.fight, now);
    }
    public function chartHeights():Array<Int>
        return [for (section in sections) (cast section.chart:NativeDamageChart).snapshotHeight()];
    public function snapshotHeight():Int return RiftRecapLayout.snapshotHeight(width, chartHeights());
    public function snapshotScrolls():Array<Float>
        return [for (section in sections) (cast section.chart:NativeDamageChart).snapshotScroll()];
    public function restoreScrolls(values:Array<Float>):Void {
        for (i in 0...sections.length) (cast sections[i].chart:NativeDamageChart).restoreScroll(values[i]);
    }
    public function resize(width:Int, height:Int, snapshot:Bool = false):Void {
        if (!snapshot && !snapshotLayout && this.width == width && this.height == height) return;
        this.width = width; this.height = height; snapshotLayout = snapshot;
        size(object, width, height);
        var panels = RiftRecapLayout.panels(width, height, snapshot ? chartHeights() : null);
        for (i in 0...sections.length) {
            var section = sections[i], panel = panels[i];
            section.width = panel.width;
            size(section.obj, panel.width, panel.height); position(section.obj, panel.x, panel.y);
            size(section.heading, panel.width, RiftRecapLayout.HEADER);
            (cast section.chart:NativeDamageChart).resize(panel.width, Std.int(Math.max(1, panel.height - RiftRecapLayout.HEADER)));
        }
    }
    public function alignLabels():Void {
        for (section in sections) {
            G.call("ui.comp.FmtText", "updateScale", section.time);
            var timeWidth = G.number(G.call("h2d.Text", "get_textWidth", section.time)) * G.number(G.field(section.time, "scaleX"), 1);
            var nameWidth = Std.int(Math.max(1, section.width - timeWidth - 12));
            if (nameWidth != section.nameWidth) {
                section.nameWidth = nameWidth;
                G.call("ui.comp.FmtText", "set_maxWidthText", section.name, [nameWidth]);
            }
            G.call("ui.comp.FmtText", "updateScale", section.name);
            position(section.name, 0, 4); position(section.time, section.width - timeWidth, 4);
        }
    }
    function addSection(parent:Dynamic, id:String):Void {
        var panel = node("flow", parent, [], id, "vertical");
        var obj = G.field(panel, "obj");
        padding(obj, 0); flow(panel, "set_verticalSpacing", 0); style(obj, "vspacing", 0);
        var limit = G.enumeration("h2d.FlowOverflow", "Limit");
        flow(panel, "set_overflow", limit); style(obj, "overflow", limit);
        absolute(object, obj);
        var heading = node("flow", panel, [], id + "Header", "horizontal");
        var headingObject = G.field(heading, "obj"); padding(headingObject, 0);
        var name = label(heading, ""), time = label(heading, "");
        for (text in [name, time]) {
            absolute(headingObject, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]); style(text, "text-align", left);
        }
        var chart = new NativeDamageChart(panel, id + "Rows", "No damage recorded", true);
        sections.push({obj: obj, heading: headingObject, name: name, time: time, chart: chart, fight: null, width: 0, nameWidth: 0});
    }
}
