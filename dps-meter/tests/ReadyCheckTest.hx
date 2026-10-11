import dpsmeter.ReadyCheck;
import dpsmeter.ReadyCheck.ReadyMember;
import dpsmeter.MeterConfig;

class ReadyCheckTest {
    static var checks = 0;
    static var members:Array<ReadyMember> = [{uid:"leader", name:"Alex"}, {uid:"two", name:"Alex"}, {uid:"three", name:"C"}];
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function client(self:String = "leader"):ReadyCheck {
        var state = new ReadyCheck();
        state.sync(true, self, "party", "leader", members);
        return state;
    }
    static function complete(state:ReadyCheck, now:Float = 0):Void {
        state.receive("leader", "rc", "Group", now);
        state.receive("two", "r", "Group", now + 1);
        state.receive("three", "r", "Group", now + 2);
    }
    static function main():Void {
        var config = MeterConfig.defaults();
        eq(config.readyCheckEnabled, true, "ready checks default on");
        eq(config.disableCountdownAudio, false, "countdown sound plays by default");
        eq(config.disableCountdownVoiceover, false, "voiceover plays by default");
        eq(config.readyCheckX, null, "first popup centered horizontally");
        eq(config.readyCheckY, null, "first popup centered vertically");
        config.readyCheckX = 123.5; config.readyCheckY = 246.5;
        config.disableCountdownAudio = true;
        config.disableCountdownVoiceover = true;
        config = haxe.Json.parse(haxe.Json.stringify(config)); MeterConfig.normalize(config);
        eq(config.readyCheckX, 123.5, "saved horizontal position survives reload");
        eq(config.readyCheckY, 246.5, "saved vertical position survives reload");
        eq(config.disableCountdownAudio, true, "audio preference survives reload");
        eq(config.disableCountdownVoiceover, true, "voiceover preference survives reload");
        config.readyCheckX = Math.NaN; config.readyCheckY = Math.POSITIVE_INFINITY;
        MeterConfig.normalize(config);
        eq(config.readyCheckX, null, "invalid position returns to center");
        eq(config.readyCheckY, null, "infinite position returns to center");
        var formats:Array<Dynamic> = haxe.Json.parse(sys.io.File.getContent("configFormats.json")).configs;
        eq(formats.filter(d -> d.type == "title" && d.label == "Ready Check").length, 1, "settings category exists");
        eq(formats.filter(d -> d.key == "readyCheckEnabled" && d.label == "Enabled").length, 1, "settings toggle exists");
        eq(formats.filter(d -> d.key == "disableCountdownAudio" && d.label == "Disable countdown sound effects" && d.type == "checkbox").length, 1, "effects toggle retains existing saved preference");
        eq(formats.filter(d -> d.key == "disableCountdownVoiceover" && d.label == "Disable countdown voiceover" && d.type == "checkbox").length, 1, "independent voiceover toggle exists");

        for (channel in ["Local", "All", "Group"]) {
            var state = client();
            state.receive("two", "rc", channel, 0); eq(state.active, false, "member cannot initiate");
            state.receive("outsider", "rc", channel, 0); eq(state.active, false, "outsider cannot initiate");
            state.receive("leader", " Rc \n", channel, 10);
            eq(state.active, true, "leader starts on supported channel");
            eq(state.secondsLeft(10), 60, "60 second timer");
            eq(state.secondsLeft(10.2), 60, "timer rounds up");
            eq(state.secondsLeft(11), 59, "timer advances");
            eq(state.isReady("leader"), true, "initiator ready by default");
            eq(state.isReady("two"), false, "same display name does not share ready status");
            state.receive("leader", "rc", channel, 11); eq(state.deadline, 70, "duplicate rc cannot extend timer");
            state.receive("two", "r", channel, 12); eq(state.isReady("two"), true, "ready message");
            state.receive("two", "nr", channel, 13); eq(state.isReady("two"), false, "not ready reverses readiness");
            state.receive("leader", "nr", channel, 14); eq(state.isReady("leader"), false, "leader can mark not ready");
            state.receive("outsider", "r", channel, 15); eq(state.isReady("outsider"), false, "outsider response ignored");
            state.receive("two", "cancelrc", channel, 16); eq(state.active, true, "member cannot cancel");
            state.receive("leader", "cancelrc", channel, 17); eq(state.active, false, "leader cancels");
            eq(state.tick(20), null, "cancellation produces no countdown");
            eq(state.takeCompletionSound(), false, "cancellation produces no sound");
        }
        for (channel in ["Player", "System", "AllSystem", "", "Guild"]) {
            var state = client(); state.receive("leader", "rc", channel, 0);
            eq(state.active, false, "private/system/unknown channels cannot start checks");
            state.receive("leader", "rc", "Group", 0);
            state.receive("two", "r", channel, 1); eq(state.isReady("two"), false, "wrong channel cannot respond");
            state.receive("leader", "cancelrc", channel, 1); eq(state.active, true, "wrong channel cannot cancel");
        }
        for (text in ["ready", "rc please", "/rc", "r!", "we need nr", "cancelrc now", "5", "GO", ""]) {
            eq(ReadyCheck.command(text), "", "only standalone commands recognized");
        }
        var clients = [client("leader"), client("two"), client("three")];
        for (state in clients) {
            complete(state, 100); eq(state.active, false, "every client closes immediately when ready");
            state.receive("three", "r", "Group", 102); // repeated echo must not restart countdown
            eq(state.takeCompletionSound(), true, "leader and followers each play one completion sound");
            eq(state.takeCompletionSound(), false, "completion sound is consumed only once");
            state.receive("three", "r", "Group", 103);
            eq(state.takeCompletionSound(), false, "duplicate response cannot play sound again");
        }
        for (state in clients.slice(1)) eq(state.tick(102), null, "followers never send countdown");
        var leader = clients[0];
        eq(leader.tick(102), null, "everyone ready leaves time for completion audio");
        eq(leader.tick(102 + ReadyCheck.COUNTDOWN_DELAY - 0.01), null, "countdown waits for full ready cue");
        for (i in 0...6) {
            eq(leader.tick(102 + ReadyCheck.COUNTDOWN_DELAY + i), ["5", "4", "3", "2", "1", "GO"][i], "leader countdown order");
            eq(leader.tick(102.9 + ReadyCheck.COUNTDOWN_DELAY + i), null, "countdown waits one second");
        }
        eq(leader.tick(120), null, "countdown finishes once");
        complete(leader, 130); eq(leader.tick(150), "5", "stalled frame sends one step");
        eq(leader.tick(150), null, "no burst after frame stall");
        eq(leader.takeCompletionSound(), true, "completion sound survives a stalled frame");
        eq(leader.takeCompletionSound(), false, "stalled frame cannot repeat the sound");
        eq(leader.tick(151), "4", "stalled countdown retains spacing");
        leader.receive("leader", "cancelrc", "Group", 151.5); eq(leader.tick(152), null, "leader can stop countdown");
        complete(leader, 160); leader.receive("leader", "rc", "Group", 163);
        eq(leader.active, true, "new check replaces old countdown");
        eq(leader.tick(164), null, "old countdown discarded");
        eq(leader.isReady("two"), false, "new check clears old readiness");

        var state = client();
        state.receive("two", "r", "Group", 0); state.receive("leader", "rc", "Group", 1);
        eq(state.isReady("two"), false, "pre-check response cannot mark a future check ready");
        state.tick(31);
        eq(state.active, true, "check remains open beyond the former 30-second timeout");
        eq(state.secondsLeft(31), 30, "another 30 seconds remain at the former deadline");
        state.receive("two", "r", "Group", 60.99);
        state.receive("three", "r", "Group", 61);
        eq(state.active, false, "deadline cancels even if update has not run");
        eq(state.tick(61), null, "last response at deadline cannot trigger GO");
        eq(state.takeCompletionSound(), false, "last response at deadline cannot play sound");
        state.receive("leader", "rc", "Group", 70); state.tick(129.99);
        eq(state.active, true, "check stays open until the full minute elapses");
        state.tick(130);
        eq(state.active, false, "timer cancels without any incoming message");
        eq(state.secondsLeft(130), 0, "timer ends at zero");

        for (duringCountdown in [false, true]) for (change in ["disable", "solo", "leave", "party", "leader", "join", "replace", "self"]) {
            state = client();
            if (duringCountdown) complete(state); else state.receive("leader", "rc", "Group", 0);
            switch (change) {
                case "disable": state.sync(false, "leader", "party", "leader", members);
                case "solo": state.sync(true, "leader", "party", "leader", [members[0]]);
                case "leave": state.sync(true, "leader", "party", "leader", members.slice(0, 2));
                case "party": state.sync(true, "leader", "other-party", "leader", members);
                case "leader": state.sync(true, "leader", "party", "two", members);
                case "join": state.sync(true, "leader", "party", "leader", members.concat([{uid:"four", name:"D"}]));
                case "replace": state.sync(true, "leader", "party", "leader", [members[0], members[1], {uid:"four", name:"D"}]);
                case "self": state.sync(true, "two", "party", "leader", members);
            }
            eq(state.active, false, change + " cancels popup");
            eq(state.tick(5), null, change + " cancels queued countdown");
            eq(state.takeCompletionSound(), false, change + " cancels queued sound");
            for (text in ["5", "4", "3", "2", "1", "GO"]) state.receive("leader", text, "Group", 6);
            eq(state.takeGoSound(), false, change + " cancels GO listening");
        }
        state = client(); state.receive("leader", "rc", "Group", 0); state.receive("two", "r", "Group", 1);
        state.sync(true, "leader", "party", "leader", [members[2], {uid:"two", name:"Renamed"}, members[0]]);
        eq(state.active, true, "roster reordering/name update does not cancel");
        eq(state.isReady("two"), true, "status keyed by stable account ID");
        state.sync(true, "leader", "party", "leader", [members[0], members[0]]);
        state.receive("leader", "rc", "Group", 2); eq(state.active, false, "incomplete/duplicate roster rejected");
        state = client(); complete(state); state.reset(); eq(state.tick(5), null, "dispose clears queued countdown");
        eq(state.takeCompletionSound(), false, "dispose clears queued sound");
        state = client("two"); complete(state);
        state.receive("leader", "cancelrc", "Group", 2.1);
        eq(state.takeCompletionSound(), false, "leader cancellation clears follower's pending sound");
        complete(state, 10);
        state.receive("leader", "rc", "Group", 12.1);
        eq(state.takeCompletionSound(), false, "new check clears old pending sound");

        for (self in ["leader", "two"]) {
            state = client(self);
            for (text in ["5", "4", "3", "2", "1", "GO"]) state.receive("leader", text, "Group", 0);
            eq(state.takeGoSound(), false, "ordinary countdown without a completed check is silent");
            eq(state.takeCountdownSound(), -1, "ordinary countdown cannot trigger voice");
            complete(state, 10);
            state.takeCompletionSound();
            state.receive("leader", "GO", "Group", 12.1);
            eq(state.takeGoSound(), false, "GO before the ordered countdown is ignored");
            for (text in ["5", "4", "3", "2", "1", "GO"]) {
                for (sender in ["two", "outsider"]) state.receive(sender, text, "Group", 13);
                for (channel in ["Local", "All", "Player", "System"]) state.receive("leader", text, channel, 13);
            }
            eq(state.takeGoSound(), false, "other speakers and other channels cannot trigger GO");
            eq(state.takeCountdownSound(), -1, "other speakers and channels cannot trigger voice");
            for (text in ["5", "4", "3", "2", "1"]) {
                state.receive("leader", text, "Group", 14);
                state.receive("leader", text, "Group", 14); // duplicate delivery
                eq(state.takeGoSound(), false, "numbered steps do not trigger GO");
                eq(state.takeCountdownSound(), ReadyCheck.countdownIndex(text), "number echo selects its matching voice");
                eq(state.takeCountdownSound(), -1, "duplicate echo cannot repeat a number");
            }
            state.receive("leader", " Go ", "Group", 19);
            eq(state.takeGoSound(), true, "GO echoes play on leader and followers");
            eq(state.takeGoSound(), false, "GO cue consumed once");
            state.receive("leader", "GO", "Group", 19.1);
            eq(state.takeGoSound(), false, "duplicate GO is silent");
            eq(state.awaitingGo, false, "finished countdown no longer watches chat");
            eq(state.takeCountdownSound(), -1, "GO clears queued voice");

            for (stop in ["cancel", "timeout", "restart", "dispose"]) {
                complete(state, 30);
                for (text in ["5", "4", "3", "2", "1"]) state.receive("leader", text, "Group", 33);
                switch (stop) {
                    case "cancel": state.receive("leader", "cancelrc", "Group", 34);
                    case "timeout": state.expire(93);
                    case "restart": state.receive("leader", "rc", "Group", 34);
                    case "dispose": state.reset();
                }
                state.receive("leader", "GO", "Group", 94);
                eq(state.takeGoSound(), false, stop + " prevents late GO");
                eq(state.takeCountdownSound(), -1, stop + " clears queued voice");
            }
        }
        state = client(); complete(state);
        for (text in ["5", "4", "3"]) state.receive("leader", text, "Group", 10);
        eq(state.takeCountdownSound(), 2, "batched echoes play only newest spoken number");
        eq(state.takeCountdownSound(), -1, "batched echoes do not queue stale voice");
        Sys.println('Ready Check: $checks checks passed.');
    }
}
