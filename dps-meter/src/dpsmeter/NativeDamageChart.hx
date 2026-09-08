package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** The same scrollable player/skill chart in the live meter and phase recaps. */
class NativeDamageChart {
    var rowsRoot:Dynamic;
    var rows:Array<Dynamic> = [];
    var id:String;
    var width:Int = 1;
    var displayed:Null<Fight>;
    var selectedPlayer:String = "";
    var lastRefresh:Float = -1;
    var empty:Dynamic;
    public function new(parent:Dynamic, id:String, emptyText:String = "") {
        this.id = id;
        rowsRoot = node("flow", parent, [], id, "vertical");
        var object = G.field(rowsRoot, "obj");
        padding(object, 0);
        flow(rowsRoot, "set_verticalSpacing", 12);
        style(object, "vspacing", 12);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        flow(rowsRoot, "set_overflow", scroll);
        style(object, "overflow", scroll);
        if (emptyText != "") empty = label(rowsRoot, emptyText);
    }
    public function resize(width:Int, height:Int):Void {
        this.width = width;
        size(G.field(rowsRoot, "obj"), width, height);
        if (empty != null) G.call("ui.comp.FmtText", "set_maxWidthText", empty, [width]);
        for (row in rows) sizeRow(row);
        lastRefresh = -1;
    }
    function resetScroll():Void {
        // Reflow positions the new list at its beginning, including an empty list.
        G.set(G.field(rowsRoot, "obj"), "scrollPosY", 0.0);
        flow(rowsRoot, "set_needReflow", true);
    }
    public function update(fight:Null<Fight>, now:Float):Void {
        if (fight != displayed) {
            displayed = fight; selectedPlayer = "";
            resetScroll(); lastRefresh = -1;
        }
        if (now - lastRefresh < 0.20) return;
        lastRefresh = now;
        var ranked = fight == null ? [] : fight.ranked();
        var elapsed = fight == null ? 0 : fight.duration(now);
        // A single instant hit should not display thousands of times its damage as DPS.
        var seconds = Math.max(1, elapsed);
        var total = 0.0;
        for (p in ranked) total += p.damage;
        var selected = fight == null ? null : fight.players[selectedPlayer];
        var skillIds:Array<String> = [];
        if (selected != null) {
            skillIds = [for (id in selected.skills.keys()) id];
            skillIds.sort((a, b) -> Reflect.compare(selected.skills[b].damage, selected.skills[a].damage));
        }
        var count = selected == null ? ranked.length : skillIds.length;
        show(empty, count == 0);
        while (rows.length < count) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < count);
            if (i >= count) continue;
            var amount:Float; var color:Int; var label:String; var detail:String;
            if (selected == null) {
                var p = ranked[i]; row.uid = p.info.uid; amount = p.damage;
                color = classColor(p.info.className);
                label = (i + 1) + ". " + p.info.name;
                detail = compact(p.damage) + " (" + compact(seconds > 0 ? p.damage / seconds : 0)
                    + ", " + Std.int(total > 0 ? p.damage * 100 / total : 0) + "%)";
            } else {
                var id = skillIds[i]; var s = selected.skills[id]; row.uid = "";
                amount = s.damage; color = classColor(selected.info.className); label = id;
                detail = compact(s.damage) + " damage";
                setText(row.extra, s.casts + " casts  ·  " + s.hits + " hits  ·  " + s.crits + " crits");
            }
            row.caption = label;
            setText(row.details, detail);
            show(row.extra, selected != null);
            sizeRow(row);
            if (row.color != color) {
                row.color = color;
                G.set(row.bar, "color", color); G.set(row.bar, "fullColor", color);
                // Inline styles preserve the class tint through native CSS updates.
                style(row.bar, "color", color); style(row.bar, "full-color", color);
            }
            G.call("ui.comp.BaseGauge", "set_max", row.bar, [Math.max(1, selected == null ? total : selected.damage)]);
            G.call("ui.comp.BaseGauge", "set_value", row.bar, [amount]);
        }
    }
    function availableRowWidth():Int {
        var list = G.field(rowsRoot, "obj");
        var available = G.integer(G.call("h2d.Flow", "get_innerWidth", list), width);
        var scrollbar = G.field(list, "scrollBar");
        // Use the full body width, reserving room only for a visible scrollbar.
        if (scrollbar != null && G.field(scrollbar, "visible") == true)
            available -= G.integer(G.call("h2d.Flow", "get_outerWidth", scrollbar)) + 4;
        return Std.int(Math.max(1, available));
    }
    function sizeRow(row:Dynamic):Void {
        var rowWidth = availableRowWidth();
        if (row.width != rowWidth) {
            row.width = rowWidth;
            size(row.obj, rowWidth);
            size(row.heading, rowWidth);
            G.call("ui.comp.FmtText", "set_maxWidthText", row.details, [Std.int(Math.max(1, rowWidth - 60))]);
            G.call("ui.comp.FmtText", "set_maxWidthText", row.extra, [rowWidth]);
            G.call("ui.comp.BaseGauge", "set_barWidth", row.bar, [rowWidth]);
            size(row.bar, rowWidth, 9);
        }
        alignRow(row);
    }
    function alignRow(row:Dynamic):Void {
        var rowWidth:Int = row.width;
        // Measure native text, not spaces: numbers keep a common right edge.
        G.call("ui.comp.FmtText", "updateScale", row.details);
        var detailWidth = G.number(G.call("h2d.Text", "get_textWidth", row.details)) * G.number(G.field(row.details, "scaleX"), 1);
        G.call("ui.comp.FmtText", "set_maxWidthText", row.name, [Std.int(Math.max(1, rowWidth - detailWidth - 12))]);
        // Restore the full name when widening a previously ellipsized row.
        setText(row.name, row.caption);
        G.call("ui.comp.FmtText", "updateScale", row.name);
        var lineHeight = 0.0;
        for (text in [row.name, row.details]) lineHeight = Math.max(lineHeight,
            G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1));
        var h = Std.int(Math.ceil(Math.max(18, lineHeight)));
        if (row.lineHeight != h) { row.lineHeight = h; size(row.heading, rowWidth, h); }
        position(row.name, 0, 0);
        position(row.details, rowWidth - detailWidth, 0);
    }
    function makeRow(index:Int):Dynamic {
        var d = node("element", rowsRoot, [], id + "Row" + index, "vertical");
        padding(G.field(d, "obj"), 0);
        flow(d, "set_verticalSpacing", 4);
        style(G.field(d, "obj"), "vspacing", 4);
        var heading = node("flow", d, [], id + "Heading" + index, "horizontal");
        var headingObject = G.field(heading, "obj");
        padding(headingObject, 0);
        var name = label(heading, "");
        var details = label(heading, "");
        for (text in [name, details]) {
            absolute(headingObject, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]);
            style(text, "text-align", left);
        }
        G.call("ui.comp.FmtText", "set_useEllipsis", name, [true]);
        var extra = label(d, "");
        G.call("ui.comp.FmtText", "set_useEllipsis", extra, [true]);
        show(extra, false);
        var barDom = node("base-gauge", d, [], id + "Bar" + index);
        var bar = G.field(barDom, "obj");
        G.call("ui.comp.BaseGauge", "set_barHeight", bar, [7]);
        G.call("ui.comp.BaseGauge", "set_showValues", bar, [false]);
        var obj = G.field(d, "obj");
        var row:Dynamic = {obj: obj, heading: headingObject, name: name, details: details,
            extra: extra, bar: bar, uid: "", caption: "", lineHeight: 0, color: -1, width: 0};
        G.call("ui.UIElement", "set_onClick", obj, [() -> { selectedPlayer = row.uid; resetScroll(); lastRefresh = -1; }]);
        sizeRow(row);
        return row;
    }
}
