package dpsmeter;

typedef ReadyMember = { var uid:String; var name:String; }

/** Chat protocol and clock, independent of native UI and combat collection. */
class ReadyCheck {
    public static inline var DURATION = 60.0;
    // The audible ready cue ends around 1.76 s; its 4.48 s asset includes a quiet tail.
    public static inline var COUNTDOWN_DELAY = 1.8;
    public var active(default, null) = false;
    public var members(default, null):Array<ReadyMember> = [];
    public var self(default, null) = "";
    public var leader(default, null) = "";
    public var deadline(default, null) = 0.0;
    public var countingDown(default, null) = false;
    public var completionSoundPending(default, null) = false;
    public var awaitingGo(default, null) = false;
    public var goSoundPending(default, null) = false;
    public var countdownSoundPending(default, null) = -1;
    var party = "";
    var roster = "";
    var ready:Map<String, Bool> = [];
    var pendingResponses:Array<Bool> = [];
    var nextCountAt = 0.0;
    var countIndex = 0;
    var receivedCount = 0;
    var goDeadline = 0.0;
    static final COUNTDOWN = ["5", "4", "3", "2", "1", "GO"];

    public function new() {}

    public static function command(text:String):String {
        if (text == null) return "";
        return switch (StringTools.trim(text).toLowerCase()) {
            case "rc": "rc";
            case "r": "r";
            case "nr": "nr";
            case "cancelrc": "cancelrc";
            default: "";
        };
    }
    public static function channelAllowed(channel:String):Bool
        return channel == "Local" || channel == "Group" || channel == "All";

    public static function countdownIndex(text:String):Int
        return text == null ? -1 : COUNTDOWN.indexOf(StringTools.trim(text).toUpperCase());

    /** A membership/leader change invalidates the whole check, including its countdown. */
    public function sync(enabled:Bool, self:String, party:String, leader:String, members:Array<ReadyMember>):Void {
        var ids = [for (member in members) member.uid];
        var unique:Map<String, Bool> = [];
        var valid = enabled && self != "" && party != "" && members.length > 1
            && ids.indexOf(self) >= 0 && ids.indexOf(leader) >= 0;
        for (id in ids) {
            if (id == "" || unique.exists(id)) valid = false;
            unique[id] = true;
        }
        if (!valid) { reset(); this.members = []; this.self = ""; this.leader = ""; this.party = ""; roster = ""; return; }
        ids.sort(Reflect.compare);
        var roster = haxe.Json.stringify(ids);
        if (this.self != self || this.party != party || this.leader != leader || this.roster != roster) reset();
        this.self = self; this.party = party; this.leader = leader; this.roster = roster;
        this.members = [for (member in members) {uid:member.uid, name:member.name}];
    }
    public function isLeader():Bool return self != "" && self == leader;
    public function isReady(uid:String):Bool return ready[uid] == true;
    public function canRespond(value:Bool):Bool {
        var current = pendingResponses.length == 0 ? isReady(self) : pendingResponses[pendingResponses.length - 1];
        return active && current != value;
    }
    public function responseSent(value:Bool):Void pendingResponses.push(value);
    public function secondsLeft(now:Float):Int return active ? Std.int(Math.max(0, Math.ceil(deadline - now))) : 0;
    public function expire(now:Float):Void {
        if ((active && now >= deadline) || (awaitingGo && now >= goDeadline)) reset();
    }

    public function accepts(sender:String, text:String, channel:String, now:Float):Bool {
        expire(now);
        if (members.length < 2 || !channelAllowed(channel) || !hasMember(sender)) return false;
        return switch (command(text)) {
            case "rc": sender == leader;
            case "cancelrc": sender == leader && (active || countingDown || completionSoundPending || awaitingGo || goSoundPending);
            case "r", "nr": active;
            // Only a completed check's ordered leader countdown can trigger GO.
            // Ordinary chat, duplicate echoes, and other senders remain silent.
            default: awaitingGo && sender == leader && channel == "Group" && countdownIndex(text) == receivedCount;
        };
    }
    public function receive(sender:String, text:String, channel:String, now:Float):Void {
        if (!accepts(sender, text, channel, now)) return;
        switch (command(text)) {
            case "rc":
                // Duplicate start messages cannot extend the 60-second deadline.
                if (active) return;
                reset(); active = true; deadline = now + DURATION; ready[leader] = true;
            case "cancelrc": reset();
            case "r", "nr":
                ready[sender] = command(text) == "r";
                // Replies arrive in order. Keep the latest queued choice while
                // earlier replies arrive, so double-clicks cannot repeat chat.
                if (sender == self && pendingResponses.length > 0 && pendingResponses[0] == ready[sender]) pendingResponses.shift();
                for (member in members) if (!isReady(member.uid)) return;
                active = false;
                completionSoundPending = true;
                awaitingGo = true; receivedCount = 0; goDeadline = now + DURATION;
                // Every client closes its popup; only the initiating leader speaks.
                if (isLeader()) { countingDown = true; countIndex = 0; nextCountAt = now + COUNTDOWN_DELAY; }
            default:
                // If multiple messages arrive in one frame, play only the
                // newest number instead of bursting stale voice clips.
                countdownSoundPending = receivedCount;
                receivedCount++;
                goDeadline = now + DURATION;
                if (receivedCount == COUNTDOWN.length) {
                    awaitingGo = false; countingDown = false;
                    completionSoundPending = false;
                    countdownSoundPending = -1;
                    goSoundPending = true;
                }
        }
    }
    /** At most one message per update; a stalled frame never bursts chat messages. */
    public function tick(now:Float):Null<String> {
        expire(now);
        if (!countingDown || now < nextCountAt) return null;
        var text = COUNTDOWN[countIndex++];
        nextCountAt = now + 1;
        if (countIndex == COUNTDOWN.length) countingDown = false;
        return text;
    }
    /** Every client plays the completion cue once when everyone is ready. */
    public function takeCompletionSound():Bool {
        if (!completionSoundPending) return false;
        completionSoundPending = false;
        return true;
    }
    /** Use the server echo on every client, including the leader. */
    public function takeGoSound():Bool {
        if (!goSoundPending) return false;
        goSoundPending = false;
        return true;
    }
    public function takeCountdownSound():Int {
        var index = countdownSoundPending;
        countdownSoundPending = -1;
        return index;
    }
    public function reset():Void {
        active = false; countingDown = false; ready = []; pendingResponses = []; deadline = 0; countIndex = 0; nextCountAt = 0;
        completionSoundPending = false;
        awaitingGo = false; goSoundPending = false; receivedCount = 0; goDeadline = 0;
        countdownSoundPending = -1;
    }
    function hasMember(uid:String):Bool {
        for (member in members) if (member.uid == uid) return true;
        return false;
    }
}
