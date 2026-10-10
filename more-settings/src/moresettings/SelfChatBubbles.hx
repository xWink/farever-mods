package moresettings;

import moresettings.GameAccess as G;

/** A native overhead chat bubble without the local player's name/health widget. */
class SelfChatBubbles {
    static var enabled = false;
    static var hero:Dynamic;
    static var object:Dynamic;
    static var ui:Dynamic;
    static var widget:Dynamic;

    public static function configure(value:Bool):Void {
        enabled = value;
        if (!enabled) dispose();
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
            } catch (error:Dynamic) {
                dispose();
                throw error;
            }
        }
        var offset = G.field(G.current("Const", "UI"), "WidgetHeightOffset");
        G.set(widget, "offsetZ", G.number(G.field(hero, "height")) + G.number(offset));
    }

    public static function dispose():Void {
        var old = widget;
        widget = null;
        hero = null;
        object = null;
        ui = null;
        if (old != null && G.field(old, "parent") != null) G.call("h2d.Object", "remove", old);
    }
}
