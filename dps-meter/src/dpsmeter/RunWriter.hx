package dpsmeter;

import dpsmeter.CombatModel.Fight;
import sys.thread.Thread;
import dpsmeter.FightHistory;
import dpsmeter.BossRecords;

/** The game thread hands off detached reports; the uploader owns disk and HTTP work. */
class RunWriter {
    var uploader:LogUploader;
    public var timeline:CombatTimeline;
    var started:Bool = false;
    var stopped:Bool = false;
    var reportSequence:Int = Std.random(0x3fffffff);
    var historySequence:Int = 0;
    final historySession:String = DateTools.format(Date.now(), "%Y%m%d_%H%M%S") + "_" + Std.random(0x3fffffff);

    public function new() {}
    public function recordTimeline(batch:CombatTimeline.TimelineBatch):Void {
        if (stopped) return;
        prepare(); uploader.recordTimeline(batch);
    }
    function attachTimeline(record:Dynamic, fight:Fight):Void {
        if (timeline == null) return;
        timeline.flush(haxe.Timer.stamp());
        Reflect.setField(record, "_timeline", timeline.span(fight.start, Math.max(fight.last, fight.closed), fight.me));
    }
    public static function historyPath():String {
        var path = haxe.io.Path.join([Sys.getCwd(), "hlx", "mods", "dps-meter", "history"]);
        return Sys.systemName() == "Windows" ? StringTools.replace(path, "/", "\\") : path;
    }

    public function archive(fight:Fight):Void {
        if (stopped || (fight.category == HistoryCatalog.HistoryCategory.OTHER && !fight.targetDummy)) return;
        var record = FightHistory.encode(fight, "fight_" + historySession + "_" + (++historySequence));
        if (!HistoryCatalog.HistoryCategory.canArchive(record)) return;
        attachTimeline(record, fight);
        prepare();
        uploader.archive(record);
    }
    public function archiveRecap(recap:dpsmeter.RiftTracker.RiftRecap):Void {
        if (stopped) return;
        var record = RiftRecapHistory.encode(recap, "recap_" + historySession + "_" + (++historySequence));
        if (timeline != null) {
            var start = recap.gate == null ? recap.boss.start : recap.gate.start;
            timeline.flush(haxe.Timer.stamp());
            Reflect.setField(record, "_timeline", timeline.span(start, Math.max(recap.boss.last, recap.boss.closed), recap.boss.me));
        }
        prepare();
        uploader.archive(record);
    }
    public function archiveHistory(model:dpsmeter.CombatModel):Void {
        while (model.history.length > 0) {
            archive(model.history[0]);
            model.history.shift();
        }
        while (model.recapHistory.length > 0) {
            archiveRecap(model.recapHistory[0]);
            model.recapHistory.shift();
        }
    }
    public function requestHistory(request:HistoryRequest):Void { prepare(); uploader.requestHistory(request); }
    public function receiveHistory():Null<HistoryResponse> return uploader == null ? null : uploader.receiveHistory();
    public function requestBossRecord(request:BossRecordRequest):Void { prepare(); uploader.requestBossRecord(request); }
    public function receiveBossRecord():Null<BossRecordResponse> return uploader == null ? null : uploader.receiveBossRecord();

    public function enqueue(fight:Fight):Void {
        // The older boss collector records a confirmed boss kill in defeated;
        // history/Rift snapshots also have an explicit outcome. A defeat or an
        // unknown result must never become an upload, even if queued by mistake.
        if (stopped || (fight.outcome != "" ? fight.outcome != "Victory" : !fight.defeated)) return;
        prepare();
        var timestamp = DateTools.format(Date.now(), "%Y%m%d-%H%M%S");
        reportSequence = (reportSequence + 1) & 0x3fffffff;
        var report = fight.json(timestamp, reportSequence);
        if (report.players.length == 0) return;
        // Queue-only metadata survives restarts; LogUploader removes it before POST.
        Reflect.setField(report, "outcome", "Victory");
        uploader.enqueue("run_" + timestamp + "_" + reportSequence + ".json", report);
    }

    function prepare():Void {
        if (uploader == null) uploader = new LogUploader("hlx/mods/dps-meter");
    }

    public function update(now:Float):Void {
        if (started || stopped) return;
        prepare();
        // Creating a thread during HLX module loading can deadlock startup.
        // This method is called only after the first GameApp.update.
        Thread.create(uploader.run);
        started = true;
    }

    public function stop():Void {
        if (stopped) return;
        if (timeline != null) {
            timeline.flush(haxe.Timer.stamp());
            if (uploader != null) uploader.finishTimeline(timeline.stream);
        }
        stopped = true;
        if (uploader != null) uploader.stop();
    }
}
