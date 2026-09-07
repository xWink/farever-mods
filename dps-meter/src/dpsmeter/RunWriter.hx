package dpsmeter;

import dpsmeter.CombatModel.Fight;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import sys.thread.Thread;
import sys.thread.Deque;

class RunWriter {
    public var status(default, null):String = "Starting uploader";
    public var gamePid(default, null):Int = 0;
    var startup:Deque<String> = new Deque();
    var pending:Array<Dynamic> = [];
    var retryAt:Float = 0;
    var draftsRecovered:Bool = false;
    final moduleRoot:String;
    final logsDirectory:String;
    public function new() {
        moduleRoot = FileSystem.fullPath("hlx/mods/dps-meter");
        // The uploader resolves its configuration and queue beside its executable.
        logsDirectory = moduleRoot + "/logs";
        // Only plain strings cross threads; game objects and UI stay on the game thread.
        Thread.create(() -> {
            var child:Process = null;
            try {
                var script = moduleRoot + "/start-uploader.ps1";
                var command = "& {\n" + File.getContent(script) + "\n} -ModuleRoot '" + StringTools.replace(moduleRoot, "'", "''") + "'";
                child = new Process("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", command]);
                var output = child.stdout.readAll().toString();
                var error = child.stderr.readAll().toString();
                var code = child.exitCode();
                child.close(); child = null;
                for (line in output.split("\n")) if (StringTools.startsWith(StringTools.trim(line), "PID=")) startup.add(StringTools.trim(line));
                if (code != 0) startup.add("ERROR " + StringTools.trim(error));
            } catch (e:Dynamic) {
                if (child != null) child.close();
                startup.add("ERROR " + Std.string(e));
            }
        });
    }
    public function enqueue(fight:Fight):Void {
        var timestamp = DateTools.format(Date.now(), "%Y%m%d-%H%M%S");
        // Freeze the report before phase resumption can mutate the encounter.
        var report = fight.json(timestamp, gamePid);
        if (report.players.length == 0) return;
        pending.push({report: report, timestamp: timestamp, boss: fight.bossKind});
    }
    public function update(now:Float):Void {
        var message:String;
        while ((message = startup.pop(false)) != null) {
            if (StringTools.startsWith(message, "PID=")) {
                var id = Std.parseInt(message.substr(4));
                if (id != null && id > 0) { gamePid = id; status = "Uploader running"; }
            } else {
                status = "Uploader unavailable; check HLX log";
                trace("[DpsMeter] " + message);
            }
        }
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
                } catch (e:Dynamic) trace("[DpsMeter] Could not recover draft " + name + ": " + e);
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
                trace("[DpsMeter] " + path + " written");
            }
        } catch (e:Dynamic) {
            retryAt = now + 5;
            status = "Could not save run; retrying";
            trace("[DpsMeter] " + e);
        }
    }
}
