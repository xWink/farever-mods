import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.LogUploader;
import dpsmeter.HistoryCatalog;
import dpsmeter.SkillBreakdown;
import dpsmeter.NativeCombatMetadata;
import dpsmeter.GameAccess;
import dpsmeter.HistoryRequests;
import dpsmeter.SnapshotLayout;
import dpsmeter.SnapshotTexture;
import dpsmeter.HistoryOptions;
import dpsmeter.BossRecords;
import dpsmeter.LiteralText;
import dpsmeter.RunWriter;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

@:access(dpsmeter.LogUploader)
@:access(dpsmeter.RunWriter)
@:access(dpsmeter.NativeCombatMetadata)
class HistoryTest {
    static var checks = 0;
    static final UNKNOWN_SPLIT = "  ·  Physical: 0%  ·  Magical: 0%  ·  Raw: 0%";
    static function check(condition:Bool, message:String):Void {
        checks++;
        if (!condition) throw message;
    }
    static function profile(id:String = "me", mine:Bool = true):PlayerInfo return {
        uid: id, name: mine ? "Shawn" : "Ally", isMe: mine, className: mine ? "warrior" : "mage",
        weapon: null, classSkills: [], weaponSkills: []
    };
    static function hit(time:Float, amount:Float, kill:Bool = false, boss:Bool = false, source:String = "me", target:String = "enemy"):DamageEvent return {
        time: time, source: source, amount: amount, critical: false, kill: kill, effect: 0, skill: "Strike",
        target: target, bossKind: boss ? "BossKind" : "", bossName: boss ? "The Guardian" : "",
        bossFlags: boss ? 8 : 0, bossLevel: 25, bossFoeId: 7
    };
    static function model():CombatModel {
        var m = new CombatModel(1); m.me = "me";
        m.profiles["me"] = profile(); m.profiles["ally"] = profile("ally", false);
        m.party["me"] = true; m.party["ally"] = true;
        return m;
    }
    static function sample():Fight {
        var f = new Fight(10); f.startedAt = Date.fromString("2026-09-14 13:20:30").getTime();
        f.me = "me"; f.bossName = "The Guardian"; f.category = HistoryCategory.WORLD;
        f.add(hit(10, 100.5), profile());
        var critical = hit(12, 250, true); critical.critical = true;
        f.add(critical, profile()); f.add(hit(14, 500, false, false, "ally"), profile("ally", false));
        f.last = 20; f.closed = 20; return f;
    }
    static function request(action:String, group:String = "", page:Int = 0, fightId:String = ""):HistoryRequest
        return {id: 17, action: action, group: group, page: page, fightId: fightId};
    static function main():Void {
        clientSkillCompatibility(); archivePolicy(); targetDummies();
        lifecycle(); chakram(); outcomes(); recapSummary(); snapshots(); storage(); uploader(); categories(); metadata(); breakdown(); encounterDetails(); historyActions(); snapshotLayouts(); snapshotTextures(); historyOptions(); literalLabels(); bossRecords();
        Sys.println('Fight history: $checks checks passed');
    }
    static function archivePolicy():Void {
        var root = temp("archive-policy");
        var store = new FightHistoryStore(root, _ -> {});
        var other = sample(); other.category = HistoryCategory.OTHER;
        other.bossKind = "Phrixes"; // A recognized name must not override an explicit Other classification.
        var record = FightHistory.encode(other, "other");
        store.save(record);
        check(!FileSystem.exists(root + "/history/other.json"), "Unclassified nondummy fights never produce an archive, even with a known boss name");
        other.bossName = ""; other.bossKind = "";
        var ordinary = FightHistory.encode(other, "ordinary");
        check(ordinary.name == "Other combat", "Ordinary combat fixture has the reported fallback title");
        store.save(ordinary);
        check(!FileSystem.exists(root + "/history/ordinary.json"), "Other combat does not write a file");
        var writer = new RunWriter(); writer.archive(other);
        check(writer.uploader == null, "Other fights are discarded before creating a worker or queued record");
        existingHistory(root, ordinary);
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("chart", "", 0, "ordinary")).record.id == "ordinary",
            "Existing Other history remains available and is not deleted");
        check(File.getContent(root + "/history/ordinary.json") == Json.stringify(ordinary),
            "Browsing an old Other fight leaves its saved file unchanged");
        for (category in [HistoryCategory.BOSS, HistoryCategory.DUNGEON, HistoryCategory.WORLD]) {
            var fight = sample(); fight.category = category;
            var id = "allowed_" + category.split(" ").join("_");
            store.save(FightHistory.encode(fight, id));
            check(FileSystem.exists(root + "/history/" + id + ".json"), "Recognized encounters still save: " + category);
        }
        var legacy = FightHistory.legacy(other.json("20260917-120000", 1), Date.now().getTime(), "legacy_other");
        store.save(legacy);
        check(!FileSystem.exists(root + "/history/legacy_other.json"), "Unclassified legacy exports are not imported as new Other archives");
        remove(root);
    }
    static function targetDummies():Void {
        var key = "_Data.Unit_group_Impl_.Dummy";
        GameAccess.globals.remove(key); NativeCombatMetadata.dummyGroup = null;
        check(!NativeCombatMetadata.isTargetDummy({group: 0}), "Missing native dummy metadata does not classify ordinary units");
        GameAccess.globals[key] = 0;
        check(NativeCombatMetadata.isTargetDummy({group: 0}), "Retry after definitions load, including a zero-valued dummy group");
        NativeCombatMetadata.dummyGroup = null; GameAccess.globals[key] = 42;
        var definition = {id: "FuturePracticeTarget", name: "Mannequin", group: 42};
        check(NativeCombatMetadata.isTargetDummy(definition), "New IDs and translated names use native dummy classification");
        check(!NativeCombatMetadata.isTargetDummy({id: "Dummy", name: "Target dummy", group: 7}), "Names alone cannot enable saving");
        check(!NativeCombatMetadata.isTargetDummy(null) && !NativeCombatMetadata.isTargetDummy({id: "Dummy"}), "Missing unit or group is not a dummy");

        for (flags in [0, 8, 16, 32, 0x38]) {
            var root = temp("dummy-" + flags);
            var m = model(); m.activityId = "PracticeArea"; m.activityCategory = HistoryCategory.BOSS;
            var event = hit(10, 100, false, false, "me", "dummy");
            event.targetDummy = NativeCombatMetadata.isTargetDummy(definition);
            event.bossKind = definition.id; event.bossFlags = flags;
            // The opening hit can precede native combat entry, and practice
            // ends without killing the target. Include an ally's damage too.
            m.record(event); m.onCombatEnter("me", 10.1);
            event = Reflect.copy(event); event.time = 11; event.source = "ally"; event.amount = 200;
            m.record(event); m.onCombatExit("me", 12); m.update(13, false);
            check(m.history.length == 1 && m.history[0].targetDummy, "Dummy marker survives opening-hit buffering and history copies");
            var fight = m.history[0];
            check(fight.category == HistoryCategory.DUMMY && FightHistory.name(fight) == "Target dummy", "Dummy flags keep practice in its own category");
            check(m.boss == null && m.completed.length == 0, "Dummy flags cannot produce boss uploads");
            var writer = new RunWriter(); writer.archive(fight);
            check(writer.uploader != null, "Dummy practice reaches the archive worker");
            var record = writer.uploader.historyIncoming.pop(false);
            check(record != null && record.targetDummy == true, "Detached queue preserves dummy evidence");
            var store = new FightHistoryStore(root, _ -> {}); store.save(record);
            check(FileSystem.exists(root + "/history/" + record.id + ".json"), "Dummy practice is written to disk");
            store = new FightHistoryStore(root, _ -> {});
            var query = request("groups"); query.category = HistoryCategory.DUMMY;
            query.catalog = {activities: ["PracticeArea" => HistoryCategory.WORLD], names: [], bosses: []};
            var groups = store.query(query);
            check(groups.groups.length == 1 && groups.groups[0].name == "Target dummy", "After restart, practice stays in Target Dummies despite area classification");
            query = request("fights", "Target dummy"); query.category = HistoryCategory.DUMMY;
            var attempts = store.query(query);
            check(attempts.total == 1 && attempts.entries[0].personalDps == 50, "Saved dummy attempt retains its duration and personal DPS");
            var chart = FightHistory.decode(store.query(request("chart", "", 0, record.id)).record);
            check(chart.targetDummy && chart.players["ally"].damage == 200 && chart.players["me"].skills["Strike"].damage == 100,
                "Dummy charts retain player and skill breakdowns");
            var earlier = Reflect.copy(record); earlier.id = "earlier_" + flags; earlier.category = HistoryCategory.OTHER;
            store.save(earlier);
            var earlierPath = root + "/history/" + earlier.id + ".json";
            var original = File.getContent(earlierPath);
            store = new FightHistoryStore(root, _ -> {});
            var menu = store.query(request("categories"));
            check(menu.groups[3].name == HistoryCategory.DUMMY && menu.groups[3].count == 2
                && menu.groups[4].name == HistoryCategory.OTHER && menu.groups[4].count == 0,
                "New and previously saved dummy fights share the new category and leave Other");
            check(store.query(query).entries.length == 2, "Earlier dummy attempts remain accessible in the new category");
            check(store.query(request("chart", "", 0, earlier.id)).record.id == earlier.id,
                "Earlier dummy charts keep their existing IDs");
            check(File.getContent(earlierPath) == original, "Reclassification does not rewrite saved damage logs");
            m.onCombatEnter("me", 20); m.record(hit(20, 50)); m.onCombatExit("me", 22); m.update(23, false);
            writer.archive(m.history[1]);
            check(!m.history[1].targetDummy && writer.uploader.historyIncoming.pop(false) == null, "Following ordinary combat does not inherit the dummy exception");
            remove(root);
        }
        var m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 5));
        var heal = hit(11, 20); heal.effect = 1; heal.targetDummy = true; m.record(heal);
        m.onCombatExit("me", 12); m.update(13, false);
        check(!HistoryCategory.canArchive(FightHistory.encode(m.history[0], "healing")), "Healing alone cannot enable the dummy exception");
        m = model(); m.profiles["stranger"] = profile("stranger", false); m.onCombatEnter("me", 10); m.record(hit(10, 5));
        var remote = hit(11, 20, false, false, "stranger"); remote.targetDummy = true; m.record(remote);
        m.onCombatExit("me", 12); m.update(13, false);
        check(!m.history[0].targetDummy, "An unrelated player training nearby cannot make ordinary combat save");
        GameAccess.globals.remove(key); NativeCombatMetadata.dummyGroup = null;
    }
    static function clientSkillCompatibility():Void {
        var oldSkill = {kind: "OldStrike"};
        var newSkill = {kind: "NewStrike"};
        var reader = GameAccess.field;
        check(gamecompat.HitSkill.read({baseSkill: oldSkill}, reader) == oldSkill, "live hit keeps its skill");
        check(gamecompat.HitSkill.read({skill: newSkill}, reader) == newSkill, "PTR hit keeps its skill");
        check(gamecompat.HitSkill.read({skill: newSkill, baseSkill: oldSkill}, reader) == newSkill, "prefer the new skill field");
        check(gamecompat.HitSkill.read({skill: null, baseSkill: oldSkill}, reader) == oldSkill, "null field can fall back");
        check(gamecompat.HitSkill.read(null, reader) == null, "missing hit is safe");
        var fight = new Fight(1);
        for (data in ([{baseSkill: oldSkill}, {skill: newSkill}]:Array<Dynamic>)) {
            var event = hit(1, 25);
            event.skill = GameAccess.text(GameAccess.field(gamecompat.HitSkill.read(data, reader), "kind"));
            fight.add(event, profile());
        }
        var player = fight.players["me"];
        check(player.damage == 50 && player.skills["OldStrike"].damage == 25
            && player.skills["NewStrike"].damage == 25, "both client shapes retain totals and breakdown damage");
    }
    static function literalLabels():Void {
        var record = FightHistory.encode(sample(), "instant"); record.duration = .001;
        var detail = FightHistory.attemptDetail(FightHistory.entry(record));
        var failed = false;
        try Xml.parse("<text>" + detail + "</text>") catch (_:Dynamic) failed = true;
        check(failed, "An unescaped sub-second attempt reproduces the native XML parse error");
        for (value in [detail, "Wink <Warrior> & friends", "<b>Ratsar</b>", "[Warrior_RageStrike] $unit(Ratsar)",
            "Literal &lt;tag&gt;", "Best: <0.01 sec", "Your DPS: 265"]) {
            var encoded = LiteralText.escape(value);
            var decoded = Xml.parse("<text>" + encoded + "</text>").firstElement().firstChild().nodeValue;
            check(decoded == value, "Native XML label round-trips literal text: " + value);
            check(!~/<([a-zA-Z]+)>(.*?)<\/\1>/.match(encoded)
                && !~/\$([a-z_]+)\(([^)]*)\)/.match(encoded)
                && !~/\[([!;A-Za-z0-9][A-Za-z0-9_]+)(-([A-Za-z0-9_]+))?\]([A-Za-z]*)/.match(encoded),
                "Game formatting syntax is inert before XML decoding: " + value);
        }
    }
    static function bossRecords():Void {
        var root = temp("boss_records");
        FileSystem.createDirectory(root + "/recycled");
        var store = new FightHistoryStore(root, _ -> {}, path ->
            FileSystem.rename(path, root + "/recycled/" + haxe.io.Path.withoutDirectory(path)));
        var f = sample(); f.bossKind = "BossKind"; f.difficulty = 1; f.outcome = "Victory";
        var prior = FightHistory.encode(f, "prior"); prior.duration = 72.34;
        store.save(prior);
        var query:BossRecordRequest = {id: 200, bossKind: "BossKind", difficulty: 1,
            playerName: "Shawn", playerClass: "warrior", before: f.startedAt + 100000};
        check(store.bossRecord(query).best == 72.34, "Previously saved victories are available without opening history");
        var excluded = ["difficulty", "class", "character", "boss", "defeat", "unknown", "gates", "zero"];
        for (reason in excluded) {
            var other:Dynamic = Json.parse(Json.stringify(prior)); other.id = reason; other.duration = 1;
            switch (reason) {
                case "difficulty": other.difficulty = 2;
                case "class": for (p in (cast other.players:Array<Dynamic>)) if (p.isMe) p.className = "mage";
                case "character": for (p in (cast other.players:Array<Dynamic>)) if (p.isMe) p.name = "Someone else";
                case "boss": other.bossKind = "AnotherBoss";
                case "defeat": other.outcome = "Defeat";
                case "unknown": Reflect.deleteField(other, "outcome");
                case "gates": other.phase = dpsmeter.RiftTracker.GATES_PHASE;
                case "zero": other.duration = 0;
            }
            store.save(other);
            check(store.bossRecord(query).best == 72.34, "Prior record excludes " + reason);
        }
        var current:Dynamic = Json.parse(Json.stringify(prior)); current.id = "current";
        current.startedAt = query.before; current.duration = 60;
        store.save(current);
        check(store.bossRecord(query).best == 72.34, "A newly archived faster current kill still displays the old record");
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.bossRecord(query).best == 72.34, "Restart rebuilds the same previous record from saved logs");
        query.before += 100000;
        check(store.bossRecord(query).best == 60, "The new record becomes eligible for the next encounter");
        store.query(request("delete", "", 0, "current"));
        check(store.bossRecord(query).best == 72.34, "Recycling the fastest log immediately restores the next fastest record");
        query.bossKind = "NoKillsYet";
        check(store.bossRecord(query).best == null && BossRecords.label(store.bossRecord(query)) == "Best: none",
            "A first kill has no invented previous record");
        query.bossKind = "BossKind"; query.difficulty = -1;
        check(store.bossRecord(query).error != "" && BossRecords.label(store.bossRecord(query)) == "Best: unavailable",
            "Missing difficulty is not mistaken for an empty record history");
        query.difficulty = 1; query.playerClass = "";
        check(store.bossRecord(query).error != "", "Missing character class cannot mix same-name characters");
        query.playerClass = "warrior";
        var worker = new LogUploader(root);
        worker.warmHistory();
        // A fresh worker has not answered any queries. Once warmed, it must
        // serve summaries without reopening old chart files at kill time.
        var priorPath = root + "/history/prior.json";
        var original = File.getContent(priorPath);
        File.saveContent(priorPath, "{simulate an unreadable file after startup");
        worker.requestBossRecord(query); worker.readBossRecords();
        check(worker.receiveBossRecord().best == 72.34, "Startup warming serves the first kill from memory without reopening charts");
        File.saveContent(priorPath, original);
        var queued:Dynamic = Json.parse(Json.stringify(prior)); queued.id = "queued";
        queued.duration = 50; queued.startedAt = query.before;
        worker.archive(queued); worker.requestBossRecord(query); worker.requestHistory(request("categories"));
        worker.flush(); worker.browseHistory(); worker.readBossRecords();
        check(worker.receiveBossRecord().best == 72.34, "Worker can save the current record before lookup without using it as prior best");
        check(worker.receiveHistory().id == 17 && worker.receiveBossRecord() == null,
            "History navigation and record notifications have independent response queues");
        var next = {id: 201, bossKind: query.bossKind, difficulty: 1, playerName: "Shawn", playerClass: "warrior", before: query.before + 100000};
        worker.requestBossRecord(query); worker.requestBossRecord(next); worker.readBossRecords();
        check(worker.receiveBossRecord().id == 200 && worker.receiveBossRecord().best == 50,
            "Consecutive boss lookups are not coalesced away and retain their own cutoff");
        remove(root);

        var m = model(); m.difficulty = 1; m.onCombatEnter("me", 10);
        m.record(hit(10, 100, false, true));
        var start = m.current.startedAt;
        var q = BossRecords.request(1, "BossKind", m, 5, start + 100000);
        check(q.before == start && q.playerName == "Shawn" && q.playerClass == "warrior" && q.difficulty == 1,
            "Kill progress before combat exit uses the active encounter's start and stable character identity");
        m.record(hit(12, 200, true, true)); m.onCombatExit("me", 12);
        check(BossRecords.request(2, "BossKind", m, 5, start + 100000).before == start,
            "The final-damage grace period retains the same record cutoff");
        m.update(13, false); m.history = [];
        check(BossRecords.request(3, "BossKind", m, 5, start + 100000).before == start,
            "Draining the archive queue does not let the current kill become its own record");
        check(BossRecords.request(4, "BossKind", m, 14, start + 100000).before == start + 100000,
            "An unobserved shared kill does not reuse a fight older than the counter baseline");
        m = model(); m.difficulty = 2; m.record(hit(20, 10, true, true));
        check(BossRecords.request(5, "BossKind", m, 15, 1).before > 1,
            "Instant kills in the pre-combat buffer also exclude themselves");
        m = model(); m.difficulty = 1; m.enableRift(); m.updateRiftState(10, true, false, "BossKind");
        m.record(hit(10, 100, false, true)); m.updateRiftState(20, true, true, "BossKind");
        check(BossRecords.request(6, "BossKind", m, 5, 1).before == m.lastCombat.startedAt,
            "Rift boss completion uses the boss phase's start, not the gates phase");
        check(BossRecords.duration(72.34) == "1 min 12.34 sec" && BossRecords.duration(59.999) == "1 min 00.00 sec"
            && BossRecords.duration(.001) == "<0.01 sec", "Record durations retain hundredths and round minute boundaries correctly");
        var best:BossRecordResponse = {id: 1, best: 10, error: ""};
        check(BossRecords.label(best) == "Best: 10.00 sec", "The label is always Best without needing current-fight finalization");
    }
    static function chakramHit(time:Float, amount:Float, kill:Bool = false):DamageEvent {
        var e = hit(time, amount, kill, true, "me", "chakram");
        e.bossKind = "Phrixes"; e.bossFlags = 0x10; e.bossName = "High Inquisitor Chakram";
        return e;
    }
    static function chakram():Void {
        var m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false);
        m.record(chakramHit(10, 100));
        m.updatePhrixes(20, "chakram", 1, false, true, false);
        m.record(chakramHit(20, 200, true));
        m.onCombatExit("me", 20);
        m.update(21, false);
        check(m.history.length == 0 && m.current != null && m.current.players["me"].damage == 300,
            "Chakram's first health bar and local combat exit do not archive a separate encounter");
        check(m.completed.length == 0 && m.boss != null && m.boss.players["me"].kills == 0,
            "A lethal first health bar does not produce a boss kill or upload");
        m.updatePhrixes(22, "chakram", 2, false, true, false);
        m.updatePhrixes(60, "chakram", 3, false, true, false);
        m.update(60, false);
        check(m.current.duration(60) == 50 && m.boss != null, "The long bridge transition retains both clocks and the uploader aggregate");
        m.record(hit(61, 50, false, false, "ally", "bridgeAdd"));
        check(m.current.players["ally"].damage == 50, "Party damage during the bridge belongs to the held encounter");
        m.updatePhrixes(70, "chakram", 4, true, false, false);
        m.onCombatEnter("me", 70); m.record(chakramHit(71, 300));
        check(m.current.start == 10 && m.current.players["me"].damage == 600, "Re-entering combat in demon form preserves first-phase damage and start time");
        m.updatePhrixes(80, "chakram", 4, false, false, true);
        m.onCombatExit("me", 80);
        m.record(chakramHit(80.1, 400, true)); m.update(81, false);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 1000 && m.history[0].defeated,
            "Death-before-damage ordering still records one complete two-phase fight");
        check(m.completed.length == 1 && m.completed[0].players["me"].damage == 1000,
            "Only the real final kill queues the combined boss report");
        check(Math.abs(m.history[0].duration() - 70.1) < .000001 && m.history[0].players["me"].kills == 1,
            "Combined duration includes the bridge, with exactly one boss kill");
        m.updatePhrixes(83, "chakram", 1, true, false, false);
        m.onCombatEnter("me", 83); m.record(chakramHit(83, 5));
        check(m.current.start == 83 && m.boss.players["me"].damage == 5, "A new kill attempt never resumes an already completed Chakram report");

        // A first-bar wipe is not a transformation; allow one second for native
        // replication to settle, then freeze the actual exit, not the grace time.
        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.updatePhrixes(15, "chakram", 1, false, false, false); m.onCombatExit("me", 15);
        m.updatePhrixes(16, "chakram", 1, false, false, false); m.update(16, false);
        check(m.history.length == 1 && m.history[0].duration() == 5 && !m.history[0].defeated && m.boss == null,
            "A first-phase wipe finishes at the local exit and discards the incomplete uploader fight");
        m.updatePhrixes(17, "chakram", 1, true, false, false); m.onCombatEnter("me", 17); m.record(chakramHit(17, 7));
        check(m.current.start == 17 && m.boss.players["me"].damage == 7, "A same-entity wipe and retry stays a separate attempt");

        m.updatePhrixes(20, "chakram", 4, true, false, false); m.record(chakramHit(20, 8));
        m.updatePhrixes(22, "chakram", 4, false, false, false); m.onCombatExit("me", 22);
        m.updatePhrixes(23, "chakram", 4, false, false, false); m.update(23, false);
        check(m.history.length == 2 && m.current == null && m.completed.length == 0,
            "A wipe at a demon-form checkpoint ends even when the phase number does not decrease");
        m.updatePhrixes(24, "chakram", 4, true, false, false); m.onCombatEnter("me", 24); m.record(chakramHit(24, 3));
        check(m.current.start == 24 && m.boss.players["me"].damage == 3, "Checkpoint retries do not inherit a previous attempt's damage");
        m.updatePhrixes(25, "chakram", 1, true, false, false); m.record(chakramHit(25, 2)); m.update(26, true);
        check(m.history.length == 3 && m.current.start == 25 && m.boss.players["me"].damage == 2,
            "A phase regression also splits a reset that occurs between combat polls");
        m.updatePhrixes(27, "chakram", 2, false, true, false); m.onCombatExit("me", 27); m.reset(40);
        check(m.history.length == 4 && m.history[3].duration() == 15 && m.current == null,
            "Leaving the zone during a bridge transition preserves the unfinished fight once");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 4, true, false, false); m.record(chakramHit(10, 11));
        m.updatePhrixes(15, "chakram", 4, false, false, true);
        m.record(chakramHit(15.1, 9, true)); m.update(16, true);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 20 && m.current == null,
            "Final death before the lethal RPC does not create a one-hit second log when the hero's flag is still true");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 4, true, false, false); m.record(chakramHit(10, 12));
        m.updatePhrixes(15, "chakram", 4, false, false, true);
        m.updatePhrixes(15.6, "chakram", 4, false, false, true); m.update(16, false);
        check(m.history.length == 1 && m.history[0].duration() == 5 && m.completed.length == 0,
            "Missing final RPC still closes local history at observed death without inventing an upload");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.onCombatExit("me", 15);
        m.updatePhrixes(20, "chakram", 3, false, true, false);
        m.updatePhrixes(40, "chakram", 4, true, false, false);
        m.record(hit(50, 20, false, false, "ally", "chakram"));
        m.updatePhrixes(60, "chakram", 4, false, false, false);
        m.updatePhrixes(61, "chakram", 4, false, false, false); m.update(61, false);
        check(m.history.length == 1 && m.history[0].duration() == 50 && m.history[0].players["ally"].damage == 20,
            "A later party wipe never rewinds the duration to the local hero's first-phase exit");
    }
    static function lifecycle():Void {
        var m = model();
        m.onCombatEnter("me", 10);
        m.record(hit(10, 100, false, true));
        m.record(hit(11, 400, false, false, "ally"));
        m.onCombatExit("me", 12);
        check(m.history.length == 0, "History must wait for late damage");
        m.record(hit(12.1, 200, true, true));
        m.update(12.6, false);
        check(m.history.length == 1, "One completed combat, not a second boss report");
        check(m.completed.length == 1, "Boss upload still queued separately");
        var f = m.history[0];
        check(f.duration() == 2 && f.players["me"].damage == 300, "Final blow included without extending duration");
        check(FightHistory.name(f) == "The Guardian", "Human-readable boss name");
        check(FightHistory.entry(FightHistory.encode(f, "one")).personalDps == 150, "DPS is the local player's total, not the party's");
        m.update(30, false); check(m.history.length == 1, "No repeated archive during idle updates");
        m.onCombatEnter("me", 31); m.record(hit(31, 5)); m.onCombatExit("me", 33); m.update(34, false);
        check(m.history.length == 2 && FightHistory.name(m.history[1]) == "Other combat", "Ordinary combat archived too");
        check(f.players["me"].damage == 300, "A later fight cannot mutate its predecessor");
        m = model(); m.record(hit(10, 50, true)); m.update(10.6, false);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 50, "One-shot with no combat entry retained");
        m = model(); m.record(hit(10, 50, false, false, "ally")); m.update(11, false);
        check(m.history.length == 0, "Remote damage while resting is not a local fight");
        m = model(); m.record(hit(10, 50)); m.onCombatEnter("me", 10.1); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history.length == 1 && m.history[0].start == 10, "Opening damage before combat entry retained once");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 80)); m.reset(20);
        check(m.history.length == 1 && m.history[0].duration() == 10, "Zone changes preserve unfinished fights");
        m.reset(21); check(m.history.length == 1, "Double shutdown does not duplicate a fight");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 80)); m.onCombatExit("me", 11);
        m.onCombatEnter("me", 11.1); m.record(hit(11.1, 40)); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history.length == 2 && m.history[0].players["me"].damage == 80
            && m.history[1].players["me"].damage == 40, "Rapid consecutive fights remain separate");
        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 10)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 100, false, true)); m.updateRiftState(25, true, true, "BossKind");
        m.record(hit(25.1, 200, true, true)); m.update(26, false);
        check(m.history.length == 2 && m.completed.length == 2 && m.recaps.length == 1, "Both rift phases archived, uploads and recap intact");
        check(FightHistory.name(m.history[0]) == "Rift: Gates" && FightHistory.name(m.history[1]) == "Rift: The Guardian", "Rift grouping names");
        check(m.history[1].players["me"].damage == 300, "Late rift killing blow retained");
        m.update(30, false); m.reset(31);
        check(m.history.length == 2, "Completed rift not archived twice on leaving");
        m = model(); m.enableRift(); m.record(hit(10, 10)); m.reset(15);
        check(m.history.length == 1 && m.completed.length == 0 && m.recaps.length == 0, "Abandoned rift stays local");
        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 10)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 70, false, true)); m.reset(24);
        check(m.history.length == 2 && m.completed.length == 1, "Leaving during rift boss preserves both charts, only gates uploaded");
        m = model(); m.onCombatEnter("me", 10); m.onCombatExit("me", 12); m.reset(13);
        check(m.history.length == 0, "No empty fights from combat flags alone");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 90, false, false, "ally"));
        m.onCombatExit("me", 12); m.update(13, false);
        var passive = FightHistory.entry(FightHistory.encode(m.history[0], "passive"));
        check(passive.personalDps == 0 && passive.playerName == "Shawn", "A known local player who dealt no damage has zero DPS and keeps their name");
    }
    static function outcomes():Void {
        var m = model(); m.onCombatEnter("me", 10);
        m.record(hit(10, 20, true)); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].outcome == "Victory", "Defeating every foe in an ordinary fight records a victory");
        m = model(); m.record(hit(10, 20, true)); m.update(11, false);
        check(m.history[0].outcome == "Victory", "A one-shot victory works without a combat-entry event");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 20));
        m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].outcome == "Defeat", "Leaving combat while an observed foe survives is a failure");

        m = model(); m.onCombatEnter("me", 10);
        var bossHit = hit(10, 100, false, true, "me", "boss"); bossHit.bossFlags = 0x10;
        m.record(bossHit); m.record(hit(11, 20, true, false, "me", "add"));
        m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].outcome == "Defeat", "Killing a boss's adds cannot count as defeating the boss");

        m = model(); m.onCombatEnter("me", 10); m.record(bossHit);
        m.record(hit(11, 20, false, false, "me", "add"));
        m.onTargetDeath("boss", 12); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].outcome == "Victory", "A native boss death records victory even with surviving adds and an external player's final blow");
        check(m.completed.length == 0, "Outcome observation never invents a damage event or an uploader report");

        m = model(); m.onCombatEnter("me", 10); m.record(bossHit);
        m.onCombatExit("me", 12); m.onTargetDeath("boss", 12.2); m.update(13, false);
        check(m.history[0].outcome == "Victory", "Boss death arriving just after local combat exit updates the pending archive");
        m.onTargetDeath("anotherBoss", 14);
        check(m.history[0].outcome == "Victory", "Unrelated later deaths cannot change an archived outcome");
        m = model(); m.onCombatEnter("me", 10); m.record(bossHit); m.onCombatExit("me", 12);
        var finalHit = hit(12.2, 200, true, true, "me", "boss"); finalHit.bossFlags = 0x10;
        m.record(finalHit); m.update(13, false);
        check(m.history[0].outcome == "Victory" && m.history[0].players["me"].damage == 300,
            "Late lethal damage confirms victory without losing damage or creating a second log");

        var saved = m.history[0].copy(); saved.partySize = 3; saved.category = HistoryCategory.WORLD;
        var record = FightHistory.encode(saved, "outcome_victory");
        var entry = FightHistory.entry(Json.parse(Json.stringify(record)));
        check(FightHistory.decode(record).outcome == "Victory" && record.outcome == "Victory",
            "A copied fight retains its outcome through JSON serialization and decoding");
        check(StringTools.endsWith(FightHistory.attemptHeading(entry), "Party: 3  ·  Victory")
            && StringTools.endsWith(FightHistory.chartDetail(entry), "2 sec  ·  Victory" + UNKNOWN_SPLIT),
            "Victory appears after party size in the list and after duration in the chart and snapshot summary");
        var parts = FightHistory.attemptHeadingParts(entry);
        check(parts.player == entry.playerName && parts.before + parts.player + parts.after == FightHistory.attemptHeading(entry)
            && parts.before.indexOf("Party:") < 0 && parts.after.indexOf("Party: 3") >= 0,
            "The coloured name is isolated from the date, party size, and outcome without changing their text order");
        var unnamed:HistoryEntry = Reflect.copy(entry); unnamed.playerName = "";
        parts = FightHistory.attemptHeadingParts(unnamed);
        check(parts.player == "" && parts.before == FightHistory.dateLabel(entry.startedAt)
            && parts.after.indexOf("  ·  Party:") == 0, "An unknown character leaves no empty name or extra separator in the heading");
        saved.outcome = "Defeat";
        var failure = FightHistory.encode(saved, "outcome_failure");
        check(FightHistory.decode(failure).outcome == "Defeat" && StringTools.endsWith(FightHistory.attemptHeading(FightHistory.entry(failure)), "Defeat"),
            "Defeat survives serialization and has the requested history label");
        var root = temp("outcomes"); var store = new FightHistoryStore(root, _ -> {});
        store.save(record); store.save(failure);
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("chart", "", 0, record.id)).record.outcome == "Victory"
            && reopened.query(request("fights", record.name)).entries.length == 2,
            "Victory and failure records survive a store restart and remain in the same encounter list");
        var old = FightHistory.encode(sample(), "old_outcome"); Reflect.deleteField(old, "outcome");
        var unchanged = Json.stringify(old); store.save(old);
        var oldEntry = FightHistory.entry(old);
        check(oldEntry.outcome == "" && StringTools.endsWith(FightHistory.attemptHeading(oldEntry), "Outcome unknown")
            && FightHistory.decode(old).outcome == "", "Older logs without outcome metadata are never labelled failure by default");
        reopened = new FightHistoryStore(root, _ -> {}); reopened.query(request("chart", "", 0, old.id));
        check(File.getContent(root + "/history/old_outcome.json") == unchanged, "Reading old outcome-less logs does not rewrite them");
        var legacy = FightHistory.legacy(sample().json("20260914-120000", 1), Date.now().getTime(), "legacy_outcome");
        check(FightHistory.entry(legacy).outcome == "", "Legacy exports without explicit outcomes are not guessed from skill kill counts");
        remove(root);

        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 20, true)); m.updateRiftState(20, true, false, "BossKind");
        var clone = hit(21, 30, true, true); clone.summoned = true;
        m.record(hit(20, 100, false, true)); m.record(clone); m.onTargetDeath("enemy", 21); m.update(22, false);
        check(m.history.length == 1 && m.history[0].outcome == "Victory", "Clearing Rift gates is a phase victory; a boss clone death does not complete the boss phase");
        m.reset(23);
        check(m.history.length == 2 && m.history[1].outcome == "Defeat", "Leaving an unfinished Rift boss records failure despite a lethal clone hit");
        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 20, true)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 100, false, true)); m.updateRiftState(25, true, true, "BossKind"); m.update(26, false);
        check(m.history.length == 2 && m.history[1].outcome == "Victory", "Rift boss objective completion confirms victory without needing the final damage RPC");
        m = model(); m.enableRift(); m.record(hit(10, 20, true)); m.reset(20);
        check(m.history[0].outcome == "Defeat", "Leaving Rift gates before their objective finishes is failure even if every observed gate died");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.updatePhrixes(20, "chakram", 2, false, true, false); m.record(chakramHit(20, 20, true));
        m.onCombatExit("me", 20); m.reset(30);
        check(m.history[0].outcome == "Defeat", "Chakram's first-bar lethal result is not a victory when the full encounter is abandoned");
        check(dpsmeter.MeterConfig.defaults().historyHotkey == 0, "History hotkey starts unbound and cannot collide with an existing binding");
    }
    static function snapshots():Void {
        var f = sample(); var record = FightHistory.encode(f, "snapshot");
        check(FightHistory.entry(record).personalDps == 35.05, "Snapshot retains exact personal DPS");
        var decoded = FightHistory.decode(Json.parse(Json.stringify(record)));
        check(decoded.duration(99999) == 10 && decoded.startedAt == f.startedAt, "Reopened timer frozen independent of game session clock");
        check(decoded.ranked()[0].info.name == "Ally", "Player ranking restored");
        check(decoded.players["me"].damage == 350.5 && decoded.players["me"].skills["Strike"].damage == 350.5, "Exact damage and skill totals round-trip");
        var skill = decoded.players["me"].skills["Strike"];
        check(skill.casts == 2 && skill.hits == 2 && skill.crits == 1 && skill.kills == 1, "Skill breakdown statistics round-trip");
        check(decoded.me == "me" && decoded.players["me"].info.className == "warrior", "Own character and class preserved");
        f.players["me"].damage = 999; f.players["me"].skills["Strike"].damage = 999;
        check(FightHistory.decode(record).players["me"].damage == 350.5, "Handoff is detached from mutable fight");
        check(FightHistory.dpsLabel(12345) == "Your DPS: 12,345", "Readable exact DPS with thousands separators");
        check(FightHistory.dpsLabel(null) == "Your DPS: unavailable", "Missing local player never displays party DPS");
        check(FightHistory.durationLabel(0.001) == "<1 sec" && FightHistory.durationLabel(91) == "1 min 31 sec"
            && FightHistory.durationLabel(3661) == "1 hr 1 min 1 sec", "Readable short and long durations");
        check(FightHistory.dateLabel(f.startedAt) == "Sep 14, 2026 at 13:20:30", "Unambiguous local date/time includes seconds");
        var instant = new Fight(10); instant.add(hit(10, 100), profile()); instant.closed = 10;
        check(FightHistory.entry(FightHistory.encode(instant, "instant")).personalDps == 100, "One-shot DPS matches chart's one-second floor");
        var unknown = new Fight(10); unknown.add(hit(10, 40, false, false, "ally"), profile("ally", false)); unknown.closed = 10;
        check(FightHistory.entry(FightHistory.encode(unknown, "unknown")).personalDps == null, "Unknown personal DPS marked unavailable");
    }
    static function temp(name:String):String {
        var root = "build/history-tests/" + name + "_" + Std.random(0x3fffffff);
        FileSystem.createDirectory(root); return root;
    }
    static function existingHistory(root:String, record:Dynamic):Void {
        FileSystem.createDirectory(root + "/history");
        File.saveContent(root + "/history/" + record.id + ".json", Json.stringify(record));
    }
    static function remove(path:String):Void {
        if (FileSystem.isDirectory(path)) { for (name in FileSystem.readDirectory(path)) remove(path + "/" + name); FileSystem.deleteDirectory(path); }
        else FileSystem.deleteFile(path);
    }
    static function storage():Void {
        var root = temp("store"); var errors:Array<String> = [];
        var store = new FightHistoryStore(root, e -> errors.push(e));
        store.initialize();
        check(store.query(request("groups")).total == 0, "Fresh history is empty");
        for (i in 0...19) {
            var f = sample(); f.startedAt += i * 1000;
            store.save(FightHistory.encode(f, "boss_" + i));
        }
        var groups = store.query(request("groups"));
        check(groups.groups.length == 1 && groups.groups[0].count == 19, "Attempts grouped by encounter name");
        var first = store.query(request("fights", "The Guardian"));
        check(first.entries.length == FightHistory.PAGE_SIZE && first.entries[0].id == "boss_18", "Newest-first paged attempts");
        var finalPage = store.query(request("fights", "The Guardian", 999));
        check(finalPage.page == 2 && finalPage.entries.length == 3, "Page clamping and remainder");
        var chart = store.query(request("chart", "", 0, "boss_18"));
        check(FightHistory.decode(chart.record).players["me"].damage == 350.5, "Selected chart loaded from its own file");
        store.save(chart.record);
        check(store.query(request("fights", "The Guardian")).total == 19, "Retrying an archive is idempotent");
        for (i in 0...11) { var f = sample(); f.bossName = "Encounter " + i; store.save(FightHistory.encode(f, "group_" + i)); }
        check(store.query(request("groups")).groups.length == 8 && store.query(request("groups", "", 1)).groups.length == 4, "Encounter names paginate too");
        var old = sample(); old.startedAt = Date.fromString("2020-01-01 00:00:00").getTime();
        store.save(FightHistory.encode(old, "old"));
        File.saveContent(root + "/history/corrupt.json", "{broken");
        var reopened = new FightHistoryStore(root, e -> errors.push(e)); reopened.initialize();
        check(reopened.query(request("fights", "The Guardian")).total == 20, "Restart retains all years of history; a corrupt neighbor is isolated");
        check(FileSystem.exists(root + "/history/old.json") && FileSystem.exists(root + "/history/corrupt.json"), "History initialization never deletes logs");
        var escaped = false; try reopened.query(request("chart", "", 0, "../../secret")) catch (_:Dynamic) escaped = true;
        check(escaped, "Only indexed safe IDs may load a chart");
        var draft = FightHistory.encode(sample(), "draft"); File.saveContent(root + "/history/draft.json.tmp", Json.stringify(draft));
        var recovered = new FightHistoryStore(root, e -> errors.push(e)); recovered.initialize();
        check(recovered.query(request("chart", "", 0, "draft")).record.id == "draft", "Completed draft recovered after interrupted rename");
        remove(root);
    }
    static function uploader():Void {
        var root = temp("uploader");
        for (folder in ["logs", "logs/sent", "logs/rejected"]) FileSystem.createDirectory(root + "/" + folder);
        var old = sample(); old.bossKind = "OldGuardian"; old.phase = "Rift: OldGuardian";
        var report = old.json("20200101-123456", 1);
        for (folder in ["logs", "logs/sent", "logs/rejected"])
            File.saveContent(root + "/" + folder + "/run_20200101-123456_1.json", Json.stringify(report));
        File.saveContent(root + "/uploader.ini", "keep_days=7\n");
        var uploader = new LogUploader(root);
        uploader.loadSettings();
        uploader.archive(FightHistory.encode(sample(), "local_only"));
        uploader.flush();
        check(FileSystem.exists(root + "/history/local_only.json"), "Local history works without queuing an upload");
        check(FileSystem.readDirectory(root + "/logs").length == 3, "Local chart is not submitted to the upload queue");
        var store = new FightHistoryStore(root, _ -> {});
        var all = store.query(request("groups"));
        check(all.groups.length == 2, "Surviving original reports imported alongside local history");
        check(store.query(request("fights", "Rift: OldGuardian")).total == 1, "Legacy encounter name retained and queued/sent/rejected copies deduplicated");
        check(FileSystem.exists(root + "/logs/sent/run_20200101-123456_1.json"), "Old sent logs preserved even with keep_days=7");
        var second = new LogUploader(root); second.flush();
        second.requestHistory(request("groups")); second.browseHistory();
        var response = second.receiveHistory();
        check(response.id == 17 && response.error == "", "Background browsing replies to the matching request");
        check(second.history.query(request("fights", "Rift: OldGuardian")).total == 1, "Restart does not duplicate legacy migration");
        second.archive(FightHistory.encode(sample(), "shutdown")); second.stop();
        check(FileSystem.exists(root + "/history/shutdown.json"), "Normal shutdown persists pending histories");
        remove(root);
    }
    static function categories():Void {
        check(HistoryCategory.fromObjectives(true, true, true, true) == "World Bosses", "Rifts take priority over clearing objectives");
        check(HistoryCategory.fromObjectives(false, true, true, false) == "Boss Dungeons", "Boss target with no clearing phase is a boss dungeon");
        check(HistoryCategory.fromObjectives(false, true, true, true) == "Classic Dungeons", "Clearing phase makes a classic dungeon");
        check(HistoryCategory.fromObjectives(false, true, false, false) == "Other", "Do not classify partially replicated objectives as an arena");
        check(HistoryCategory.fromObjectives(false, false, true, true) == "Other", "World activities cannot become dungeons through objectives alone");
        var catalog:HistoryCatalog = {activities: ["FutureArena" => "Boss Dungeons", "FutureDungeon" => "Classic Dungeons", "FutureRift" => "World Bosses"],
            names: ["FutureGuardian" => "The Future Guardian"], bosses: ["FutureGuardian" => true, "Crimson_Z3W_Caster_E" => false]};
        var old:Dynamic = {name: "FutureGuardian", activityId: "FutureArena", bossKind: "FutureGuardian"};
        check(HistoryCategory.resolve(old, catalog) == "Boss Dungeons", "Legacy activity ID uses running-game definitions, not a boss allowlist");
        check(HistoryCategory.displayName(old, catalog) == "The Future Guardian", "Native localized name replaces legacy data ID");
        check(HistoryCategory.resolve({name: "FutureGuardian"}, catalog) == "Other", "A boss name alone does not invent missing historical context");
        check(HistoryCategory.resolve({name: "Rift: Gates"}, catalog) == "World Bosses", "Older rift gates recognizable without activity metadata");
        check(HistoryCategory.resolve({name: "Rift: FutureGuardian"}, catalog) == "World Bosses", "Older rift boss recognizable without activity metadata");
        check(HistoryCategory.displayName({name: "Rift: FutureGuardian"}, catalog) == "Rift: The Future Guardian", "Rift prefix preserved with localized name");
        check(HistoryCategory.resolve({category: "Other", categoryVersion: 2, activityId: "FutureArena", bossKind: "Crimson_Z3W_Caster_E"}, catalog) == "Other", "Recorded nonboss context isn't promoted by a later catalog");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "Ratsar"}, catalog) == "Boss Dungeons", "Correct old Ratsar misclassification");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "Phrixes"}, catalog) == "Boss Dungeons", "Chakram uses its actual internal ID");
        check(HistoryCategory.resolve({activityId: "Unknown", bossKind: "RobinHoof"}, catalog) == "Classic Dungeons", "Robin Hoof has a clearing phase");
        check(HistoryCategory.resolve({category: "Classic Dungeons", activityId: "Unknown", bossKind: "FutureGuardian"}, catalog) == "Other", "Unverified old inheritance label is not treated as evidence");
        check(HistoryCategory.resolve({phase: "Rift: Boss", activityId: "Unknown", bossKind: "Ratsar"}, catalog) == "World Bosses", "Rift instances override legacy boss fallback");
        check(HistoryCategory.resolve({activityId: "FutureArena", bossKind: "Crimson_Z3W_Caster_E"}, catalog) == "Other", "Old elite uploads excluded from dungeon-boss filters");
        var m = model(); m.activityId = "FutureArena"; m.activityCategory = "Boss Dungeons";
        m.onCombatEnter("me", 10);
        var boss = hit(10, 100, false, true); boss.bossFlags = 16; m.record(boss);
        var elite = hit(11, 80, true, true, "me", "elite"); elite.bossKind = "Crimson_Z3W_Caster_E"; elite.bossName = elite.bossKind;
        m.record(elite); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].category == "Boss Dungeons", "New boss fight captures its native activity category");
        check(m.history[0].bossName == "The Guardian", "Elite adds cannot replace a real boss's encounter name");
        var encoded = FightHistory.encode(m.history[0], "category");
        check(FightHistory.decode(Json.parse(Json.stringify(encoded))).category == "Boss Dungeons", "Category survives saving/reopening a chart");
        check(encoded.activityId == "FutureArena" && encoded.bossKind == "BossKind", "New history retains source activity and boss identity");
        m = model(); m.activityId = "FutureDungeon"; m.activityCategory = "Classic Dungeons";
        m.onCombatEnter("me", 10); m.record(elite); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].category == "Other", "Dungeon trash and elite fights remain under Other");
        var root = temp("categories"); var store = new FightHistoryStore(root, _ -> {});
        store.initialize();
        for (category in HistoryCategory.all()) {
            var f = sample(); f.category = category; store.save(FightHistory.encode(f, "category_" + category.split(" ").join("_")));
        }
        var req = request("categories"); req.catalog = catalog;
        var categories = store.query(req);
        check([for (group in categories.groups) group.name].join("|")
            == "Boss Dungeons|Classic Dungeons|World Bosses|Target Dummies|Other", "Category menu has the requested order");
        for (category in HistoryCategory.all()) {
            var req = request("groups"); req.category = category;
            var groups = store.query(req);
            if (category == HistoryCategory.OTHER) {
                check(groups.groups.length == 0 && !FileSystem.exists(root + "/history/category_Other.json"),
                    "Other fights create neither a history file nor an indexed attempt");
                continue;
            }
            check(groups.groups.length == 1 && groups.groups[0].count == 1, "Category filters same-named encounters independently: " + category);
            req = request("fights", groups.groups[0].name); req.category = category;
            check(store.query(req).entries[0].category == category, "Attempt list retains the selected category: " + category);
        }
        var legacyFight = sample(); legacyFight.bossKind = "FutureGuardian"; legacyFight.activityId = "FutureArena";
        var report = legacyFight.json("20260914-132030", 6);
        var legacy = FightHistory.legacy(report, legacyFight.startedAt + 10000, "legacy_" + haxe.crypto.Md5.encode(report.session_id));
        check(legacy.activityId == "FutureArena" && legacy.bossKind == "FutureGuardian", "New imports preserve classification metadata");
        // Simulate the first history release's omitted metadata, then restore it
        // using the exact legacy session ID, with no destructive file migration.
        for (field in ["activityId", "bossKind", "phase"]) Reflect.deleteField(legacy, field);
        existingHistory(root, legacy);
        FileSystem.createDirectory(root + "/logs/sent");
        File.saveContent(root + "/logs/sent/run_20260914-132030_6.json", Json.stringify(report));
        var reopened = new FightHistoryStore(root, _ -> {});
        var req = request("groups"); req.category = "Boss Dungeons"; req.catalog = catalog;
        var groups = reopened.query(req);
        check(groups.groups.length == 2 && groups.groups[0].name == "The Future Guardian - Unknown difficulty", "Original imported logs recover category and name without inventing missing difficulty");
        var original:Dynamic = Json.parse(File.getContent(root + "/history/" + legacy.id + ".json"));
        check(!Reflect.hasField(original, "activityId"), "Metadata recovery leaves the existing archive file untouched");
        remove(root);
        root = temp("learned"); store = new FightHistoryStore(root, _ -> {});
        var oldRecord = FightHistory.encode(sample(), "old");
        oldRecord.category = "Classic Dungeons"; oldRecord.categoryVersion = 0;
        oldRecord.activityId = "NewArena"; oldRecord.bossKind = "NewBoss";
        existingHistory(root, oldRecord);
        req = request("groups"); req.category = "Other";
        check(store.query(req).groups[0].count == 1, "Unobserved legacy activity starts unclassified");
        var observed = sample(); observed.category = "Boss Dungeons"; observed.activityId = "NewArena"; observed.bossKind = "NewBoss";
        store.save(FightHistory.encode(observed, "observed"));
        reopened = new FightHistoryStore(root, _ -> {});
        req = request("groups"); req.category = "Boss Dungeons";
        req.catalog = {activities: [], names: [], bosses: []};
        check(reopened.query(req).groups[0].count == 2, "Saved objective evidence reclassifies older logs after restart");
        check(Json.parse(File.getContent(root + "/history/old.json")).category == "Classic Dungeons", "Reclassification never rewrites old damage logs");
        var missingActivity = FightHistory.encode(sample(), "missing_activity");
        missingActivity.category = "Other"; missingActivity.categoryVersion = 0;
        missingActivity.activityId = ""; missingActivity.bossKind = "NewBoss";
        store.save(missingActivity);
        reopened = new FightHistoryStore(root, _ -> {});
        req = request("groups"); req.category = "Boss Dungeons";
        check(reopened.query(req).groups[0].count == 3, "Confirmed boss evidence recovers logs without an activity ID after restart");
        req.catalog = {activities: [], names: [], bosses: []};
        check(reopened.query(req).groups[0].count == 3, "Opening a fresh catalog preserves learned boss categories");
        check(Json.parse(File.getContent(root + "/history/missing_activity.json")).activityId == "", "Boss recovery does not rewrite archives");
        var bossCatalog:HistoryCatalog = {activities: [], names: ["NewBoss" => "New Guardian"], bosses: ["NewBoss" => true],
            bossCategories: ["NewBoss" => "Boss Dungeons"]};
        check(HistoryCategory.resolve({name: "New Guardian"}, bossCatalog) == "Boss Dungeons", "Exact unique display names recover early imported boss logs");
        check(HistoryCategory.resolve({name: "New Guardian's add"}, bossCatalog) == "Other", "Boss recovery never matches a substring");
        bossCatalog.names["DifferentBoss"] = "New Guardian"; bossCatalog.bosses["DifferentBoss"] = true;
        check(HistoryCategory.resolve({name: "New Guardian"}, bossCatalog) == "Other", "Ambiguous localized boss names stay unclassified");
        HistoryCategory.observeBoss(bossCatalog.bossCategories, "NewBoss", "Classic Dungeons");
        check(HistoryCategory.resolve({bossKind: "NewBoss"}, bossCatalog) == "Other", "Boss IDs reused in both dungeon formats require activity evidence");
        bossCatalog.activities["Arena"] = "Boss Dungeons";
        check(HistoryCategory.resolve({bossKind: "NewBoss", activityId: "Arena"}, bossCatalog) == "Boss Dungeons", "Exact activity takes priority over ambiguous boss evidence");
        check(HistoryCategory.resolve({name: "Rift: New Guardian", bossKind: "NewBoss"}, bossCatalog) == "World Bosses", "Boss fallback never takes a rift out of World Bosses");
        check(HistoryCategory.resolve({bossKind: "Ratsar"}, null) == "Boss Dungeons", "Confirmed legacy Ratsar ID works without old activity metadata");
        remove(root);
    }
    static function metadata():Void {
        var definitions:Map<String, Dynamic> = [
            "Warrior_Rage_Strike" => {texts: {name: "Raging Smash"}},
            "GA_Craft_FinalCombo" => {texts: {name: "Brutal Frenzy"}},
            "Warrior_Hemorrhage_Status" => {texts: {name: "Hemorrhage"}},
            "GA_Craft_Skill1" => {texts: {name: "Rampage"}},
            "GA_Base_Attack" => {type: 0, texts: {}}, "GA_Base_Attack2" => {type: 1, texts: {}},
            "RefEffect" => {texts: {refs: {ref: "GA_Craft_Skill1"}}},
            "Bracket" => {texts: {name: "[GA_Craft_FinalCombo]"}},
            "CycleA" => {texts: {refs: {ref: "CycleB"}}}, "CycleB" => {texts: {refs: {ref: "CycleA"}}}
        ];
        GameAccess.globals["Data.skill"] = {byId: definitions};
        // This native field is a formatter, not a label. Reproduce that shape
        // so turning it into a function address cannot regress unnoticed.
        GameAccess.globals["Texts.item_weapon_base_attack"] = (_:Dynamic) -> "Weapon damage description";
        GameAccess.globals["skillRefs"] = ["ChildEffect" => {id: "GA_Craft_Skill1"}];
        for (id => expected in ["Warrior_Rage_Strike" => "Raging Smash", "GA_Craft_FinalCombo" => "Brutal Frenzy",
            "Warrior_Hemorrhage_Status" => "Hemorrhage", "GA_Craft_Skill1" => "Rampage",
            "GA_Base_Attack" => "Base Attack", "GA_Base_Attack2" => "Base Attack 2",
            "RefEffect" => "Rampage", "Bracket" => "Brutal Frenzy", "ChildEffect" => "Rampage"])
            check(NativeCombatMetadata.skillName(id) == expected, "Native display-name metadata: " + id);
        check(NativeCombatMetadata.skillName("CycleA") == "CycleA", "Cyclic name references terminate safely");
        check(NativeCombatMetadata.skillName("Removed_Skill") == "Removed Skill", "Removed skills keep a readable fallback");
        GameAccess.globals["activities"] = ["TestArena" => {types: ["Dungeon"]}, "TestClassic" => {types: ["Boss", "Dungeon"]}];
        var activity:Dynamic = {};
        var player:Dynamic = {context: {objectives: {array: []}}};
        check(NativeCombatMetadata.activityCategory("TestArena", false, player, activity) == "Other", "Wait for native objective replication");
        player.context.objectives.array = [{kind: "KillBoss", target: TestObjectiveTarget.Unit("NewBoss")}];
        check(NativeCombatMetadata.activityCategory("TestArena", false, player, activity) == "Boss Dungeons", "Dungeon implementation can be a boss-only arena");
        player.context.objectives.array = [{kind: "KillBoss", target: TestObjectiveTarget.Unit("NewBoss")}, {kind: "KillAllDungeonFoes", completed: true}];
        check(NativeCombatMetadata.activityCategory("TestClassic", false, player, activity) == "Classic Dungeons", "Completed clearing objective still identifies a classic dungeon despite Boss inheritance");
        check(NativeCombatMetadata.activityCategory("TestClassic", true, player, activity) == "World Bosses", "Native rift override");
        var sharedObjectives:Array<Dynamic> = [
            {kind: "KillBoss", target: TestObjectiveTarget.Unit("SharedBoss")}, {kind: "KillAllDungeonFoes", completed: true}];
        var sharedActivity:Dynamic = {globalCtx: {objectives: {array: sharedObjectives}}};
        player.context.objectives.array = [];
        check(NativeCombatMetadata.activityCategory("TestClassic", false, player, sharedActivity) == "Classic Dungeons", "Shared objectives are read even when a personal context exists but is empty");
        var icons:Map<String, Dynamic> = ["Dungeon_Default" => {name: "Normal"}, "Dungeon_LevelMax" => {name: "Hard"}, "Dungeon_Heroic" => {name: "Heroic"}];
        GameAccess.globals["Data.icon"] = {byId: icons};
        var catalog = NativeCombatMetadata.catalog();
        check(catalog.difficulties[0] == "Normal" && catalog.difficulties[1] == "Hard" && catalog.difficulties[2] == "Heroic", "Difficulty values use the native selection-screen icon names");
        check(catalog.bossCategories["SharedBoss"] == "Classic Dungeons", "Native objective boss IDs populate the history recovery catalog");
    }
    static function historyOptions():Void {
        var root = temp("options"); var store = new FightHistoryStore(root, _ -> {});
        // Enough records to catch sorting/filtering only the current page.
        for (i in 0...12) {
            var record = FightHistory.encode(sample(), "sort_" + StringTools.lpad(Std.string(i), "0", 2));
            record.startedAt += i * 1000; record.duration = 12 - i;
            var mine:Dynamic = FightHistory.array(record.players).filter(p -> p.isMe == true)[0];
            mine.uid = "spawn_" + i; record.me = mine.uid;
            mine.name = i % 2 == 0 ? "Wink" : "Priest"; mine.className = i % 2 == 0 ? "warrior" : "cleric";
            mine.damage = (i % 3) * 100 * record.duration;
            store.save(record);
        }
        var group = store.query(request("groups")).groups[0].name;
        var req = request("fights", group); var result = store.query(req);
        check(result.total == 12 && result.entries[0].id == "sort_11", "Default is all characters, newest first");
        check(result.characters.length == 2, "Character picker deduplicates changing spawned-hero UIDs");
        check(result.characters[0].name == "Priest" && result.characters[0].className == "cleric", "Character picker sorts names and carries class colours");
        for (field in ["time", "dps", "duration"]) for (asc in [false, true]) {
            req.sortBy = field; req.ascending = asc; req.page = 0;
            var first = store.query(req); req.page = 1;
            var all = first.entries.concat(store.query(req).entries);
            var sorted = true;
            for (i in 1...all.length) {
                var a = all[i - 1]; var b = all[i];
                var x = field == "time" ? a.startedAt : field == "duration" ? a.duration : a.personalDps;
                var y = field == "time" ? b.startedAt : field == "duration" ? b.duration : b.personalDps;
                if (asc ? x > y : x < y) sorted = false;
            }
            check(sorted && all.length == 12, "Sorts the entire archive before pagination: " + field + (asc ? " ascending" : " descending"));
        }
        req.page = 99; req.character = haxe.Json.stringify(["Wink", "warrior"]);
        result = store.query(req);
        check(result.total == 6 && result.page == 0 && result.entries.length == 6, "Character filtering precedes counts and page clamping");
        check(result.entries.filter(e -> e.playerName != "Wink").length == 0, "Filtered attempts belong only to the requested character");
        check(result.characters.length == 2, "Filtering does not remove other characters from the picker");
        var sameName = FightHistory.encode(sample(), "same_name");
        for (p in FightHistory.array(sameName.players)) if (p.isMe == true) { p.name = "Wink"; p.className = "mage"; }
        store.save(sameName);
        check(store.query(req).total == 6 && store.query(req).characters.length == 3, "Same name on different classes remains distinct");
        req.character = "missing";
        check(store.query(req).total == 0 && store.query(req).characters.length == 3, "Empty filter results still allow changing the filter");
        var unknown = FightHistory.encode(sample(), "no_personal_dps"); unknown.me = ""; unknown.meName = "";
        for (p in FightHistory.array(unknown.players)) p.isMe = false;
        store.save(unknown);
        req.character = ""; req.sortBy = "dps";
        for (asc in [false, true]) {
            req.ascending = asc; req.page = 1; result = store.query(req);
            check(result.entries[result.entries.length - 1].id == "no_personal_dps", "Unavailable DPS sorts last in " + (asc ? "ascending" : "descending") + " order");
        }
        req.page = 0; req.ascending = false; result = store.query(req);
        check(result.entries[0].id == "sort_11" && result.entries[1].id == "sort_08", "Equal DPS uses stable newest-first tie breaking");
        var encoded = FightHistory.encode(sample(), "uid_fallback");
        for (p in FightHistory.array(encoded.players)) p.isMe = false;
        var summary = FightHistory.entry(encoded);
        check(summary.playerName == "Shawn" && summary.playerClass == "warrior" && Math.abs(summary.personalDps - 35.05) < .0001, "Older records can recover personal stats from the recorded local UID");
        remove(root);
    }
    static function encounterDetails():Void {
        var root = temp("difficulties"); var store = new FightHistoryStore(root, _ -> {});
        for (difficulty in [0, 1, 2, -1]) {
            var f = sample(); f.category = "Boss Dungeons"; f.bossName = "King Ratsar";
            f.bossKind = "Ratsar"; f.activityId = "Arena"; f.difficulty = difficulty; f.partySize = 5;
            var record = FightHistory.encode(f.copy(), "diff_" + (difficulty + 1));
            store.save(record);
            var restored = FightHistory.decode(Json.parse(Json.stringify(record)));
            check(restored.difficulty == difficulty && restored.partySize == 5, "Difficulty and roster size survive copied and saved fights " + difficulty);
        }
        var req = request("groups"); req.category = "Boss Dungeons";
        var groups = store.query(req).groups;
        check(groups.length == 4, "One boss produces distinct Normal, Hard, Heroic, and unknown encounter choices");
        for (name in ["Normal", "Hard", "Heroic", "Unknown difficulty"]) {
            var req = request("fights", "King Ratsar - " + name); req.category = "Boss Dungeons";
            check(store.query(req).entries.length == 1, "Selecting " + name + " only lists that difficulty");
        }
        var f = sample(); f.partySize = 5;
        var entry = FightHistory.entry(FightHistory.encode(f, "details"));
        check(FightHistory.attemptHeading(entry) == FightHistory.dateLabel(f.startedAt) + "  ·  Shawn  ·  Party: 5  ·  Outcome unknown", "Attempt button starts with date, character, complete roster size, and outcome");
        check(FightHistory.attemptDetail(entry) == "10 sec  ·  Your DPS: 35", "Attempt button second line has duration then DPS");
        check(FightHistory.chartDetail(entry) == FightHistory.dateLabel(f.startedAt) + "  ·  Shawn  ·  Your DPS: 35  ·  10 sec  ·  Outcome unknown" + UNKNOWN_SPLIT, "Chart summary has date, character, DPS, duration, outcome, and damage types in one row");
        var old = FightHistory.encode(sample(), "old"); Reflect.deleteField(old, "difficulty"); Reflect.deleteField(old, "partySize");
        entry = FightHistory.entry(old);
        check(entry.difficulty == -1 && entry.partySize == 0 && entry.recordedPlayers == 2, "Old logs preserve unknown difficulty and only a lower bound on party size");
        check(FightHistory.attemptHeading(entry).indexOf("Party: ≥2  ·") >= 0, "Old logs cannot mistake damage contributors for the whole party");
        var m = model(); m.party["passive"] = true;
        m.onCombatEnter("me", 10); m.record(hit(10, 20)); m.onCombatExit("me", 12); m.update(13, false);
        check(m.history[0].partySize == 3 && Lambda.count(m.history[0].players) == 1, "Party size includes members who never deal damage");
        m = model(); m.party["passive"] = true; m.enableRift(); m.record(hit(10, 20)); m.reset(12);
        check(m.history[0].partySize == 3, "Rift archive keeps the present-player roster size too");
        // Previous history versions retained activity IDs but dropped difficulty.
        // The original uploader report is matched by its exact session ID.
        f = sample(); f.bossKind = "Ratsar"; f.activityId = "Arena"; f.difficulty = 2;
        var report = f.json("20260914-132030", 8);
        var legacy = FightHistory.legacy(report, f.startedAt + 10000, "legacy_" + haxe.crypto.Md5.encode(report.session_id));
        Reflect.deleteField(legacy, "difficulty"); store.save(legacy);
        FileSystem.createDirectory(root + "/logs/sent");
        File.saveContent(root + "/logs/sent/run_20260914-132030_8.json", Json.stringify(report));
        var reopened = new FightHistoryStore(root, _ -> {});
        var recovered = reopened.query(request("chart", "", 0, legacy.id)).record;
        check(recovered.difficulty == 2, "Recover missing difficulty even when legacy activity metadata already exists");
        check(Json.parse(File.getContent(root + "/history/" + legacy.id + ".json")).difficulty == null, "Difficulty recovery never rewrites the old log");
        check(HistoryCategory.encounterName({name: "Boss", difficulty: 7}, null) == "Boss - Difficulty 7", "Unrecognized future difficulty remains distinct");
        remove(root);
    }
    static function historyActions():Void {
        var root = temp("recycle");
        var recycled:Array<String> = [];
        FileSystem.createDirectory(root + "/Recycle Bin");
        var store = new FightHistoryStore(root, _ -> {}, path -> {
            recycled.push(path);
            FileSystem.rename(path, root + "/Recycle Bin/" + haxe.io.Path.withoutDirectory(path));
        });
        var source = FightHistory.encode(sample(), "chosen");
        store.save(source); store.save(FightHistory.encode(sample(), "keep"));
        store.query(request("delete", "", 0, "chosen"));
        check(recycled.length == 1 && recycled[0] == FileSystem.fullPath(root + "/history") + "/chosen.json", "Only the selected archive file is passed to the recycler by absolute path");
        check(File.getContent(root + "/Recycle Bin/chosen.json") == Json.stringify(source), "The recycled log keeps its full original contents for recovery");
        check(store.query(request("fights", "The Guardian")).entries.length == 1, "Successful recycling removes the fight from the index immediately");
        check(FileSystem.exists(root + "/history/keep.json"), "Other combat logs are untouched");
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("fights", "The Guardian")).entries.length == 1, "Deleted chart stays absent after restarting the archive");
        var failing = new FightHistoryStore(root, _ -> {}, _ -> { throw "Recycle unavailable"; });
        var failed = false;
        try failing.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && FileSystem.exists(root + "/history/keep.json") && failing.query(request("fights", "The Guardian")).entries.length == 1,
            "Recycle failure preserves the file and index instead of permanently deleting");
        var noOp = new FightHistoryStore(root, _ -> {}, _ -> {});
        failed = false;
        try noOp.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && noOp.query(request("fights", "The Guardian")).entries.length == 1, "A recycler reporting success without moving the file cannot hide it");
        var unexpectedlyDestructive = new FightHistoryStore(root, _ -> {}, path -> { FileSystem.deleteFile(path); throw "Shell could not confirm recycling"; });
        var retainedContent = File.getContent(root + "/history/keep.json");
        failed = false;
        try unexpectedlyDestructive.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && File.getContent(root + "/history/keep.json") == retainedContent,
            "An unexpected destructive shell failure restores the complete log from its recovery backup");
        check(!FileSystem.exists(root + "/history/chosen.json.tmp") && !FileSystem.exists(root + "/history/keep.json.tmp"),
            "Completed and rolled-back deletion leave no draft that could resurrect or replace a chart later");
        failed = false;
        try store.query(request("delete", "", 0, "../keep")) catch (_:Dynamic) failed = true;
        check(failed && recycled.length == 1, "Invalid or unindexed IDs never reach the filesystem recycler");
        var queue = HistoryRequests.coalesce([request("groups"), request("fights"), request("delete", "", 0, "keep"), request("chart"), request("categories")]);
        check([for (r in queue) r.action].join(",") == "fights,delete,categories", "Navigation coalescing preserves every explicit deletion in order");
        queue = HistoryRequests.coalesce([request("delete", "", 0, "a"), request("delete", "", 0, "b")]);
        check(queue.length == 2 && queue[0].fightId == "a" && queue[1].fightId == "b", "Consecutive mutations cannot supersede one another");
        // Exercise the actual worker's navigation queue, not just its coalescer.
        var worker = new LogUploader(root);
        var failedDelete = request("delete", "", 0, "keep"); failedDelete.id = 100;
        var followup = request("categories"); followup.id = 101;
        worker.requestHistory(failedDelete); worker.requestHistory(followup); worker.browseHistory();
        var result = worker.receiveHistory();
        check(result.id == 100 && result.error != "", "Worker reports the deletion result even when navigation arrives immediately after it");
        check(worker.receiveHistory().id == 101 && FileSystem.exists(root + "/history/keep.json"), "Worker then services navigation; missing native bridge never deletes permanently");
        remove(root);

    }
    static function recapSummary():Void {
        var gates = sample(); gates.phase = dpsmeter.RiftTracker.GATES_PHASE; gates.outcome = "Victory";
        var boss = sample(); boss.startedAt += 120000; boss.outcome = "Victory";
        var recap:dpsmeter.RiftTracker.RiftRecap = {gate: gates, boss: boss};
        check(FightHistory.recapDetail(recap) == "Sep 14, 2026 at 13:20:30  ·  Shawn  ·  Victory" + UNKNOWN_SPLIT,
            "Recap summary uses the gates start, recorded local player, and boss result in history's date format");
        boss.outcome = "Defeat";
        check(StringTools.endsWith(FightHistory.recapDetail(recap), "  ·  Defeat" + UNKNOWN_SPLIT),
            "A gates victory does not override a defeated boss phase");
        boss.outcome = "";
        check(StringTools.endsWith(FightHistory.recapDetail(recap), "  ·  Outcome unknown" + UNKNOWN_SPLIT),
            "Missing outcome is not invented as a victory or defeat");
        boss.outcome = "Victory"; recap.gate = null;
        check(FightHistory.recapDetail(recap) == "Sep 14, 2026 at 13:22:30  ·  Shawn  ·  Victory" + UNKNOWN_SPLIT,
            "Boss-only recap uses its recorded boss start time");
        boss.players.remove("me"); boss.meName = "Wink <Mage> & friends";
        check(FightHistory.recapDetail(recap).indexOf("  ·  Wink <Mage> & friends  ·  ") >= 0,
            "A local player without damage retains their recorded name as literal text");
        boss.meName = ""; recap.gate = gates;
        check(FightHistory.recapDetail(recap).indexOf("  ·  Shawn  ·  ") >= 0,
            "The gates phase supplies the local name when the boss recording lacks it");
        recap.gate = null;
        check(FightHistory.recapDetail(recap) == "Sep 14, 2026 at 13:22:30  ·  Victory",
            "Missing local identity never substitutes an ally's name");
    }
    static function snapshotLayouts():Void {
        check(SnapshotLayout.historyHeight(600) == 724, "History body fits the encounter summary and every row without the window header or action footer");
        check(SnapshotLayout.historyHeight(30) == 200, "Empty charts retain the live body height without the controls' space");
        check(SnapshotLayout.historyHeight(30, 820) == 700
            && SnapshotLayout.recapHeight(true, [30, 30], 580) == 588,
            "Snapshots retain visible chart space while reserving the recap title and summary");
        var columns = SnapshotLayout.recapHeight(true, [600, 80]);
        var stacked = SnapshotLayout.recapHeight(false, [600, 80]);
        check(columns == 780, "Side-by-side recap fits its title, summary and taller complete phase");
        check(stacked == 924, "Stacked recap fits its title, summary, both complete charts and phase headings");
        var image = SnapshotLayout.imageSize(980, columns);
        check(image.width == 1928 && image.height == 1528, "Capture crops to the native body at twice the UI resolution without an outer border");
        var historyImage = SnapshotLayout.imageSize(900, 700);
        check(historyImage.width == 1768 && historyImage.height == 1368,
            "The 884-unit native history body fills the image instead of sitting inside a 48-pixel surround");
        var tall = SnapshotLayout.imageSize(980, SnapshotLayout.recapHeight(true, [6000, 30]));
        check(tall.height > 2048 && tall.width * 1.0 * tall.height * 4 < 128 * 1024 * 1024,
            "Long rankings remain available across GPU strips");
        for (dimensions in [[0, 10], [100, -1], [16, 100], [100, 16], [980, 100000], [0x40000000, 40]]) {
            var failed = false;
            try SnapshotLayout.imageSize(dimensions[0], dimensions[1]) catch (_:Dynamic) failed = true;
            check(failed, "Invalid or oversized captures fail before allocation or clipboard changes");
        }
    }
    static function snapshotTextures():Void {
        GameAccess.globals["hxd.PixelFormat.RGBA"] = "RGBA";
        GameAccess.globals["hxd.PixelFormat.BGRA"] = "BGRA";
        var flags = ["Target"];
        var texture = SnapshotTexture.create(2, 1, flags);
        check(texture.format == "RGBA" && texture.width == 2 && texture.height == 1 && texture.flags == flags,
            "Snapshot allocates a DX12-supported RGBA target with the requested dimensions and flags");
        var pixels:Dynamic = {format: "RGBA", bytes: haxe.io.Bytes.ofHex("ff0000ff0000ffff"), disposed: false};
        GameAccess.globals["capturedPixels"] = pixels;
        check(SnapshotTexture.readBgra(texture) == pixels && pixels.format == "BGRA"
            && (cast pixels.bytes:haxe.io.Bytes).toHex() == "0000ffffff0000ff",
            "Readback converts red and blue pixels to the clipboard's channel order");
        check(texture.format == "RGBA" && !pixels.disposed, "Conversion leaves the GPU target unchanged and readback alive for copying");
        GameAccess.globals["failPixelConversion"] = true;
        var failed = false;
        try SnapshotTexture.readBgra(texture) catch (_:Dynamic) failed = true;
        check(failed && pixels.disposed, "Failed CPU conversion releases the captured pixel buffer");
        GameAccess.globals.remove("failPixelConversion");
        GameAccess.globals.remove("capturedPixels");
        failed = false;
        try SnapshotTexture.readBgra(texture) catch (_:Dynamic) failed = true;
        check(failed, "Failed GPU readback reports an error instead of accessing a null pixel buffer");
    }
    static function breakdown():Void {
        var skill = new SkillStats(); skill.damage = 4500; skill.casts = 13; skill.hits = 15; skill.crits = 7;
        var values = SkillBreakdown.values(skill, 25000, 82);
        check(values.damage == 4500 && values.percent == 18 && Math.abs(values.dps - 54.87804878) < .00001, "Ability damage/share/DPS use player damage and whole-fight duration");
        check(values.avgCast == 4500 / 13 && values.avgHit == 300 && values.crit == 700 / 15, "Separate cast/hit averages and hit-based crit percentage");
        var empty = SkillBreakdown.values(new SkillStats(), 0, 0);
        check(empty.percent == 0 && empty.dps == 0 && empty.avgCast == 0 && empty.avgHit == 0 && empty.crit == 0, "Empty charts have finite statistics");
        check(SkillBreakdown.values(skill, 4500, .001).dps == 4500, "Instant-fight DPS matches the player chart's one-second floor");
        var f = sample(); var roundtrip = FightHistory.decode(Json.parse(Json.stringify(FightHistory.encode(f, "table"))));
        var totalDps = 0.0; var totalPercent = 0.0;
        for (s in roundtrip.players["me"].skills) {
            var v = SkillBreakdown.values(s, roundtrip.players["me"].damage, roundtrip.duration(9999));
            totalDps += v.dps; totalPercent += v.percent;
        }
        check(totalDps == 35.05 && totalPercent == 100, "Reopened ability DPS sums to the archived player's DPS");
        for (width in [280, 360, 499, 500, 579, 580, 699, 700, 799, 800, 828, 852]) {
            var columns = SkillBreakdown.columns(width); var edge = 0;
            for (c in columns) { check(c.x == edge && c.width > 0, "Table columns cannot overlap at width " + width); edge += c.width; }
            check(edge == width && columns[0].key == "ability" && columns[1].key == "percent"
                && columns[2].key == "distribution" && columns[3].key == "damage"
                && columns[columns.length - 1].key == (width >= 700 ? "crit" : "damage")
                && !Lambda.exists(columns, c -> c.key == "dps"), "Core information fits every supported width without a DPS column " + width);
        }
        check(SkillBreakdown.columns(828).length == 9, "Normal history width shows every remaining statistic and the separate distribution");
    }
}

enum TestObjectiveTarget { Unit(id:String); }
