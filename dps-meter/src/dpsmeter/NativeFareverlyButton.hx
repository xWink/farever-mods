package dpsmeter;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;
class NativeFareverlyButton {
    public var object(default, null):Dynamic;
    static var resource:Dynamic;
    var logo:Dynamic;
    var spinner:Dynamic;
    var busy:Null<Bool>;
    var enabled:Null<Bool>;
    var tip = "";
    public function new(parent:Dynamic, click:Void->Void) {
        object = button(parent, "", "dpsHistoryFareverly", click);
        padding(object, 0); size(object, 36, 36);
        if (resource == null) {
            var bytes = haxe.Resource.getBytes("dps-meter/fareverly-icon.png");
            if (bytes == null) throw "Embedded Fareverly icon is missing.";
            var raw:hl.Bytes = @:privateAccess bytes.b;
            var nativeBytes = G.create("haxe.io.Bytes", [raw, bytes.length]);
            resource = G.staticCall("hxd.res.Any", "fromBytes", ["fareverly-icon.png", nativeBytes]);
        }
        logo = G.create("h2d.Graphics", [object]); absolute(object, logo);
        var tile = G.call("hxd.res.Any", "toTile", resource);
        G.call("h2d.Graphics", "beginTileFill", logo, [0.0, 0.0, 1.0, 1.0, tile]);
        G.call("h2d.Graphics", "moveTo", logo, [90.0, 15.0]);
        // Clip the original image to the hexagon; the dark square is excluded.
        for (point in [[151.,51.], [151.,126.], [90.,165.], [29.,126.], [29.,51.], [90.,15.]])
            G.call("h2d.Graphics", "lineTo", logo, [point[0], point[1]]);
        G.call("h2d.Graphics", "endFill", logo);
        var scale = 32.0 / 150;
        G.call("h2d.Object", "setScale", logo, [scale]); position(logo, 18 - 90 * scale, 2 - 15 * scale); G.set(logo, "smooth", true);
        spinner = G.create("h2d.Graphics", [object]); absolute(object, spinner); position(spinner, 18, 18);
        for (i in 0...8) {
            var angle = i * Math.PI / 4;
            G.call("h2d.Graphics", "beginFill", spinner, [7426620, 0.2 + 0.8 * i / 7]);
            G.call("h2d.Graphics", "drawCircle", spinner, [Math.cos(angle) * 10, Math.sin(angle) * 10, 2.0, 12]);
            G.call("h2d.Graphics", "endFill", spinner);
        }
        update(false, true, 0);
    }
    public function update(loading:Bool, available:Bool, now:Float):Void {
        if (busy != loading) { busy = loading; show(logo, !loading); show(spinner, loading); }
        if (loading) G.call("h2d.Object", "set_rotation", spinner, [now * 5]);
        var clickable = available && !loading;
        if (enabled != clickable) { enabled = clickable; G.call("ui.UIElement", "set_enable", object, [clickable]); }
        var text = loading ? "Opening in Fareverly..." : available ? "Open in Fareverly" : "Not compatible with Fareverly";
        if (tip != text) { tip = text; NativeButtonTooltip.set(object, text); }
    }
}
