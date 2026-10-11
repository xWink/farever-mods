import moresettings.SelfChatBubbles as Bubbles;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class SelfChatBubblesTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw '$why: expected $expected, got $actual';
    }
    static function hero(uid:String = "me"):Dynamic {
        var player:Dynamic = {uid:uid, isMe:true}; player.chatClient = {player:player};
        return {height:1.8, obj:{}, player:player, removed:false};
    }
    static function message(text:String, channel:BubbleChannel, uid:String = "me"):Dynamic
        return {sender:{uid:uid}, text:text, channel:channel};
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
        eq(G.bubbles[0].parent.type, "ui.hud.UnitWidget", "bubble uses the native unit widget styling context");
        eq(G.bubbles[0].parent.parent, widget.container, "native unit widget is anchored inside the overhead widget");
        eq(widget.followType.object, app.hero.obj, "widget follows the character model");
        eq(widget.offsetZ, 2.05, "uses the normal overhead height offset");
        var client = app.hero.player.chatClient;
        for (channel in [Group, All]) {
            for (text in ["rc", "r", "nr", "cancelrc", "5", "4", "3", "2", "1", "GO", "ordinary chat"]) {
                var msg = message(text, channel);
                Bubbles.received(client, msg); Bubbles.update(app);
                eq(G.opened[G.opened.length - 1].message, msg, "own delivered Group/All text reaches native bubble");
                eq(G.opened[G.opened.length - 1].bubble, G.bubbles[0], "automatic messages reuse the styled native bubble");
            }
        }
        var opened = G.opened.length;
        Bubbles.update(app); eq(G.opened.length, opened, "message is displayed once, not refreshed every frame");
        for (channel in [Local, Player, System, AllSystem]) {
            Bubbles.received(client, message("r", channel)); Bubbles.update(app);
            eq(G.opened.length, opened, "Local stays native; private/system channels excluded");
        }
        var msg:Dynamic = message("r", Group); msg.notify = "system";
        Bubbles.received(client, msg);
        Bubbles.received(client, message("r", Group, "someone-else"));
        Bubbles.received(client, message("", Group));
        Bubbles.received({}, message("r", Group)); Bubbles.update(app);
        eq(G.opened.length, opened, "notifications, other senders, empty text, and unowned clients ignored");
        Bubbles.received(client, message("earlier group", Group));
        Bubbles.received(client, message("later local", Local)); Bubbles.update(app);
        eq(G.opened.length, opened, "later Local message supersedes queued Group message");
        Bubbles.received(client, message("earlier local", Local));
        var latest = message("latest all", All); Bubbles.received(client, latest); Bubbles.update(app);
        eq(G.opened[G.opened.length - 1].message, latest, "later All message supersedes Local");
        eq(G.bubbles[0].messageIndex, G.historyIndex, "native reader cannot replay older Local over newer All");
        Bubbles.received(client, message("4", Group)); latest = message("3", Group);
        Bubbles.received(client, latest); Bubbles.update(app);
        eq(G.opened[G.opened.length - 1].message, latest, "multiple deliveries display the latest text");
        Bubbles.update(app); Bubbles.configure(true); Bubbles.update(app);
        eq(G.bubbles.length, 1, "updates and unrelated settings changes never duplicate or reset the bubble");
        app.hero.height = 2.0; Bubbles.update(app);
        eq(widget.offsetZ, 2.25, "height changes update the anchor");
        app.hero.obj = {}; Bubbles.update(app);
        eq(widget.removed, true, "replaced model removes old widget");
        eq(G.ui.widgets.length, 1, "model replacement retains one widget");
        eq(G.bubbles[1].parent.parent.parent.followType.object, app.hero.obj, "new widget follows replacement model");
        var oldUi:Dynamic = G.ui;
        G.ui = {type: "ui.GameUI", widgets: []}; Bubbles.update(app);
        eq(oldUi.widgets.length, 0, "scene changes detach old UI");
        eq(G.ui.widgets.length, 1, "scene change attaches new UI");
        Bubbles.received(client, message("queued before disabling", Group));
        Bubbles.configure(false);
        eq(G.ui.widgets.length, 0, "turning off removes any visible bubble immediately");
        opened = G.opened.length;
        Bubbles.received(client, message("disabled", Group));
        Bubbles.configure(true); Bubbles.update(app);
        eq(G.opened.length, opened, "disabled messages and pending text are not replayed");
        Bubbles.received(client, message("old character", Group));
        Bubbles.dispose();
        eq(G.ui.widgets.length, 0, "leaving the game cleans up");
        app.hero = hero(); Bubbles.update(app);
        eq(G.bubbles[G.bubbles.length - 1].unit, app.hero, "next character receives its own bubble");
        eq(G.opened.length, opened, "disconnect clears pending messages");
        Bubbles.received(client, message("late old character message", Group));
        Bubbles.update(app); eq(G.opened.length, opened, "old chat client cannot display above a replacement hero");
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

enum BubbleChannel { Local; All; Group; Player; System; AllSystem; }
