package dpsmeter;

import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import haxe.io.Bytes;
import dpsmeter.FareverlyHttp.FareverlyResponse;

typedef FareverlyRequest = {id:Int, fightId:String, retry:Bool};
typedef FareverlyReport = {id:Int, fightId:String, status:String, url:String, message:String};
private typedef SubmissionState = {status:String, attempts:Int, nextAttempt:Float, reason:String, retryable:Bool, url:String};

/** Durable, bounded submission queue. Called only by the log worker. */
class FareverlyUploader {
    public static inline var ORIGIN = "https://fareverly.com";
    public static inline var MAX_BODY = 5 * 1024 * 1024;
    static inline var MAX_ATTEMPTS = 4;
    final folder:String;
    final request:(String, String, Bytes)->FareverlyResponse;
    final log:String->Void;
    final clock:Void->Float;
    final random:Void->Float;
    var loaded = false;
    var nextRequest:Float = 0;
    var catalog:Array<Dynamic>;
    var catalogDone = false;
    var catalogError = "";
    var catalogRetryAt:Float = 0;
    var catalogAttempts = 0;
    public function new(root:String, request:(String, String, Bytes)->FareverlyResponse, log:String->Void,
        ?clock:Void->Float, ?random:Void->Float) {
        folder = root + "/fareverly"; this.request = request; this.log = log;
        this.clock = clock == null ? () -> Date.now().getTime() / 1000 : clock;
        this.random = random == null ? Math.random : random;
    }
    function initialize():Void {
        if (loaded) return;
        FileSystem.createDirectory(folder);
        var path = folder + "/cooldown.json";
        if (FileSystem.exists(path) || FileSystem.exists(path + ".tmp")) {
            var value:Dynamic = read(path);
            if (value == null || !numeric(value.until) || value.until < 0) throw "Invalid Fareverly cooldown; queue kept locally.";
            nextRequest = value.until;
        }
        loaded = true;
    }
    static function initial():SubmissionState return {status:"pending", attempts:0, nextAttempt:0, reason:"", retryable:false, url:""};
    function state(path:String):SubmissionState {
        if (!FileSystem.exists(path + ".state.json") && !FileSystem.exists(path + ".state.json.tmp")) return initial();
        var value:Dynamic = read(path + ".state.json");
        if (value == null || ["pending", "accepted", "duplicate", "not_retained", "failed"].indexOf(value.status) < 0
            || !numeric(value.attempts) || value.attempts < 0 || value.attempts > MAX_ATTEMPTS || value.attempts % 1 != 0
            || !numeric(value.nextAttempt) || value.nextAttempt < 0 || !Std.isOfType(value.retryable, Bool))
            throw "Invalid Fareverly retry state; queue kept locally.";
        return value;
    }
    function save(path:String, state:SubmissionState):Void write(path + ".state.json", Json.stringify(state));
    function cooldown(until:Float):Void {
        nextRequest = Math.max(nextRequest, until);
        write(folder + "/cooldown.json", Json.stringify({until:nextRequest}));
    }
    public function enqueue(record:Dynamic):Void {
        if (!FareverlyContract.candidate(record)) return;
        FileSystem.createDirectory(folder);
        var path = reportPath(record.id);
        if (FileSystem.exists(path)) return;
        var json = Json.stringify(record);
        write(path, json);
        var reason = Bytes.ofString(json).length > MAX_BODY ? "Log exceeds Fareverly's 5 MiB limit." : FareverlyContract.validate(record, clock());
        if (reason != "") finish(path, initial(), "failed", reason, false);
    }
    function paths():Array<String> {
        if (!FileSystem.exists(folder)) return [];
        var result = [for (name in FileSystem.readDirectory(folder))
            if (~/^fight_[a-f0-9]{64}\.json$/.match(name) && !FileSystem.isDirectory(folder + "/" + name)) folder + "/" + name];
        result.sort(Reflect.compare); return result;
    }
    public function prune(cutoff:Float):Int {
        var count = 0;
        for (path in paths()) try {
            var record:Dynamic = read(path);
            if (!LogRetention.expired(FightHistory.number(record.startedAt), cutoff)) continue;
            for (suffix in [".tmp", "", ".state.json.tmp", ".state.json"])
                if (FileSystem.exists(path + suffix)) FileSystem.deleteFile(path + suffix);
            count++;
        } catch (error:Dynamic) log("Could not delete expired submission: " + Std.string(error));
        return count;
    }
    public function retryFailed(?fightId:String):Void {
        initialize(); catalog = null; catalogDone = false; catalogAttempts = 0; catalogRetryAt = nextRequest; catalogError = "";
        for (path in paths()) {
            if (fightId != null && path != reportPath(fightId)) continue;
            var saved = state(path);
            if (saved.status != "failed" || !saved.retryable) continue;
            var reset = initial(); reset.nextAttempt = Math.max(clock(), saved.nextAttempt); save(path, reset);
        }
    }
    function reportPath(id:String):String return folder + "/fight_" + haxe.crypto.Sha256.encode(id) + ".json";
    public function report(request:FareverlyRequest, enabled:Bool):FareverlyReport {
        var result:FareverlyReport = {id:request.id, fightId:request.fightId, status:"unavailable", url:"", message:""};
        var path = reportPath(request.fightId);
        if (!FileSystem.exists(path)) { result.message = "This log has not been submitted to Fareverly."; return result; }
        var saved = state(path);
        if (request.retry && enabled && saved.status == "failed" && saved.retryable) { retryFailed(request.fightId); saved = state(path); }
        if (saved.status == "accepted" || saved.status == "duplicate") {
            result.url = reportUrl(saved.url);
            if (result.url != "") result.status = "ready";
            else result.message = "The saved Fareverly report address is unavailable.";
        } else if (saved.status == "pending") {
            if (enabled) result.status = "pending";
            else result.message = "Enable combat log uploads in DPS Meter settings to finish this submission.";
        } else if (saved.status == "not_retained")
            result.message = "Fareverly did not retain this clear because it is outside your three fastest results.";
        else result.message = !enabled && saved.retryable ? "Enable combat log uploads in DPS Meter settings to retry this submission." : saved.reason;
        return result;
    }
    function fetchCatalog(now:Float):Bool {
        if (catalogDone) return true;
        if (now < catalogRetryAt) return false;
        catalogAttempts++;
        var response = call("GET", ORIGIN + "/api/v1/encounters", null); now = clock();
        if (response.status == 200 && response.error == "") try {
            var data:Dynamic = Json.parse(response.body);
            if (data == null || !Std.isOfType(data.encounters, Array)) throw "Missing encounters list";
            var entries:Array<Dynamic> = data.encounters;
            if (entries.length > 1000) throw "Encounter catalog too large";
            for (entry in entries) if (entry == null || !Std.isOfType(entry.bossKind, String) || entry.bossKind == ""
                || !Std.isOfType(entry.category, String) || !Std.isOfType(entry.ranked, Bool)) throw "Malformed encounter entry";
            catalog = entries; catalogDone = true; return true;
        } catch (error:Dynamic) response.error = "Invalid encounter response: " + Std.string(error);
        catalogError = "Could not load Fareverly encounters: " + describe(response);
        if (transient(response) && catalogAttempts < MAX_ATTEMPTS) {
            catalogRetryAt = now + delay(response, catalogAttempts, now); cooldown(catalogRetryAt);
            log(catalogError + "; retry scheduled"); return false;
        }
        catalogDone = true; return true;
    }
    public function step():Void {
        if (!FileSystem.exists(folder)) return;
        initialize(); var now = clock();
        if (now < nextRequest) return;
        for (path in paths()) {
            var saved = state(path);
            if (saved.status != "pending" || now < saved.nextAttempt) continue;
            if (saved.attempts >= MAX_ATTEMPTS) { finish(path, saved, "failed", "Retry limit reached; local log retained.", true); continue; }
            if (!fetchCatalog(now)) return;
            if (catalog == null) { finish(path, saved, "failed", catalogError, true); continue; }
            var bytes:Bytes; var record:Dynamic;
            try {
                if (FileSystem.stat(path).size > MAX_BODY) throw "Log exceeds Fareverly's 5 MiB limit.";
                bytes = File.getBytes(path); record = Json.parse(bytes.toString());
                var reason = FareverlyContract.validate(record, now); if (reason != "") throw reason;
            } catch (error:Dynamic) { finish(path, saved, "failed", Std.string(error), false); continue; }
            var matching = [for (entry in catalog) if (entry.bossKind == record.bossKind && FareverlyContract.category(entry.category) == record.category) entry];
            if (matching.length != 1) { finish(path, saved, "failed", "Encounter is not in Fareverly's supported catalog.", false); continue; }
            if (matching[0].ranked != true) { finish(path, saved, "failed", "Fareverly rankings are temporarily unavailable. Try again later.", true); continue; }
            // Persist the attempt before sending: a crash cannot reset the retry budget.
            saved.attempts++; saved.nextAttempt = now + 30; save(path, saved); cooldown(now + 7);
            var response = call("POST", ORIGIN + "/api/v1/logs", bytes); now = clock();
            var data:Dynamic = null; try data = Json.parse(response.body) catch (_:Dynamic) {}
            if ((response.status == 200 || response.status == 201) && response.error == "" && data != null) {
                if (data.status == "not_retained" && data.reason == "outside_top_three") {
                    finish(path, saved, "not_retained", "Outside your three fastest clears; local log retained.", false); return;
                }
                var url = reportUrl(data.url);
                if ((data.status == "accepted" || data.status == "duplicate") && url != "") {
                    saved.url = url; finish(path, saved, data.status, data.status == "accepted" ? "Victory submitted." : "Victory already submitted.", false); return;
                }
            }
            if (response.status >= 200 && response.status < 300 && response.error == "") response.error = "Unexpected successful upload response";
            var retryable = transient(response);
            saved.nextAttempt = Math.max(nextRequest, now + delay(response, saved.attempts, now));
            if (retryable) cooldown(saved.nextAttempt);
            if (retryable && saved.attempts < MAX_ATTEMPTS) {
                saved.reason = describe(response); save(path, saved); log("Fareverly: " + saved.reason + "; retry scheduled");
            } else finish(path, saved, "failed", describe(response) + "; local log retained.", retryable);
            return;
        }
    }
    function call(method:String, url:String, bytes:Bytes):FareverlyResponse {
        try return request(method, url, bytes) catch (error:Dynamic) return {status:0, body:"", retryAfter:"", error:Std.string(error)};
    }
    function finish(path:String, state:SubmissionState, status:String, reason:String, retryable:Bool):Void {
        state.status = status; state.reason = reason; state.retryable = retryable; save(path, state);
        log("Fareverly " + haxe.io.Path.withoutDirectory(path) + ": " + status + ": " + reason);
    }
    function delay(response:FareverlyResponse, attempts:Int, now:Float):Float
        return Math.max(retryAfter(response.retryAfter, now), Math.max(response.status == 429 ? 60 : 0, Math.pow(2, attempts - 1) * 5 + random() * 3));
    static function numeric(value:Dynamic):Bool return (Std.isOfType(value, Int) || Std.isOfType(value, Float)) && Math.isFinite(value);
    static function transient(response:FareverlyResponse):Bool
        return response.status == 0 || response.status == 429 || response.status >= 500 || (response.status >= 200 && response.status < 300 && response.error != "");
    static function describe(response:FareverlyResponse):String {
        var prefix = response.status == 0 ? "Network error" : "HTTP " + response.status;
        try {
            var data:Dynamic = Json.parse(response.body);
            var message:String = Std.isOfType(data.message, String) ? data.message : Std.isOfType(data.error, String) ? data.error : "";
            if (message != "") return prefix + ": " + message.substr(0, 300)
                + (Std.isOfType(data.path, String) && data.path != "" ? " (" + (cast data.path:String).substr(0, 150) + ")" : "");
        } catch (_:Dynamic) {}
        return prefix + (response.error == "" ? "" : ": " + response.error.substr(0, 300));
    }
    public static function reportUrl(value:Dynamic):String {
        if (!Std.isOfType(value, String)) return "";
        var path:String = value;
        if (StringTools.startsWith(path, ORIGIN)) path = path.substr(ORIGIN.length);
        return ~/^\/reports\/[A-Za-z0-9_-]+$/.match(path) ? ORIGIN + path : "";
    }
    public static function retryAfter(value:String, now:Float):Float {
        if (value == null) return 0;
        value = StringTools.trim(value);
        if (~/^[0-9]+$/.match(value)) { var seconds = Std.parseFloat(value); return Math.isFinite(seconds) ? seconds : 0; }
        var date = ~/^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$/;
        if (!date.match(value)) return 0;
        var month = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"].indexOf(date.matched(2));
        if (month < 0) return 0;
        try {
            var parsed = new Date(Std.parseInt(date.matched(3)), month, Std.parseInt(date.matched(1)),
                Std.parseInt(date.matched(4)), Std.parseInt(date.matched(5)), Std.parseInt(date.matched(6)));
            return Math.max(0, (parsed.getTime() - parsed.getTimezoneOffset() * 60000) / 1000 - now);
        } catch (_:Dynamic) return 0;
    }
    static function write(path:String, contents:String):Void {
        File.saveContent(path + ".tmp", contents);
        if (FileSystem.exists(path)) FileSystem.deleteFile(path);
        FileSystem.rename(path + ".tmp", path);
    }
    static function read(path:String):Dynamic {
        if (FileSystem.exists(path + ".tmp")) try return Json.parse(File.getContent(path + ".tmp")) catch (_:Dynamic) {}
        return Json.parse(File.getContent(path));
    }
}
