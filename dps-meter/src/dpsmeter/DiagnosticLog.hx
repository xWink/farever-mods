package dpsmeter;

import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;

/** Bounded diagnostics, separate from combat-log retention. No server bodies. */
class DiagnosticLog {
    public static inline var LIMIT = 1024 * 1024;
    final path:String;
    final mutex = new Mutex();
    public function new(root:String) path = root + "/uploader.log";
    public function maintain():Void {
        mutex.acquire();
        try rotate(0) catch (_:Dynamic) {}
        mutex.release();
    }
    function rotate(extra:Int):Void {
        var previous = path + ".1";
        // Do not read a potentially huge legacy file into memory.
        if (FileSystem.exists(previous) && FileSystem.stat(previous).size > LIMIT) FileSystem.deleteFile(previous);
        if (!FileSystem.exists(path)) return;
        var size = FileSystem.stat(path).size;
        if (size + extra <= LIMIT) return;
        if (FileSystem.exists(previous)) FileSystem.deleteFile(previous);
        if (size <= LIMIT) FileSystem.rename(path, previous);
        else FileSystem.deleteFile(path);
    }
    public function write(message:String):Void {
        mutex.acquire();
        try {
            FileSystem.createDirectory(haxe.io.Path.directory(path));
            // Defense in depth for callers; authentication never logs payloads.
            message = ~/fv1_[A-Za-z0-9_-]+/g.replace(message, "[redacted key]");
            message = ~/[A-Za-z0-9_-]{43,}/g.replace(message, "[redacted identifier]");
            message = StringTools.replace(StringTools.replace(message, "\r", " "), "\n", " ").substr(0, 1000);
            var line = "[" + DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S") + "] " + message + "\n";
            rotate(haxe.io.Bytes.ofString(line).length);
            var output = File.append(path, false);
            try output.writeString(line) catch (error:Dynamic) { output.close(); throw error; }
            output.close();
        } catch (_:Dynamic) {}
        mutex.release();
    }
}
