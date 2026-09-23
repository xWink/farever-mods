package itemutilities;

import hlx.runtime.HlxPrefixResult;
import hlx.runtime.PatchTargetKey;
import itemutilities.InspectAccess as G;
import itemutilities.InspectMenuContext.InspectTarget;

/** Optional PTR hook. Live clients without the social menu are left untouched. */
class PlayerInspect {
    static final menuKey = new PatchTargetKey("ui.GameUI", "openPlayerInteractionMenu");
    static final contextKey = new PatchTargetKey("ui.BaseUI", "displayContextMenu");
    static var context = new InspectMenuContext();
    static var isEnabled:Void->Bool;
    static var requested:InspectTarget;
    static var popup:InspectWindow;
    static var active = false;

    public static function initialize(enabled:Void->Bool):Void {
        isEnabled = enabled;
        try {
            if (!G.hasMethod("ui.GameUI", "openPlayerInteractionMenu")) return;
            HlxRuntime.registerPrefix(menuKey, beginMenu, receiveMenu);
            HlxRuntime.registerPostfix(menuKey, endMenu, receiveMenu);
            HlxRuntime.registerPrefix(contextKey, extendMenu, receiveContext);
            active = true;
        } catch (error:Dynamic) trace("[Item Utilities] Inspect unavailable: " + error);
    }
    static function receiveMenu(ui:Dynamic, uid:String, name:String, position:Dynamic):Dynamic
        return HlxRuntime.dispatch(menuKey, [ui, uid, name, position]);
    static function receiveContext(ui:Dynamic, items:Dynamic, position:Dynamic):Dynamic
        return HlxRuntime.dispatch(contextKey, [ui, items, position]);
    static function beginMenu(ui:Dynamic, uid:String, name:String, position:Dynamic):HlxPrefixResult<Void> {
        context.begin(ui, uid, name, isEnabled());
        return Continue;
    }
    static function endMenu(ui:Dynamic, uid:String, name:String, position:Dynamic, result:Dynamic):Dynamic {
        context.clear();
        return result;
    }
    static function extendMenu(ui:Dynamic, items:Dynamic, position:Dynamic):HlxPrefixResult<Void> {
        var target = context.take(ui);
        if (target == null || !isEnabled()) return Continue;
        try {
            var icons = G.field(G.current("Data", "icon"), "byId");
            var icon = G.call("haxe.ds.StringMap", "get", icons, ["SendMessage"]);
            if (icon == null) return Continue;
            var sendMessage = G.text(G.staticCall("HText", "icon", [icon, null]));
            var index = InspectMenuContext.insertionIndex(
                [for (item in G.array(items)) G.text(G.field(item, "label"))], sendMessage);
            if (index >= 0) {
                var entry:Dynamic = {label: "Inspect", onClick: function():Void {
                    // Open on the next UI frame, after the context menu finishes closing.
                    if (isEnabled()) requested = target;
                }};
                G.call("hl.types.ArrayObj", "insertDyn", items, [index, entry]);
            }
        } catch (error:Dynamic) trace("[Item Utilities] Could not add Inspect: " + error);
        return Continue;
    }
    public static function update():Void {
        if (!active) return;
        context.clear();
        if (requested == null && popup == null) return;
        try {
            var ui = G.current("ui.BaseUI", "current");
            if (!isEnabled()) { requested = null; close(); return; }
            if (requested != null) {
                var target = requested; requested = null;
                close();
                if (target.ui == ui && localHero() != null) {
                    popup = new InspectWindow();
                    popup.open(target, localHero());
                }
            }
            if (popup != null && !popup.update(ui, localHero())) close();
        } catch (error:Dynamic) {
            close();
            trace("[Item Utilities] Could not display Inspect: " + error);
        }
    }
    static function close():Void {
        if (popup == null) return;
        var old = popup; popup = null;
        old.dispose();
    }
    public static function localHero():Dynamic {
        var controller = G.current("client.PlayerController", "inst");
        return controller == null ? null : G.call("client.PlayerController", "get_hero", controller);
    }
    public static function remoteHero(local:Dynamic, uid:String):Dynamic {
        var layer = G.field(G.field(local, "player"), "layer");
        if (layer == null) return null;
        return G.field(G.call("st.GameLayer", "getPlayerById", layer, [uid]), "hero");
    }
}
