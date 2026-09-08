package dpsmeter;

import dpsmeter.CombatModel.Fight;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class RunWriter {
    public var status(default, null):String = "Waiting for game startup";
    public var gamePid(default, null):Int = 0;
    var launcher:Process;
    var startupPath:String;
    var startupStarted:Bool = false;
    var startupDeadline:Float = 0;
    var nextStartupPoll:Float = 0;
    var pending:Array<Dynamic> = [];
    var retryAt:Float = 0;
    var draftsRecovered:Bool = false;
    final moduleRoot:String;
    final logsDirectory:String;
    public function new() {
        moduleRoot = FileSystem.fullPath("hlx/mods/dps-meter");
        // The uploader resolves its configuration and queue beside its executable.
        logsDirectory = moduleRoot + "/logs";
        // Do not start threads or processes while HLX is still loading mods.
    }
    function pollStartup(now:Float):Void {
        if (startupStarted && launcher == null) return;
        try {
            if (!startupStarted) {
                startupStarted = true;
                startupDeadline = now + 30;
                startupPath = moduleRoot + "/uploader-startup-" + DateTools.format(Date.now(), "%Y%m%d-%H%M%S")
                    + "-" + Std.random(0x3fffffff) + ".json";
                var script = File.getContent(moduleRoot + "/start-uploader.ps1");
                var command = "& {\n" + script + "\n} -ModuleRoot '" + StringTools.replace(moduleRoot, "'", "''")
                    + "' -ResultPath '" + StringTools.replace(startupPath, "'", "''") + "'";
                launcher = new Process("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", command], true);
                status = "Starting uploader";
            }
            if (now < nextStartupPoll) return;
            nextStartupPoll = now + 0.25;
            if (FileSystem.exists(startupPath)) {
                var response:Dynamic = haxe.Json.parse(File.getContent(startupPath));
                if (Std.isOfType(response.gamePid, Int) && response.gamePid > 0) gamePid = response.gamePid;
                if (response.running != true || gamePid == 0) throw "Uploader startup failed: " + response.error;
                status = "Uploader running";
                closeLauncher(false);
            } else {
                // Never read pipes or wait for a process to exit on the game thread.
                var code = launcher.exitCode(false);
                if (code != null) throw "Launcher exited with code " + code + " without a startup result";
                if (now >= startupDeadline) throw "Launcher timed out after 30 seconds";
            }
        } catch (_:Dynamic) {
            status = "Uploader unavailable";
            closeLauncher(true);
        }
    }
    function closeLauncher(kill:Bool):Void {
        if (launcher != null) {
            // Only the short-lived launcher is stopped; the uploader stays independent.
            if (kill) try launcher.kill() catch (_:Dynamic) {}
            try launcher.close() catch (_:Dynamic) {}
            launcher = null;
        }
        if (startupPath != null) for (path in [startupPath, startupPath + ".tmp"])
            try { if (FileSystem.exists(path)) FileSystem.deleteFile(path); } catch (_:Dynamic) {}
    }
    public function enqueue(fight:Fight):Void {
        var timestamp = DateTools.format(Date.now(), "%Y%m%d-%H%M%S");
        // Freeze the report before phase resumption can mutate the encounter.
        var report = fight.json(timestamp, gamePid);
        if (report.players.length == 0) return;
        pending.push({report: report, timestamp: timestamp, boss: fight.reportKey()});
    }
    public function update(now:Float):Void {
        pollStartup(now);
        if (gamePid > 0 && !draftsRecovered) {
            draftsRecovered = true;
            if (FileSystem.exists(logsDirectory)) for (name in FileSystem.readDirectory(logsDirectory)) {
                if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".pending")) continue;
                try {
                    var path = logsDirectory + "/" + name;
                    var item:Dynamic = haxe.Json.parse(File.getContent(path));
                    if (item.report == null || item.timestamp == null || item.boss == null) continue;
                    item.draft = path;
                    pending.push(item);
                } catch (_:Dynamic) {}
            }
        }
        if (now < retryAt || pending.length == 0) return;
        try {
            if (!FileSystem.exists(logsDirectory)) FileSystem.createDirectory(logsDirectory);
            while (pending.length > 0) {
                var item = pending[0];
                // Preserve a recoverable draft if process discovery is unavailable.
                // It stays outside the uploader's .json queue until a PID is known.
                if (gamePid <= 0) {
                    var draft = logsDirectory + "/run_" + item.timestamp;
                    var draftPath = draft + ".pending";
                    var index = 1;
                    while (FileSystem.exists(draftPath)) draftPath = draft + "_" + index++ + ".pending";
                    File.saveContent(draftPath, haxe.Json.stringify(item, null, "  "));
                    pending.shift();
                    continue;
                }
                item.report.session_id = item.boss + "-" + item.timestamp + "-" + gamePid;
                var stem = logsDirectory + "/run_" + item.timestamp;
                var path = stem + ".json";
                var n = 1;
                while (FileSystem.exists(path) || FileSystem.exists(logsDirectory + "/sent/" + haxe.io.Path.withoutDirectory(path))
                    || FileSystem.exists(logsDirectory + "/rejected/" + haxe.io.Path.withoutDirectory(path))) path = stem + "_" + n++ + ".json";
                var temp = path.substr(0, path.length - 5) + ".tmp";
                File.saveContent(temp, haxe.Json.stringify(item.report, null, "  "));
                FileSystem.rename(temp, path);
                pending.shift();
                if (item.draft != null && FileSystem.exists(item.draft)) FileSystem.deleteFile(item.draft);
                status = "Run queued for upload";
            }
        } catch (_:Dynamic) {
            retryAt = now + 5;
            status = "Could not save run; retrying";
        }
    }
}
