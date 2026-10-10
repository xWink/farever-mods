package itemutilities;

import hlx.runtime.HlxPrefixResult;
import hlx.runtime.PatchTargetKey;
import itemutilities.InspectAccess as G;
import itemutilities.InspectMenuContext.InspectTarget;

/** Add Inspect to player interaction and Social window gear menus. */
class PlayerInspect {
    static final menuKey = new PatchTargetKey("ui.GameUI", "openPlayerInteractionMenu");
    static final contextKey = new PatchTargetKey("ui.BaseUI", "displayContextMenu");
    static final actionsKey = new PatchTargetKey("ui.UIElement", "onActionsMenu");
    static final tooltipKey = new PatchTargetKey("ui.Tooltip", "sync");
    static var context = new InspectMenuContext();
    static var isEnabled:Void->Bool;
    static var requested:InspectTarget;
    static var popup:InspectWindow;
    static var active = false;
    static var reportedMenuIssue = false;

    public static function initialize(enabled:Void->Bool):Void {
        isEnabled = enabled;
        try {
            // Register now; HLX resolves these hooks after module recovery.
            HlxRuntime.registerPrefix(menuKey, beginMenu, receiveMenu);
            HlxRuntime.registerPostfix(menuKey, endMenu, receiveMenu);
            HlxRuntime.registerPrefix(actionsKey, beginActionsMenu, receiveActions);
            HlxRuntime.registerPostfix(actionsKey, endActionsMenu, receiveActions);
            HlxRuntime.registerPrefix(contextKey, extendMenu, receiveContext);
            HlxRuntime.registerPostfix(tooltipKey, fitInspectTooltip, receiveTooltip);
            active = true;
        } catch (error:Dynamic) trace("[Item Utilities] Inspect unavailable: " + error);
    }
    static function receiveMenu(ui:Dynamic, uid:String, name:String, position:Dynamic):Dynamic
        return HlxRuntime.dispatch(menuKey, [ui, uid, name, position]);
    static function receiveContext(ui:Dynamic, items:Dynamic, position:Dynamic):Dynamic
        return HlxRuntime.dispatch(contextKey, [ui, items, position]);
    static function receiveActions(button:Dynamic):Dynamic
        return HlxRuntime.dispatch(actionsKey, [button]);
    static function receiveTooltip(tip:Dynamic, context:Dynamic):Dynamic
        return HlxRuntime.dispatch(tooltipKey, [tip, context]);
    static function fitInspectTooltip(tip:Dynamic, context:Dynamic, result:Dynamic):Dynamic {
        if (popup != null) popup.fitTooltip(tip);
        return result;
    }
    static function beginMenu(ui:Dynamic, uid:String, name:String, position:Dynamic):HlxPrefixResult<Void> {
        context.begin(ui, uid, name, isEnabled());
        return Continue;
    }
    static function endMenu(ui:Dynamic, uid:String, name:String, position:Dynamic, result:Dynamic):Dynamic {
        if (context.take(ui) != null && result != null && isEnabled())
            reportMenuIssue("The social menu opened without reaching the context-menu hook");
        context.clear();
        return result;
    }
    static function beginActionsMenu(button:Dynamic):HlxPrefixResult<Dynamic> {
        context.clear();
        if (!isEnabled()) return Continue;
        try {
            var target = InspectTargets.fromSocialButton(button);
            if (target != null) context.begin(target.ui, target.uid, target.name, true, true);
        } catch (error:Dynamic) reportMenuIssue(Std.string(error));
        return Continue;
    }
    static function endActionsMenu(button:Dynamic, result:Dynamic):Dynamic {
        context.clear();
        return result;
    }
    static function extendMenu(ui:Dynamic, items:Dynamic, position:Dynamic):HlxPrefixResult<Void> {
        var target = context.take(ui);
        if (target == null || !isEnabled()) return Continue;
        try {
            var icons = G.field(G.current("Data", "icon"), "byId");
            var icon = G.call("haxe.ds.StringMap", "get", icons, ["SendMessage"]);
            if (icon == null) {
                reportMenuIssue("SendMessage icon metadata was not available");
                return Continue;
            }
            var sendMessage = G.text(G.staticCall("HText", "icon", [icon, null]));
            var index = InspectMenuContext.insertionIndex(
                [for (item in G.array(items)) G.text(G.field(item, "label"))], sendMessage, target.fromSocialWindow == true);
            if (index >= 0) {
                var entry:Dynamic = {label: "Inspect", onClick: function():Void {
                    // Open on the next UI frame, after the context menu finishes closing.
                    if (isEnabled()) requested = target;
                }};
                G.call("hl.types.ArrayObj", "insertDyn", items, [index, entry]);
            } else reportMenuIssue("The social menu did not contain the expected Send message label");
        } catch (error:Dynamic) reportMenuIssue(Std.string(error));
        return Continue;
    }
    static function reportMenuIssue(message:String):Void {
        if (reportedMenuIssue) return;
        reportedMenuIssue = true;
        trace("[Item Utilities] Could not add Inspect: " + message);
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
                if (target.ui == ui) {
                    var local = localHero();
                    if (InspectTargets.available(remoteHero(local, target.uid))) {
                        popup = new InspectWindow();
                        popup.open(target, local);
                    } else chatError(ui, "Cannot inspect " + (target.name == null || target.name == "" ? "this player" : target.name)
                        + ". Their character or equipment is unavailable. Try again when they are nearby.");
                }
            }
            if (popup != null && !popup.update(ui, localHero())) close();
        } catch (error:Dynamic) {
            close();
            trace("[Item Utilities] Could not display Inspect: " + error);
            chatError(G.current("ui.BaseUI", "current"), "Could not inspect this player. Please try again.");
        }
    }
    static function chatError(ui:Dynamic, message:String):Void {
        try {
            if (ui == null || !G.isA(ui, "ui.GameUI")) return;
            var chat = G.call("ui.GameUI", "get_chat", ui);
            if (chat != null) G.call("ui.hud.ChatBox", "chatError", chat, [InspectUi.escape(message)]);
        } catch (error:Dynamic) trace("[Item Utilities] Could not show Inspect error: " + error);
    }
    static function close():Void {
        if (popup == null) return;
        var old = popup; popup = null;
        old.dispose();
        InspectTooltips.clear();
    }
    public static function localHero():Dynamic {
        var controller = G.current("client.PlayerController", "inst");
        return controller == null ? null : G.call("client.PlayerController", "get_hero", controller);
    }
    public static function remoteHero(local:Dynamic, uid:String):Dynamic {
        return InspectTargets.remoteHero(local, uid);
    }
}
