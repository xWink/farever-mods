package bettermodsettings;

/** Give the companion window the menu's lifetime rules before native rebuild. */
class NativeSettingsWindow {
    static var menu:Dynamic;
    public static var creating(get, never):Bool;
    static function get_creating():Bool return menu != null;

    public static function create(escapeMenu:Dynamic):Dynamic {
        if (escapeMenu == null) throw "Native Game Menu was not found";
        menu = escapeMenu;
        try {
            var window = HlxRuntime.constructInstanceByName(
                HlxRuntime.resolveType("ui.win.TitleWindow"), 2, ["Options", null]);
            menu = null;
            return window;
        } catch (error:Dynamic) {
            menu = null;
            throw error;
        }
    }

    public static function beforeRebuild(window:Dynamic):Void {
        if (menu == null || window == menu) return;
        // TitleWindow's default flags require a live world. BaseElement calls
        // rebuild inside its constructor, so copying flags afterward is too late
        // on character select: the native rebuild has already skipped its DOM.
        var flags = HlxRuntime.resolveField(menu, "windowFlags");
        if (flags == null) throw "Native Game Menu window flags were not found";
        var setter = HlxRuntime.resolveMember(HlxRuntime.resolveType("ui.win.BaseWindow"), "set_windowFlags");
        HlxRuntime.callResolved(setter, [window, flags]);
    }
}
