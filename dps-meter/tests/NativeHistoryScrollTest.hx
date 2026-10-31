import dpsmeter.HistoryScroll;
import dpsmeter.NativeHistoryScroll;
import dpsmeter.GameAccess as G;

class NativeHistoryScrollTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var calls = 0;
        var viewport:Dynamic = {parent:{}, visible:true, width:818., height:400., x:20., y:100.,
            scrollPosY:0., innerHeight:400., onAfterReflow:() -> calls++, needReflow:false};
        var state = new HistoryScroll(57, 3, 114);
        var view = new NativeHistoryScroll({obj:viewport}, "events", state);
        state.accept(0, [for (i in 0...128) i], 100000); view.resize(800);
        check(view.content.height == 5699997 && view.content.width == 800, "The canvas represents every event without creating every row");
        check(view.content.properties.isAbsolute == false && view.content.properties.verticalAlign == "Top", "Canvas stays in normal top-aligned flow for native scrollbar measurements");
        view.restore(2850000); view.sync();
        check(state.offset == 2850000 && viewport.scrollPosY == 0, "Saved position survives until the resized canvas has reflowed");
        var reflow:Void->Void = viewport.onAfterReflow; reflow(); view.sync();
        check(calls == 1 && state.offset == 2850000 && viewport.scrollPosY == 2850000, "Native reflow restores a distant position and preserves the original callback");
        viewport.scrollPosY = 100.; view.sync(); reflow();
        check(state.offset == 100 && viewport.scrollPosY == 100, "Later reflows do not overwrite user scrolling");
        viewport.needReflow = false; view.resize(800);
        check(viewport.needReflow == false, "Unchanged dimensions avoid continuous native reflows");
        state.expanded = 1; view.resize(800);
        check(view.content.height == 5700111 && viewport.scrollPosY == 100, "Expanding details changes the scrollbar extent without resetting position");
        state.accept(0, [], 1); view.resize(800); view.restore(2850000); reflow(); view.sync();
        check(state.offset == 0, "Native clamping handles shorter results after filtering or deletion");
        check(view.viewportHeight() == 400, "Visible row range uses the native inner viewport height");
        var push = (_:Dynamic) -> {}, drag = (_:Dynamic) -> {};
        var bar:Dynamic = {height:400., width:0., x:818., y:0., visible:true, children:[], onPush:push};
        var thumb:Dynamic = {height:40., width:0., y:180., onDrag:drag};
        viewport.scrollBar = bar; viewport.scrollBarCursor = thumb;
        view.updateScrollbar(); var paint = G.paints[0];
        check(bar.x == 804 && bar.width == 10 && thumb.width == 10, "Native scrollbar is placed inside the reserved right margin");
        check(bar.onPush == push && thumb.onDrag == drag && bar.children.length == 0,
            "Painting preserves native track clicks, dragging, and child layout arrays");
        check(paint.visible && paint.absolute && paint.parent == viewport.parent && paint.x == 824 && paint.y == 100,
            "Visible graphics are an absolute sibling rather than a child of native scrollbar flows");
        var draws:Array<Array<Dynamic>> = paint.draws;
        check(draws.length == 6 && draws[5][1] == 180 && draws[5][3] == 40, "Skin follows native thumb geometry exactly, with two soft edge layers");
        var clears:Int = paint.clears; view.updateScrollbar();
        check(paint.clears == clears, "Stationary scrollbars are not repainted every frame");
        thumb.y = 320.; view.updateScrollbar(); draws = paint.draws;
        check(draws[5][1] == 320, "Wheel scrolling and dragging move the painted thumb");
        viewport.visible = false; view.updateScrollbar(); check(!paint.visible, "Changing history views hides the scrollbar skin");
        viewport.visible = true; bar.visible = false; view.updateScrollbar(); check(!paint.visible, "Lists that fit need no scrollbar");
        Sys.println('Native history scroll: $checks checks passed');
    }
}
