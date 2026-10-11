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
        eq(config.readyCheckX, null, "first popup centered horizontally");
        eq(config.readyCheckY, null, "first popup centered vertically");
        config.readyCheckX = 123.5; config.readyCheckY = 246.5;
        config = haxe.Json.parse(haxe.Json.stringify(config)); MeterConfig.normalize(config);
        eq(config.readyCheckX, 123.5, "saved horizontal position survives reload");
        eq(config.readyCheckY, 246.5, "saved vertical position survives reload");
        config.readyCheckX = Math.NaN; config.readyCheckY = Math.POSITIVE_INFINITY;
        MeterConfig.normalize(config);
        eq(config.readyCheckX, null, "invalid position returns to center");
        eq(config.readyCheckY, null, "infinite position returns to center");
        var formats:Array<Dynamic> = haxe.Json.parse(sys.io.File.getContent("configFormats.json")).configs;
        eq(formats.filter(d -> d.type == "title" && d.label == "Ready Check").length, 1, "settings category exists");
        eq(formats.filter(d -> d.key == "readyCheckEnabled" && d.label == "Enabled").length, 1, "settings toggle exists");

        for (channel in ["Local", "All", "Group"]) {
            var state = client();
            state.receive("two", "rc", channel, 0); eq(state.active, false, "member cannot initiate");
            state.receive("outsider", "rc", channel, 0); eq(state.active, false, "outsider cannot initiate");
            state.receive("leader", " Rc \n", channel, 10);
            eq(state.active, true, "leader starts on supported channel");
            eq(state.secondsLeft(10), 30, "30 second timer");
            eq(state.secondsLeft(10.2), 30, "timer rounds up");
            eq(state.secondsLeft(11), 29, "timer advances");
            eq(state.isReady("leader"), true, "initiator ready by default");
            eq(state.isReady("two"), false, "same display name does not share ready status");
            state.receive("leader", "rc", channel, 11); eq(state.deadline, 40, "duplicate rc cannot extend timer");
            state.receive("two", "r", channel, 12); eq(state.isReady("two"), true, "ready message");
            state.receive("two", "nr", channel, 13); eq(state.isReady("two"), false, "not ready reverses readiness");
            state.receive("leader", "nr", channel, 14); eq(state.isReady("leader"), false, "leader can mark not ready");
            state.receive("outsider", "r", channel, 15); eq(state.isReady("outsider"), false, "outsider response ignored");
            state.receive("two", "cancelrc", channel, 16); eq(state.active, true, "member cannot cancel");
            state.receive("leader", "cancelrc", channel, 17); eq(state.active, false, "leader cancels");
            eq(state.tick(20), null, "cancellation produces no countdown");
            eq(state.takeBell(20), false, "cancellation produces no bell");
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
            eq(state.takeBell(102), true, "leader and followers each ring immediately on completion");
            eq(state.takeBell(102), false, "two bells cannot play in one frame");
            eq(state.takeBell(102.19), false, "second bell waits for gap");
            eq(state.takeBell(102.2), true, "second bell after 200 ms");
            state.receive("three", "r", "Group", 103);
            eq(state.takeBell(103), false, "duplicate response cannot ring again");
        }
        for (state in clients.slice(1)) eq(state.tick(102), null, "followers never send countdown");
        var leader = clients[0];
        for (i in 0...6) {
            eq(leader.tick(102 + i), ["5", "4", "3", "2", "1", "GO"][i], "leader countdown order");
            eq(leader.tick(102.9 + i), null, "countdown waits one second");
        }
        eq(leader.tick(120), null, "countdown finishes once");
        complete(leader, 130); eq(leader.tick(150), "5", "stalled frame sends one step");
        eq(leader.tick(150), null, "no burst after frame stall");
        eq(leader.takeBell(150), true, "late first bell still plays");
        eq(leader.takeBell(150), false, "stall never merges two dings");
        eq(leader.takeBell(150.2), true, "late second bell retains gap");
        eq(leader.tick(151), "4", "stalled countdown retains spacing");
        leader.receive("leader", "cancelrc", "Group", 151.5); eq(leader.tick(152), null, "leader can stop countdown");
        complete(leader, 160); leader.receive("leader", "rc", "Group", 163);
        eq(leader.active, true, "new check replaces old countdown");
        eq(leader.tick(164), null, "old countdown discarded");
        eq(leader.isReady("two"), false, "new check clears old readiness");

        var state = client();
        state.receive("two", "r", "Group", 0); state.receive("leader", "rc", "Group", 1);
        eq(state.isReady("two"), false, "pre-check response cannot mark a future check ready");
        state.receive("two", "r", "Group", 30.99);
        state.receive("three", "r", "Group", 31);
        eq(state.active, false, "deadline cancels even if update has not run");
        eq(state.tick(31), null, "last response at deadline cannot trigger GO");
        eq(state.takeBell(31), false, "last response at deadline cannot ring");
        state.receive("leader", "rc", "Group", 40); state.tick(70);
        eq(state.active, false, "timer cancels without any incoming message");
        eq(state.secondsLeft(70), 0, "timer ends at zero");

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
            eq(state.takeBell(5), false, change + " cancels queued bells");
        }
        state = client(); state.receive("leader", "rc", "Group", 0); state.receive("two", "r", "Group", 1);
        state.sync(true, "leader", "party", "leader", [members[2], {uid:"two", name:"Renamed"}, members[0]]);
        eq(state.active, true, "roster reordering/name update does not cancel");
        eq(state.isReady("two"), true, "status keyed by stable account ID");
        state.sync(true, "leader", "party", "leader", [members[0], members[0]]);
        state.receive("leader", "rc", "Group", 2); eq(state.active, false, "incomplete/duplicate roster rejected");
        state = client(); complete(state); state.reset(); eq(state.tick(5), null, "dispose clears queued countdown");
        eq(state.takeBell(5), false, "dispose clears queued bells");
        state = client("two"); complete(state);
        eq(state.takeBell(2), true, "follower rings first bell");
        state.receive("leader", "cancelrc", "Group", 2.1);
        eq(state.takeBell(2.2), false, "leader cancellation clears follower's second bell");
        complete(state, 10); state.takeBell(12);
        state.receive("leader", "rc", "Group", 12.1);
        eq(state.takeBell(12.2), false, "new check clears old second bell");
        Sys.println('Ready Check: $checks checks passed.');
    }
}
