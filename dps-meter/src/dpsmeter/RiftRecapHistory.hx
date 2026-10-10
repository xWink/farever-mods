package dpsmeter;

import dpsmeter.FightHistory.HistoryEntry;
import dpsmeter.HistoryCatalog.HistoryCategory;
import dpsmeter.RiftTracker.RiftRecap;

/** A self-contained pair of phase snapshots, independent of the popup and phase files. */
class RiftRecapHistory {
    public static inline var KIND = "rift-recap";
    public static inline var NAME = "Rift Recap";

    public static function isRecap(record:Dynamic):Bool
        return record != null && FightHistory.text(record.kind) == KIND;

    public static function encode(recap:RiftRecap, id:String):Dynamic return {
        version: 1, kind: KIND, id: id, name: NAME, gameVersion: recap.boss.gameVersion,
        gate: recap.gate == null ? null : FightHistory.encode(recap.gate, id + "_gates"),
        boss: FightHistory.encode(recap.boss, id + "_boss")
    };

    public static function validate(record:Dynamic):Void {
        if (!isRecap(record) || record.version != 1 || FightHistory.text(record.id) == ""
            || record.name != NAME || !Reflect.hasField(record, "gate") || record.boss == null)
            throw "Invalid rift recap history record.";
        for (phase in [record.gate, record.boss]) if (phase != null) {
            // Phases must be ordinary snapshots, never another nested recap.
            if (FightHistory.text(phase.kind) != "") throw "Invalid rift recap phase.";
            FightHistory.validate(phase);
        }
    }

    public static function decode(record:Dynamic):RiftRecap {
        validate(record);
        return {gate: record.gate == null ? null : FightHistory.decode(record.gate), boss: FightHistory.decode(record.boss)};
    }

    /** Index only the combined summary; do not instantiate skills/charts on the worker. */
    public static function entry(record:Dynamic):HistoryEntry {
        validate(record);
        var boss = FightHistory.entry(record.boss);
        var gate = record.gate == null ? null : FightHistory.entry(record.gate);
        var result:HistoryEntry = Reflect.copy(boss);
        result.id = record.id; result.kind = KIND; result.name = NAME;
        result.recapBossName = HistoryCategory.normalizeName(boss.name);
        result.category = HistoryCategory.WORLD; result.categoryVersion = HistoryCategory.VERSION;
        result.phase = "";
        result.startedAt = gate == null ? boss.startedAt : gate.startedAt;
        // DPS uses the sum of the two recorded phase durations, excluding any
        // unrecorded interval before the first boss hit.
        result.duration = boss.duration + (gate == null ? 0 : gate.duration);
        result.partySize = gate == null ? boss.partySize : Std.int(Math.max(gate.partySize, boss.partySize));
        if (result.playerName == "" && gate != null) {
            result.playerName = gate.playerName; result.playerClass = gate.playerClass;
        }
        if (result.playerClass == "" && gate != null && result.playerName == gate.playerName)
            result.playerClass = gate.playerClass;
        var players:Map<String, Bool> = [];
        var damage = 0.0;
        var known = false;
        var breakdown = new DamageBreakdown();
        for (phase in [record.gate, record.boss]) if (phase != null) {
            var me = FightHistory.text(phase.me);
            if (me != "") { players[me] = true; known = true; }
            var found = false;
            for (player in FightHistory.array(phase.players)) {
                var uid = FightHistory.text(player.uid);
                if (uid != "") players[uid] = true;
                if (!found && (player.isMe == true || (me != "" && uid == me))) {
                    found = true; known = true;
                    damage += FightHistory.number(player.damage);
                    breakdown.merge(DamageBreakdown.read(player.damageBreakdown));
                }
            }
        }
        result.recordedPlayers = Lambda.count(players);
        result.personalDps = known ? damage / Math.max(1, result.duration) : null;
        result.damageTypeSummary = breakdown.summary(damage);
        return result;
    }
}
