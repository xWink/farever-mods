package dpsmeter;

import dpsmeter.CombatModel.Fight;
import sys.thread.Thread;
import dpsmeter.FightHistory;
import dpsmeter.BossRecords;

/** The game thread hands off detached reports; the uploader owns disk and HTTP work. */
class RunWriter {
    var uploader:LogUploader;
    var started:Bool = false;
    var stopped:Bool = false;
    var reportSequence:Int = Std.random(0x3fffffff);
    var historySequence:Int = 0;
    final historySession:String = DateTools.format(Date.now(), "%Y%m%d_%H%M%S") + "_" + Std.random(0x3fffffff);

    public function new() {}
    public static function historyPath():String {
        var path = haxe.io.Path.join([Sys.getCwd(), "hlx", "mods", "dps-meter", "history"]);
        return Sys.systemName() == "Windows" ? StringTools.replace(path, "/", "\\") : path;
    }

    public function archive(fight:Fight):Void {
        if (stopped || (fight.category == HistoryCatalog.HistoryCategory.OTHER && !fight.targetDummy)) return;
        var record = FightHistory.encode(fight, "fight_" + historySession + "_" + (++historySequence));
        if (!HistoryCatalog.HistoryCategory.canArchive(record)) return;
        prepare();
        uploader.archive(record);
    }
    public function requestHistory(request:HistoryRequest):Void { prepare(); uploader.requestHistory(request); }
    public function receiveHistory():Null<HistoryResponse> return uploader == null ? null : uploader.receiveHistory();
    public function requestBossRecord(request:BossRecordRequest):Void { prepare(); uploader.requestBossRecord(request); }
    public function receiveBossRecord():Null<BossRecordResponse> return uploader == null ? null : uploader.receiveBossRecord();

    public function enqueue(fight:Fight):Void {
        if (stopped) return;
        prepare();
        var timestamp = DateTools.format(Date.now(), "%Y%m%d-%H%M%S");
        reportSequence = (reportSequence + 1) & 0x3fffffff;
        var report = fight.json(timestamp, reportSequence);
        if (report.players.length == 0) return;
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
        stopped = true;
        if (uploader != null) uploader.stop();
    }
}
