package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

private typedef KillPopup = {
    id:String,
    category:String,
    object:Dynamic,
    title:Dynamic,
    expires:Float
};

/** Native SmallNotify text, positioned independently of the meter window. */
class NativeKillPopups {
    public static var constructing:Bool = false;
    var config:MeterConfig;
    var owner:Dynamic;
    var root:Dynamic;
    var rows:Array<KillPopup> = [];
    var fade:Float = 0.4;

    public function new(config:MeterConfig) this.config = config;

    public function show(id:String, message:String, category:String, count:Int, goal:Int, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null) return;
        if (owner != ui) { clear(); owner = ui; }
        root = G.field(ui, "rootOverlay");
        if (root == null) root = G.field(ui, "root");
        var settings = G.current("Const", "UI");
        fade = Math.max(0.1, G.number(G.field(settings, "Notification_DisappearDuration"), 0.4));
        var duration = Math.max(fade + 1, G.number(G.field(settings, "Notification_DefaultDuration"), 4));
        for (row in rows) if (row.id == id) {
            setText(row.title, message);
            row.expires = now + duration; row.category = category;
            G.set(row.object, "alpha", 1);
            return;
        }
        var object:Dynamic = null;
        constructing = true;
        try object = G.create("ui.notify.SmallNotify", ["CodexProgress", {id: id, progress: count, maxProgress: goal}, root])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        try {
            absolute(root, object);
            padding(object, 0);
            // Use the real native component and title font, without a panel.
            G.call("ui.BaseElement", "set_backgroundType", object, [null]);
            G.call("h2d.Flow", "set_backgroundTile", object, [null]);
            G.call("ui.UIElement", "set_appear", object, [true]);
            var title = G.field(object, "title");
            var center = G.enumeration("h2d.Align", "Center");
            G.call("h2d.Text", "set_textAlign", title, [center]);
            style(title, "text-align", center);
            setText(title, message);
            rows.unshift({id: id, category: category, object: object, title: title, expires: now + duration});
            if (rows.length > 3) G.call("h2d.Object", "remove", rows.pop().object);
            update(true, now);
        } catch (e:Dynamic) { G.call("h2d.Object", "remove", object); throw e; }
    }

    public function update(active:Bool, now:Float):Void {
        if (!active || owner != G.current("ui.BaseUI", "current")) { clear(); return; }
        if (rows.length == 0) return;
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var width = Std.int(Math.max(1, Math.min(900, bottom.x - top.x - 40)));
        var y = top.y + (bottom.y - top.y) * 0.18;
        for (row in rows.copy()) {
            var enabled = switch (row.category) {
                case "boss": config.showBossKills;
                case "incomplete": config.showIncompleteCodexKills;
                default: config.showCompletedCodexKills;
            };
            if (now >= row.expires || !enabled) {
                rows.remove(row); G.call("h2d.Object", "remove", row.object); continue;
            }
            G.call("ui.comp.FmtText", "set_maxWidthText", row.title, [width]);
            G.call("ui.comp.FmtText", "updateScale", row.title);
            G.call("h2d.Flow", "reflow", row.object);
            var bounds = G.call("h2d.Object", "getBounds", row.title, [row.object, null]);
            var left = G.number(G.field(bounds, "xMin"));
            var right = G.number(G.field(bounds, "xMax"));
            var textTop = G.number(G.field(bounds, "yMin"));
            var textBottom = G.number(G.field(bounds, "yMax"));
            // Center the rendered text, regardless of the native flow's padding.
            position(row.object, (top.x + bottom.x - left - right) / 2, y - textTop);
            G.set(row.object, "alpha", Math.min(1, (row.expires - now) / fade));
            y += textBottom - textTop + 8;
        }
    }

    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }

    public function clear():Void {
        var old = rows; rows = []; owner = null; root = null;
        for (row in old) G.call("h2d.Object", "remove", row.object);
    }
}
