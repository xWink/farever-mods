package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.FightHistory.HistoryEntry;
import dpsmeter.RiftTracker.RiftRecap;

/** Presentation helpers keep damage labels and old history data untouched. */
class HealingDisplay {
    public static function output(stats:HealingStats, value:Float, format:Float->String):String {
        if (stats.unknownOutputHits > 0 && value <= 0) return "Unavailable";
        return format(value);
    }
    public static function crit(stats:HealingStats):String {
        if (stats.knownCritHits == 0) return "—";
        return Std.string(SkillStats.rounded(stats.crits * 100 / stats.knownCritHits, 1)) + "%";
    }
    public static function number(value:Float):String {
        var label = FightHistory.dpsLabel(value, false);
        return label.substr(5);
    }
    public static function recorded(fight:Fight):Bool {
        for (p in fight.players) if (p.healingRecorded) return true;
        return false;
    }
    public static function local(fight:Null<Fight>):Null<PlayerStats> {
        if (fight == null) return null;
        if (fight.players.exists(fight.me)) return fight.players[fight.me];
        for (p in fight.players) if (p.info.isMe) return p;
        return null;
    }
    public static function detail(entry:Null<HistoryEntry>, fight:Null<Fight>, ?selected:PlayerStats):String {
        if (entry == null) return "";
        var p = selected == null ? local(fight) : selected;
        var known = p != null && p.healingRecorded;
        var name = p == null ? entry.playerName : p.info.name;
        var received = fight == null ? null : fight.healingReceived.total(p == null ? fight.me : p.info.uid);
        return FightHistory.dateLabel(entry.startedAt) + (name == "" ? "" : "  ·  " + name)
            + "  ·  " + (selected == null ? "Your HPS: " : "HPS: ")
            + (known ? output(p.healing, p.heal / Math.max(1, entry.duration), number) : "unavailable")
            + "  ·  " + FightHistory.durationLabel(entry.duration) + "  ·  " + FightHistory.outcomeLabel(entry)
            + "\nTotal healing: " + (known ? output(p.healing, p.heal, number) : "unavailable")
            + "  ·  Total healing received: " + (received == null ? "unavailable" : number(received));
    }
    public static function recapDetail(recap:RiftRecap):String {
        var first = recap.gate == null ? recap.boss : recap.gate;
        var name = "", total = new HealingStats(), known = true;
        var received = 0.0, receivedKnown = true;
        for (fight in [recap.gate, recap.boss]) if (fight != null) {
            var p = local(fight);
            var incoming = fight.healingReceived.total(p == null ? fight.me : p.info.uid);
            if (incoming == null) receivedKnown = false; else received += incoming;
            if (p == null || !p.healingRecorded) { known = false; continue; }
            name = p.info.name;
            total.output += p.heal; total.unknownOutputHits += p.healing.unknownOutputHits;
        }
        return FightHistory.dateLabel(first.startedAt) + (name == "" ? "" : "  ·  " + name)
            + "  ·  " + (recap.boss.outcome == "" ? "Outcome unknown" : recap.boss.outcome)
            + "\nTotal healing: " + (known ? output(total, total.output, number) : "unavailable")
            + "  ·  Total healing received: " + (receivedKnown ? number(received) : "unavailable");
    }
}
