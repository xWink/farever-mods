package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.MeterConfig.MeterSettings;

/** Uses the game's ordinary chat transport; never focuses or edits the chat box. */
class ReadyCheckController {
    public final state = new ReadyCheck();
    var config:MeterSettings;
    var view:NativeReadyCheckWindow;
    var player:Dynamic;
    var reported:Map<String, Bool> = [];

    public function new(config:MeterSettings) {
        this.config = config;
        view = new NativeReadyCheckWindow(config, state, sendCommand);
    }
    function refresh(player:Dynamic):Void {
        this.player = player;
        var group = G.field(player, "group");
        var members = [];
        if (group != null) for (member in G.array(G.field(group, "players"), true))
            members.push({uid:G.text(G.field(member, "uid")), name:G.text(G.call("st.Player", "getName", member))});
        var leader = group == null ? null : G.call("st.Group", "get_leader", group);
        state.sync(config.enabled && config.readyCheckEnabled && G.field(player, "isMe") == true,
            G.text(G.field(player, "uid")), G.text(G.field(group, "groupId")), G.text(G.field(leader, "uid")), members);
    }
    function ownClient(client:Dynamic):Bool {
        var owner = G.field(client, "player");
        return owner != null && G.field(owner, "isMe") == true && G.field(owner, "chatClient") == client;
    }
    function channel(message:Dynamic):String {
        var value = G.field(message, "channel");
        return value == null ? "" : Type.enumConstructor(value);
    }
    public function outgoing(client:Dynamic, message:Dynamic, now:Float):Void {
        if (!ownClient(client) || G.field(message, "notify") != null) return;
        var text = G.text(G.field(message, "text"));
        if (ReadyCheck.command(text) == "") return;
        refresh(G.field(client, "player"));
        var sender = G.text(G.field(G.field(message, "sender"), "uid"));
        if (sender == state.self && state.accepts(sender, text, channel(message), now)) {
            // Local is distance-limited. Route recognized commands to Group
            // before native sendMessage, avoiding duplicate local/group echoes.
            var group = G.enumeration("st.Channel", "Group");
            if (group == null) throw "Group chat channel is unavailable";
            G.set(message, "channel", group);
        }
    }
    public function received(client:Dynamic, message:Dynamic, now:Float):Void {
        if (!ownClient(client) || G.field(message, "notify") != null) return;
        var text = G.text(G.field(message, "text"));
        if (ReadyCheck.command(text) == "") return;
        refresh(G.field(client, "player"));
        state.receive(G.text(G.field(G.field(message, "sender"), "uid")), text, channel(message), now);
    }
    public function update(app:Dynamic, now:Float):Void {
        // Chat events refresh before starting a check. Avoid scanning/naming
        // the native party every frame while this feature is idle.
        if (state.active || state.countingDown || state.completionSoundPending) refresh(G.field(app, "me"));
        if (state.takeCompletionSound() && !config.disableCountdownAudio) playCompletionSound();
        var text = state.tick(now);
        if (text != null) send(text);
        view.update(now, G.field(app, "hero") != null);
    }
    function playCompletionSound():Void {
        try {
            G.staticCall("client.Audio", "play", ["UI_Notify_Quest_Completed", null, null]);
        } catch (error:Dynamic) {
            // An unavailable audio backend must not interrupt the countdown.
            var text = "sound: " + Std.string(error);
            if (!reported.exists(text)) { reported[text] = true; trace("[DPS Meter] Ready Check " + text); }
        }
    }
    function sendCommand(text:String):Void {
        try {
            refresh(player);
            if (!state.accepts(state.self, text, "Group", haxe.Timer.stamp())) return;
            if (text == "r" || text == "nr") {
                var ready = text == "r";
                if (!state.canRespond(ready)) return;
                state.responseSent(ready);
            }
            send(text);
        } catch (error:Dynamic) report(error);
    }
    function send(text:String):Void {
        var client = G.field(player, "chatClient");
        if (!ownClient(client)) { state.reset(); return; }
        var group = G.enumeration("st.Channel", "Group");
        if (group == null) throw "Group chat channel is unavailable";
        // Match ChatBox.processMessage's structural message. Status changes
        // only on the server's echo, just as it does on every other client.
        var message:Dynamic = {
            sender:{uid:G.text(G.field(player, "uid")), name:G.text(G.call("st.Player", "getName", player))},
            channel:group, text:text, args:null, localStamp:null, localTextId:null, notify:null
        };
        G.call("st.player.ChatClient", "sendMessage", client, [message]);
    }
    public function report(error:Dynamic):Void {
        state.reset();
        view.dispose();
        var text = Std.string(error);
        if (!reported.exists(text)) { reported[text] = true; trace("[DPS Meter] Ready Check: " + text); }
    }
    public function dispose():Void { state.reset(); player = null; view.dispose(); }
}
