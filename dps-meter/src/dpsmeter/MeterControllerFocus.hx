package dpsmeter;

import dpsmeter.GameAccess as G;

/** Keep the persistent live meter out of the game's controller focus stack. */
class MeterControllerFocus {
    static var root:Dynamic;

    public static function track(window:Dynamic):Void {
        root = window;
        configureNode(window);
    }

    public static function forget(window:Dynamic):Void {
        if (root == window) root = null;
    }

    public static function configureNode(object:Dynamic):Void {
        if (root == null || object == null) return;
        var ancestor = object;
        while (ancestor != null && ancestor != root) ancestor = G.field(ancestor, "parent");
        if (ancestor == root) releaseTree(object);
    }

    static function releaseTree(object:Dynamic):Void {
        // Native controls can contain their own focusable children or layers.
        // Release those first, before their parent's bindings are reparented.
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        for (i in 0...count) releaseTree(G.call("h2d.Object", "getChildAt", object, [i]));
        // Plain Flow/Graphics/Interactive objects have no controller state.
        if (G.field(object, "isBindLayer") == null) return;
        G.call("ui.UIElement", "set_padDefaultFocus", object, [false]);
        G.call("ui.UIElement", "set_padFocusable", object, [false]);
        G.set(object, "padAlwaysFocusable", false);
        G.call("ui.UIElement", "set_padClick", object, [null]);
        G.call("ui.UIElement", "set_padHover", object, [null]);
        // Clearing windowFlags after TitleWindow construction does not undo
        // AutoRegisterLayer. Its native setter must unregister the input layer.
        G.call("ui.UIElement", "set_isBindLayer", object, [false]);
        var dom = G.field(object, "dom");
        if (dom == null) return;
        // Clickable/hover/controller-mode styles must not reclaim focus later.
        for (property in ["pad-default-focus", "pad-focusable", "pad-always-focusable", "is-bind-layer"])
            G.call("domkit.Properties", "initStyle", dom, [property, false]);
        for (property in ["pad-click", "pad-hover"])
            G.call("domkit.Properties", "initStyle", dom, [property, null]);
        // Mouse callbacks and interactives are deliberately left enabled.
    }
}
