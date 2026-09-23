package itemutilities;

import itemutilities.InspectAccess as G;

/** Give an ImGui popup a matching hit target in the game's native UI. */
class PresetDropdownInput {
    var input:Dynamic;
    var scene:Dynamic;
    var errorLogged = false;

    public function new() {}

    public function update(host:Dynamic, pixels:OverlayRect):Void {
        try {
            if (host == null || pixels == null) {
                remove();
                return;
            }
            var nextScene = G.call("h2d.Object", "getScene", host);
            var area = NativeUiLayout.localRect(nextScene, pixels);
            if (nextScene == null || area == null) {
                remove();
                return;
            }
            if (scene != nextScene) remove();
            if (input == null) {
                scene = nextScene;
                // ImGui still receives raw mouse input. This invisible native
                // target stops tabs, skills, and other controls behind the menu
                // from also reacting to that same hover, click, or wheel event.
                input = G.create("h2d.Interactive", [area.width, area.height, scene, null]);
                G.set(input, "propagateEvents", false);
                G.set(input, "cancelEvents", false);
                G.set(input, "enableRightButton", true);
                G.call("h2d.Interactive", "set_cursor", input, [G.current("hxd.Cursor", "Default")]);
            }
            G.set(input, "width", area.width);
            G.set(input, "height", area.height);
            G.call("h2d.Object", "setPosition", input, [area.left, area.top]);
            // Scene parenting avoids clipping at the host window's edge. Keep
            // the input order consistent with the popup drawn over native UI.
            var count:Int = G.call("h2d.Object", "get_numChildren", scene);
            if (G.call("h2d.Object", "getChildAt", scene, [count - 1]) != input)
                G.call("h2d.Object", "addChild", scene, [input]);
            G.call("h2d.Object", "syncPos", input);
        } catch (error:Dynamic) {
            remove();
            if (!errorLogged) {
                errorLogged = true;
                trace("[Item Utilities] Unable to capture preset dropdown input: " + error);
            }
        }
    }

    function remove():Void {
        if (input != null) G.call("h2d.Object", "remove", input);
        input = null;
        scene = null;
    }
}
