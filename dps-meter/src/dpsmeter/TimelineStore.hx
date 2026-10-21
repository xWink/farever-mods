package dpsmeter;

import dpsmeter.CombatTimeline;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

/** Worker-only chunk spool and self-contained per-fight timeline sidecars. */
class TimelineStore {
    var root:String;
    var chunks:Map<String, Array<{path:String, first:Float, last:Float}>> = [];
    public function new(root:String) { this.root = root + "/timeline-spool"; }
    static function safe(value:String):String {
        if (!~/^[A-Za-z0-9_-]+$/.match(value)) throw "Invalid timeline identifier";
        return value;
    }
    /** Remove abandoned session chunks once, before this worker begins saving.
        Archived .json.timeline files live under history and are never touched. */
    public function cleanupStartup(?log:String->Void):Int {
        if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return 0;
        var count = 0;
        for (stream in FileSystem.readDirectory(root)) {
            // Current-session data can already exist if shutdown flush ran first.
            if (!~/^[A-Za-z0-9_-]+$/.match(stream) || chunks.exists(stream)) continue;
            var folder = root + "/" + stream;
            if (!FileSystem.isDirectory(folder)) continue;
            try {
                // A single known level only: never recursively delete arbitrary files.
                for (name in FileSystem.readDirectory(folder)) {
                    if (!~/^[0-9]{9,}\.json(\.tmp)?$/.match(name)) continue;
                    var path = folder + "/" + name;
                    if (FileSystem.isDirectory(path)) continue;
                    FileSystem.deleteFile(path); count++;
                }
                if (FileSystem.readDirectory(folder).length == 0) FileSystem.deleteDirectory(folder);
            } catch (error:Dynamic) if (log != null) log("Could not clean an abandoned timeline stream: " + Std.string(error));
        }
        if (count > 0 && log != null) log("Removed " + count + " abandoned timeline chunks on startup.");
        return count;
    }
    public function append(batch:TimelineBatch):Void {
        var folder = root + "/" + safe(batch.stream);
        FileSystem.createDirectory(folder);
        var path = folder + "/" + StringTools.lpad(Std.string(batch.index), "0", 9) + ".json";
        // Atomic and idempotent: a failed archive/save may retry this handoff.
        if (!FileSystem.exists(path)) {
            File.saveContent(path + ".tmp", Json.stringify(batch));
            FileSystem.rename(path + ".tmp", path);
        }
        if (!chunks.exists(batch.stream)) chunks[batch.stream] = [];
        var list = chunks[batch.stream];
        if (list.length == 0 || list[list.length - 1].path != path)
            list.push({path:path, first:batch.first, last:batch.last});
    }
    public function archive(record:Dynamic, path:String):Void {
        var span:TimelineSpan = record._timeline;
        if (span == null) return;
        var list = chunks[span.stream];
        if (list == null) { record.detail = {version:1, error:"No detailed events were captured."}; return; }
        var events:Array<TimelineEvent> = [];
        var active:Map<String, TimelineEvent> = [];
        var seen:Map<Int, Bool> = [];
        var seeded = false;
        // A short lead-in includes the initiating skill before its first impact.
        var from = Math.max(0, span.start - 2);
        for (chunk in list) {
            if (chunk.last < from || chunk.first > span.end) continue;
            var batch:TimelineBatch = Json.parse(File.getContent(chunk.path));
            if (!seeded) {
                for (e in batch.initial) CombatTimeline.applyState(active, e);
                seeded = true;
            }
            for (e in batch.events) {
                if (e.seq > span.through || e.time > span.end) continue;
                if (e.time < from) { CombatTimeline.applyState(active, e); continue; }
                if (seen.exists(e.seq) || (e.source != span.me && e.target != span.me)) continue;
                seen[e.seq] = true;
                var row:TimelineEvent = Reflect.copy(e); row.time -= span.start;
                events.push(row);
            }
        }
        events.sort(compare);
        var initial:Array<TimelineEvent> = [];
        for (e in active) if (e.source == span.me || e.target == span.me) {
            var row:TimelineEvent = Reflect.copy(e);
            if (row.duration != null && row.duration >= 0) row.duration = Math.max(0, row.duration - (from - row.time));
            row.time = from - span.start;
            if (StringTools.startsWith(row.kind, "proc_")) row.kind = "proc_present";
            else if (StringTools.startsWith(row.kind, "status_")) row.kind = "status_present";
            initial.push(row);
        }
        initial.sort(compare);
        var header:Dynamic = {version:1, dpsMeterVersion:record.dpsMeterVersion, me:span.me, duration:Math.max(0, span.end - span.start),
            initial:initial, count:events.length, clock:"client-observed", leadIn:2};
        var output = File.write(path + ".timeline.tmp", false);
        try {
            output.writeString(Json.stringify(header) + "\n");
            for (e in events) output.writeString(Json.stringify(e) + "\n");
            output.close();
        } catch (error:Dynamic) { output.close(); throw error; }
        FileSystem.rename(path + ".timeline.tmp", path + ".timeline");
        record.detail = {version:1, count:events.length};
    }
    public function finish(stream:String):Void {
        var list = chunks[stream];
        if (list == null) return;
        for (chunk in list) if (FileSystem.exists(chunk.path)) FileSystem.deleteFile(chunk.path);
        var folder = root + "/" + safe(stream);
        if (FileSystem.exists(folder) && FileSystem.readDirectory(folder).length == 0) FileSystem.deleteDirectory(folder);
        chunks.remove(stream);
    }
    public static function compare(a:TimelineEvent, b:TimelineEvent):Int {
        var result = Reflect.compare(a.time, b.time);
        return result != 0 ? result : a.seq - b.seq;
    }
    public static function read(path:String):Dynamic {
        if (!FileSystem.exists(path + ".timeline")) return null;
        return readFile(path + ".timeline");
    }
    public static function readFile(path:String):Dynamic {
        var input = File.read(path, false);
        try {
            var header:Dynamic = Json.parse(input.readLine());
            if (header.version != 1) throw "Unsupported detailed report version.";
            var events:Array<TimelineEvent> = [];
            while (!input.eof()) {
                var line:String;
                try line = input.readLine() catch (_:haxe.io.Eof) break;
                if (StringTools.trim(line) != "") events.push(Json.parse(line));
            }
            input.close();
            if (events.length != header.count) throw "The detailed report is incomplete.";
            header.events = events;
            return header;
        } catch (error:Dynamic) { input.close(); throw error; }
    }
}
