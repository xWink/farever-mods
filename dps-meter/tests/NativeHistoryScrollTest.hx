import dpsmeter.HistoryScroll;
import dpsmeter.NativeHistoryScroll;
import dpsmeter.GameAccess as G;

class NativeHistoryScrollTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var calls = 0;
        var viewport:Dynamic = {scrollPosY:0., innerHeight:400., onAfterReflow:() -> calls++, needReflow:false};
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
        Sys.println('Native history scroll: $checks checks passed');
    }
}
