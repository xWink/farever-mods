package dpsmeter;

import dpsmeter.CombatModel;

typedef HistoryEntry = {
    id:String, name:String, startedAt:Float, duration:Float, personalDps:Null<Float>, playerName:String,
    category:String, categoryVersion:Int, activityId:String, bossKind:String, phase:String,
    difficulty:Int, partySize:Int, recordedPlayers:Int, playerClass:String, outcome:String,
    ?damageTypeSummary:String, ?targetDummy:Bool
};
typedef HistoryGroup = {name:String, count:Int};
typedef HistoryHeading = {before:String, player:String, after:String};
typedef HistoryCharacter = {key:String, name:String, className:String};
typedef HistoryRequest = {id:Int, action:String, group:String, page:Int, fightId:String,
    ?category:String, ?catalog:HistoryCatalog, ?sortBy:String, ?ascending:Bool, ?character:String};
typedef HistoryResponse = {
    id:Int, page:Int, total:Int, groups:Array<HistoryGroup>, entries:Array<HistoryEntry>, record:Dynamic, error:String,
    ?characters:Array<HistoryCharacter>
};

/** Detached, versioned chart snapshots. No game types or monotonic clocks on disk. */
class FightHistory {
    public static inline var PAGE_SIZE = 8;
    public static function encode(fight:Fight, id:String):Dynamic {
        var players:Array<Dynamic> = [for (p in fight.ranked()) {
            var skills:Array<Dynamic> = [for (id => s in p.skills) {id: id, damage: s.damage, hits: s.hits,
                crits: s.crits, kills: s.kills, casts: s.casts, damageBreakdown: s.damageBreakdown.json(s.damage)}];
            {
                uid: p.info.uid, name: p.info.name, isMe: p.info.isMe || p.info.uid == fight.me,
                className: p.info.className, damage: p.damage, heal: p.heal,
                hits: p.hits, crits: p.crits, kills: p.kills,
                skills: skills, damageBreakdown: p.damageBreakdown.json(p.damage)
            }
        }];
        return {version: 1, id: id, name: name(fight), startedAt: fight.startedAt, duration: fight.duration(),
            me: fight.me, meName: fight.meName, players: players, category: fight.category, categoryVersion: fight.categoryVersion,
            activityId: fight.activityId, bossKind: fight.bossKind, phase: fight.phase,
            difficulty: fight.difficulty, partySize: fight.partySize, outcome: outcome(fight.outcome), targetDummy: fight.targetDummy};
    }
    public static function name(fight:Fight):String {
        if (fight.category == HistoryCatalog.HistoryCategory.OTHER && fight.targetDummy) return "Target dummy";
        return fight.phase != "" ? fight.phase : fight.bossName != "" ? fight.bossName
            : fight.bossKind != "" ? fight.bossKind : "Other combat";
    }
    public static function entry(record:Dynamic):HistoryEntry {
        validate(record);
        var damage:Null<Float> = text(record.me) == "" ? null : 0;
        var playerName = text(record.meName);
        var playerClass = "";
        var damageTypeSummary = "";
        for (p in array(record.players)) if (p.isMe == true || (text(record.me) != "" && text(p.uid) == text(record.me))) {
            damage = number(p.damage); playerName = text(p.name); playerClass = text(p.className).toLowerCase();
            damageTypeSummary = DamageBreakdown.read(p.damageBreakdown).summary(damage); break;
        }
        return {id: record.id, name: record.name, startedAt: record.startedAt, duration: record.duration,
            personalDps: damage == null ? null : damage / Math.max(1, number(record.duration)), playerName: playerName, playerClass: playerClass,
            category: text(record.category), categoryVersion: Std.int(number(record.categoryVersion)),
            activityId: text(record.activityId), bossKind: text(record.bossKind), phase: text(record.phase),
            difficulty: difficulty(record.difficulty), partySize: Std.int(number(record.partySize)), recordedPlayers: recordedPlayers(record),
            outcome: outcome(record.outcome), damageTypeSummary: damageTypeSummary, targetDummy: record.targetDummy == true};
    }
    public static function decode(record:Dynamic):Fight {
        validate(record);
        var fight = new Fight(1);
        fight.startedAt = record.startedAt;
        fight.last = 1 + number(record.duration);
        fight.closed = fight.last;
        fight.bossName = record.name;
        fight.me = text(record.me); fight.meName = text(record.meName);
        fight.category = text(record.category); fight.activityId = text(record.activityId);
        fight.targetDummy = record.targetDummy == true;
        fight.categoryVersion = Std.int(number(record.categoryVersion));
        fight.bossKind = text(record.bossKind); fight.phase = text(record.phase);
        fight.difficulty = difficulty(record.difficulty); fight.partySize = Std.int(number(record.partySize));
        fight.outcome = outcome(record.outcome); fight.defeated = fight.outcome == "Victory";
        for (p in array(record.players)) {
            var uid = text(p.uid);
            if (uid == "") throw "A history player has no ID.";
            var stats = new PlayerStats({uid: uid, name: text(p.name), isMe: p.isMe == true,
                className: text(p.className), weapon: null, classSkills: [], weaponSkills: []});
            stats.damage = number(p.damage); stats.heal = number(p.heal);
            stats.damageBreakdown = DamageBreakdown.read(p.damageBreakdown);
            stats.hits = Std.int(number(p.hits)); stats.crits = Std.int(number(p.crits)); stats.kills = Std.int(number(p.kills));
            for (s in array(p.skills)) {
                var skill = new SkillStats();
                skill.damage = number(s.damage); skill.hits = Std.int(number(s.hits));
                skill.damageBreakdown = DamageBreakdown.read(s.damageBreakdown);
                skill.crits = Std.int(number(s.crits)); skill.kills = Std.int(number(s.kills)); skill.casts = Std.int(number(s.casts));
                stats.skills[text(s.id)] = skill;
            }
            fight.players[uid] = stats;
            if (stats.info.isMe) fight.me = uid;
        }
        return fight;
    }
    public static function validate(record:Dynamic):Void {
        if (record == null || record.version != 1 || text(record.id) == "" || text(record.name) == ""
            || number(record.startedAt) <= 0 || number(record.duration) < 0
            || !Std.isOfType(record.players, Array)) throw "Invalid fight history record.";
    }
    /** Import the original uploader's surviving reports, once, without uploading them again. */
    public static function legacy(report:Dynamic, timestamp:Float, id:String):Dynamic {
        if (report == null || !Std.isOfType(report.players, Array)) throw "Invalid legacy combat report.";
        var phase = text(report.phase);
        var name = phase != "" ? phase : text(report.boss_name);
        if (name == "") name = text(report.boss_kind);
        if (name == "") name = "Other combat";
        // Old filenames record export time rather than the first-hit time.
        var duration = number(report.duration_sec);
        var players:Array<Dynamic> = [for (p in array(report.players)) {
            var skills:Array<Dynamic> = [for (s in array(p.skills)) {id: text(s.id), damage: number(s.damage), hits: number(s.hits),
                crits: number(s.crits), kills: number(s.kills), casts: number(s.casts), damageBreakdown: s.damage_breakdown}];
            {
                uid: text(p.uid), name: text(p.name), isMe: p.is_me == true,
                className: text(Reflect.field(p, "class")), damage: number(p.total_damage), heal: number(p.heal),
                hits: number(p.hits), crits: number(p.crits), kills: number(p.kills),
                skills: skills, damageBreakdown: p.damage_breakdown
            }
        }];
        return {version: 1, id: id, name: name, startedAt: timestamp - duration * 1000, duration: duration, players: players,
            activityId: text(report.activity_id), bossKind: text(report.boss_kind), phase: phase,
            difficulty: difficulty(report.difficulty), partySize: Std.int(number(report.party_size)), outcome: outcome(report.outcome)};
    }
    public static function outcome(value:Dynamic):String return switch (text(value)) {
        case "Victory": "Victory";
        case "Defeat": "Defeat";
        default: "";
    };
    public static function outcomeLabel(entry:HistoryEntry):String {
        var label = outcome(entry.outcome);
        return label == "" ? "Outcome unknown" : label;
    }
    public static function difficulty(value:Dynamic):Int return value == null ? -1 : Std.int(number(value));
    static function recordedPlayers(record:Dynamic):Int {
        var ids:Map<String, Bool> = [];
        if (text(record.me) != "") ids[text(record.me)] = true;
        for (p in array(record.players)) if (text(p.uid) != "") ids[text(p.uid)] = true;
        return Lambda.count(ids);
    }
    static function dateAndPlayer(entry:HistoryEntry):String return dateLabel(entry.startedAt)
        + (entry.playerName == "" ? "" : "  ·  " + entry.playerName);
    public static function attemptHeadingParts(entry:HistoryEntry):HistoryHeading return {
        before: dateLabel(entry.startedAt) + (entry.playerName == "" ? "" : "  ·  "),
        player: entry.playerName,
        after: "  ·  Party: " + (entry.partySize > 0 ? Std.string(entry.partySize)
            : entry.recordedPlayers > 0 ? "≥" + entry.recordedPlayers : "unknown") + "  ·  " + outcomeLabel(entry)
    };
    public static function attemptHeading(entry:HistoryEntry):String {
        var parts = attemptHeadingParts(entry);
        return parts.before + parts.player + parts.after;
    }
    public static function attemptDetail(entry:HistoryEntry):String return durationLabel(entry.duration) + "  ·  " + dpsLabel(entry.personalDps);
    public static function chartDetail(entry:Null<HistoryEntry>):String return entry == null ? "" : dateAndPlayer(entry)
        + "  ·  " + dpsLabel(entry.personalDps) + "  ·  " + durationLabel(entry.duration) + "  ·  " + outcomeLabel(entry)
        + (entry.damageTypeSummary == null || entry.damageTypeSummary == "" ? "" : "  ·  " + entry.damageTypeSummary);
    public static function recapDetail(recap:dpsmeter.RiftTracker.RiftRecap):String {
        // Use the beginning of the recorded rift, not the later boss phase or
        // the time the recap is copied. Boss-only recordings use their own start.
        var first = recap.gate != null ? recap.gate : recap.boss;
        var player = recordedPlayerName(recap.boss);
        if (player == "") player = recordedPlayerName(recap.gate);
        // Clearing the gates alone cannot make the overall rift a victory.
        var result = outcome(recap.boss.outcome);
        var breakdown = new DamageBreakdown();
        var total = 0.0;
        for (fight in [recap.gate, recap.boss]) if (fight != null) {
            var stats = fight.players[fight.me];
            if (stats == null) for (p in fight.players) if (p.info.isMe) { stats = p; break; }
            if (stats != null) { total += stats.damage; breakdown.merge(stats.damageBreakdown); }
        }
        var split = breakdown.summary(total);
        return dateLabel(first.startedAt) + (player == "" ? "" : "  ·  " + player)
            + "  ·  " + (result == "" ? "Outcome unknown" : result) + (split == "" ? "" : "  ·  " + split);
    }
    static function recordedPlayerName(fight:Null<Fight>):String {
        if (fight == null) return "";
        var player = fight.players[fight.me];
        if (player != null && player.info.name != "") return player.info.name;
        for (p in fight.players) if (p.info.isMe && p.info.name != "") return p.info.name;
        return fight.meName;
    }
    public static function dateLabel(timestamp:Float):String {
        var date = Date.fromTime(timestamp);
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear() + " at "
            + StringTools.lpad(Std.string(date.getHours()), "0", 2) + ":"
            + StringTools.lpad(Std.string(date.getMinutes()), "0", 2) + ":"
            + StringTools.lpad(Std.string(date.getSeconds()), "0", 2);
    }
    public static function durationLabel(seconds:Float):String {
        var n = Std.int(seconds);
        return n < 1 ? "<1 sec" : n < 60 ? n + " sec" : n < 3600 ? Std.int(n / 60) + " min " + n % 60 + " sec"
            : Std.int(n / 3600) + " hr " + Std.int(n % 3600 / 60) + " min " + n % 60 + " sec";
    }
    public static function dpsLabel(value:Null<Float>):String {
        if (value == null) return "Your DPS: unavailable";
        var raw = Std.string(Math.fround(value));
        var result = "";
        for (i in 0...raw.length) {
            if (i > 0 && (raw.length - i) % 3 == 0) result += ",";
            result += raw.charAt(i);
        }
        return "Your DPS: " + result;
    }
    public static function array(value:Dynamic):Array<Dynamic> return Std.isOfType(value, Array) ? cast value : [];
    public static function text(value:Dynamic):String return Std.isOfType(value, String) ? cast value : "";
    public static function number(value:Dynamic):Float {
        if (value == null) return 0;
        if ((!Std.isOfType(value, Float) && !Std.isOfType(value, Int)) || !Math.isFinite(value))
            throw "Invalid number in fight history.";
        return value;
    }
}
