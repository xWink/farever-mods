package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.SkillBreakdown;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One ability per row, shared by live, history, and rift recap charts. */
class NativeSkillTable {
    static inline var PHYSICAL_COLOR:Int = 0xc95846;
    static inline var MAGICAL_COLOR:Int = 0x438dcc;
    static inline var RAW_COLOR:Int = 0xf2eee7;
    static inline var TEAM_COLOR:Int = 0x56ad72;
    static inline var SELF_COLOR:Int = 0xe5bd4f;

    public var object(default, null):Dynamic;
    public var headerHeight(default, null):Int = 30;
    var root:Dynamic;
    var header:Dynamic;
    var rows:Array<Dynamic> = [];
    var names:Map<String, String> = [];
    var icons:Map<String, Dynamic> = [];
    var back:Void->Void;
    var id:String;
    var width:Int = 0;
    var columns:Array<SkillColumn> = [];
    var recap:Bool;
    var healing:Bool = false;
    public function new(parent:Dynamic, id:String, back:Void->Void, ?headerParent:Dynamic, recap:Bool = false) {
        this.id = id; this.back = back; this.recap = recap;
        root = node("flow", parent, [], id + "Table", "vertical");
        object = G.field(root, "obj"); padding(object, 0);
        flow(root, "set_verticalSpacing", 0); style(object, "vspacing", 0);
        header = makeRow(-1, headerParent);
        show(object, false);
    }
    public function clear():Void { names = []; icons = []; }
    public function update(player:PlayerStats, duration:Float, width:Int, healing:Bool = false):Void {
        var resized = this.width != width || this.healing != healing;
        this.healing = healing;
        this.width = width;
        if (resized) { columns = SkillBreakdown.columns(width, recap, healing); size(object, width); }
        show(object, true);
        var ids = healing ? [for (id in player.healingSkills.keys()) id] : [for (id in player.skills.keys()) id];
        ids.sort((a, b) -> {
            var difference = healing ? Reflect.compare(player.healingSkills[b].output, player.healingSkills[a].output)
                : Reflect.compare(player.skills[b].damage, player.skills[a].damage);
            return difference != 0 ? difference : Reflect.compare(a, b);
        });
        while (rows.length < ids.length) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < ids.length);
            if (i >= ids.length) continue;
            var key = ids[i];
            var synthetic = key == "Regen / unattributed" || key == "Unknown healing";
            if (!names.exists(key)) names[key] = synthetic ? key : NativeCombatMetadata.skillName(key);
            if (!icons.exists(key)) icons[key] = synthetic ? null : NativeCombatMetadata.skillIcon(key);
            if (row.skill != key || row.tile != icons[key]) {
                row.skill = key; row.tile = icons[key];
                G.call("h2d.Bitmap", "set_tile", row.icon, [row.tile]);
                if (row.tile != null) G.call("h2d.Object", "setScale", row.icon,
                    [26 / Math.max(1, Math.max(G.number(G.field(row.tile, "width")), G.number(G.field(row.tile, "height"))))]);
                show(row.icon, row.tile != null);
            }
            var v = healing ? SkillBreakdown.healingValues(player.healingSkills[key], player.heal, duration)
                : SkillBreakdown.values(player.skills[key], player.damage, duration);
            var distribution = healing ? null : player.skills[key].damageBreakdown.distribution(player.skills[key].damage);
            row.physical = distribution == null ? -1.0 : distribution.physical;
            row.magical = distribution == null ? -1.0 : distribution.magical;
            row.percentages = distribution == null ? [] : [for (share in [distribution.physical, distribution.magical, distribution.raw])
                Std.string(SkillStats.rounded(share * 100, 1)) + "%"];
            row.values = ["ability" => names[key], "percent" => Std.string(SkillStats.rounded(v.percent, 1)) + "%",
                "distribution" => distribution == null ? "—" : "", "damage" => compact(v.damage), "casts" => Std.string(v.casts),
                "avgCast" => compact(v.avgCast), "hits" => Std.string(v.hits), "avgHit" => compact(v.avgHit),
                "crit" => Std.string(SkillStats.rounded(v.crit, 1)) + "%", "dps" => compact(v.dps)];
            var values:Map<String, String> = row.values;
            if (healing) {
                var stats = player.healingSkills[key];
                var split = stats.distribution();
                row.physical = split == null ? -1.0 : split.team;
                row.magical = split == null ? -1.0 : split.self;
                row.percentages = split == null ? [] : [for (share in [split.team, split.self])
                    Std.string(SkillStats.rounded(share * 100, 1)) + "%"];
                values["distribution"] = split == null ? "—" : "";
                values["damage"] = HealingDisplay.output(stats, v.damage, compact);
                values["dps"] = HealingDisplay.output(stats, v.dps, compact);
                values["avgCast"] = HealingDisplay.output(stats, v.avgCast, compact);
                values["avgHit"] = HealingDisplay.output(stats, v.avgHit, compact);
                values["crit"] = HealingDisplay.crit(stats);
                if (player.healing.unknownOutputHits > 0) values["percent"] = "—";
            }
            var signature = healing + "|" + row.physical + "|" + row.magical + "|" + (cast row.percentages:Array<String>).join("|")
                + "|" + [for (key in SkillBreakdown.KEYS) values[key]].join("|");
            var nameText = (cast row.texts:Map<String, Dynamic>)["ability"];
            var font = G.field(nameText, "font"); var scale = G.field(nameText, "scaleX");
            if (row.drawnValues != signature || row.drawnWidth != width
                || row.drawnTile != row.tile || row.font != font || row.scale != scale) {
                layout(row);
                row.drawnValues = signature; row.drawnWidth = width;
                row.drawnTile = row.tile;
                row.font = G.field(nameText, "font"); row.scale = G.field(nameText, "scaleX");
            }
        }
        // Font styles can settle one frame after native DOM creation.
        var nameText = (cast header.texts:Map<String, Dynamic>)["ability"];
        if (resized || header.font != G.field(nameText, "font") || header.scale != G.field(nameText, "scaleX")) {
            layout(header); header.font = G.field(nameText, "font"); header.scale = G.field(nameText, "scaleX");
        }
    }
    function makeRow(index:Int, ?parent:Dynamic):Dynamic {
        var dom = node("element", parent == null ? root : parent, [], id + "SkillRow" + index, "horizontal");
        var obj = G.field(dom, "obj"); padding(obj, 0);
        var row:Dynamic = {obj: obj, texts: new Map<String, Dynamic>(), values: new Map<String, String>(),
            graphic: G.create("h2d.Graphics", [obj]), icon: null, tile: null,
            skill: "", physical: -1.0, magical: -1.0, percentages: [], distributionTexts: [], index: index,
            drawnValues: "", drawnWidth: 0, drawnTile: null, font: null, scale: null};
        absolute(obj, row.graphic);
        for (key in SkillBreakdown.KEYS) {
            var t = label(dom, ""); absolute(obj, t);
            G.call("ui.comp.FmtText", "set_useEllipsis", t, [true]);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", t, [left]); style(t, "text-align", left);
            if (index < 0 || key == "ability")
                G.call("domkit.Properties", "addClass", G.field(t, "dom"), ["bold-14"]);
            (cast row.texts:Map<String, Dynamic>)[key] = t;
        }
        if (index >= 0) {
            for (i in 0...3) {
                var t = label(dom, ""); absolute(obj, t);
                var left = G.enumeration("h2d.Align", "Left");
                G.call("h2d.Text", "set_textAlign", t, [left]); style(t, "text-align", left);
                (cast row.distributionTexts:Array<Dynamic>).push(t);
            }
            row.icon = G.create("h2d.Bitmap", [null, obj]); absolute(obj, row.icon);
            G.call("ui.UIElement", "set_onClick", obj, [back]);
        }
        return row;
    }
    function layout(row:Dynamic):Void {
        var heading:Bool = row.index < 0;
        var stacked = false;
        for (column in columns) if (column.key == "distribution") stacked = !healing && !recap && column.width - 10 < 105;
        var height = stacked ? 60 : heading ? 30 : 40;
        if (heading) headerHeight = height;
        size(row.obj, width, height);
        G.call("h2d.Graphics", "clear", row.graphic);
        if (!heading && row.index % 2 == 0) rect(row.graphic, 0, 0, width, height, 0x5b4334, .06);
        rect(row.graphic, 0, height - 1, width, 1, 0x5b4334, .18);
        var texts:Map<String, Dynamic> = row.texts;
        var values:Map<String, String> = row.values;
        for (t in texts) show(t, false);
        var distributionTexts:Array<Dynamic> = row.distributionTexts;
        for (t in distributionTexts) show(t, false);
        if (heading && recap) { layoutRecapHeader(texts, height); return; }
        if (!heading) position(row.icon, 5, (height - 26) / 2);
        for (column in columns) {
            var t = texts[column.key]; show(t, true);
            var x = column.x + 5.0;
            var cellWidth = column.width - 10.0;
            var value = heading ? column.title : values[column.key];
            if (column.key == "ability") {
                if (!heading && row.tile != null) { x += 32; cellWidth -= 32; }
                fit(t, value, x, cellWidth, height, false);
            } else if (column.key == "distribution") {
                if (heading)
                    fitDetail(t, stacked ? StringTools.replace(value, "/", "/\n") : value, x, 3, cellWidth, height - 6);
                else if (row.physical < 0) fit(t, value, x, cellWidth, height, false);
                else {
                    show(t, false);
                    var physicalWidth = cellWidth * row.physical;
                    var magicalWidth = cellWidth * row.magical;
                    // Healing reuses the same layout: team first, then self.
                    // Any unclassified output remains neutral, never self-healing.
                    var barY = stacked ? 48 : 26;
                    rect(row.graphic, x, barY, cellWidth, 8, healing ? 0xaaa39a : RAW_COLOR, .95);
                    if (physicalWidth > 0) rect(row.graphic, x, barY, physicalWidth, 8, healing ? TEAM_COLOR : PHYSICAL_COLOR, .95);
                    if (magicalWidth > 0) rect(row.graphic, x + physicalWidth, barY, magicalWidth, 8, healing ? SELF_COLOR : MAGICAL_COLOR, .95);
                }
                if (!heading && row.physical >= 0) {
                    var labels:Array<String> = row.percentages;
                    for (i in 0...labels.length) {
                        var detail = distributionTexts[i]; show(detail, true);
                        fitDetail(detail, labels[i], stacked ? x : x + cellWidth * i / labels.length,
                            stacked ? 3 + i * 14 : 5, stacked ? cellWidth : cellWidth / labels.length, stacked ? 14 : 16);
                    }
                }
            } else fit(t, value, x, cellWidth, height, true);
        }
    }
    function layoutRecapHeader(texts:Map<String, Dynamic>, height:Int):Void {
        // All headings use the native bold-14 font at the same scale. Measure
        // complete labels first so an unusually narrow viewport scales the
        // whole header uniformly, rather than shrinking individual columns.
        var scale = 1.0;
        var measured = [for (column in columns) {
            var text = texts[column.key]; show(text, true);
            G.call("ui.comp.FmtText", "set_maxWidthText", text, [null]);
            setText(text, column.title);
            G.call("ui.comp.FmtText", "updateScale", text);
            var w = G.number(G.call("h2d.Text", "get_textWidth", text));
            var h = G.number(G.call("h2d.Text", "get_textHeight", text));
            scale = Math.min(scale, Math.min(Math.max(1, column.width - 12) / Math.max(1, w), (height - 6) / Math.max(1, h)));
            {column: column, text: text, width: w, height: h};
        }];
        for (entry in measured) {
            G.call("h2d.Object", "setScale", entry.text, [scale]);
            var x = entry.column.x + 5.0;
            if (entry.column.key != "ability") x += Math.max(0, (entry.column.width - 10 - entry.width * scale) / 2);
            position(entry.text, x, (height - entry.height * scale) / 2);
        }
    }
    static function fitDetail(text:Dynamic, value:String, x:Float, y:Float, width:Float, height:Int):Void {
        // Measure the full value before scaling: percentages must never acquire
        // an ellipsis. These secondary labels stay inside their own small cells.
        G.call("ui.comp.FmtText", "set_maxWidthText", text, [null]);
        setText(text, value);
        G.call("ui.comp.FmtText", "updateScale", text);
        var w = G.number(G.call("h2d.Text", "get_textWidth", text));
        var h = G.number(G.call("h2d.Text", "get_textHeight", text));
        var scale = Math.min(1, Math.min(Math.max(1, width - 2) / Math.max(1, w), height / Math.max(1, h)));
        G.call("h2d.Object", "setScale", text, [scale]);
        position(text, x + Math.max(0, (width - w * scale) / 2), y + Math.max(0, (height - h * scale) / 2));
    }
    static function fit(text:Dynamic, value:String, x:Float, width:Float, height:Int, right:Bool):Void {
        G.call("ui.comp.FmtText", "set_maxWidthText", text, [Std.int(Math.max(1, width))]);
        setText(text, value);
        G.call("ui.comp.FmtText", "updateScale", text);
        var w = G.number(G.call("h2d.Text", "get_textWidth", text)) * G.number(G.field(text, "scaleX"), 1);
        var h = G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
        position(text, right ? x + Math.max(0, width - w) : x, Math.max(0, (height - h) / 2));
    }
    static function rect(graphic:Dynamic, x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float):Void {
        G.call("h2d.Graphics", "beginFill", graphic, [color, alpha]);
        G.call("h2d.Graphics", "drawRect", graphic, [x, y, w, h]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
}
