import moresettings.SelfChatBubbles as Bubbles;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class SelfChatBubblesTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw '$why: expected $expected, got $actual';
    }
    static function hero():Dynamic return {height: 1.8, obj: {}, player: {chatClient: {}}, removed: false};
    static function main():Void {
        eq(SettingsData.defaults().showSelfChatBubbles, false, "self bubbles are opt-in");
        G.ui = {type: "ui.GameUI", widgets: []};
        var app:Dynamic = {hero: hero()};
        Bubbles.configure(false); Bubbles.update(app);
        eq(G.bubbles.length, 0, "disabled setting creates no UI");
        Bubbles.configure(true);
        eq(G.bubbles.length, 0, "configuration does not access game types during startup");
        Bubbles.update(app);
        eq(G.ui.widgets.length, 1, "one native overhead widget");
        eq(G.bubbles.length, 1, "one native bubble");
        var widget:Dynamic = G.ui.widgets[0];
        eq(G.bubbles[0].unit, app.hero, "bubble filters for the local hero's sender identity");
        eq(G.bubbles[0].parent, widget.container, "native bubble is anchored inside the widget");
        eq(widget.followType.object, app.hero.obj, "widget follows the character model");
        eq(widget.offsetZ, 2.05, "uses the normal overhead height offset");
        Bubbles.update(app); Bubbles.configure(true); Bubbles.update(app);
        eq(G.bubbles.length, 1, "updates and unrelated settings changes never duplicate or reset the bubble");
        app.hero.height = 2.0; Bubbles.update(app);
        eq(widget.offsetZ, 2.25, "height changes update the anchor");
        app.hero.obj = {}; Bubbles.update(app);
        eq(widget.removed, true, "replaced model removes old widget");
        eq(G.ui.widgets.length, 1, "model replacement retains one widget");
        eq(G.bubbles[1].parent.parent.followType.object, app.hero.obj, "new widget follows replacement model");
        var oldUi:Dynamic = G.ui;
        G.ui = {type: "ui.GameUI", widgets: []}; Bubbles.update(app);
        eq(oldUi.widgets.length, 0, "scene changes detach old UI");
        eq(G.ui.widgets.length, 1, "scene change attaches new UI");
        Bubbles.configure(false);
        eq(G.ui.widgets.length, 0, "turning off removes any visible bubble immediately");
        Bubbles.configure(true); Bubbles.update(app); Bubbles.dispose();
        eq(G.ui.widgets.length, 0, "leaving the game cleans up");
        app.hero = hero(); Bubbles.update(app);
        eq(G.bubbles[G.bubbles.length - 1].unit, app.hero, "next character receives its own bubble");
        app.hero.removed = true; Bubbles.update(app);
        eq(G.ui.widgets.length, 0, "removed hero clears the bubble");
        app.hero.removed = false; app.hero.player.chatClient = null; Bubbles.update(app);
        eq(G.ui.widgets.length, 0, "waits until local chat is ready");
        app.hero.player.chatClient = {}; G.fail = true;
        var failed = false;
        try Bubbles.update(app) catch (_:Dynamic) failed = true;
        eq(failed, true, "native constructor error is reportable");
        eq(G.ui.widgets.length, 0, "failed bubble creation cleans up its widget");
        G.fail = false; Bubbles.update(app);
        eq(G.ui.widgets.length, 1, "initialization can recover");
        oldUi = G.ui; G.ui = {type: "ui.LobbyUI", widgets: []}; Bubbles.update(app);
        eq(oldUi.widgets.length, 0, "lobby transition removes gameplay bubble");
        eq(G.ui.widgets.length, 0, "lobby receives no bubble");
        Bubbles.dispose();
        Sys.println('Self chat bubbles: $checks checks passed.');
    }
}
