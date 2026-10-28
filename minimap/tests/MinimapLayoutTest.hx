import minimap.GameAccess as G;
import minimap.MinimapSettings;
import minimap.MinimapView;

@:access(minimap.MinimapView)
class MinimapLayoutTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var scene:Dynamic = {width:1920, height:1080};
        // Opening Talents invalidates the root before App.render applies styles.
        // The native boundary deliberately has no Flow sizing/reflow methods:
        // calling one would both fail this test and lay out unrelated windows.
        var root:Dynamic = {needReflow:true, calculatedWidth:0., calculatedHeight:0.,
            paddingLeft:0, paddingRight:0, paddingTop:0, paddingBottom:0};
        var view = new MinimapView();
        view.owner = {s2d:scene}; view.root = root;
        view.panel = G.create("h2d.Object", [root]); view.size = 250;
        var config:MinimapSettings = cast {xOffset:0., yOffset:0.};
        eq(view.updatePosition(config), true, "Position available before first native layout");
        eq(view.panel.x, 1640., "Right margin uses UI scene width");
        eq(view.panel.y, 24., "Top margin preserved");
        eq(root.needReflow, true, "Pending talent layout is left for the renderer");
        eq(root.calculatedWidth, 0., "Root is not measured early");

        // Talent hover rebuilds its details. Neither pending nor previously
        // measured window sizes may move the HUD or clear its hover state.
        view.hovered = true;
        for (width in [1860., 1200., 2400., 0., 1920.]) {
            root.calculatedWidth = width; root.calculatedHeight = width / 2;
            root.needReflow = true;
            eq(view.updatePosition(config), true, "Hover update has a stable viewport");
            eq(view.panel.x, 1640., "Talent details cannot shift minimap horizontally");
            eq(view.panel.y, 24., "Talent details cannot shift minimap vertically");
            eq(view.hovered, true, "Unrelated UI invalidation does not clear map hover");
            eq(root.needReflow, true, "Hover does not force a global reflow");
        }

        config.yOffset = 100;
        // These are already scaled scene units, not physical monitor pixels.
        scene.width = 1280; scene.height = 720;
        eq(view.updatePosition(config), true, "Live UI scale/resize updates position");
        eq(view.panel.x, 1000., "Resize keeps right margin");
        eq(view.panel.y, 440., "Resize keeps bottom margin");
        eq(view.hovered, false, "Actual position changes clear stale hover");
        eq(view.viewportWidth, 1280., "Filter rail shares scaled viewport width");
        eq(view.viewportHeight, 720., "Filter rail shares scaled viewport height");

        root.paddingLeft = 10; root.paddingRight = 20;
        root.paddingTop = 5; root.paddingBottom = 15;
        view.updatePosition(config);
        eq(view.panel.x, 970., "Preserves root inner-width padding semantics");
        eq(view.panel.y, 420., "Preserves root inner-height padding semantics");
        scene.width = 0; scene.height = 0;
        eq(view.updatePosition(config), false, "Unavailable scene is deferred without measuring root");
        eq(view.panel.x, 970., "Unavailable scene does not move existing panel");
        scene.width = 1280; scene.height = 720;
        eq(view.updatePosition(config), true, "Scene becoming available restores layout");

        view.dispose();
        eq(view.viewportWidth, 0., "Disposal clears viewport width");
        eq(view.viewportHeight, 0., "Disposal clears viewport height");
        Sys.println('Minimap layout tests passed ($checks checks)');
    }
}
