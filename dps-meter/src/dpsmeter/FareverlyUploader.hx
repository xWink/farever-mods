package dpsmeter;

import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import haxe.io.Bytes;
import dpsmeter.FareverlyHttp.FareverlyResponse;

private typedef SubmissionState = {status:String, attempts:Int, nextAttempt:Float, reason:String, retryable:Bool, url:String};

/** Durable, bounded submission queue. Called only by the log worker. */
class FareverlyUploader {
    public static inline var ORIGIN = "https://fareverly.com";
    public static inline var MAX_BODY = 5 * 1024 * 1024;
    static inline var MAX_ATTEMPTS = 4;
    final folder:String;
    final request:fareverly.Protocol.Transport;
    final apiKey:Void->String;
    public var authMessage(default, null) = "";
    var blockedKey = "";
    var key = "";
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
    public function new(root:String, request:fareverly.Protocol.Transport, log:String->Void,
        ?clock:Void->Float, ?random:Void->Float, ?apiKey:Void->String) {
        folder = root + "/fareverly"; this.request = request; this.log = log;
        this.clock = clock == null ? () -> Date.now().getTime() / 1000 : clock;
        this.random = random == null ? Math.random : random;
        this.apiKey = apiKey == null ? () -> FareverlyConfig.read() : apiKey;
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
        var paused = folder + "/auth-paused.json";
        if (FileSystem.exists(paused)) {
            var state:Dynamic = read(paused);
            if (state != null && Std.isOfType(state.fingerprint, String)) {
                blockedKey = state.fingerprint;
                authMessage = state.mismatch == true ? fareverly.Protocol.error("account_mismatch") : fareverly.Protocol.error("unauthorized");
            }
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
        key = apiKey();
        if (!fareverly.Protocol.validKey(key)) {
            authMessage = "Sign in through Steam in DPS Meter settings to enable ranked uploads."; return;
        }
        var fingerprint = haxe.crypto.Sha256.encode(key);
        if (fingerprint == blockedKey) return;
        authMessage = "";
        if (now < nextRequest) return;
        for (path in paths()) {
            var saved = state(path);
            if (saved.status == "failed" && StringTools.startsWith(saved.reason, "HTTP 401")) {
                saved = initial(); save(path, saved);
            }
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
            // The server authenticates this bearer key and checks the log's
            // uploader account. No account/Steam metadata is stored in config.
            var matching = [for (entry in catalog) if (entry.bossKind == record.bossKind && FareverlyContract.category(entry.category) == record.category) entry];
            if (matching.length != 1) { finish(path, saved, "failed", "Encounter is not in Fareverly's supported catalog.", false); continue; }
            if (matching[0].ranked != true) { finish(path, saved, "failed", "Fareverly rankings are temporarily unavailable. Try again later.", true); continue; }
            // Persist the attempt before sending: a crash cannot reset the retry budget.
            saved.attempts++; saved.nextAttempt = now + 30; save(path, saved); cooldown(now + 7);
            var response = call("POST", ORIGIN + "/api/v1/logs", bytes); now = clock();
            if (response.status == 401 || response.status == 403) {
                // Stop all automatic requests with this key, including after restart.
                blockedKey = fingerprint;
                authMessage = fareverly.Protocol.error(response.status == 401 ? "unauthorized" : "account_mismatch");
                write(folder + "/auth-paused.json", Json.stringify({fingerprint:fingerprint, mismatch:response.status == 403}));
                saved.attempts--; saved.reason = authMessage; save(path, saved);
                log("Fareverly: " + authMessage); return;
            }
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
        try return request(method, url, bytes, method == "POST" ? key : "") catch (error:Dynamic) return {status:0, body:"", retryAfter:"", error:Std.string(error)};
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
        // Remote text may be localized or include private data. Keep only known
        // error codes and translate diagnostics locally, never echo response bodies.
        var code = "";
        try { var data:Dynamic = Json.parse(response.body); if (data != null && Std.isOfType(data.error, String)) code = data.error; } catch (_:Dynamic) {}
        var explanation = switch (code) {
            case "account_mismatch": "Uploader account does not match the connected key";
            case "unauthorized": "Steam sign-in or a new key is required";
            case "rate_limited": "Upload rate limit reached";
            case "inconsistent_totals": "Recorded combat totals do not match their breakdown";
            case "unsupported_encounter": "Encounter is not supported";
            case "ineligible_fight": "Fight is not eligible for ranking";
            case "missing_metadata": "Required fight metadata is missing";
            default: switch (response.status) {
                case 0: "Could not connect to Fareverly";
                case 400, 408, 413, 415, 422: "Fareverly rejected the log format or recorded values";
                case 429: "Upload rate limit reached";
                case 503: "Fareverly uploads are temporarily unavailable";
                default: "Fareverly could not complete the request";
            }
        };
        return prefix + ": " + explanation;
    }
    public static function reportUrl(value:Dynamic):String {
        if (!Std.isOfType(value, String)) return "";
        var path:String = value;
        if (StringTools.startsWith(path, ORIGIN)) path = path.substr(ORIGIN.length);
        return ~/^\/reports\/[A-Za-z0-9_-]+$/.match(path) ? ORIGIN + path : "";
    }
    public static function retryAfter(value:String, now:Float):Float return fareverly.Protocol.retryAfter(value, now);
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
