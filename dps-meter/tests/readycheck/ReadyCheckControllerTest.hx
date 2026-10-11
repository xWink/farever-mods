import dpsmeter.ReadyCheckController;
import dpsmeter.NativeReadyCheckWindow;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess as G;
import dpsmeter.GameAccess.TestChannel;

class ReadyCheckControllerTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function message(player:Dynamic, text:String, channel:TestChannel):Dynamic
        return {sender:{uid:player.uid, name:player.name}, channel:channel, text:text};
    static function main():Void {
        var now = haxe.Timer.stamp();
        var configs = [MeterConfig.defaults(), MeterConfig.defaults(), MeterConfig.defaults()];
        configs[0].visible = false; // Hiding the meter does not disable this feature.
        var controllers = [for (config in configs) new ReadyCheckController(config)];
        var players:Array<Dynamic> = [for (i in 0...3) {uid:'p$i', name:"Same Name", isMe:true}];
        var group:Dynamic = {groupId:"9223372036854770001", players:{array:players}};
        for (player in players) { player.group = group; player.chatClient = {player:player}; }
        var apps = [for (player in players) {me:player, hero:{}}];
        function deliver(msg:Dynamic, time:Float):Void {
            for (i in 0...3) controllers[i].received(players[i].chatClient, msg, time);
        }
        function update(time:Float):Void { for (i in 0...3) controllers[i].update(apps[i], time); }
        update(now);
        var msg = message(players[0], "rc", Local({x:0, y:0, z:0}));
        controllers[0].outgoing(players[0].chatClient, msg, now);
        eq(msg.channel, Group, "local leader command routed to party before sending");
        eq(controllers[0].state.active, false, "outgoing message waits for actual server delivery");
        deliver(msg, now); update(now);
        for (view in NativeReadyCheckWindow.views) eq(view.visible, true, "all enabled party clients open popup");
        for (controller in controllers) {
            eq(controller.state.isReady("p0"), true, "native account UID resolves leader");
            eq(controller.state.isReady("p1"), false, "matching display name cannot share readiness");
        }
        msg = message(players[1], "nr", All);
        controllers[1].outgoing(players[1].chatClient, msg, now); eq(msg.channel, Group, "all-chat response routed to party");
        msg = message(players[1], "hello", All);
        controllers[1].outgoing(players[1].chatClient, msg, now); eq(msg.channel, All, "ordinary chat is unchanged");
        msg = message(players[1], "rc", All);
        controllers[1].outgoing(players[1].chatClient, msg, now); eq(msg.channel, All, "nonleader start is not rerouted");
        msg = message(players[1], "r", Player("p0", "Name"));
        controllers[1].outgoing(players[1].chatClient, msg, now);
        eq(Type.enumConstructor(msg.channel), "Player", "whisper untouched");
        deliver(msg, now); eq(controllers[0].state.isReady("p1"), false, "whisper cannot ready a member");
        msg = message(players[1], "r", Group); msg.notify = "PartyNotification";
        deliver(msg, now); eq(controllers[0].state.isReady("p1"), false, "notification text is not a command");
        msg = message({uid:"outsider", name:"Same Name"}, "r", All);
        deliver(msg, now); eq(controllers[0].state.isReady("outsider"), false, "outsider ignored even with matching name");
        var remote:Dynamic = {uid:"other", name:"Other", isMe:false, group:group}; remote.chatClient = {player:remote};
        controllers[0].received(remote.chatClient, message(players[1], "r", Group), now);
        eq(controllers[0].state.isReady("p1"), false, "unowned chat clients ignored");

        NativeReadyCheckWindow.views[0].send("r");
        NativeReadyCheckWindow.views[1].send("nr");
        eq(G.sent.length, 0, "buttons cannot resend the initial leader/member status");
        NativeReadyCheckWindow.views[1].send("r");
        NativeReadyCheckWindow.views[1].send("r");
        eq(G.sent.length, 1, "Ready button sends one message");
        eq(G.sent[0].message.text, "r", "Ready button text");
        eq(G.sent[0].message.channel, Group, "Ready button group channel");
        eq(G.sent[0].message.sender.uid, "p1", "Ready button uses local player identity");
        eq(controllers[1].state.isReady("p1"), false, "button waits for server echo");
        deliver(G.sent.shift().message, now + 0.1);
        NativeReadyCheckWindow.views[1].send("r");
        eq(G.sent.length, 0, "already ready cannot send Ready again");
        NativeReadyCheckWindow.views[1].send("nr");
        NativeReadyCheckWindow.views[1].send("nr");
        eq(G.sent.length, 1, "double-click Not Ready sends only once before echo");
        eq(G.sent[0].message.text, "nr", "Not Ready button text");
        deliver(G.sent.shift().message, now + 0.2);
        eq(controllers[0].state.isReady("p1"), false, "Not Ready updates every client");
        NativeReadyCheckWindow.views[1].send("nr");
        eq(G.sent.length, 0, "already not ready cannot send Not Ready again");
        for (text in ["r", "r", "nr", "nr", "r", "r"]) NativeReadyCheckWindow.views[1].send(text);
        eq([for (sent in G.sent) sent.message.text].join(","), "r,nr,r", "rapid status changes send each change once");
        deliver(G.sent.shift().message, now + 0.21);
        deliver(G.sent.shift().message, now + 0.22);
        NativeReadyCheckWindow.views[1].send("r");
        eq(G.sent.length, 1, "earlier replies cannot clear the latest pending status");
        deliver(G.sent.shift().message, now + 0.23);
        NativeReadyCheckWindow.views[1].send("cancelrc"); eq(G.sent.length, 0, "nonleader cannot send cancel through button callback");
        NativeReadyCheckWindow.views[0].send("cancelrc"); eq(G.sent[0].message.text, "cancelrc", "leader Cancel sends command");
        deliver(G.sent.shift().message, now + 0.3); update(now + 0.3);
        for (view in NativeReadyCheckWindow.views) eq(view.visible, false, "cancel closes every popup");

        deliver(message(players[0], "rc", All), now + 1);
        deliver(message(players[1], "r", Local({x:0, y:0, z:0})), now + 2);
        deliver(message(players[2], "r", Group), now + 3);
        update(now + 3);
        for (view in NativeReadyCheckWindow.views) eq(view.visible, false, "everyone ready closes every popup");
        eq(G.sent.length, 1, "one leader sends first countdown step");
        for (i in 1...6) update(now + 3 + i);
        eq([for (sent in G.sent) sent.message.text].join(","), "5,4,3,2,1,GO", "native send receives complete ordered countdown");
        for (sent in G.sent) {
            eq(sent.client, players[0].chatClient, "countdown originates only from leader");
            eq(sent.message.channel, Group, "countdown always uses group chat");
        }
        G.sent = [];
        deliver(message(players[0], "rc", Group), now + 10); update(now + 10);
        configs[1].readyCheckEnabled = false; update(now + 11);
        eq(NativeReadyCheckWindow.views[1].visible, false, "live disable removes popup");
        msg = message(players[1], "r", All);
        controllers[1].outgoing(players[1].chatClient, msg, now + 11);
        eq(msg.channel, All, "disabled feature leaves outgoing commands unchanged");
        deliver(message(players[1], "r", Group), now + 12);
        deliver(message(players[2], "r", Group), now + 12);
        configs[0].readyCheckEnabled = false; update(now + 13);
        eq(G.sent.length, 0, "disable cancels leader countdown before it sends");
        configs[0].readyCheckEnabled = true;
        deliver(message(players[0], "rc", Group), now + 20);
        controllers[0].dispose();
        eq(controllers[0].state.active, false, "disconnect resets protocol");
        eq(NativeReadyCheckWindow.views[0].visible, false, "disconnect closes view");
        update(now + 51);
        eq(G.sent.length, 0, "timeout never sends a countdown");
        for (view in NativeReadyCheckWindow.views) eq(view.visible, false, "timeout closes remaining views");
        Sys.println('Ready Check chat integration: $checks checks passed.');
    }
}
