import dpsmeter.ReadyCheckController;
import dpsmeter.ReadyCheck;
import dpsmeter.ReadyCheckAudio;
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
        update(now + 2); eq(G.sounds.length, 0, "incomplete and cancelled checks stay silent");
        deliver(message(players[2], "r", Group), now + 3);
        update(now + 3);
        eq(G.sounds.length, 3, "completion sound plays once on leader and both followers");
        update(now + 3.1); eq(G.sounds.length, 3, "next frame does not repeat sound");
        update(now + 3.21); eq(G.sounds.length, 3, "old second-bell timer does not repeat sound");
        for (sound in G.sounds) {
            eq(sound.event, "UI_Notify_Quest_Completed", "uses chosen quest-completed sound");
            eq(sound.params, null, "quest-completed event needs no parameters");
            eq(sound.source, null, "completion sound is local UI audio");
        }
        for (view in NativeReadyCheckWindow.views) eq(view.visible, false, "everyone ready closes every popup");
        eq(G.sent.length, 0, "ready cue plays before countdown starts");
        update(now + 3 + ReadyCheck.COUNTDOWN_DELAY - 0.01);
        eq(G.sent.length, 0, "full ready cue delay is respected");
        now += ReadyCheck.COUNTDOWN_DELAY;
        for (i in 0...6) update(now + 3 + i);
        eq([for (sent in G.sent) sent.message.text].join(","), "5,4,3,2,1,GO", "native send receives complete ordered countdown");
        eq(G.sounds.length, 3, "countdown steps do not repeat the sound");
        for (sent in G.sent) {
            eq(sent.client, players[0].chatClient, "countdown originates only from leader");
            eq(sent.message.channel, Group, "countdown always uses group chat");
        }
        eq(G.sounds.length, 3, "sending GO alone does not play before the server echo");
        for (sent in G.sent) deliver(sent.message, now + 8.1);
        update(now + 8.1);
        eq(G.sounds.length, 6, "GO echo plays once for the leader and every follower");
        for (sound in G.sounds.slice(3)) eq(sound.event, "ready-check-go", "GO uses the supplied boom");
        deliver(message(players[0], "GO", Group), now + 8.2); update(now + 8.2);
        eq(G.sounds.length, 6, "duplicate GO cannot repeat the boom");
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
        eq(NativeReadyCheckWindow.views[2].visible, true, "follower popup remains open after 30 seconds");
        now += 30;
        update(now + 51);
        eq(G.sent.length, 0, "timeout never sends a countdown");
        for (view in NativeReadyCheckWindow.views) eq(view.visible, false, "timeout closes remaining views");
        for (config in configs) config.readyCheckEnabled = true;
        G.sounds = [];
        deliver(message(players[0], "rc", Group), now + 60);
        deliver(message(players[1], "r", Group), now + 61);
        deliver(message(players[2], "r", Group), now + 62);
        G.failAudio = true; update(now + 62); G.failAudio = false;
        update(now + 62 + ReadyCheck.COUNTDOWN_DELAY);
        eq(G.sent[0].message.text, "5", "audio failure cannot stop countdown");
        update(now + 62.21 + ReadyCheck.COUNTDOWN_DELAY);
        eq(G.sounds.length, 0, "failed sound is not retried during the countdown");
        deliver(message(players[0], "rc", Group), now + 70);
        deliver(message(players[1], "r", Group), now + 71);
        deliver(message(players[2], "r", Group), now + 72);
        controllers[0].dispose(); configs[1].readyCheckEnabled = false;
        update(now + 72);
        eq(G.sounds.length, 1, "dispose and follower disable cancel pending sounds");
        eq(controllers[1].state.completionSoundPending, false, "idle follower still refreshes settings before sound");
        for (config in configs) config.readyCheckEnabled = true;
        G.sounds = []; G.sent = [];
        deliver(message(players[0], "rc", Group), now + 80);
        deliver(message(players[1], "r", Group), now + 81);
        deliver(message(players[2], "r", Group), now + 82);
        configs[0].disableCountdownAudio = true;
        configs[1].disableCountdownAudio = true;
        update(now + 82);
        eq(G.sounds.length, 1, "leader and follower mute their own audio without muting another member");
        update(now + 82 + ReadyCheck.COUNTDOWN_DELAY);
        eq(G.sent[0].message.text, "5", "muting audio preserves countdown chat");
        configs[0].disableCountdownAudio = false;
        configs[1].disableCountdownAudio = false;
        update(now + 83 + ReadyCheck.COUNTDOWN_DELAY);
        eq(G.sounds.length, 1, "unmuting mid-countdown does not play a delayed sound");
        eq(G.sent[1].message.text, "4", "countdown continues while audio preference changes");
        deliver(message(players[0], "rc", Group), now + 90);
        deliver(message(players[1], "r", Group), now + 91);
        deliver(message(players[2], "r", Group), now + 92); update(now + 92);
        eq(G.sounds.length, 4, "unmuting restores one sound per client for the next check");

        configs[0].disableCountdownAudio = true;
        configs[1].disableCountdownAudio = true;
        for (text in ["5", "4", "3", "2", "1", "GO"]) deliver(message(players[0], text, Group), now + 97);
        update(now + 97);
        eq(G.sounds.length, 5, "GO respects each client's countdown audio mute");
        eq(G.sounds[4].event, "ready-check-go", "unmuted follower hears boom");
        configs[0].disableCountdownAudio = false;
        configs[1].disableCountdownAudio = false; update(now + 98);
        eq(G.sounds.length, 5, "unmuting after GO cannot play a delayed boom");

        for (scenario in ["disable", "party", "audio failure"]) {
            deliver(message(players[0], "rc", Group), now + 100);
            deliver(message(players[1], "r", Group), now + 101);
            deliver(message(players[2], "r", Group), now + 102); update(now + 102);
            for (text in ["5", "4", "3", "2", "1", "GO"]) deliver(message(players[0], text, Group), now + 107);
            var before = G.sounds.length;
            if (scenario == "disable") for (config in configs) config.readyCheckEnabled = false;
            if (scenario == "party") group.groupId = "other-party";
            if (scenario == "audio failure") G.failAudio = true;
            update(now + 107);
            eq(G.sounds.length, before, scenario + " prevents queued boom without disrupting update");
            for (config in configs) config.readyCheckEnabled = true;
            G.failAudio = false; update(now + 108);
            eq(G.sounds.length, before, scenario + " cannot replay a stale boom");
        }
        var start = now + 200;
        for (muteVoice in [false, true]) for (muteEffects in [false, true]) {
            for (config in configs) {
                config.disableCountdownVoiceover = muteVoice;
                config.disableCountdownAudio = muteEffects;
            }
            G.sounds = []; G.sent = []; ReadyCheckAudio.voices = [];
            deliver(message(players[0], "rc", Group), start);
            deliver(message(players[1], "r", Group), start + 1);
            deliver(message(players[2], "r", Group), start + 2); update(start + 2);
            eq(G.sounds.length, muteEffects ? 0 : 3, "ready effect follows only effects preference");
            eq(ReadyCheckAudio.voices.length, 0, "voice waits for countdown echo");
            for (i in 0...5) {
                var time = start + 2 + ReadyCheck.COUNTDOWN_DELAY + i;
                update(time); // Leader sends, but voice waits for delivery.
                eq(ReadyCheckAudio.voices.length, muteVoice ? 0 : i * 3, "sending a number alone does not speak it");
                deliver(message(players[0], Std.string(5 - i), Group), time + 0.1); update(time + 0.1);
                eq(ReadyCheckAudio.voices.length, muteVoice ? 0 : (i + 1) * 3, "each echo speaks on enabled clients only");
                if (!muteVoice) eq(ReadyCheckAudio.voices[i * 3], i, "voice number matches delivered chat number");
                deliver(message(players[0], Std.string(5 - i), Group), time + 0.2); update(time + 0.2);
                eq(ReadyCheckAudio.voices.length, muteVoice ? 0 : (i + 1) * 3, "duplicate number echo is silent");
            }
            deliver(message(players[0], "GO", Group), start + 12); update(start + 12);
            eq(G.sounds.length, muteEffects ? 0 : 6, "GO follows only effects preference");
            start += 20;
        }
        Sys.println('Ready Check chat integration: $checks checks passed.');
    }
}
