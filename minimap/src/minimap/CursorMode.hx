package minimap;

import minimap.GameAccess as G;

/** Remembers the player's cursor mode and restores it when the large map closes. */
class CursorMode {
    static var app:Dynamic;
    static var previous:Null<Bool>;

    public static function engage(game:Dynamic):Void {
        if (previous != null || game == null) return;
        app = game;
        previous = requested(game);
        if (previous != true) G.set(game, "playerRequestedFreeCursor", true);
        apply();
    }

    public static function restore():Void {
        if (previous == null) return;
        var game = app;
        var mode = previous;
        previous = null;
        app = null;
        if (game != null) G.set(game, "playerRequestedFreeCursor", mode);
        if (game != null) try G.call("GameApp", "updateMouseLock", game) catch (_:Dynamic) {}
    }

    static function requested(game:Dynamic):Bool {
        var flag = G.field(game, "playerRequestedFreeCursor");
        if (flag != null) return flag == true;
        try return G.call("GameApp", "isCursorFree", game) == true catch (_:Dynamic) return false;
    }

    static function apply():Void {
        if (app == null) return;
        try G.call("GameApp", "updateMouseLock", app) catch (_:Dynamic) {}
    }
}
