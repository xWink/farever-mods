package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.SkillBreakdown;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One ability per row, shared by live, history, and rift recap charts. */
class NativeSkillTable {
    static inline var PHYSICAL_COLOR:Int = 0xc95846;
    static inline var MAGICAL_COLOR:Int = 0x438dcc;

    public var object(default, null):Dynamic;
    var root:Dynamic;
    var header:Dynamic;
    var rows:Array<Dynamic> = [];
    var names:Map<String, String> = [];
    var icons:Map<String, Dynamic> = [];
    var back:Void->Void;
    var id:String;
    var width:Int = 0;
    var columns:Array<SkillColumn> = [];
    public function new(parent:Dynamic, id:String, back:Void->Void) {
        this.id = id; this.back = back;
        root = node("flow", parent, [], id + "Table", "vertical");
        object = G.field(root, "obj"); padding(object, 0);
        flow(root, "set_verticalSpacing", 0); style(object, "vspacing", 0);
        header = makeRow(-1);
        show(object, false);
    }
    public function clear():Void { names = []; icons = []; }
    public function update(player:PlayerStats, duration:Float, width:Int):Void {
        var resized = this.width != width;
        this.width = width;
        if (resized) { columns = SkillBreakdown.columns(width); size(object, width); }
        show(object, true);
        var ids = [for (id in player.skills.keys()) id];
        ids.sort((a, b) -> {
            var difference = Reflect.compare(player.skills[b].damage, player.skills[a].damage);
            return difference != 0 ? difference : Reflect.compare(a, b);
        });
        while (rows.length < ids.length) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < ids.length);
            if (i >= ids.length) continue;
            var key = ids[i];
            if (!names.exists(key)) names[key] = NativeCombatMetadata.skillName(key);
            if (!icons.exists(key)) icons[key] = NativeCombatMetadata.skillIcon(key);
            if (row.skill != key || row.tile != icons[key]) {
                row.skill = key; row.tile = icons[key];
                G.call("h2d.Bitmap", "set_tile", row.icon, [row.tile]);
                if (row.tile != null) G.call("h2d.Object", "setScale", row.icon,
                    [26 / Math.max(1, Math.max(G.number(G.field(row.tile, "width")), G.number(G.field(row.tile, "height"))))]);
                show(row.icon, row.tile != null);
            }
            var v = SkillBreakdown.values(player.skills[key], player.damage, duration);
            var distribution = player.skills[key].damageBreakdown.distribution(player.skills[key].damage);
            row.physical = distribution == null ? -1.0 : distribution.physical;
            row.magical = distribution == null ? -1.0 : distribution.magical;
            row.values = ["ability" => names[key], "percent" => Std.string(SkillStats.rounded(v.percent, 1)) + "%",
                "distribution" => distribution == null ? "—" : "", "damage" => compact(v.damage), "casts" => Std.string(v.casts),
                "avgCast" => compact(v.avgCast), "hits" => Std.string(v.hits), "avgHit" => compact(v.avgHit),
                "crit" => Std.string(SkillStats.rounded(v.crit, 1)) + "%", "dps" => compact(v.dps)];
            var values:Map<String, String> = row.values;
            var signature = row.physical + "|" + row.magical + "|" + [for (key in SkillBreakdown.KEYS) values[key]].join("|");
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
    function makeRow(index:Int):Dynamic {
        var dom = node("element", root, [], id + "SkillRow" + index, "horizontal");
        var obj = G.field(dom, "obj"); padding(obj, 0);
        var row:Dynamic = {obj: obj, texts: new Map<String, Dynamic>(), values: new Map<String, String>(),
            graphic: G.create("h2d.Graphics", [obj]), icon: null, tile: null,
            skill: "", physical: -1.0, magical: -1.0, index: index,
            drawnValues: "", drawnWidth: 0, drawnTile: null, font: null, scale: null};
        absolute(obj, row.graphic);
        for (key in SkillBreakdown.KEYS) {
            var t = label(dom, ""); absolute(obj, t);
            G.call("ui.comp.FmtText", "set_useEllipsis", t, [true]);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", t, [left]); style(t, "text-align", left);
            if (index < 0 || key == "ability" || key == "dps")
                G.call("domkit.Properties", "addClass", G.field(t, "dom"), ["bold-14"]);
            (cast row.texts:Map<String, Dynamic>)[key] = t;
        }
        if (index >= 0) {
            row.icon = G.create("h2d.Bitmap", [null, obj]); absolute(obj, row.icon);
            G.call("ui.UIElement", "set_onClick", obj, [back]);
        }
        return row;
    }
    function layout(row:Dynamic):Void {
        var heading:Bool = row.index < 0;
        var height = heading ? 30 : 40;
        size(row.obj, width, height);
        G.call("h2d.Graphics", "clear", row.graphic);
        if (!heading && row.index % 2 == 0) rect(row.graphic, 0, 0, width, height, 0x5b4334, .06);
        rect(row.graphic, 0, height - 1, width, 1, 0x5b4334, .18);
        var texts:Map<String, Dynamic> = row.texts;
        var values:Map<String, String> = row.values;
        for (t in texts) show(t, false);
        if (!heading) position(row.icon, 5, 7);
        for (column in columns) {
            var t = texts[column.key]; show(t, true);
            var x = column.x + 5.0;
            var cellWidth = column.width - 10.0;
            var value = heading ? column.title : values[column.key];
            if (column.key == "ability") {
                if (!heading && row.tile != null) { x += 32; cellWidth -= 32; }
                fit(t, value, x, cellWidth, height, false);
            } else if (column.key == "distribution") {
                if (heading || row.physical < 0) fit(t, value, x, cellWidth, height, false);
                else {
                    show(t, false);
                    var physicalWidth = cellWidth * row.physical;
                    var magicalWidth = cellWidth * row.magical;
                    // Every bar represents this ability's own damage, with Raw
                    // left as the unfilled gray portion after physical/magical.
                    rect(row.graphic, x, 16, cellWidth, 8, 0x70757d, .35);
                    if (physicalWidth > 0) rect(row.graphic, x, 16, physicalWidth, 8, PHYSICAL_COLOR, .95);
                    if (magicalWidth > 0) rect(row.graphic, x + physicalWidth, 16, magicalWidth, 8, MAGICAL_COLOR, .95);
                }
            } else fit(t, value, x, cellWidth, height, true);
        }
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
