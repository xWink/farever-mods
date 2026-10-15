package dpsmeter;

import sys.FileSystem;
import sys.io.File;
import sys.thread.Deque;
import sys.thread.Lock;
import sys.thread.Mutex;
import dpsmeter.FightHistory;
import dpsmeter.BossRecords;
import dpsmeter.FareverlyUploader;

private typedef QueuedHistory = {record:Dynamic, submitFareverly:Bool};

/** One worker owns uploads and queue maintenance. No game objects cross into it. */
class LogUploader {
    final root:String;
    final diagnostics:DiagnosticLog;
    final stopRequests = new Deque<Bool>();
    final wake = new Lock();
    final saveMutex = new Mutex();
    final historyIncoming = new Deque<QueuedHistory>();
    final historyPending:Array<QueuedHistory> = [];
    final historyRequests = new Deque<HistoryRequest>();
    final historyResponses = new Deque<HistoryResponse>();
    final bossRequests = new Deque<BossRecordRequest>();
    final bossResponses = new Deque<BossRecordResponse>();
    final history:FightHistoryStore;
    final timelineIncoming = new Deque<CombatTimeline.TimelineBatch>();
    final timelinePending:Array<CombatTimeline.TimelineBatch> = [];
    final timelineFinished = new Deque<String>();
    final timelineFinishedPending:Array<String> = [];
    final fareverly:FareverlyUploader;
    final authMessages = new Deque<String>();
    var lastAuthMessage = "";
    public function receiveAuthMessage():Null<String> return authMessages.pop(false);
    final fareverlySettings = new Deque<Bool>();
    final fareverlyRetries = new Deque<Bool>();
    public function retryFareverly():Void { fareverlyRetries.add(true); wake.release(); }
    final retentionSettings = new Deque<{enabled:Bool, months:Int}>();
    var fareverlyEnabled = false;
    var retentionReady = false;
    var retentionEnabled = true;
    var retentionMonths = 12;
    var nextPrune:Float = 0;
    var stopping:Bool = false;
    var nextSaveAt:Float = 0;

    public function new(root:String) {
        this.root = root;
        diagnostics = new DiagnosticLog(root);
        history = new FightHistoryStore(root, log);
        fareverly = new FareverlyUploader(root, new FareverlyHttp(progress).authenticated, log);
    }

    public function archive(record:Dynamic, submitFareverly:Bool = false):Void {
        historyIncoming.add({record:record, submitFareverly:submitFareverly}); wake.release();
    }
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

    public function setFareverlyEnabled(enabled:Bool):Void { fareverlySettings.add(enabled); wake.release(); }
    public function setRetention(enabled:Bool, months:Int):Void { retentionSettings.add({enabled:enabled, months:LogRetention.months(months)}); wake.release(); }
    function updateFareverlySettings():Void {
        var value = fareverlySettings.pop(false);
        while (value != null) { fareverlyEnabled = value; value = fareverlySettings.pop(false); }
        var retry = fareverlyRetries.pop(false);
        if (retry != null && fareverlyEnabled) fareverly.retryFailed();
        while (fareverlyRetries.pop(false) != null) {}
    }
    /** Settings changes only update the next scheduled pass; they never trigger deletion. */
    function prune(?now:Date):Void {
        var setting = retentionSettings.pop(false);
        while (setting != null) {
            retentionReady = true; retentionEnabled = setting.enabled; retentionMonths = setting.months;
            setting = retentionSettings.pop(false);
        }
        if (!retentionReady) return;
        if (now == null) now = Date.now();
        if (now.getTime() < nextPrune) return;
        nextPrune = now.getTime() + 86400000.0;
        if (!retentionEnabled) return;
        var cutoff = LogRetention.cutoff(now, retentionMonths);
        saveMutex.acquire();
        try { history.prune(cutoff); fareverly.prune(cutoff); }
        catch (error:Dynamic) { saveMutex.release(); throw error; }
        saveMutex.release();
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
        // The worker owns startup disk work. No current-session chunks have been
        // written yet; the store also protects any streams already appended by stop().
        saveMutex.acquire();
        try history.timeline.cleanupStartup(log) catch (error:Dynamic) log("Timeline startup cleanup: " + Std.string(error));
        saveMutex.release();
        diagnostics.maintain();
        var historyWarmAttempted = false;
        while (!shouldStop()) {
            try {
                flush();
                if (!historyWarmAttempted) {
                    historyWarmAttempted = true;
                    try warmHistory() catch (error:Dynamic) log("History preload: " + Std.string(error));
                }
                browseHistory(); readBossRecords();
                try prune() catch (error:Dynamic) log("Automatic log deletion: " + Std.string(error));
                updateFareverlySettings();
                if (fareverlyEnabled && !shouldStop())
                    try {
                        fareverly.step();
                        if (lastAuthMessage != fareverly.authMessage) {
                            lastAuthMessage = fareverly.authMessage; authMessages.add(lastAuthMessage);
                        }
                    } catch (error:Dynamic) log("Fareverly: " + Std.string(error));

            } catch (error:Dynamic) {
                if (!shouldStop()) log("Uploader will retry: " + Std.string(error));
            }
            if (!shouldStop()) wake.wait(5);
        }
        try flush() catch (_:Dynamic) {}
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
                    var job = historyPending[0];
                    history.save(job.record);
                    if (job.submitFareverly) fareverly.enqueue(job.record);
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
        } catch (e:Dynamic) {
            saveMutex.release();
            throw e;
        }
        saveMutex.release();
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

    function log(message:String):Void diagnostics.write(message);
}
