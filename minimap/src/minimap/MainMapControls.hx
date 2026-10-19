package minimap;

import minimap.GameAccess as G;

/** Use native movement/autorun handling while retaining other windows' locks. */
class MainMapControls {
    var movementWindows = new haxe.ds.ObjectMap<Dynamic, Bool>();
    var extendedWindows = new haxe.ds.ObjectMap<Dynamic, Bool>();
    var zoomRequests = new haxe.ds.ObjectMap<Dynamic, Float>();
    var keyboardFlag:Int = 0;
    public var suppressMapMovement(default, null):Bool = false;

    public function new() {}
    public function update(window:Dynamic, config:MinimapSettings):Void {
        var allow = config.enabled && config.mainMapMovement == true
            && G.call("ui.win.MapWindow", "isSelector", window) != true;
        if (allow) {
            if (keyboardFlag == 0) keyboardFlag = G.enumBit("ui.win.WindowFlags", "AllowKeyboardInput");
            var flags = G.integer(G.field(window, "windowFlags"));
            if (!movementWindows.exists(window)) movementWindows.set(window, (flags & keyboardFlag) != 0);
            if ((flags & keyboardFlag) == 0) G.call("ui.win.BaseWindow", "set_windowFlags", window, [flags | keyboardFlag]);
        } else restoreMovement(window);
        if (!config.enabled && extendedWindows.exists(window)) {
            extendedWindows.remove(window);
            G.call("ui.win.MapWindow", "clampTargetZoom", window);
        }
    }
    public function beginInputs(window:Dynamic):Void {
        suppressMapMovement = movementWindows.exists(window)
            && G.staticCall("gamepad.Pad", "get_active", []) != true;
    }
    public function endInputs():Void suppressMapMovement = false;
    public function filterMove(result:Dynamic):Dynamic {
        if (suppressMapMovement && result != null) {
            G.set(result, "x", 0.); G.set(result, "y", 0.);
        }
        return result;
    }
    public function beforeClamp(window:Dynamic, config:MinimapSettings):Void {
        if (config.enabled)
            zoomRequests.set(window, G.number(G.field(window, "targetZoom")));
        else zoomRequests.remove(window);
    }
    public function afterClamp(window:Dynamic):Void {
        if (!zoomRequests.exists(window)) return;
        var requested:Float = zoomRequests.get(window);
        zoomRequests.remove(window);
        // Keep the native anchor/panning math, then extend only the requested
        // end of its range: travel zooms farther out, the regular map farther in.
        var clamped = G.number(G.field(window, "targetZoom"));
        var travel = G.call("ui.win.MapWindow", "isSelector", window) == true;
        if (clamped > 0 && travel && requested < clamped) {
            G.set(window, "targetZoom", Math.max(requested, clamped * 0.5));
            extendedWindows.set(window, true);
        } else if (clamped > 0 && !travel && requested > clamped) {
            G.set(window, "targetZoom", Math.min(requested, clamped * 2));
            extendedWindows.set(window, true);
        }
    }
    function restoreMovement(window:Dynamic):Void {
        if (!movementWindows.exists(window)) return;
        var flags = G.integer(G.field(window, "windowFlags"));
        var original = movementWindows.get(window);
        G.call("ui.win.BaseWindow", "set_windowFlags", window,
            [original ? flags | keyboardFlag : flags & ~keyboardFlag]);
        movementWindows.remove(window);
    }
    public function remove(window:Dynamic):Void {
        restoreMovement(window);
        extendedWindows.remove(window); zoomRequests.remove(window);
        endInputs();
    }
    public function dispose():Void {
        for (window in [for (window in movementWindows.keys()) window]) restoreMovement(window);
        extendedWindows.clear(); zoomRequests.clear(); endInputs();
    }
}
