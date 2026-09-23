import itemutilities.OverlayRect;
import itemutilities.PresetDropdownState;

class PresetDropdownStateTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function main():Void {
        for (kind in 0...4) {
            var state = new PresetDropdownState();
            check(state.covered(kind, true, false), "closed controls respect native tooltips");
            state.beginFrame();
            state.update(kind, true, new OverlayRect(100, 200, 236, 370));
            state.endFrame();
            check(state.inputBounds() != null && state.inputBounds().left == 100
                && state.inputBounds().bottom == 370, "all preset menus provide their native input capture bounds");
            // Regression: a skill tooltip appears underneath an already-open
            // menu and overlaps its anchor on a subsequent draw frame.
            state.beginFrame();
            check(!state.covered(kind, true, false), "background tooltips cannot hide an open preset menu");
            check(state.covered((kind + 1) % 4, true, false), "other preset bars keep their tooltip occlusion");
            check(state.covered(kind, false, true) && state.covered(kind, true, true),
                "real covering windows still take precedence");
            check(state.blocksTooltip(120, 230), "hovering a dropdown option suppresses the underlying skill tooltip");
            check(!state.blocksTooltip(99, 230) && !state.blocksTooltip(236, 230)
                && !state.blocksTooltip(120, 199) && !state.blocksTooltip(120, 370),
                "native hover elsewhere is unaffected");
            state.update((kind + 1) % 4, false);
            check(state.isOpen(), "a different closed category does not close the active menu");
            state.update(kind, true, new OverlayRect(300, 400, 436, 570));
            state.endFrame();
            check(!state.blocksTooltip(120, 230) && state.blocksTooltip(320, 430), "bounds follow repositioning");
            check(state.inputBounds().left == 300 && state.inputBounds().bottom == 570,
                "native hit target follows the relocated popup instead of blocking the old position");
            state.update(kind, false);
            check(state.inputBounds() == null, "selecting an option or clicking outside removes the native hit target");
            check(!state.isOpen() && !state.blocksTooltip(320, 430), "selection/outside dismissal releases native hover");
            check(state.covered(kind, true, false), "normal tooltip occlusion resumes after closing");
            state.update(kind, true, new OverlayRect(100, 200, 236, 370));
            state.beginFrame();
            state.endFrame();
            check(!state.isOpen() && !state.blocksTooltip(120, 230),
                "hidden host, tab changes, or disabling the mod cannot leave stale hover suppression");
            check(state.inputBounds() == null, "hidden host or disabled mod cannot leave an invisible input blocker");
            state.update(kind, true, new OverlayRect(100, 200, 100, 370));
            check(state.inputBounds() == null, "unmeasured popup must not block an unrelated native area");
        }
        trace('Preset dropdowns: $checks checks passed');
    }
}
