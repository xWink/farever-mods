package dpsmeter;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Deque;
import sys.thread.Lock;
import sys.thread.Mutex;

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
    final retryAt:Map<String, Float> = [];
    var apiUrl:String = DEFAULT_URL;
    var token:String = "";
    var pollSeconds:Float = 5;
    var keepDays:Int = 7;
    var stopping:Bool = false;
    var nextSaveAt:Float = 0;

    public function new(root:String) {
        this.root = root;
        logs = root + "/logs";
    }

    public function enqueue(name:String, report:Dynamic):Void {
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
        while (!shouldStop()) {
            try {
                // Saving encounters must also work if upload configuration or
                // network initialization fails.
                flush();
                if (!initialized) {
                    loadSettings();
                    FileSystem.createDirectory(logs + "/sent");
                    FileSystem.createDirectory(logs + "/rejected");
                    recoverDrafts();
                    purgeSent();
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
            File.saveContent(path, "api_url=" + DEFAULT_URL + "\ntoken=\npoll_sec=5\nkeep_days=7\n");
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
                case "keep_days":
                    var days = Std.parseInt(value);
                    if (days != null && days >= 0) keepDays = days;
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

    function saveReport(name:String, report:Dynamic):Void {
        // Stable names also make recovery safe if shutdown occurs between
        // committing the JSON and removing its old .pending draft.
        for (folder in [logs, logs + "/sent", logs + "/rejected"]) {
            var existing = folder + "/" + name;
            if (FileSystem.exists(existing)) {
                if (Json.parse(File.getContent(existing)).session_id == report.session_id) return;
                throw "A different report already uses " + name;
            }
        }
        var path = logs + "/" + name;
        var temp = path.substr(0, path.length - 5) + ".tmp";
        File.saveContent(temp, Json.stringify(report, null, "  "));
        FileSystem.rename(temp, path);
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
                saveMutex.acquire();
                try saveReport(Path.withoutExtension(name) + "_recovered_" + id + ".json", draft.report)
                catch (e:Dynamic) { saveMutex.release(); throw e; }
                saveMutex.release();
                FileSystem.deleteFile(path);
            } catch (e:Dynamic) log("Could not recover " + name + ": " + Std.string(e));
        }
    }

    function purgeSent():Void {
        if (keepDays == 0) return;
        var cutoff = Date.now().getTime() - keepDays * 86400000.0;
        var folder = logs + "/sent";
        for (name in FileSystem.readDirectory(folder)) {
            var path = folder + "/" + name;
            if (isRun(name) && !FileSystem.isDirectory(path) && FileSystem.stat(path).mtime.getTime() < cutoff)
                FileSystem.deleteFile(path);
        }
    }

    function progress():Void {
        if (shouldStop()) throw "Upload stopped";
        var now = haxe.Timer.stamp();
        if (now >= nextSaveAt) {
            nextSaveAt = now + 0.1;
            // Keep persisting new encounters even while a slow upload waits.
            flush();
        }
    }

    function upload(name:String):Void {
        var path = logs + "/" + name;
        var status = 0;
        var error:String = "";
        var socket:UploadSocket = null;
        try {
            progress();
            var request = new sys.Http(apiUrl);
            request.cnxTimeout = 30;
            request.noShutdown = true;
            request.setHeader("Content-Type", "application/json");
            request.setHeader("User-Agent", "farever-group-dps-uploader/1.0");
            if (token != "") request.setHeader("Authorization", "Bearer " + token);
            request.setPostBytes(File.getBytes(path));
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
