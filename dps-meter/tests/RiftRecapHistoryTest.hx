import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.HistoryCatalog;
import dpsmeter.HistoryOptions;
import dpsmeter.BossRecords;
import dpsmeter.BossRecords.BossRecordRequest;
import dpsmeter.LogUploader;
import dpsmeter.RunWriter;
import dpsmeter.RiftRecapHistory;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

@:access(dpsmeter.RunWriter)
@:access(dpsmeter.LogUploader)
class RiftRecapHistoryTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void { checks++; if (!ok) throw message; }
    static function player(id:String):PlayerInfo return {
        uid: id, name: id == "me" ? "Wink" : "Ally", isMe: id == "me", className: "mage",
        weapon: null, classSkills: [], weaponSkills: []
    };
    static function hit(time:Float, amount:Float, boss:Bool = false, kill:Bool = false, source:String = "me"):DamageEvent return {
        time: time, amount: amount, source: source, target: boss ? "boss" : "mob", critical: kill, kill: kill,
        effect: 0, skill: boss ? "Spell" : "Strike", damageType: boss ? "magical" : "physical",
        bossKind: boss ? "MaatDemon" : "", bossName: boss ? "Nightking Maat Demon" : "",
        bossFlags: boss ? 8 : 0, bossLevel: 25, bossFoeId: 10
    };
    static function model():CombatModel {
        var m = new CombatModel(1, "0.3.0.test"); m.me = "me"; m.difficulty = 2;
        m.activityId = "Rift";
        for (id in ["me", "ally"]) { m.profiles[id] = player(id); m.party[id] = true; }
        m.enableRift(); m.updateRiftState(1, false, false, "MaatDemon");
        return m;
    }
    static function completed():CombatModel {
        var m = model(); m.onCombatEnter("me", 1); m.record(hit(1, 9999));
        m.startRiftGates(); m.record(hit(10, 100)); m.record(hit(11, 200, false, false, "ally"));
        m.updateRiftState(20, true, false, "MaatDemon");
        m.record(hit(20.1, 50, false, true));
        m.record(hit(21, 300, true)); m.record(hit(24, 100, true, false, "ally"));
        m.updateRiftState(30, true, true, "MaatDemon"); m.record(hit(30.1, 50, true, true));
        m.update(30.2, false);
        check(m.recapHistory.length == 0, "Recap archive waits for the final damage grace period");
        m.update(31, false);
        return m;
    }
    static function request(action:String, id:String = ""):HistoryRequest return {
        id: 1, action: action, group: RiftRecapHistory.NAME, page: 0, fightId: id, category: HistoryCategory.WORLD
    };
    static function remove(path:String):Void {
        if (FileSystem.isDirectory(path)) {
            for (name in FileSystem.readDirectory(path)) remove(path + "/" + name);
            FileSystem.deleteDirectory(path);
        } else FileSystem.deleteFile(path);
    }
    static function main():Void {
        var root = "build/recap-tests/" + Std.random(0x3fffffff);
        FileSystem.createDirectory(root);
        var m = completed();
        check(m.history.length == 2 && m.completed.length == 2 && m.recaps.length == 1 && m.recapHistory.length == 1,
            "The existing phase logs/reports, popup, and combined archive each receive their own handoff");
        var popup = m.recaps[0];
        m.recaps = []; // Same discard performed by a disabled automatic popup.
        m.update(32, false); m.reset(33); m.reset(34);
        check(m.recapHistory.length == 1 && m.recaps.length == 0, "Disabled popups and repeated zone/shutdown drains cannot lose or duplicate the archive");
        var writer = new RunWriter(); writer.uploader = new LogUploader(root);
        writer.archiveHistory(m);
        check(m.recapHistory.length == 0 && m.history.length == 0 && m.completed.length == 2,
            "The real archive handoff consumes local logs independently of report uploading");
        writer.uploader.flush();
        check(!FileSystem.exists(root + "/fareverly"), "Combined recaps never enter the network upload queue");
        writer.archiveHistory(m); writer.uploader.flush();
        var store = new FightHistoryStore(root, _ -> {}, path -> FileSystem.deleteFile(path));
        var groups = store.query(request("groups")).groups;
        check(groups.length == 3 && [for (g in groups) g.name].indexOf("Rift Recap") >= 0,
            "World Bosses lists one recap group alongside the two individual phase groups");
        var attempts = store.query(request("fights"));
        check(attempts.total == 1, "A completed rift is archived exactly once across repeated handoffs");
        var entry = attempts.entries[0];
        var path = root + "/history/Rift Recap/" + entry.id + ".json";
        check(FileSystem.exists(path) && FileSystem.readDirectory(root + "/history/Rift Recap").length == 1,
            "All difficulties use exactly the requested Rift Recap folder");
        var record = store.query(request("chart", entry.id)).record;
        var recap = RiftRecapHistory.decode(record);
        check(recap.gate.players["me"].damage == 150 && recap.boss.players["me"].damage == 350,
            "Both stored phases retain late killing blows and exclude pre-gate damage");
        check(recap.gate.players["ally"].damage == 200 && recap.boss.players["ally"].damage == 100,
            "Both phase rosters and other players' damage survive storage");
        check(recap.boss.players["me"].skills["Spell"].crits == 1
            && recap.boss.players["me"].damageBreakdown.summary(350).indexOf("Magical: 100%") >= 0,
            "Stored recap charts retain skill breakdowns, critical counts, and damage types");
        check(record.gameVersion == "0.3.0.test" && recap.gate.gameVersion == record.gameVersion
            && recap.boss.gameVersion == record.gameVersion, "Recaps and both phases retain the recorded game version");
        check(FightHistory.recapDetail(recap) == FightHistory.recapDetail(popup), "History reuses exactly the popup's recorded recap summary");
        check(entry.duration == 19 && Math.abs(entry.personalDps - 500 / 19) < .00001
            && entry.startedAt == recap.gate.startedAt, "Attempt summary combines damage over the sum of phase durations, starting at gates");
        check(entry.damageTypeSummary == "Physical: 30%  ·  Magical: 70%  ·  Raw: 0%"
            && entry.recordedPlayers == 2 && entry.playerName == "Wink", "Combined summary merges damage types and deduplicates player IDs");
        check(FightHistory.attemptDetail(entry).indexOf("Rift - Nightking Maat Demon") == 0,
            "Recap attempts identify the boss in the log list");
        var filter = request("fights"); filter.outcome = "Defeat";
        check(store.query(filter).total == 0, "Victory recaps respect the Outcome filter");
        filter.outcome = "Victory"; filter.character = HistoryOptions.characterKey(entry);
        check(store.query(filter).total == 1, "Recaps support combined character and outcome filtering");
        var otherCategory = request("groups"); otherCategory.category = HistoryCategory.BOSS;
        check(store.query(otherCategory).total == 0, "Recaps are only grouped under World Bosses");
        var bossRequest:BossRecordRequest = {id: 1, bossKind: "MaatDemon", difficulty: 2,
            playerName: "Wink", playerClass: "mage", before: Date.now().getTime() + 100000};
        check(BossRecords.best([entry].iterator(), bossRequest) == null, "Combined recaps cannot become boss kill-time records");
        check(store.bossRecord(bossRequest).best == 9, "The independent boss phase still supplies its normal kill-time record");

        // Phase files can be deleted independently: the recap is self-contained.
        for (group in groups) if (group.name != "Rift Recap") {
            var req = request("fights"); req.group = group.name;
            for (phase in store.query(req).entries) store.query(request("delete", phase.id));
        }
        var reopened = new FightHistoryStore(root, _ -> {}, file -> FileSystem.deleteFile(file));
        check(RiftRecapHistory.decode(reopened.query(request("chart", entry.id)).record).boss.players["me"].damage == 350,
            "Deleting the individual logs and restarting cannot break a saved recap");
        check(File.getContent(path) == Json.stringify(record), "Opening a recap leaves its archive bytes unchanged");
        reopened.query(request("delete", entry.id));
        check(!FileSystem.exists(path) && !FileSystem.exists(path + ".tmp"), "Deleting the recap removes only its self-contained log and recovery backup");
        reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("fights")).total == 0, "Deleted recaps do not return after restart");

        var bossOnly = model(); bossOnly.updateRiftState(10, true, false, "MaatDemon");
        bossOnly.record(hit(11, 123, true)); bossOnly.updateRiftState(20, true, true, "MaatDemon"); bossOnly.reset(20.1);
        check(bossOnly.recapHistory.length == 1 && bossOnly.recapHistory[0].gate == null, "Shutdown finalizes a boss-only recap without inventing gates");
        var single = RiftRecapHistory.encode(bossOnly.recapHistory[0], "boss_only");
        check(RiftRecapHistory.decode(single).gate == null && FightHistory.entry(single).duration == 9
            && FightHistory.entry(single).startedAt == bossOnly.recapHistory[0].boss.startedAt,
            "Boss-only recaps preserve an empty gate panel and use the boss start and duration");
        var temp = root + "/history/Rift Recap/boss_only.json.tmp";
        File.saveContent(temp, Json.stringify(single));
        reopened = new FightHistoryStore(root, _ -> {}); reopened.warm();
        check(reopened.query(request("chart", "boss_only")).record.id == "boss_only" && !FileSystem.exists(temp),
            "Interrupted recap saves recover through the existing nested draft mechanism");
        var incomplete = model(); incomplete.record(hit(1, 500)); incomplete.reset(5);
        check(incomplete.recapHistory.length == 0, "Pre-gate warm-up alone never produces a recap");
        incomplete = model(); incomplete.startRiftGates(); incomplete.record(hit(10, 100)); incomplete.reset(20);
        check(incomplete.recapHistory.length == 0, "An unfinished rift does not invent a completed recap");
        for (malformed in [{version: 1, kind: "rift-recap", id: "bad", name: "Rift Recap", gate: null, boss: null},
            {version: 1, kind: "rift-recap", id: "bad", name: "Rift Recap", gate: null, boss: record}]) {
            var failed = false; try FightHistory.validate(malformed) catch (_:Dynamic) failed = true;
            check(failed, "Missing or nested recap phases are rejected without recursive deserialization");
        }
        var ordinary = FightHistory.encode(popup.boss, "ordinary");
        check(!RiftRecapHistory.isRecap(ordinary) && FightHistory.decode(ordinary).players["me"].damage == 350,
            "Existing ordinary history records keep their original format and chart decoding");
        remove(root);
        Sys.println('Rift recap history: $checks checks passed');
    }
}
