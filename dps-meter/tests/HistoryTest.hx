import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.LogUploader;
import dpsmeter.HistoryCatalog;
import dpsmeter.SkillBreakdown;
import dpsmeter.NativeCombatMetadata;
import dpsmeter.GameAccess;
import dpsmeter.PartyCombat;
import dpsmeter.HistoryRequests;
import dpsmeter.SnapshotLayout;
import dpsmeter.SnapshotTexture;
import dpsmeter.SnapshotViewport;
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
        lifecycle(); partyCombat(); chakram(); riftCountdown(); gameVersions(); outcomes(); recapSummary(); snapshots(); storage(); encounterFolders(); uploader(); categories(); metadata(); breakdown(); encounterDetails(); historyActions(); snapshotLayouts(); snapshotTextures(); snapshotViewports(); historyOptions(); literalLabels(); bossRecords();
        Sys.println('Fight history: $checks checks passed');
    }
    static function archivePolicy():Void {
        var root = temp("archive-policy");
        var store = new FightHistoryStore(root, _ -> {});
        var other = sample(); other.category = HistoryCategory.OTHER;
        other.bossKind = "Phrixes"; // A recognized name must not override an explicit Other classification.
        var record = FightHistory.encode(other, "other");
        store.save(record);
        check(!FileSystem.exists(archivePath(root, "other")), "Unclassified nondummy fights never produce an archive, even with a known boss name");
        other.bossName = ""; other.bossKind = "";
        var ordinary = FightHistory.encode(other, "ordinary");
        check(ordinary.name == "Other combat", "Ordinary combat fixture has the reported fallback title");
        store.save(ordinary);
        check(!FileSystem.exists(archivePath(root, "ordinary")), "Other combat does not write a file");
        var writer = new RunWriter(); writer.archive(other);
        check(writer.uploader == null, "Other fights are discarded before creating a worker or queued record");
        existingHistory(root, ordinary);
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("chart", "", 0, "ordinary")).record.id == "ordinary",
            "Existing Other history remains available and is not deleted");
        check(File.getContent(archivePath(root, "ordinary")) == Json.stringify(ordinary),
            "Browsing an old Other fight leaves its saved file unchanged");
        for (category in [HistoryCategory.BOSS, HistoryCategory.DUNGEON, HistoryCategory.WORLD]) {
            var fight = sample(); fight.category = category;
            var id = "allowed_" + category.split(" ").join("_");
            store.save(FightHistory.encode(fight, id));
            check(FileSystem.exists(archivePath(root, id)), "Recognized encounters still save: " + category);
        }
        var legacy = FightHistory.legacy(other.json("20260917-120000", 1), Date.now().getTime(), "legacy_other");
        store.save(legacy);
        check(!FileSystem.exists(archivePath(root, "legacy_other")), "Unclassified legacy exports are not imported as new Other archives");
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
            check(FileSystem.exists(archivePath(root, record.id)), "Dummy practice is written to disk");
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
            var earlierPath = archivePath(root, earlier.id);
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
        var firstSkill = {kind: "FirstStrike"};
        var secondSkill = {kind: "SecondStrike"};
        var reader = GameAccess.field;
        check(gamecompat.HitSkill.read({skill: firstSkill}, reader) == firstSkill, "hit retains its skill");
        check(gamecompat.HitSkill.read({skill: null}, reader) == null, "missing skill is safe");
        check(gamecompat.HitSkill.read(null, reader) == null, "missing hit is safe");
        var fight = new Fight(1);
        for (data in [{skill: firstSkill}, {skill: secondSkill}]) {
            var event = hit(1, 25);
            event.skill = GameAccess.text(GameAccess.field(gamecompat.HitSkill.read(data, reader), "kind"));
            fight.add(event, profile());
        }
        var player = fight.players["me"];
        check(player.damage == 50 && player.skills["FirstStrike"].damage == 25
            && player.skills["SecondStrike"].damage == 25, "skills retain totals and breakdown damage");
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
        var priorPath = archivePath(root, "prior");
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
        m = model(); m.difficulty = 1; m.enableRift(); m.startRiftGates(); m.updateRiftState(10, true, false, "BossKind");
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
        var intro = m.displayedFight();
        check(m.inCombat && intro != null && intro.closed == 0 && intro.players["me"].damage == 100,
            "Opening-bar damage appears immediately in the live HUD while in combat");
        check(m.bossRecordFight("Phrixes", 1) == null,
            "The live opening chart is not an eligible encounter for boss records");
        m.record(hit(11, 50, false, false, "ally", "introAdd"));
        m.updatePhrixes(20, "chakram", 1, false, true, false);
        m.record(chakramHit(20, 200, true));
        m.onCombatExit("me", 20); m.update(21, false);
        check(m.current == null && m.displayedFight() == intro && intro.closed == 0 && m.boss == null
            && m.history.length == 0 && m.completed.length == 0,
            "The opening chart stays visible through the surrender animation without a saved encounter or report");
        check(intro.players["me"].damage == 300 && intro.players["ally"].damage == 50 && intro.duration(21) == 11,
            "Opening damage, party contributions and elapsed time update in the temporary live chart");
        check(m.session.players["me"].damage == 300 && m.session.players["me"].kills == 0,
            "Session totals retain intro damage without inventing a boss kill");
        m.updatePhrixes(22, "chakram", 2, true, false, false);
        m.record(chakramHit(22, 200, true));
        check(m.current == null && m.boss == null && m.displayedFight() == null,
            "Surrender clears the live intro, and a late first-bar lethal RPC cannot reopen it");
        m.onCombatEnter("me", 23); m.record(chakramHit(23, 60));
        check(m.current.start == 23 && m.current.players["me"].damage == 60,
            "The first post-surrender hit begins a clean encounter");
        check(m.displayedFight() == m.current && m.current != intro && !m.current.players.exists("ally"),
            "The HUD switches to the main encounter without importing any opening-phase players or damage");
        m.updatePhrixes(30, "chakram", 3, false, true, false);
        m.onCombatExit("me", 30); m.update(60, false);
        check(m.current.duration(60) == 37 && m.boss != null, "The later bridge retains the post-surrender encounter");
        m.record(hit(61, 50, false, false, "ally", "bridgeAdd"));
        check(m.current.players["ally"].damage == 50, "Party damage during the bridge belongs to the held encounter");
        m.updatePhrixes(70, "chakram", 4, true, false, false);
        m.onCombatEnter("me", 70); m.record(chakramHit(71, 300));
        check(m.current.start == 23 && m.current.players["me"].damage == 360, "Demon form resumes the post-surrender encounter");
        m.updatePhrixes(80, "chakram", 4, false, false, true); m.onCombatExit("me", 80);
        m.record(chakramHit(80.1, 400, true)); m.update(81, false);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 760 && m.history[0].defeated,
            "Death-before-damage records one complete post-surrender fight");
        check(m.completed.length == 1 && m.completed[0].players["me"].damage == 760,
            "The real final kill uploads only post-surrender damage");
        check(Math.abs(m.history[0].duration() - 57.1) < .000001 && m.history[0].players["me"].kills == 1,
            "Duration excludes the opening bar and includes the later bridge");
        m.updatePhrixes(83, "chakram", 1, true, false, false);
        m.onCombatEnter("me", 83); m.record(chakramHit(83, 5));
        check(m.current == null && m.boss == null && m.history.length == 1,
            "A new opening bar never resumes an already completed report");
        check(m.displayedFight().start == 83 && m.displayedFight().players["me"].damage == 5,
            "A new intro replaces the previously completed fight on the HUD with fresh totals");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.updatePhrixes(15, "chakram", 1, false, false, false); m.onCombatExit("me", 15);
        m.updatePhrixes(16, "chakram", 1, false, false, false); m.update(16, false);
        check(m.history.length == 0 && m.current == null && m.boss == null, "An opening-bar wipe is not archived");
        check(m.displayedFight().closed == 15 && m.displayedFight().duration(100) == 5,
            "A wiped intro freezes at the combat end and can use the normal HUD hiding delay");
        m.updatePhrixes(17, "chakram", 1, true, false, false); m.onCombatEnter("me", 17); m.record(chakramHit(17, 7));
        check(m.displayedFight().start == 17 && m.displayedFight().players["me"].damage == 7,
            "An opening-bar retry cannot inherit damage or time from the wiped intro");
        m.reset(19);
        check(m.history.length == 0 && m.completed.length == 0 && m.displayedFight() == null,
            "Leaving during the opening bar discards its temporary chart without saving or uploading");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.onCombatExit("me", 12, true); m.updatePhrixes(15, "chakram", 1, true, false, false);
        m.update(15, false, true); m.record(hit(16, 20, false, false, "ally", "chakram"));
        check(m.displayedFight().closed == 0 && m.displayedFight().players["ally"].damage == 20,
            "Local death does not hide the intro while the party continues fighting");
        m.onCombatEnter("me", 17); m.record(chakramHit(18, 15));
        check(m.displayedFight().start == 10 && m.displayedFight().players["me"].damage == 25,
            "Revival resumes the same live intro without creating a saved encounter");
        m.reset(19);
        check(m.history.length == 0 && m.completed.length == 0, "A revived opening phase is still never saved");

        // Phase 2 is playable combat, not a permanent transition exemption.
        m = model(); m.onCombatEnter("me", 20);
        m.updatePhrixes(20, "chakram", 2, true, false, false); m.record(chakramHit(20, 8));
        m.updatePhrixes(22, "chakram", 2, false, false, false); m.onCombatExit("me", 22);
        m.updatePhrixes(23, "chakram", 2, false, false, false); m.update(23, false);
        check(m.history.length == 1 && m.history[0].duration() == 2 && m.history[0].outcome == "Defeat"
            && m.current == null && m.completed.length == 0, "A post-surrender wipe ends at the first inactive time");
        m.updatePhrixes(24, "chakram", 2, true, false, false); m.onCombatEnter("me", 24); m.record(chakramHit(24, 3));
        check(m.current.start == 24 && m.boss.players["me"].damage == 3, "Checkpoint retries do not inherit prior damage");
        m.updatePhrixes(25, "chakram", 1, true, false, false); m.record(chakramHit(25, 2)); m.update(26, true);
        check(m.history.length == 2 && m.current == null && m.boss == null,
            "A phase regression closes the real attempt without starting an opening-bar encounter");
        m.updatePhrixes(27, "chakram", 2, true, false, false); m.record(chakramHit(27, 5));
        m.updatePhrixes(28, "chakram", 3, false, true, false); m.onCombatExit("me", 28); m.reset(40);
        check(m.history.length == 3 && m.history[2].duration() == 13 && m.current == null,
            "Leaving during the later bridge preserves the real attempt once");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 4, true, false, false); m.record(chakramHit(10, 11));
        m.updatePhrixes(15, "chakram", 4, false, false, true);
        m.record(chakramHit(15.1, 9, true)); m.update(16, true);
        check(m.history.length == 1 && m.history[0].players["me"].damage == 20 && m.current == null,
            "Final death before lethal RPC does not create a second log with a stale hero combat flag");
        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 4, true, false, false); m.record(chakramHit(10, 12));
        m.updatePhrixes(15, "chakram", 4, false, false, true);
        m.updatePhrixes(15.6, "chakram", 4, false, false, true); m.update(16, false);
        check(m.history.length == 1 && m.history[0].duration() == 5 && m.completed.length == 0,
            "Missing final RPC closes history at observed death without inventing an upload");
        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 2, true, false, false); m.record(chakramHit(10, 10));
        m.onCombatExit("me", 15); m.updatePhrixes(20, "chakram", 3, false, true, false);
        m.updatePhrixes(40, "chakram", 4, true, false, false);
        m.record(hit(50, 20, false, false, "ally", "chakram"));
        m.updatePhrixes(60, "chakram", 4, false, false, false);
        m.updatePhrixes(61, "chakram", 4, false, false, false); m.update(61, false);
        check(m.history.length == 1 && m.history[0].duration() == 50 && m.history[0].players["ally"].damage == 20,
            "A later party wipe never rewinds the encounter to an earlier local death");
    }
    static function riftCountdown():Void {
        var m = model(); m.enableRift(); m.onCombatEnter("me", 10);
        m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 100, false, false, "me", "warmup"));
        m.record(hit(19.9, 200, true, false, "ally", "warmup"));
        m.update(20, true);
        var warmup = m.displayedFight();
        check(m.waitingForRiftGates() && m.current == null && warmup != null && warmup.closed == 0
            && m.completed.length == 0 && m.history.length == 0,
            "Countdown damage appears live and keeps the HUD visible without starting the saved gate encounter");
        check(warmup.players["me"].damage == 100 && warmup.players["ally"].damage == 200 && warmup.duration(20) == 10,
            "Warm-up charts retain damage, party contributions and elapsed time");
        m.startRiftGates();
        check(m.displayedFight() == null, "Countdown completion clears warm-up even before the first gate hit");
        m.record(hit(20.01, 30, false, false, "me", "warmup"));
        check(!m.waitingForRiftGates() && m.current.start == 20.01 && m.current.players["me"].damage == 30
            && !m.current.players.exists("ally"), "Same-mob post-countdown damage starts cleanly without importing warm-up hits");
        m.startRiftGates(); m.updateRiftState(400, false, false, "BossKind");
        m.record(hit(400, 40, false, false, "ally", "gate"));
        check(m.current.start == 20.01 && m.current.players["ally"].damage == 40,
            "An elapsed wave timer does not discard remaining gate cleanup");
        m.updateRiftState(410, true, false, "BossKind");
        m.record(hit(410.1, 10, true, false, "ally", "gate"));
        m.record(hit(411, 300, false, true));
        m.updateRiftState(420, true, true, "BossKind"); m.update(421, false);
        check(m.history.length == 2 && m.completed.length == 2 && m.recaps.length == 1,
            "Gated countdown tracking preserves both reports, history phases and recap");
        check(m.recaps[0].gate.players["me"].damage == 30 && m.recaps[0].gate.players["ally"].damage == 50
            && m.recaps[0].boss.players["me"].damage == 300,
            "Recap and exports contain only actual gate damage, including late gate kills");
        m = model(); m.enableRift(); m.record(hit(10, 100, true)); m.reset(20);
        check(m.history.length == 0 && m.completed.length == 0, "Leaving during countdown never archives a gate attempt");
        m.me = "me"; m.profiles["me"] = profile(); m.party["me"] = true;
        m.enableRift(); m.record(hit(21, 20));
        check(m.waitingForRiftGates() && m.current == null, "A new rift resets its countdown gate");
        m.updateRiftState(30, true, false, "BossKind"); m.record(hit(31, 70, false, true));
        m.updateRiftState(40, true, true, "BossKind"); m.update(41, false);
        check(m.recaps.length == 1 && m.recaps[0].gate == null && m.recaps[0].boss.players["me"].damage == 70,
            "Joining during the boss still records it without inventing a gate phase");

        m = model(); m.enableRift();
        m.record(hit(10, 20));
        check(m.displayedFight().closed == 10, "Damage before replicated combat entry is visible with a frozen clock");
        m.onCombatEnter("me", 10.1); warmup = m.displayedFight();
        check(warmup.closed == 0 && warmup.start == 10, "Combat entry resumes the opening hit's warm-up chart");
        m.onCombatExit("me", 12); m.record(hit(12.1, 30, true)); m.update(13, false);
        check(warmup.closed == 12 && warmup.duration(99) == 2 && warmup.players["me"].damage == 50,
            "Combat exit freezes the timer for HUD fading while retaining the late killing blow");
        m.onCombatEnter("me", 15); m.record(hit(15, 70));
        check(m.displayedFight() != warmup && m.displayedFight().start == 15 && m.displayedFight().players["me"].damage == 70,
            "A later pre-countdown fight starts with fresh live totals");
        m.onCombatExit("me", 16, true); m.update(18, false, true);
        m.record(hit(18, 40, false, false, "ally"));
        check(m.displayedFight().closed == 0 && m.displayedFight().players["ally"].damage == 40,
            "Warm-up remains visible when the local hero dies while party members keep fighting");
        m.onCombatEnter("me", 19); m.record(hit(20, 10));
        check(m.displayedFight().start == 15 && m.displayedFight().players["me"].damage == 80,
            "Revival resumes the same temporary warm-up chart");
        m.onCombatExit("me", 21); m.reset(22);
        check(m.history.length == 0 && m.completed.length == 0 && m.recaps.length == 0 && m.displayedFight() == null,
            "Multiple warm-up combats, deaths and kills produce no saved logs or recap");
    }
    static function gameVersions():Void {
        var version = "0.3.0.30903";
        var m = new CombatModel(1, version); m.me = "me"; m.profiles["me"] = profile(); m.party["me"] = true;
        m.onCombatEnter("me", 10); m.record(hit(10, 100, false, true));
        m.record(hit(20, 50, true, true)); m.onCombatExit("me", 20); m.update(21, false);
        var archive = FightHistory.encode(m.history[0], "versioned");
        var report = m.completed[0].json("stamp", 1);
        check(archive.gameVersion == version && report.game_version == version && m.session.gameVersion == version,
            "History and upload logs record the native version separately from schema version");
        var restored = FightHistory.decode(Json.parse(Json.stringify(archive)));
        check(restored.copy().gameVersion == version && restored.json("later", 2).game_version == version,
            "Copying or reopening a chart preserves its recorded game version");
        check(FightHistory.legacy(report, 1000, "imported").gameVersion == version, "Legacy report import retains its original game version");
        Reflect.deleteField(archive, "gameVersion"); Reflect.deleteField(report, "game_version");
        check(FightHistory.decode(archive).gameVersion == "" && FightHistory.legacy(report, 1000, "old").gameVersion == "",
            "Old logs without a version remain readable and never acquire today's version");
        m.reset(30); m.me = "me"; m.profiles["me"] = profile(); m.party["me"] = true;
        m.enableRift(); m.startRiftGates(); m.record(hit(40, 10));
        m.updateRiftState(50, true, false, "BossKind"); m.record(hit(51, 20, false, true));
        m.updateRiftState(60, true, true, "BossKind"); m.update(61, false);
        check(m.session.gameVersion == version && m.recaps[0].gate.gameVersion == version
            && m.recaps[0].boss.gameVersion == version, "Zone resets and both rift snapshots retain the current version");
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
        m = model(); m.enableRift(); m.startRiftGates(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 10)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 100, false, true)); m.updateRiftState(25, true, true, "BossKind");
        m.record(hit(25.1, 200, true, true)); m.update(26, false);
        check(m.history.length == 2 && m.completed.length == 2 && m.recaps.length == 1, "Both rift phases archived, uploads and recap intact");
        check(FightHistory.name(m.history[0]) == "Rift - Gates" && FightHistory.name(m.history[1]) == "Rift - The Guardian", "Rift grouping names");
        check(m.history[1].players["me"].damage == 300, "Late rift killing blow retained");
        m.update(30, false); m.reset(31);
        check(m.history.length == 2, "Completed rift not archived twice on leaving");
        m = model(); m.enableRift(); m.startRiftGates(); m.record(hit(10, 10)); m.reset(15);
        check(m.history.length == 1 && m.completed.length == 0 && m.recaps.length == 0, "Abandoned rift stays local");
        m = model(); m.enableRift(); m.startRiftGates(); m.updateRiftState(10, false, false, "BossKind");
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
    static function partyCombat():Void {
        var layer = {};
        var player:Dynamic = {};
        var hero:Dynamic = {__uid: "me", player: player, layer: layer, isInCombat: true};
        var ally:Dynamic = {__uid: "ally", layer: layer, isInCombat: true, dead: false, removed: false};
        var member:Dynamic = {hero: ally, removed: false};
        var group:Dynamic = {players: {array: [player, member]}};
        player.group = group;
        check(PartyCombat.active(hero), "A living party member in this instance can prolong combat");
        check(!PartyCombat.active(hero, "ally"), "A teammate's explicit exit wins over their still-true combat flag");
        group.players.array = [member, {isMe: true, hero: hero}];
        check(PartyCombat.active(hero), "Recognize the replicated local-player flag even after other roster entries");
        var third:Dynamic = {hero: {__uid: "third", layer: layer, isInCombat: true}};
        group.players.array = [player, member, third];
        check(PartyCombat.active(hero, "ally"), "Another living teammate keeps fighting when one teammate exits");
        group.players.array = [player, member];
        ally.dead = true;
        check(!PartyCombat.active(hero), "Dead teammates cannot hold a wiped encounter open");
        ally.dead = false; ally.layer = {};
        check(!PartyCombat.active(hero), "Party combat in another instance is ignored");
        ally.layer = layer; ally.removed = true;
        check(!PartyCombat.active(hero), "Removed heroes cannot keep combat running");
        ally.removed = false; member.removed = true;
        check(!PartyCombat.active(hero), "Disconnected players cannot keep combat running");
        member.removed = false; ally.isInCombat = false;
        check(!PartyCombat.active(hero), "An idle living teammate cannot hold the fight open");
        ally.isInCombat = true; group.players.array = [member];
        check(!PartyCombat.active(hero), "A stale group that no longer contains us is ignored");
        group.players.array = [player, member]; player.group = null;
        check(!PartyCombat.active(hero) && !PartyCombat.active(null), "Solo and missing heroes have no party continuation");
        player.group = group;

        var m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 100));
        var original = m.current;
        m.onCombatExit("me", 12, PartyCombat.active(hero, "me"));
        m.update(12.1, true, true);
        check(!m.inCombat && m.current == original && m.history.length == 0,
            "Local death keeps the same party fight without a stale flag undoing the exit");
        m.record(hit(13, 200, false, false, "ally"));
        m.record(hit(14, 25)); // The dead player's remaining damage-over-time effect.
        m.update(30, false, true);
        check(m.current == original && original.closed == 0 && original.start == 10
            && original.players["me"].damage == 125 && original.players["ally"].damage == 200 && m.history.length == 0,
            "Party damage and lingering local damage stay in the same fight through long death/revival delays");
        m.onCombatEnter("me", 31); m.record(hit(32, 50)); m.update(33, true, false);
        check(m.current == original && original.players["me"].damage == 175,
            "Revival resumes the original clock and damage totals even after teammates leave combat");
        m.onCombatExit("me", 35, false); m.update(36, false, false);
        check(m.history.length == 1 && m.history[0].duration() == 25
            && m.history[0].players["me"].damage == 175 && m.history[0].players["ally"].damage == 200,
            "One complete history includes the death interval and revived damage");

        m = model(); m.onCombatEnter("me", 10);
        var bossHit = hit(10, 100, false, true, "me", "boss"); bossHit.bossFlags = 0x10;
        m.record(bossHit); m.onCombatExit("me", 12, true);
        m.onCombatExit("ally", 20, false);
        var lethal = hit(20.1, 300, true, true, "ally", "boss"); lethal.bossFlags = 0x10;
        m.record(lethal); m.onTargetDeath("boss", 20.1); m.update(21, false, false);
        check(m.history.length == 1 && m.history[0].duration() == 10 && m.history[0].outcome == "Victory"
            && m.history[0].players["ally"].damage == 300,
            "A teammate's final blow after their combat-exit callback completes the dead player's existing fight");
        check(m.completed.length == 1, "The party boss kill still produces exactly one upload");

        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 100));
        m.onCombatExit("me", 12, true); m.update(20, false, false); m.update(21, false, false);
        check(m.history.length == 1 && m.history[0].duration() == 10 && m.history[0].outcome == "Defeat",
            "Polling still closes a full wipe if the last teammate's exit callback is missing");
        m.onCombatEnter("me", 30); m.record(hit(30, 7));
        check(m.current.start == 30 && m.current.players["me"].damage == 7,
            "The next attempt after a wipe starts a fresh fight");

        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 100));
        m.onCombatExit("ally", 11, false);
        check(m.current != null && m.inCombat, "A teammate's exit cannot end the living local player's combat");
        m.onCombatExit("me", 12, true); m.onCombatExit("ally", 15, true);
        m.onCombatExit("stranger", 16, false);
        check(m.current != null, "Other active teammates prolong the fight; strangers' exits cannot close it");
        m.reset(20); m.reset(21);
        check(m.history.length == 1 && m.history[0].duration() == 10 && m.current == null,
            "Leaving the instance closes a party-held encounter exactly once");

        m = model(); m.record(hit(10, 50, false, false, "ally")); m.update(11, false, true);
        check(m.current == null && m.history.length == 0 && !m.inCombat,
            "Party combat does not start the meter for an idle local player");
        m = model(); m.onCombatEnter("me", 10); m.record(hit(10, 100));
        m.update(12, false, true); m.record(hit(13, 50, false, false, "ally"));
        check(m.current != null && m.current.players["ally"].damage == 50,
            "The local combat polling fallback also preserves a party fight if the death-exit callback was missed");
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
        check(File.getContent(archivePath(root, "old_outcome")) == unchanged, "Reading old outcome-less logs does not rewrite them");
        var legacy = FightHistory.legacy(sample().json("20260914-120000", 1), Date.now().getTime(), "legacy_outcome");
        check(FightHistory.entry(legacy).outcome == "", "Legacy exports without explicit outcomes are not guessed from skill kill counts");
        remove(root);

        m = model(); m.enableRift(); m.startRiftGates(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 20, true)); m.updateRiftState(20, true, false, "BossKind");
        var clone = hit(21, 30, true, true); clone.summoned = true;
        m.record(hit(20, 100, false, true)); m.record(clone); m.onTargetDeath("enemy", 21); m.update(22, false);
        check(m.history.length == 1 && m.history[0].outcome == "Victory", "Clearing Rift gates is a phase victory; a boss clone death does not complete the boss phase");
        m.reset(23);
        check(m.history.length == 2 && m.history[1].outcome == "Defeat", "Leaving an unfinished Rift boss records failure despite a lethal clone hit");
        m = model(); m.enableRift(); m.startRiftGates(); m.updateRiftState(10, false, false, "BossKind");
        m.record(hit(10, 20, true)); m.updateRiftState(20, true, false, "BossKind");
        m.record(hit(21, 100, false, true)); m.updateRiftState(25, true, true, "BossKind"); m.update(26, false);
        check(m.history.length == 2 && m.history[1].outcome == "Victory", "Rift boss objective completion confirms victory without needing the final damage RPC");
        m = model(); m.enableRift(); m.startRiftGates(); m.record(hit(10, 20, true)); m.reset(20);
        check(m.history[0].outcome == "Defeat", "Leaving Rift gates before their objective finishes is failure even if every observed gate died");

        m = model(); m.onCombatEnter("me", 10);
        m.updatePhrixes(10, "chakram", 1, true, false, false); m.record(chakramHit(10, 10));
        m.updatePhrixes(20, "chakram", 2, false, true, false); m.record(chakramHit(20, 20, true));
        m.onCombatExit("me", 20); m.reset(30);
        check(m.history.length == 0 && m.completed.length == 0, "An abandoned intro cannot become a false Victory or Defeat encounter");
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
    // Existing behavioral checks read whichever layout a fixture currently uses.
    // encounterFolders separately checks exact paths and the migration itself.
    static function archivePath(root:String, id:String):String {
        var flat = root + "/history/" + id + ".json";
        if (FileSystem.exists(flat) || !FileSystem.exists(root + "/history")) return flat;
        for (name in FileSystem.readDirectory(root + "/history")) {
            var path = root + "/history/" + name;
            if (FileSystem.isDirectory(path) && FileSystem.exists(path + "/" + id + ".json")) return path + "/" + id + ".json";
        }
        return flat;
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
        check(finalPage.page == 2 && finalPage.entries.length == 5, "Page clamping and remainder");
        var chart = store.query(request("chart", "", 0, "boss_18"));
        check(FightHistory.decode(chart.record).players["me"].damage == 350.5, "Selected chart loaded from its own file");
        store.save(chart.record);
        check(store.query(request("fights", "The Guardian")).total == 19, "Retrying an archive is idempotent");
        for (i in 0...11) { var f = sample(); f.bossName = "Encounter " + i; store.save(FightHistory.encode(f, "group_" + i)); }
        check(store.query(request("groups")).groups.length == 7 && store.query(request("groups", "", 1)).groups.length == 5, "Encounter names paginate too");
        var old = sample(); old.startedAt = Date.fromString("2020-01-01 00:00:00").getTime();
        store.save(FightHistory.encode(old, "old"));
        File.saveContent(root + "/history/corrupt.json", "{broken");
        var reopened = new FightHistoryStore(root, e -> errors.push(e)); reopened.initialize();
        check(reopened.query(request("fights", "The Guardian")).total == 20, "Restart retains all years of history; a corrupt neighbor is isolated");
        check(FileSystem.exists(archivePath(root, "old")) && FileSystem.exists(archivePath(root, "corrupt")), "History initialization never deletes logs");
        var escaped = false; try reopened.query(request("chart", "", 0, "../../secret")) catch (_:Dynamic) escaped = true;
        check(escaped, "Only indexed safe IDs may load a chart");
        var draft = FightHistory.encode(sample(), "draft"); File.saveContent(root + "/history/draft.json.tmp", Json.stringify(draft));
        var recovered = new FightHistoryStore(root, e -> errors.push(e)); recovered.initialize();
        check(recovered.query(request("chart", "", 0, "draft")).record.id == "draft", "Completed draft recovered after interrupted rename");
        remove(root);
    }
    static function encounterFolders():Void {
        var root = temp("encounter-folders");
        var errors:Array<String> = [];
        var store = new FightHistoryStore(root, e -> errors.push(e), path -> FileSystem.deleteFile(path));
        var fight = sample(); fight.bossName = "Crabgantua"; fight.category = HistoryCategory.BOSS; fight.difficulty = 2;
        var heroic = FightHistory.encode(fight, "heroic");
        store.save(heroic);
        var heroicPath = root + "/history/Crabgantua - Heroic/heroic.json";
        check(File.getContent(heroicPath) == Json.stringify(heroic) && !FileSystem.exists(root + "/history/heroic.json"),
            "New archives use encounter and difficulty folders with unchanged JSON and filenames");
        fight.difficulty = 1;
        store.save(FightHistory.encode(fight, "veteran"));
        check(FileSystem.exists(root + "/history/Crabgantua - Veteran/veteran.json"), "Different difficulties have separate folders");
        var changed = Json.parse(Json.stringify(heroic)); changed.name = "Different name"; changed.duration = 999;
        store.save(changed);
        check(File.getContent(heroicPath) == Json.stringify(heroic)
            && store.query(request("chart", "", 0, "heroic")).record.duration == heroic.duration,
            "Retrying an ID cannot move or overwrite its saved log, or replace its summary");

        for (name in ["Rift: Gates", "Rift: Nightking Maat Demon", "Rift: Before gates"]) {
            var entry = {name: name, difficulty: -1};
            var expected = name.split(":").join(" -");
            check(HistoryCategory.folderName(entry, null) == expected && HistoryCategory.displayName(entry, null) == expected,
                "Rift labels and folders replace the colon: " + name);
            check(HistoryCategory.resolve({name: expected}, null) == HistoryCategory.WORLD, "New rift names retain their category");
        }
        for (name in ["CON", "nul.txt", "LPT1", "COM¹.txt", "CONOUT$"]) {
            check(HistoryCategory.folderName({name: name}, null) == "_" + name, "Reserved Windows names are escaped: " + name);
        }
        check(HistoryCategory.folderName({name: "  A<>:\"/\\|?*\nB.  "}, null) == "A - B", "Illegal characters and trailing dots/spaces are removed");
        check(HistoryCategory.folderName({name: "..."}, null) == "Unknown encounter", "An empty sanitized name has a safe fallback");
        var longName = [for (_ in 0...100) "É界"].join("");
        var shortened = HistoryCategory.folderName({name: longName}, null);
        check(haxe.io.Bytes.ofString(shortened).length <= 100 && shortened != HistoryCategory.folderName({name: longName + "!"}, null),
            "Long Unicode folder names are bounded and remain distinct");
        for (i in 0...2) {
            fight.bossName = i == 0 ? "A/B" : "A\\B"; fight.difficulty = -1;
            store.save(FightHistory.encode(fight, "collision_" + i));
            check(FileSystem.exists(root + "/history/A - B - Unknown difficulty/collision_" + i + ".json"),
                "Sanitized encounter-name collisions retain both unique log files");
        }
        changed.id = "../escape";
        var rejected = false; try store.save(changed) catch (_:Dynamic) rejected = true;
        check(rejected && !FileSystem.exists(root + "/escape.json"), "Encounter folders do not weaken log ID validation");

        // Seed older flat logs and drafts, then restart. Migration must not
        // reserialize metadata, change timestamps, duplicate or lose attempts.
        var old = FightHistory.encode(sample(), "flat"); old.name = "Rift: Gates"; old.phase = "Rift: Gates";
        existingHistory(root, old);
        var flatPath = root + "/history/flat.json";
        var original = Json.stringify(old, null, "  ") + "\n"; File.saveContent(flatPath, original);
        File.saveContent(flatPath + ".tmp", original);
        var modified = FileSystem.stat(flatPath).mtime.getTime();
        var draft = FightHistory.encode(sample(), "nested_draft");
        File.saveContent(root + "/history/Crabgantua - Heroic/nested_draft.json.tmp", Json.stringify(draft));
        var bad = FightHistory.encode(sample(), "wrong_id");
        File.saveContent(root + "/history/Crabgantua - Heroic/bad.json", Json.stringify(bad));
        File.saveContent(root + "/history/Crabgantua - Heroic/bad.json.tmp", Json.stringify(bad));
        store = new FightHistoryStore(root, e -> errors.push(e), path -> FileSystem.deleteFile(path));
        store.warm();
        var migratedPath = root + "/history/Rift - Gates/flat.json";
        check(!FileSystem.exists(flatPath) && File.getContent(migratedPath) == original
            && FileSystem.stat(migratedPath).mtime.getTime() == modified, "Flat archives move without changing bytes or modification time");
        check(!FileSystem.exists(flatPath + ".tmp"), "An identical recovery backup cannot be stranded by migration and resurrect a deleted log");
        check(store.query(request("fights", "Rift - Gates")).total == 1, "Old rift names share the normalized history group");
        check(store.query(request("chart", "", 0, "nested_draft")).record.id == "nested_draft",
            "Interrupted saves/deletions recover in encounter subfolders using their actual path");
        rejected = false; try store.query(request("chart", "", 0, "wrong_id")) catch (_:Dynamic) rejected = true;
        check(rejected && FileSystem.exists(root + "/history/Crabgantua - Heroic/bad.json.tmp"),
            "Mismatched nested filenames and drafts are rejected without deleting them");
        store.save(old);
        store.query(request("delete", "", 0, "flat"));
        check(!FileSystem.exists(migratedPath) && !FileSystem.exists(migratedPath + ".tmp"), "Migrated logs can be deleted without leaving a resurrection backup");
        store = new FightHistoryStore(root, e -> errors.push(e));
        check(store.query(request("fights", "Rift - Gates")).total == 0, "Deleted migrated logs stay deleted after restart");
        // A failed move must not make a valid archive disappear from history.
        fight.bossName = "Blocked"; fight.difficulty = 2;
        var blocked = FightHistory.encode(fight, "blocked"); existingHistory(root, blocked);
        File.saveContent(root + "/history/Blocked - Heroic", "existing unrelated file");
        store = new FightHistoryStore(root, e -> errors.push(e));
        check(store.query(request("chart", "", 0, "blocked")).record.id == "blocked"
            && FileSystem.exists(root + "/history/blocked.json"), "A failed migration stays readable in the flat folder");
        FileSystem.deleteFile(root + "/history/Blocked - Heroic");
        store = new FightHistoryStore(root, e -> errors.push(e)); store.warm();
        check(FileSystem.exists(root + "/history/Blocked - Heroic/blocked.json")
            && !FileSystem.exists(root + "/history/blocked.json"), "Failed migration retries on the next launch");
        // Names can change with localization; existing paths still load/delete.
        FileSystem.rename(root + "/history/Blocked - Heroic", root + "/history/Renamed encounter");
        store = new FightHistoryStore(root, e -> errors.push(e), path -> FileSystem.deleteFile(path));
        check(store.query(request("chart", "", 0, "blocked")).record.name == "Blocked", "Existing folders need not match the current display name");
        store.query(request("delete", "", 0, "blocked"));
        check(!FileSystem.exists(root + "/history/Renamed encounter/blocked.json"), "Deletion uses the indexed path after a folder rename");
        var conflict = FightHistory.encode(sample(), "conflict"); existingHistory(root, conflict);
        var otherVersion = Json.parse(Json.stringify(conflict)); otherVersion.duration = 500;
        var unresolvedPath = root + "/history/conflict.json.tmp";
        File.saveContent(unresolvedPath, Json.stringify(otherVersion));
        store = new FightHistoryStore(root, e -> errors.push(e)); store.warm();
        check(FileSystem.exists(root + "/history/conflict.json") && File.getContent(unresolvedPath) == Json.stringify(otherVersion)
            && store.query(request("chart", "", 0, "conflict")).record.duration == conflict.duration,
            "Conflicting recovery drafts stay beside the committed file without overwriting it or being stranded");
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
        check(FileSystem.exists(archivePath(root, "local_only")), "Local history works without queuing an upload");
        check(FileSystem.readDirectory(root + "/logs").length == 3, "Local chart is not submitted to the upload queue");
        var store = new FightHistoryStore(root, _ -> {});
        var all = store.query(request("groups"));
        check(all.groups.length == 2, "Surviving original reports imported alongside local history");
        check(store.query(request("fights", "Rift - OldGuardian")).total == 1, "Legacy encounter name retained and queued/sent/rejected copies deduplicated");
        check(FileSystem.exists(root + "/logs/sent/run_20200101-123456_1.json"), "Old sent logs preserved even with keep_days=7");
        var second = new LogUploader(root); second.flush();
        second.requestHistory(request("groups")); second.browseHistory();
        var response = second.receiveHistory();
        check(response.id == 17 && response.error == "", "Background browsing replies to the matching request");
        check(second.history.query(request("fights", "Rift - OldGuardian")).total == 1, "Restart does not duplicate legacy migration");
        second.archive(FightHistory.encode(sample(), "shutdown")); second.stop();
        check(FileSystem.exists(archivePath(root, "shutdown")), "Normal shutdown persists pending histories");
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
        check(HistoryCategory.displayName({name: "Rift: FutureGuardian"}, catalog) == "Rift - The Future Guardian", "Rift prefix preserved with localized name");
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
                check(groups.groups.length == 0 && !FileSystem.exists(archivePath(root, "category_Other")),
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
        var original:Dynamic = Json.parse(File.getContent(archivePath(root, legacy.id)));
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
        check(Json.parse(File.getContent(archivePath(root, "old"))).category == "Classic Dungeons", "Reclassification never rewrites old damage logs");
        var missingActivity = FightHistory.encode(sample(), "missing_activity");
        missingActivity.category = "Other"; missingActivity.categoryVersion = 0;
        missingActivity.activityId = ""; missingActivity.bossKind = "NewBoss";
        store.save(missingActivity);
        reopened = new FightHistoryStore(root, _ -> {});
        req = request("groups"); req.category = "Boss Dungeons";
        check(reopened.query(req).groups[0].count == 3, "Confirmed boss evidence recovers logs without an activity ID after restart");
        req.catalog = {activities: [], names: [], bosses: []};
        check(reopened.query(req).groups[0].count == 3, "Opening a fresh catalog preserves learned boss categories");
        check(Json.parse(File.getContent(archivePath(root, "missing_activity"))).activityId == "", "Boss recovery does not rewrite archives");
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
        var icons:Map<String, Dynamic> = ["Dungeon_Default" => {name: "Normal"}, "Dungeon_LevelMax" => {name: "Veteran"}, "Dungeon_Heroic" => {name: "Heroic"}];
        GameAccess.globals["Data.icon"] = {byId: icons};
        var catalog = NativeCombatMetadata.catalog();
        check(catalog.difficulties[0] == "Normal" && catalog.difficulties[1] == "Veteran" && catalog.difficulties[2] == "Heroic", "Difficulty values use the native selection-screen icon names");
        check(catalog.bossCategories["SharedBoss"] == "Classic Dungeons", "Native objective boss IDs populate the history recovery catalog");
    }
    static function historyOptions():Void {
        var root = temp("options"); var store = new FightHistoryStore(root, _ -> {});
        // Enough records to catch sorting/filtering only the current page.
        for (i in 0...12) {
            var record = FightHistory.encode(sample(), "sort_" + StringTools.lpad(Std.string(i), "0", 2));
            record.startedAt += i * 1000; record.duration = 12 - i;
            record.outcome = i < 9 ? "Victory" : "Defeat";
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
        req.sortBy = "time"; req.page = 99; req.outcome = "Victory";
        result = store.query(req);
        check(result.total == 9 && result.page == 1 && result.entries.length == 2,
            "Outcome filtering precedes counts and pagination across the entire archive");
        check(result.entries[0].id == "sort_01" && result.entries[1].id == "sort_00",
            "The filtered last page retains the selected sort order");
        req.outcome = "Defeat"; result = store.query(req);
        check(result.total == 3 && result.page == 0 && result.entries.filter(e -> e.outcome != "Defeat").length == 0,
            "Defeat excludes victories and unknown outcomes, and clamps a stale page");
        req.character = haxe.Json.stringify(["Wink", "warrior"]); req.outcome = "Victory";
        result = store.query(req);
        check(result.total == 5 && result.entries.filter(e -> e.playerName != "Wink" || e.outcome != "Victory").length == 0,
            "Character and outcome filters combine");
        req.character = haxe.Json.stringify(["Wink", "mage"]);
        result = store.query(req);
        check(result.total == 0 && result.page == 0 && result.characters.length == 4,
            "Empty outcome results retain the character picker, including characters with unknown outcomes");
        req.character = ""; req.outcome = ""; req.page = 0;
        result = store.query(req);
        check(result.total == 14, "Any outcome restores all records, including both older unknown-outcome logs");
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
        check(groups.length == 4, "One boss produces distinct Normal, Veteran, Heroic, and unknown encounter choices");
        for (name in ["Normal", "Veteran", "Heroic", "Unknown difficulty"]) {
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
        m = model(); m.party["passive"] = true; m.enableRift(); m.startRiftGates(); m.record(hit(10, 20)); m.reset(12);
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
        check(Json.parse(File.getContent(archivePath(root, legacy.id))).difficulty == null, "Difficulty recovery never rewrites the old log");
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
        check(recycled.length == 1 && recycled[0] == FileSystem.fullPath(root + "/history/The Guardian/chosen.json"), "Only the selected archive file is passed to the recycler by absolute path");
        check(File.getContent(root + "/Recycle Bin/chosen.json") == Json.stringify(source), "The recycled log keeps its full original contents for recovery");
        check(store.query(request("fights", "The Guardian")).entries.length == 1, "Successful recycling removes the fight from the index immediately");
        check(FileSystem.exists(archivePath(root, "keep")), "Other combat logs are untouched");
        var reopened = new FightHistoryStore(root, _ -> {});
        check(reopened.query(request("fights", "The Guardian")).entries.length == 1, "Deleted chart stays absent after restarting the archive");
        var failing = new FightHistoryStore(root, _ -> {}, _ -> { throw "Recycle unavailable"; });
        var failed = false;
        try failing.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && FileSystem.exists(archivePath(root, "keep")) && failing.query(request("fights", "The Guardian")).entries.length == 1,
            "Recycle failure preserves the file and index instead of permanently deleting");
        var noOp = new FightHistoryStore(root, _ -> {}, _ -> {});
        failed = false;
        try noOp.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && noOp.query(request("fights", "The Guardian")).entries.length == 1, "A recycler reporting success without moving the file cannot hide it");
        var unexpectedlyDestructive = new FightHistoryStore(root, _ -> {}, path -> { FileSystem.deleteFile(path); throw "Shell could not confirm recycling"; });
        var retainedContent = File.getContent(archivePath(root, "keep"));
        failed = false;
        try unexpectedlyDestructive.query(request("delete", "", 0, "keep")) catch (_:Dynamic) failed = true;
        check(failed && File.getContent(archivePath(root, "keep")) == retainedContent,
            "An unexpected destructive shell failure restores the complete log from its recovery backup");
        check(!FileSystem.exists(root + "/history/The Guardian/chosen.json.tmp") && !FileSystem.exists(root + "/history/The Guardian/keep.json.tmp"),
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
        check(worker.receiveHistory().id == 101 && FileSystem.exists(archivePath(root, "keep")), "Worker then services navigation; missing native bridge never deletes permanently");
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
        for (width in [312, 600, 791, 792, 892, 932]) {
            var live = dpsmeter.RiftRecapLayout.panels(width, 540);
            for (panel in live) check(panel.x >= 0 && panel.y >= 0
                && panel.x + panel.width <= width && panel.y + panel.height <= 540,
                "Both recap panels stay inside their owning window at width " + width);
            check(live[1].x >= live[0].x + live[0].width + 24
                || live[1].y >= live[0].y + live[0].height + 24,
                "Recap phases keep a clear gap in columns and stacked layouts");
            var fullHeight = dpsmeter.RiftRecapLayout.snapshotHeight(width, [600, 80]);
            var captured = dpsmeter.RiftRecapLayout.panels(width, fullHeight, [600, 80]);
            for (i in 0...2) check(captured[i].height >= [600, 80][i] + 40
                && captured[i].y + captured[i].height <= fullHeight,
                "Recap snapshots fit every row of both unequal phases without clipping");
            check(SnapshotLayout.historyHeight(fullHeight, 820) - 124 >= fullHeight,
                "History snapshots reserve enough space for the complete embedded recap");
        }
        var historyPanels = dpsmeter.RiftRecapLayout.panels(892, 540);
        check(historyPanels[0].width == 434 && historyPanels[1].x == 458 && historyPanels[1].y == 0,
            "The normal Fight History window fits both compact recap charts side by side");
        var image = SnapshotLayout.imageSize(980, columns);
        check(image.width == 1928 && image.height == 1528, "Capture crops to the native body at twice the UI resolution without an outer border");
        var historyImage = SnapshotLayout.imageSize(940, 700);
        check(historyImage.width == 1848 && historyImage.height == 1368,
            "The 924-unit native history body fills the image instead of sitting inside a 48-pixel surround");
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
    // Farever's RenderContext.setRZ transforms masks with Scene.viewport*,
    // even though drawTo renders geometry directly in target-texture pixels.
    static function nativeClipOrigin(scene:Dynamic, engine:Dynamic, x:Float, y:Float):{x:Int, y:Int} {
        return {
            x: Std.int(x * (scene.viewportA * engine.width / 2)
                + (scene.viewportX + 1) * engine.width / 2 + 1e-10),
            y: Std.int(y * (scene.viewportD * engine.height / 2)
                + (scene.viewportY + 1) * engine.height / 2 + 1e-10)
        };
    }
    static function snapshotViewports():Void {
        for (resolution in [[2560, 1440], [2560, 1600], [1920, 1080], [3840, 2160]]) {
            var engine = {width: resolution[0], height: resolution[1]};
            GameAccess.globals["h3d.Engine.CURRENT"] = engine;
            for (scale in [1., 1.25, 1.5, 2.]) {
                var scene:Dynamic = {viewportA: 2 * scale / engine.width, viewportD: 2 * scale / engine.height,
                    viewportX: -1., viewportY: -1.};
                if (scale == 1.25) {
                    var clipped = nativeClipOrigin(scene, engine, 32, 216);
                    check(clipped.x == 40 && clipped.y == 270,
                        "Reproduces the customer's left crop and missing first name at 125% viewport scale");
                }
                // Also exercise letterboxing offsets and different X/Y scales.
                scene.viewportD *= 1.1;
                scene.viewportX += 2 * 37.0 / engine.width;
                scene.viewportY += 2 * 19.0 / engine.height;
                var original = Json.stringify(scene);
                var window = {scene: scene};
                // Full image, full strip, and short final strip must all use
                // engine dimensions for the native mask conversion.
                for (stripHeight in [1368, 2048, 560]) {
                    var texture = {width: 1768, height: stripHeight};
                    GameAccess.globals["drawSnapshot"] = function(target:Dynamic):Void {
                        check(target == texture, "The requested texture receives the draw");
                        var top = nativeClipOrigin(scene, engine, 32, 216);
                        var bottom = nativeClipOrigin(scene, engine, 1736, stripHeight - 16);
                        check(top.x == 32 && top.y == 216 && bottom.x == 1736 && bottom.y == stripHeight - 16,
                            "Native clipping matches image pixels at every display scale, offset and strip size");
                    };
                    SnapshotViewport.drawTo(window, texture);
                    check(Json.stringify(scene) == original, "Successful capture restores all live viewport fields");
                }
                var failure = {message: "Simulated renderer failure"};
                GameAccess.globals["drawSnapshot"] = function(_:Dynamic):Void { throw failure; };
                var caught:Dynamic = null;
                try SnapshotViewport.drawTo(window, {}) catch (error:Dynamic) caught = error;
                check(caught == failure && Json.stringify(scene) == original,
                    "Failed capture restores the viewport and preserves the original error");
            }
        }
        GameAccess.globals.remove("h3d.Engine.CURRENT");
        var drew = false;
        GameAccess.globals["drawSnapshot"] = function(_:Dynamic):Void { drew = true; };
        var scene:Dynamic = {viewportA: 1., viewportD: 1., viewportX: 0., viewportY: 0.};
        var before = Json.stringify(scene);
        var failed = false;
        try SnapshotViewport.drawTo({scene: scene}, {}) catch (_:Dynamic) failed = true;
        check(failed && !drew && Json.stringify(scene) == before,
            "Unavailable renderer fails before modifying the live scene");
        GameAccess.globals.remove("drawSnapshot");
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
        for (width in [280, 360, 499, 500, 579, 580, 699, 700, 799, 800, 828, 852, 892]) {
            var columns = SkillBreakdown.columns(width); var edge = 0;
            for (c in columns) { check(c.x == edge && c.width > 0, "Table columns cannot overlap at width " + width); edge += c.width; }
            check(edge == width && columns[0].key == "ability" && columns[1].key == "percent"
                && columns[2].key == "distribution" && columns[3].key == "damage"
                && columns[columns.length - 1].key == "dps" && columns[columns.length - 1].title == "DPS",
                "Regular breakdowns keep DPS as the final column at every supported width " + width);
        }
        check(SkillBreakdown.columns(892).length == 10, "Normal history width shows all statistics including the restored DPS column");
        for (width in [280, 360, 408, 430, 434, 454, 580, 790, 852]) {
            var columns = SkillBreakdown.columns(width, true);
            check([for (c in columns) c.key].join(",") == "ability,percent,distribution,damage",
                "Recaps keep the ability inline with only three metrics at every size");
            check(columns[2].width - 10 >= 75 && columns[3].x + columns[3].width == width,
                "Compact recap distribution and damage fit inside the panel");
        }
    }
}

enum TestObjectiveTarget { Unit(id:String); }
