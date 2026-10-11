package moresettings;

import moresettings.GameAccess as G;

/** A native overhead chat bubble without the local player's name/health widget. */
class SelfChatBubbles {
    static var enabled = false;
    static var hero:Dynamic;
    static var object:Dynamic;
    static var ui:Dynamic;
    static var widget:Dynamic;
    static var bubble:Dynamic;
    static var pending:Dynamic;
    static var pendingClient:Dynamic;

    public static function configure(value:Bool):Void {
        enabled = value;
        if (!enabled) dispose();
    }

    public static function received(client:Dynamic, message:Dynamic):Void {
        if (!enabled || G.field(message, "notify") != null) return;
        var player = G.field(client, "player");
        var sender = G.field(message, "sender");
        var uid = G.text(G.field(player, "uid"));
        if (G.field(player, "isMe") != true || G.field(player, "chatClient") != client
            || uid == "" || G.text(G.field(sender, "uid")) != uid || G.text(G.field(message, "text")) == "") return;
        var channel = G.field(message, "channel");
        if (channel == null) return;
        switch (Type.enumConstructor(channel)) {
            case "Group", "All": pending = message; pendingClient = client;
            // Native ChatBubble already handles Local. A newer Local message
            // supersedes queued Group/All text from the same frame.
            case "Local": pending = null; pendingClient = null;
            default:
        }
    }

    public static function update(app:Dynamic):Void {
        if (!enabled) return;
        var nextHero = G.field(app, "hero");
        var nextObject = G.field(nextHero, "obj");
        var nextUi = G.current("ui.BaseUI", "current");
        if (nextHero == null || G.field(nextHero, "removed") == true || nextObject == null
            || !G.isA(nextUi, "ui.GameUI")
            || G.field(G.field(nextHero, "player"), "chatClient") == null) {
            dispose();
            return;
        }
        var message = pending, client = pendingClient;
        pending = null; pendingClient = null;
        if (hero != nextHero || object != nextObject || ui != nextUi || widget == null
            || G.field(widget, "removed") == true || G.field(widget, "parent") == null) {
            dispose();
            hero = nextHero;
            object = nextObject;
            ui = nextUi;
            try {
                var follow = G.enumValue("ui.EWidgetFollowType", "EFollow", [object, null]);
                widget = G.create("ui.Widget", [follow, ui, null]);
                // UnitWidget creates ChatBubble inside the native styled DOM.
                // Build it before attaching, just like GameObject.createWidget;
                // a bare ChatBubble skips the normal widget styling context.
                // HeroWidget adds the name/health UI; UnitWidget only adds chat.
                var component = G.create("ui.hud.UnitWidget", [hero, null]);
                G.call("h2d.Object", "addChild", G.field(widget, "container"), [component]);
                var count = Std.int(G.number(G.call("h2d.Object", "get_numChildren", component)));
                for (i in 0...count) {
                    var child = G.call("h2d.Object", "getChildAt", component, [i]);
                    if (G.isA(child, "ui.hud.ChatBubble")) { bubble = child; break; }
                }
                if (bubble == null) throw "Native self chat bubble was not found";
            } catch (error:Dynamic) {
                dispose();
                throw error;
            }
        }
        var offset = G.field(G.current("Const", "UI"), "WidgetHeightOffset");
        G.set(widget, "offsetZ", G.number(G.field(hero, "height")) + G.number(offset));
        // Advance this bubble's reader so an older queued Local message cannot
        // overwrite newer Group/All text on the next native UI update. Other
        // chat readers keep their own indices and see the unchanged history.
        if (message != null && client == G.field(G.field(hero, "player"), "chatClient")) {
            var history = G.call("st.player.ChatClient", "poll", client, [null]);
            G.set(bubble, "messageIndex", G.field(history, "index"));
            // Native open keeps the usual background, filtering and timeout.
            G.call("ui.hud.ChatBubble", "open", bubble, [message]);
        }
    }

    public static function dispose():Void {
        var old = widget;
        widget = null;
        bubble = null;
        pending = null; pendingClient = null;
        hero = null;
        object = null;
        ui = null;
        if (old != null && G.field(old, "parent") != null) G.call("h2d.Object", "remove", old);
    }
}
