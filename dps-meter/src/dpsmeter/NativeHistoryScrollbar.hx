package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Paint beside the viewport, leaving the native scrollbar's input and children intact. */
class NativeHistoryScrollbar {
    final viewport:Dynamic;
    final paint:Dynamic;
    var configuredBar:Dynamic;
    var configuredWidth = -1.0;
    var last:Array<Float> = [];
    public function new(viewport:Dynamic) {
        this.viewport = viewport;
        var parent = G.field(viewport, "parent");
        paint = G.create("h2d.Graphics", [parent]); absolute(parent, paint); show(paint, false);
    }
    public function update():Void {
        var bar = G.field(viewport, "scrollBar"), thumb = G.field(viewport, "scrollBarCursor");
        if (G.field(viewport, "visible") == false || bar == null || thumb == null || G.field(bar, "visible") == false) {
            show(paint, false); return;
        }
        var width = G.number(G.call("h2d.Flow", "get_outerWidth", viewport));
        if (bar != configuredBar || width != configuredWidth) {
            // Native Right alignment can put the transparent bar outside the clip.
            absolute(viewport, bar); padding(bar, 0); size(bar, 10); size(thumb, 10);
            position(bar, Math.max(0, width - 14), 0);
            configuredBar = bar; configuredWidth = width;
        }
        var height = G.number(G.call("h2d.Flow", "get_outerHeight", bar));
        var thumbHeight = G.number(G.call("h2d.Flow", "get_outerHeight", thumb));
        if (height <= 0 || thumbHeight <= 0) { show(paint, false); return; }
        thumbHeight = Math.min(height, thumbHeight);
        var x = G.number(G.field(viewport, "x")) + G.number(G.field(bar, "x"));
        var y = G.number(G.field(viewport, "y")) + G.number(G.field(bar, "y"));
        // Use native geometry, including the home page's recent-fight rows.
        var thumbY = Math.max(0, Math.min(height - thumbHeight, G.number(G.field(thumb, "y"))));
        show(paint, true);
        var values = [x, y, height, thumbHeight, thumbY];
        var changed = last.length != values.length;
        for (i in 0...values.length) if (!changed && values[i] != last[i]) changed = true;
        if (!changed) return;
        position(paint, x, y); G.call("h2d.Graphics", "clear", paint);
        rounded(0xB69B7F, .60, 0, height);
        rounded(0x806B5B, 1, thumbY, thumbHeight);
        last = values;
    }
    function rounded(color:Int, alpha:Float, y:Float, height:Float):Void {
        var radius = Math.min(5, height / 2);
        // Match Marketplace's soft subpixel edge without a per-frame blur pass.
        fill(color, alpha * .18, -.55, y - .55, 11.1, height + 1.1, radius + .55);
        fill(color, alpha * .45, -.25, y - .25, 10.5, height + .5, radius + .25);
        fill(color, alpha, 0, y, 10, height, radius);
    }
    function fill(color:Int, alpha:Float, x:Float, y:Float, width:Float, height:Float, radius:Float):Void {
        var segments = 24;
        #if hl
        var c:hl.Ref<Int> = color, a:hl.Ref<Float> = alpha, count:hl.Ref<Int> = segments;
        #else
        var c = color, a = alpha, count = segments;
        #end
        G.call("h2d.Graphics", "beginFill", paint, [c, a]);
        G.call("h2d.Graphics", "drawRoundedRect", paint, [x, y, width, height, radius, count]);
        G.call("h2d.Graphics", "endFill", paint);
    }
}
