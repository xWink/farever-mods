package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Native scrolling over a fixed-height canvas; only visible cards are children. */
class NativeHistoryScroll {
    public final state:HistoryScroll;
    public final dom:Dynamic;
    public final content:Dynamic;
    final viewport:Dynamic;
    final scrollbar:NativeHistoryScrollbar;
    var restoreTo:Null<Float>;
    var width = -1;
    var height = -1;
    public function new(list:Dynamic, id:String, state:HistoryScroll) {
        this.state = state; viewport = G.field(list, "obj");
        dom = node("element", list, [], id); content = G.field(dom, "obj"); padding(content, 0);
        var top = G.enumeration("h2d.FlowAlign", "Top"), left = G.enumeration("h2d.FlowAlign", "Left");
        G.call("h2d.Flow", "set_verticalAlign", viewport, [top]); style(viewport, "content-valign", top);
        G.call("h2d.Flow", "set_horizontalAlign", viewport, [left]); style(viewport, "content-halign", left);
        var properties = G.call("h2d.Flow", "getProperties", viewport, [content]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [false]); style(content, "position", false);
        G.set(properties, "verticalAlign", top); G.set(properties, "horizontalAlign", left);
        style(content, "valign", top); style(content, "halign", left);
        scrollbar = new NativeHistoryScrollbar(viewport);
        var previous = G.field(viewport, "onAfterReflow");
        G.set(viewport, "onAfterReflow", () -> {
            if (previous != null) Reflect.callMethod(viewport, previous, []);
            if (restoreTo != null) {
                var value:Float = restoreTo; restoreTo = null;
                G.call("h2d.Flow", "set_scrollPosY", viewport, [value]);
            }
        });
    }
    public function restore(offset:Float):Void {
        state.offset = Math.max(0, offset); restoreTo = state.offset;
        G.call("h2d.Flow", "set_needReflow", viewport, [true]);
    }
    public function sync():Void {
        if (restoreTo == null) state.offset = G.number(G.field(viewport, "scrollPosY"));
    }
    public function resize(w:Int):Void {
        var h = Std.int(Math.ceil(state.contentHeight()));
        if (width == w && height == h) return;
        width = w; height = h; size(content, w, h);
        G.call("h2d.Flow", "set_needReflow", viewport, [true]);
    }
    public function viewportHeight():Float return G.number(G.call("h2d.Flow", "get_innerHeight", viewport));
    public function updateScrollbar():Void scrollbar.update();
}
