package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.FightHistory.HistoryEntry;
import dpsmeter.RiftTracker.RiftRecap;

/** Presentation helpers keep damage labels and old history data untouched. */
class HealingDisplay {
    public static function actual(stats:HealingStats, format:Float->String):String {
        if (stats.hits > 0 && stats.measuredHits == 0) return "Unavailable";
        return (stats.estimatedActualHits > 0 ? "~" : "") + format(stats.actual) + (stats.complete() ? "" : " (partial)");
    }
    public static function output(stats:HealingStats, value:Float, format:Float->String):String {
        if (stats.unknownOutputHits > 0) return value > 0
            ? (stats.estimatedHits > stats.unknownOutputHits ? "~" : "≥") + format(value) : "Unavailable";
        return (stats.estimatedHits > 0 ? "~" : "") + format(value);
    }
    public static function crit(stats:HealingStats):String {
        if (stats.knownCritHits == 0) return "—";
        return (stats.knownCritHits < stats.hits ? "~" : "")
            + Std.string(SkillStats.rounded(stats.crits * 100 / stats.knownCritHits, 1)) + "%";
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
        return FightHistory.dateLabel(entry.startedAt) + (name == "" ? "" : "  ·  " + name)
            + "  ·  " + (selected == null ? "Your HPS: " : "HPS: ")
            + (known ? output(p.healing, p.heal / Math.max(1, entry.duration), number) : "unavailable")
            + "  ·  " + FightHistory.durationLabel(entry.duration) + "  ·  " + FightHistory.outcomeLabel(entry)
            + "  ·  Actual healing: " + (known ? actual(p.healing, number) : "unavailable");
    }
    public static function recapDetail(recap:RiftRecap):String {
        var first = recap.gate == null ? recap.boss : recap.gate;
        var name = "", total = new HealingStats(), known = true;
        for (fight in [recap.gate, recap.boss]) if (fight != null) {
            var p = local(fight);
            if (p == null || !p.healingRecorded) { known = false; continue; }
            name = p.info.name;
            total.actual += p.healing.actual; total.hits += p.healing.hits; total.measuredHits += p.healing.measuredHits;
            total.estimatedActualHits += p.healing.estimatedActualHits;
        }
        return FightHistory.dateLabel(first.startedAt) + (name == "" ? "" : "  ·  " + name)
            + "  ·  " + (recap.boss.outcome == "" ? "Outcome unknown" : recap.boss.outcome)
            + "  ·  Actual healing: " + (known ? actual(total, number) : "unavailable");
    }
}
