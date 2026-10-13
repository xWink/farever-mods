package dpsmeter;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Deque;
import sys.thread.Lock;
import sys.thread.Mutex;
import dpsmeter.FightHistory;
import dpsmeter.BossRecords;

private typedef QueuedRun = {name:String, report:Dynamic};

/** One worker owns uploads and queue maintenance. No game objects cross into it. */
class LogUploader {
    static inline var DEFAULT_URL = "https://fareverlogs.fr/api/v1/runs";
    final root:String;
    final logs:String;
    final incoming = new Deque<QueuedRun>();
    final stopRequests = new Deque<Bool>();
    final wake = new Lock();
    final saveMutex = new Mutex();
    final pending:Array<QueuedRun> = [];
    final historyIncoming = new Deque<Dynamic>();
    final historyPending:Array<Dynamic> = [];
    final historyRequests = new Deque<HistoryRequest>();
    final historyResponses = new Deque<HistoryResponse>();
    final bossRequests = new Deque<BossRecordRequest>();
    final bossResponses = new Deque<BossRecordResponse>();
    final history:FightHistoryStore;
    final timelineIncoming = new Deque<CombatTimeline.TimelineBatch>();
    final timelinePending:Array<CombatTimeline.TimelineBatch> = [];
    final timelineFinished = new Deque<String>();
    final timelineFinishedPending:Array<String> = [];
    final retryAt:Map<String, Float> = [];
    var apiUrl:String = DEFAULT_URL;
    var token:String = "";
    var pollSeconds:Float = 5;
    var stopping:Bool = false;
    var nextSaveAt:Float = 0;

    public function new(root:String) {
        this.root = root;
        logs = root + "/logs";
        history = new FightHistoryStore(root, log);
    }

    public function archive(record:Dynamic):Void { historyIncoming.add(record); wake.release(); }
    public function recordTimeline(batch:CombatTimeline.TimelineBatch):Void { timelineIncoming.add(batch); wake.release(); }
    public function finishTimeline(stream:String):Void { timelineFinished.add(stream); wake.release(); }
    public function requestHistory(request:HistoryRequest):Void { historyRequests.add(request); wake.release(); }
    public function receiveHistory():Null<HistoryResponse> return historyResponses.pop(false);
    public function requestBossRecord(request:BossRecordRequest):Void { bossRequests.add(request); wake.release(); }
    public function receiveBossRecord():Null<BossRecordResponse> return bossResponses.pop(false);

    function warmHistory():Void {
        saveMutex.acquire();
        try history.warm() catch (e:Dynamic) { saveMutex.release(); throw e; }
        saveMutex.release();
    }

    function readBossRecords():Void {
        var request = bossRequests.pop(false);
        if (request == null) return;
        saveMutex.acquire();
        // Separate from navigation coalescing: opening history must not discard
        // a kill's lookup or consume its response, and vice versa.
        while (request != null) {
            try bossResponses.add(history.bossRecord(request)) catch (e:Dynamic) {
                bossResponses.add({id: request.id, best: null, error: "Could not read boss records."});
                log("Boss record: " + Std.string(e));
            }
            request = bossRequests.pop(false);
        }
        saveMutex.release();
    }

    function browseHistory():Void {
        var first = historyRequests.pop(false);
        if (first == null) return;
        var requests = [first];
        var next = historyRequests.pop(false);
        while (next != null) { requests.push(next); next = historyRequests.pop(false); }
        saveMutex.acquire();
        // Rapid navigation can replace reads, but never an explicit deletion.
        for (request in HistoryRequests.coalesce(requests)) try historyResponses.add(history.query(request))
        catch (e:Dynamic) {
            historyResponses.add({id: request.id, page: 0, total: 0, groups: [], entries: [], record: null,
                error: request.action == "delete" ? Std.string(e) : "Could not read fight history. Try opening it again."});
            log("History: " + Std.string(e));
        }
        saveMutex.release();
    }

    public function enqueue(name:String, report:Dynamic):Void {
        if (!confirmedVictory(report)) return;
        incoming.add({name: name, report: report});
        wake.release();
    }

    public function stop():Void {
        stopRequests.add(true);
        wake.release();
        // On normal game shutdown, persist the last handoffs without waiting
        // for a network request. The worker never holds saveMutex during HTTP.
        try flush() catch (_:Dynamic) {}
    }

    function shouldStop():Bool {
        if (stopRequests.pop(false) != null) stopping = true;
        return stopping;
    }

    public function run():Void {
        var initialized = false;
        var historyWarmAttempted = false;
        while (!shouldStop()) {
            try {
                // Saving encounters must also work if upload configuration or
                // network initialization fails.
                flush();
                // Start loading at the first game update, not at the first
                // boss kill. Later lookups reuse these in-memory summaries.
                // This remains independent of upload settings and networking.
                if (!historyWarmAttempted) {
                    historyWarmAttempted = true;
                    try warmHistory() catch (e:Dynamic) log("History preload: " + Std.string(e));
                    // A preload failure must not block uploads or other work;
                    // the next explicit history/record query can retry indexing.
                }
                browseHistory();
                readBossRecords();
                if (!initialized) {
                    loadSettings();
                    FileSystem.createDirectory(logs + "/sent");
                    FileSystem.createDirectory(logs + "/rejected");
                    recoverDrafts();
                    initialized = true;
                    log("HLX uploader started");
                }
                for (name in FileSystem.readDirectory(logs)) {
                    if (shouldStop()) break;
                    if (!isRun(name) || FileSystem.isDirectory(logs + "/" + name)) continue;
                    var retry = retryAt.get(name);
                    if (retry != null && haxe.Timer.stamp() < retry) continue;
                    upload(name);
                }
            } catch (e:Dynamic) {
                if (!shouldStop()) log("Uploader will retry: " + Std.string(e));
            }
            if (!shouldStop()) wake.wait(pollSeconds);
        }
        try flush() catch (_:Dynamic) {}
    }

    function loadSettings():Void {
        var path = root + "/uploader.ini";
        if (!FileSystem.exists(path)) {
            FileSystem.createDirectory(root);
            File.saveContent(path, "api_url=" + DEFAULT_URL + "\ntoken=\npoll_sec=5\n");
            return;
        }
        for (raw in File.getContent(path).split("\n")) {
            var line = StringTools.trim(StringTools.replace(raw, "\uFEFF", ""));
            if (line == "" || StringTools.startsWith(line, ";") || StringTools.startsWith(line, "#")) continue;
            var separator = line.indexOf("=");
            if (separator < 0) continue;
            var key = StringTools.trim(line.substr(0, separator)).toLowerCase();
            var value = StringTools.trim(line.substr(separator + 1));
            switch (key) {
                case "api_url": apiUrl = value;
                case "token": token = value;
                case "poll_sec":
                    var seconds = Std.parseInt(value);
                    if (seconds != null && seconds > 0) pollSeconds = seconds;
                default:
            }
        }
        if (!StringTools.startsWith(apiUrl, "https://") && !StringTools.startsWith(apiUrl, "http://"))
            throw "Invalid api_url in uploader.ini";
        if (token.indexOf("\r") >= 0 || token.indexOf("\n") >= 0) throw "Invalid token in uploader.ini";
    }

    function flush():Void {
        saveMutex.acquire();
        try {
            try {
                history.initialize();
                // Snapshot dependents before prerequisites. The producer queues
                // chunks, then archives, then completion. Reading separate
                // queues in the opposite order can save an archive before its
                // final chunk, or clean a stream with an archive still queued.
                var finished = timelineFinished.pop(false);
                while (finished != null) { timelineFinishedPending.push(finished); finished = timelineFinished.pop(false); }
                var record = historyIncoming.pop(false);
                while (record != null) { historyPending.push(record); record = historyIncoming.pop(false); }
                var batch = timelineIncoming.pop(false);
                while (batch != null) { timelinePending.push(batch); batch = timelineIncoming.pop(false); }
                while (timelinePending.length > 0) {
                    history.timeline.append(timelinePending[0]); timelinePending.shift();
                }
                while (historyPending.length > 0) {
                    history.save(historyPending[0]);
                    historyPending.shift();
                }
                // Only retire a closed stream after all its archive handoffs
                // succeeded. Failed saves retain their recoverable chunks.
                while (timelineFinishedPending.length > 0) {
                    var finished = timelineFinishedPending[0];
                    try history.timeline.finish(finished) catch (e:Dynamic) log("Timeline cleanup: " + Std.string(e));
                    timelineFinishedPending.shift();
                }
            } catch (e:Dynamic) log("History save will retry: " + Std.string(e));
            var item = incoming.pop(false);
            while (item != null) { pending.push(item); item = incoming.pop(false); }
            if (pending.length > 0) FileSystem.createDirectory(logs);
            while (pending.length > 0) {
                var job = pending[0];
                saveReport(job.name, job.report);
                pending.shift();
            }
        } catch (e:Dynamic) {
            saveMutex.release();
            throw e;
        }
        saveMutex.release();
    }

    static function confirmedVictory(report:Dynamic):Bool
        return report != null && Reflect.field(report, "outcome") == "Victory";

    function saveReport(name:String, report:Dynamic):Bool {
        if (!confirmedVictory(report)) return false;
        // Stable names also make recovery safe if shutdown occurs between
        // committing the JSON and removing its old .pending draft.
        for (folder in [logs, logs + "/sent", logs + "/rejected"]) {
            var existing = folder + "/" + name;
            if (FileSystem.exists(existing)) {
                if (Json.parse(File.getContent(existing)).session_id == report.session_id) return true;
                throw "A different report already uses " + name;
            }
        }
        var path = logs + "/" + name;
        var temp = path.substr(0, path.length - 5) + ".tmp";
        File.saveContent(temp, Json.stringify(report, null, "  "));
        FileSystem.rename(temp, path);
        return true;
    }

    function recoverDrafts():Void {
        for (name in FileSystem.readDirectory(logs)) {
            if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".pending")) continue;
            var path = logs + "/" + name;
            try {
                var contents = File.getContent(path);
                var draft:Dynamic = Json.parse(contents);
                if (draft.report == null || draft.timestamp == null || draft.boss == null) continue;
                var id = haxe.crypto.Md5.encode(contents).substr(0, 7);
                draft.report.session_id = draft.boss + "-" + draft.timestamp + "-" + Std.parseInt("0x" + id);
                var saved = false;
                saveMutex.acquire();
                try saved = saveReport(Path.withoutExtension(name) + "_recovered_" + id + ".json", draft.report)
                catch (e:Dynamic) { saveMutex.release(); throw e; }
                saveMutex.release();
                if (saved) FileSystem.deleteFile(path);
            } catch (e:Dynamic) log("Could not recover " + name + ": " + Std.string(e));
        }
    }

    function progress():Void {
        if (shouldStop()) throw "Upload stopped";
        var now = haxe.Timer.stamp();
        if (now >= nextSaveAt) {
            nextSaveAt = now + 0.1;
            // Keep persisting new encounters even while a slow upload waits.
            flush();
            browseHistory();
            readBossRecords();
        }
    }

    function uploadBytes(name:String):Null<haxe.io.Bytes> {
        var report:Dynamic = Json.parse(File.getContent(logs + "/" + name));
        if (!confirmedVictory(report)) {
            // Old queued reports did not store an outcome. Preserve them for
            // local history, but never guess victory from damage/skill kills.
            retryAt[name] = Math.POSITIVE_INFINITY;
            log(name + " skipped: no confirmed victory (kept locally)");
            return null;
        }
        Reflect.deleteField(report, "outcome");
        return haxe.io.Bytes.ofString(Json.stringify(report));
    }

    function upload(name:String):Void {
        var path = logs + "/" + name;
        var status = 0;
        var error:String = "";
        var socket:UploadSocket = null;
        try {
            progress();
            // Check retries from disk as well as fresh queue entries, before
            // constructing an HTTP request or opening a network socket.
            var bytes = uploadBytes(name);
            if (bytes == null) return;
            var request = new sys.Http(apiUrl);
            request.cnxTimeout = 30;
            request.noShutdown = true;
            request.setHeader("Content-Type", "application/json");
            request.setHeader("User-Agent", "farever-group-dps-uploader/1.0");
            if (token != "") request.setHeader("Authorization", "Bearer " + token);
            request.setPostBytes(bytes);
            request.onStatus = value -> status = value;
            request.onError = message -> error = message;
            socket = new UploadSocket(StringTools.startsWith(apiUrl, "https://"), progress);
            request.customRequest(true, new ResponseSink(), socket, "POST");
        } catch (e:Dynamic) error = Std.string(e);
        if (socket != null) try socket.close() catch (_:Dynamic) {}
        if (shouldStop()) return;
        retryAt[name] = haxe.Timer.stamp() + pollSeconds;
        // Match the original uploader's status handling, including rejected 4xx.
        var folder = status >= 200 && status < 300 ? "sent" : status >= 400 && status < 500 ? "rejected" : null;
        if (folder != null) {
            FileSystem.rename(path, logs + "/" + folder + "/" + name);
            retryAt.remove(name);
            log(name + " HTTP " + status + " -> " + folder + "/");
        } else log(name + " upload failed" + (status > 0 ? " (HTTP " + status + ")" : "")
            + (error == "" ? "" : ": " + error) + "; retrying later");
    }

    static function isRun(name:String):Bool {
        return StringTools.startsWith(name, "run_") && StringTools.endsWith(name, ".json");
    }

    function log(message:String):Void {
        try {
            var output = File.append(root + "/uploader.log", false);
            try output.writeString("[" + DateTools.format(Date.now(), "%H:%M:%S") + "] " + message + "\n")
            catch (e:Dynamic) { output.close(); throw e; }
            output.close();
        } catch (_:Dynamic) {}
    }
}

/** The API's response body is not needed; never retain it in game memory. */
private class ResponseSink extends haxe.io.Output {
    public function new() {}
    override public function writeByte(value:Int):Void {}
    override public function writeBytes(bytes:haxe.io.Bytes, pos:Int, len:Int):Int return len;
}
