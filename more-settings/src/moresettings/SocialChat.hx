package moresettings;

import moresettings.GameAccess as G;
import moresettings.SocialCommands.SocialCommand;

private typedef KnownPlayer = {var uid:String; var name:String; var player:Dynamic; var online:Bool;}

/** Dispatch chat commands through the game's native actions. */
class SocialChat {
    public static var commandsEnabled = false;
    public static var closeAfterSend = false;
    static var sendBox:Dynamic;
    static var submitted = false;
    static var closingInput:Dynamic;
    static var submitFrame = -1;
    static var seen:Array<KnownPlayer> = [];
    static inline var MAX_SEEN = 256;

    public static function begin(box:Dynamic):Void { sendBox = box; submitted = false; }
    public static function finish(box:Dynamic):Void {
        var close = sendBox == box && submitted && closeAfterSend;
        sendBox = null; submitted = false;
        if (!close) return;
        submitFrame = G.integer(G.staticCall("hxd.Key", "getFrame", []));
        closingInput = G.field(G.field(box, "messageInput"), "input");
        try G.call("ui.hud.ChatBox", "unfocus", box) catch (error:Dynamic) {
            closingInput = null;
            throw error;
        }
        closingInput = null;
    }
    public static function focusLost(input:Dynamic, event:Dynamic):Void {
        // Chat normally vetoes blur while the mouse is over its contents.
        // TextInput.blur already hid the cursor; accepting this explicit close
        // lets both FmtTextInput and SceneEvents finish releasing keyboard focus.
        if (input != null && input == closingInput) G.set(event, "cancel", false);
    }
    public static function chatPressed(key:String, result:Bool):Bool {
        if (key != "OpenChat" || !result || submitFrame < 0) return result;
        // Native input can poll the same Enter on the following frame as well.
        if (G.integer(G.staticCall("hxd.Key", "getFrame", [])) <= submitFrame + 1) return false;
        submitFrame = -1;
        return result;
    }
    public static function sent(client:Dynamic, message:Dynamic):Void {
        // Covers native sends and the local whisper echo. Incoming messages
        // outside an active submission cannot steal chat focus.
        if (sendBox != null && G.field(sendBox, "chatClient") == client
            && G.text(G.field(message, "text")) != "") submitted = true;
    }
    public static function clear():Void { sendBox = null; submitted = false; closingInput = null; submitFrame = -1; seen = []; }
    public static function remember(message:Dynamic):Void {
        var sender = G.field(message, "sender");
        var uid = G.text(G.field(sender, "uid"));
        var name = G.text(G.field(sender, "name"));
        if (uid == "" || name == "") return;
        seen = seen.filter(entry -> entry.uid != uid);
        seen.push({uid: uid, name: name, player: null, online: true});
        if (seen.length > MAX_SEEN) seen.shift();
    }

    public static function error(box:Dynamic, message:String):Void
        G.call("ui.hud.ChatBox", "chatError", box, [AppearanceUi.escape(message)]);

    static function check(box:Dynamic, reason:Dynamic):Bool {
        if (reason == G.enumeration("EReason", "Ok")) return true;
        error(box, reason == null ? "That action is unavailable right now." : G.text(G.staticCall("HText", "reason", [reason])));
        return false;
    }

    /** Return null for a consumed command, or the whisper text for native sending. */
    public static function run(box:Dynamic, command:SocialCommand):String {
        if (command.error != "") { error(box, command.error); return null; }
        var me = G.call("ui.BaseElement", "get_myPlayer", box);
        if (me == null) { error(box, "Chat is not ready yet."); return null; }
        if (command.command == "box") {
            submitted = BoxCommand.run(box, me);
            return null;
        }
        var group = G.field(me, "group");
        if (command.command == "leave") {
            if (group == null || G.call("st.Group", "get_isSolo", group) == true) {
                error(box, "You are not in a party."); return null;
            }
            submitted = check(box, G.call("st.Group", "requestLeave", group, [null]));
            return null;
        }
        var matches = find(me, command.player);
        if (matches.length != 1) {
            error(box, matches.length > 1 ? "More than one player has that name. Use the Social menu to choose them."
                : 'Player not found: ${command.player}. They must be in your area, party, friends, or recent chat.');
            return null;
        }
        var target = matches[0];
        if (target.uid == G.text(G.field(me, "uid"))) { error(box, "Choose another player."); return null; }
        if (!target.online) { error(box, target.name + " is offline."); return null; }
        if (command.command == "invite") {
            if (group == null || !check(box, G.call("st.Group", "hasInvitePlayerAllowed", group))) return null;
            if (target.player != null) {
                submitted = check(box, G.call("st.Group", "invitePlayer", group, [G.field(target.player, "__uid"), null]));
            } else {
                G.call("st.player.Whispers", "sendInviteGroup", G.field(me, "whispers"), [target.uid]);
                submitted = true;
            }
            return null;
        }
        // /w name leaves the editor open; /w name message is sent exactly once
        // by processMessage, preserving filtering, limits and native errors.
        var channel = G.enumValue("st.Channel", "Player", [target.uid, target.name]);
        G.call("ui.hud.ChatBox", "setChannel", box, [channel]);
        // focus() queues a TextInput.focus for the next frame. Only a bare /w
        // needs it; queuing it for a sent whisper would undo close-after-send.
        if (command.message == "") G.call("ui.hud.ChatBox", "focus", box);
        return command.message == "" ? null : command.message;
    }

    static function find(me:Dynamic, name:String):Array<KnownPlayer> {
        var targetName = name.toLowerCase();
        var known:Map<String, KnownPlayer> = [];
        // Old chat names are fallback candidates, never overrides for live
        // player/friend metadata. Resolve by account UID, not a prefix match.
        for (entry in seen) known[entry.uid] = entry;
        for (friend in G.array(G.field(G.field(me, "friendList"), "friends"))) {
            var uid = G.text(G.field(friend, "uid"));
            var meta = G.field(friend, "metadata");
            if (uid != "") known[uid] = {uid: uid, name: G.text(G.field(meta, "heroName")), player: null,
                online: G.field(meta, "connected") == true};
        }
        for (list in [G.field(G.field(me, "group"), "players"), G.field(G.field(me, "layer"), "players")])
            for (player in G.array(list, true)) {
                var uid = G.text(G.field(player, "uid"));
                if (uid != "") known[uid] = {uid: uid, name: G.text(G.call("st.Player", "getName", player)),
                    player: player, online: G.field(player, "removed") != true};
            }
        return [for (entry in known) if (entry.name.toLowerCase() == targetName) entry];
    }
}
