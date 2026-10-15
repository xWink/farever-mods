import dpsmeter.CombatModel;
import dpsmeter.CombatTimeline;
import dpsmeter.DetailedReport;
import dpsmeter.FightHistory;
import dpsmeter.FightHistoryStore;
import dpsmeter.FareverlyContract;
import dpsmeter.FareverlyUploader;
import dpsmeter.FareverlyOpen;
import dpsmeter.FareverlyBrowser;
import dpsmeter.LogRetention;
import dpsmeter.LogUploader;
import dpsmeter.MeterConfig;
import dpsmeter.ReadyCheck;
import dpsmeter.TimelineStore;
import dpsmeter.FareverlyHttp.FareverlyResponse;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

@:access(dpsmeter.LogUploader)
@:access(dpsmeter.FareverlyUploader)
class RecoveryTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function remove(path:String):Void {
        if (!FileSystem.exists(path)) return;
        if (FileSystem.isDirectory(path)) { for (name in FileSystem.readDirectory(path)) remove(path + "/" + name); FileSystem.deleteDirectory(path); }
        else FileSystem.deleteFile(path);
    }
    static function fixture(id:String = "offline-test"):Dynamic {
        // These synthetic values are used only by injected transports in this test.
        return {version:1, categoryVersion:2, id:id, name:"Test Encounter", gameVersion:"test",
            activityId:"test-activity", bossKind:"TestBoss", category:"Boss Dungeons", difficulty:0,
            startedAt:Date.fromString("2026-01-01 00:00:00").getTime(), duration:10, partySize:1, outcome:"Victory", me:"test-player",
            players:[{uid:"test-player", name:"Test Player", isMe:true, accountId:"test-account", characterId:"test-character",
                damage:100.0, hits:1, crits:0, damageBreakdown:{physical:{damage:100.0}},
                skills:[{id:"TestSkill", damage:100.0, hits:1, crits:0}]}]};
    }
    static function response(status:Int, body:Dynamic = null, retryAfter:String = ""):FareverlyResponse
        return {status:status, body:body == null ? "" : Json.stringify(body), retryAfter:retryAfter, error:""};
    static function main():Void {
        cleanup(); retention(); uploads(); filters(); openButton();
        Sys.println('Recovery and startup cleanup: $checks checks passed');
    }
    static function cleanup():Void {
        var root = "build/recovery-cleanup-" + Std.random(0x3fffffff);
        var store = new TimelineStore(root);
        FileSystem.createDirectory(root + "/timeline-spool/trace_old");
        for (name in ["000000000.json", "000000001.json.tmp", "notes.txt"])
            File.saveContent(root + "/timeline-spool/trace_old/" + name, "preserved only if unknown");
        FileSystem.createDirectory(root + "/timeline-spool/trace_empty");
        FileSystem.createDirectory(root + "/timeline-spool/trace_old/000000002.json");
        File.saveContent(root + "/timeline-spool/trace_old/000000002.json/nested", "keep");
        FileSystem.createDirectory(root + "/history");
        File.saveContent(root + "/history/saved.json", "saved fight");
        File.saveContent(root + "/history/saved.json.timeline", "saved timeline");
        store.append({stream:"trace_current", index:0, first:0, last:1, initial:[], events:[]});
        check(store.cleanupStartup() == 2, "Cleanup removes both abandoned chunks and interrupted temporary chunks");
        check(FileSystem.exists(root + "/timeline-spool/trace_current/000000000.json"), "Cleanup preserves a current-session stream already written");
        check(FileSystem.exists(root + "/timeline-spool/trace_old/notes.txt"), "Cleanup preserves unknown files");
        check(FileSystem.exists(root + "/timeline-spool/trace_old/000000002.json/nested"), "Cleanup never recurses into arbitrary directories");
        check(!FileSystem.exists(root + "/timeline-spool/trace_empty"), "Empty abandoned stream directories are removed");
        check(File.getContent(root + "/history/saved.json") == "saved fight" && File.getContent(root + "/history/saved.json.timeline") == "saved timeline", "Saved logs and timelines remain intact");
        check(store.cleanupStartup() == 0, "Repeated cleanup is harmless");
        store.finish("trace_current"); check(!FileSystem.exists(root + "/timeline-spool/trace_current"), "Normal shutdown cleanup still works");
        // Exercise the startup entry point itself, with uploads disabled and stop queued.
        FileSystem.createDirectory(root + "/timeline-spool/trace_crash");
        File.saveContent(root + "/timeline-spool/trace_crash/000000000.json", "old");
        var worker = new LogUploader(root); worker.stopRequests.add(true);
        var done = new sys.thread.Lock();
        sys.thread.Thread.create(() -> { worker.run(); done.release(); });
        check(done.wait(5), "Log worker completes startup cleanup in the background");
        check(!FileSystem.exists(root + "/timeline-spool/trace_crash"), "Worker invokes cleanup at startup");
        remove(root);
    }
    static function retention():Void {
        check(LogRetention.months(0) == 1 && LogRetention.months(25) == 24, "Retention bounds stay at 1–24 months");
        check(Date.fromTime(LogRetention.cutoff(Date.fromString("2024-03-31 10:20:30"), 1)).toString() == "2024-02-29 10:20:30", "Calendar months clamp at leap day");
        check(Date.fromTime(LogRetention.cutoff(Date.fromString("2025-03-31 10:20:30"), 1)).toString() == "2025-02-28 10:20:30", "Calendar months clamp at non-leap February");
        check(!LogRetention.expired(0, 10) && !LogRetention.expired(Math.NaN, 10) && !LogRetention.expired(10, 10) && LogRetention.expired(9, 10), "Invalid and boundary timestamps are preserved");
        var config = MeterConfig.defaults();
        check(config.autoDeleteLogs && config.logRetentionMonths == 12 && config.meterScale == 100, "Restored defaults match the working build");
        var root = "build/recovery-retention-" + Std.random(0x3fffffff), worker = new LogUploader(root);
        var now = Date.fromString("2026-10-15 12:00:00");
        worker.setRetention(false, 12); worker.prune(now);
        check(worker.nextPrune == now.getTime() + 86400000, "Disabled pruning still sets the 24-hour schedule");
        var old = fixture("expired"); old.startedAt = Date.fromString("2025-09-01 00:00:00").getTime();
        worker.archive(old, true); worker.flush();
        worker.setRetention(true, 1); worker.prune(Date.fromTime(now.getTime() + 1000));
        check(FileSystem.exists(worker.fareverly.reportPath("expired")), "Changing settings does not prune early");
        worker.prune(Date.fromTime(now.getTime() + 86400000));
        check(!FileSystem.exists(worker.fareverly.reportPath("expired")), "Next daily pass removes expired submission payloads");
        check(worker.history.query({id:1, action:"groups", group:"", page:0, fightId:""}).groups.length == 0, "Daily pass also removes expired history summaries");
        remove(root);
        check(ReadyCheck.COUNTDOWN_DELAY == 0.7, "Ready check retains the final requested delay");
    }
    static function testApiKey():String return "fv1_" + StringTools.lpad("", "A", 43);
    static function uploads():Void {
        var now = Date.fromString("2026-10-15 12:00:00").getTime() / 1000;
        var good = fixture();
        check(FareverlyContract.validate(good, now) == "", "Valid synthetic victory passes local validation");
        var bad = fixture(); bad.players[0].damage = 101;
        check(FareverlyContract.validate(bad, now) != "", "Inconsistent totals are never sent");
        bad = fixture(); bad.players[0].healing = null;
        check(FareverlyContract.validate(bad, now) != "", "Unrecorded healing must be omitted");
        bad = fixture(); bad.outcome = "Defeat";
        check(!FareverlyContract.candidate(bad), "Defeats cannot enter the submission queue");
        var fight = new Fight(1); fight.last = 11; fight.closed = 11; fight.me = "test-player";
        fight.players["test-player"] = new PlayerStats({uid:"test-player", name:"Test Player", isMe:true, className:"", weapon:null, classSkills:[], weaponSkills:[]});
        fight.players["test-player"].healingRecorded = false;
        check(!Reflect.hasField(FightHistory.encode(fight, "no-heals").players[0], "healing"), "History encoder omits unrecorded healing for Fareverly compatibility");
        var root = "build/recovery-upload-" + Std.random(0x3fffffff), posts = 0, gets = 0;
        var transport = (method:String, url:String, body:haxe.io.Bytes, token:String) -> {
            if (method == "GET") { gets++; return response(200, {encounters:[{bossKind:"TestBoss", category:"boss-dungeons", ranked:true}]}); }
            posts++;
            check(body.toString() == Json.stringify(good), "Upload sends the existing JSON directly");
            return posts == 1 ? response(429, {error:"test rate limit"}, "120") : response(201, {status:"accepted", url:"/reports/test-report"});
        };
        var queue = new FareverlyUploader(root, transport, _ -> {}, () -> now, () -> 0, testApiKey);
        queue.enqueue(good); queue.step();
        check(posts == 1 && gets == 1, "Catalog is fetched before the first submission");
        var path = queue.reportPath(good.id);
        check(queue.state(path).nextAttempt == now + 120, "Retry-After takes priority over backoff");
        var restarted = new FareverlyUploader(root, transport, _ -> {}, () -> now, () -> 0, testApiKey);
        restarted.step(); check(posts == 1, "Persistent cooldown survives a restart");
        now += 120; restarted.step();
        check(posts == 2 && restarted.state(path).status == "accepted", "Retry succeeds once cooldown ends");
        check(FileSystem.exists(path), "Accepted payload is kept locally");
        remove(root);
        root = "build/recovery-retries-" + Std.random(0x3fffffff); posts = 0;
        queue = new FareverlyUploader(root, (method, url, body, token) -> {
            if (method == "GET") return response(200, {encounters:[{bossKind:"TestBoss", category:"boss-dungeons", ranked:true}]});
            posts++; return response(503);
        }, _ -> {}, () -> now, () -> 0, testApiKey);
        queue.enqueue(good);
        for (_ in 0...8) { queue.step(); now += 1000; }
        path = queue.reportPath(good.id);
        check(posts == 4 && queue.state(path).status == "failed", "Transient failures stop after four attempts");
        check(FileSystem.exists(path), "Failed payload is always retained locally");
        queue.retryFailed(good.id); queue.step();
        check(posts == 5, "Explicit background retry starts a bounded new attempt budget");
        remove(root);
        check(FareverlyUploader.reportUrl("https://fareverly.com.evil/reports/x") == "" && FareverlyUploader.reportUrl("/reports/x\"&bad") == "", "Browser URL validation excludes foreign origins and shell syntax");
        var local = Date.fromString("2026-10-15 12:00:00");
        var utc = (local.getTime() - local.getTimezoneOffset() * 60000) / 1000;
        check(FareverlyUploader.retryAfter("Thu, 15 Oct 2026 12:02:00 GMT", utc) == 120, "HTTP-date Retry-After handles the local timezone");
    }
    static function filters():Void {
        var a = CombatTimeline.event("damage", "me", "one", "test"); a.sourceName = "Player"; a.targetName = "Enemy"; a.amount = 10;
        var b = CombatTimeline.event("damage", "me", "two", "test"); b.sourceName = "Player"; b.targetName = "Enemy"; b.amount = 20;
        var c = CombatTimeline.event("damage", "one", "me", "test"); c.sourceName = "Enemy"; c.targetName = "Player"; c.amount = 5;
        var data:Dynamic = {me:"me", duration:10, events:[a,b,c], initial:[]};
        var request:HistoryRequest = {id:1, action:"detailed", group:"", page:0, fightId:"test", eventSource:"me", eventTarget:"two"};
        var report = DetailedReport.query(data, request);
        check(report.total == 1 && report.rows[0].target == "two", "Source and target filters intersect by stable actor ID");
        var targets:Array<Dynamic> = report.targets;
        check(targets.filter(x -> StringTools.startsWith(x.name, "Enemy (")).length == 2, "Duplicate names remain distinguishable");
        request.eventSource = ""; request.eventTarget = "";
        check(DetailedReport.query(data, request).total == 3, "Clearing actor filters restores every event");
    }
    static function openButton():Void {
        var button = new FareverlyOpen(); button.select("fight-a");
        check(button.begin(1) == "https://fareverly.com/analyze" && button.begin(2) == "", "Analyzer opens directly and repeated clicks are blocked");
        button.select("fight-b"); check(button.begin(2) == "", "Navigation cannot start a second browser launch");
        button.opened(3); check(button.busy(4) && !button.busy(5), "Browser handoff retains its cooldown");
        check(button.begin(5) == FareverlyOpen.URL, "No ranked lookup is required");
        // A deliberately stalled launcher proves open() returns without waiting for it.
        var entered = new sys.thread.Lock(), release = new sys.thread.Lock(), launched = new sys.thread.Lock();
        var browser = new FareverlyBrowser(url -> { entered.release(); release.wait(); launched.release(); return 0; });
        var before = haxe.Timer.stamp(); browser.open("https://fareverly.com/analyze");
        check(haxe.Timer.stamp() - before < 0.5 && entered.wait(2), "Browser launch runs off the caller thread");
        check(!browser.poll(), "Pending browser launch does not block polling");
        var rejected = false; try browser.open("https://fareverly.com/analyze") catch (_:Dynamic) rejected = true;
        check(rejected, "Duplicate native launches are rejected");
        release.release(); check(launched.wait(2), "Injected browser launcher completes without opening a real browser");
        var complete = false;
        for (_ in 0...100) { if (browser.poll()) { complete = true; break; } Sys.sleep(0.001); }
        check(complete, "Browser completion is handed back to the caller");
    }
}
