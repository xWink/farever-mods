import fareverly.AuthFlow;
import fareverly.Protocol;
import dpsmeter.FareverlyConfig;
import dpsmeter.MeterConfig;
import dpsmeter.DiagnosticLog;
import dpsmeter.FareverlyUploader;
import haxe.io.Bytes;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

@:access(dpsmeter.FareverlyUploader)
@:access(RecoveryTest)
class FareverlyAccountTest {
    static var checks = 0;
    static var key = "fv1_" + StringTools.lpad("", "K", 43);
    static var uri = "https://fareverly.com/connect/12345678-1234-1234-1234-123456789abc";
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function response(status:Int, value:Dynamic, after:String = ""):Response
        return {status:status, body:Json.stringify(value), retryAfter:after, error:""};
    static function device(?url:String):Response return response(201, {device_code:StringTools.lpad("", "D", 43), user_code:"ABCD-1234", verification_uri:url == null ? uri : url, expires_in:600, interval:5});
    static function complete(account:String = "test-account"):Response return response(200, {status:"complete", access_token:key, token_type:"Bearer", account_id:account,
        steam_id:"76561198000000000", expires_at:"2030-01-01T00:00:00.000Z", scope:"logs:upload account:read"});
    static function entropy():Bytes return Bytes.alloc(32);
    static function credential():Credential return {accessToken:key, accountId:"test-account", steamId:"76561198000000000", expiresAt:"2030-01-01T00:00:00.000Z"};
    static function main():Void {
        // Offline injected transports only. No fixture is sent to Fareverly.
        check(Protocol.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "PKCE matches the RFC 7636 S256 test vector");
        for (bad in ["http://fareverly.com/connect/x", "https://fareverly.com.evil/connect/x", "https://fareverly.com@evil/connect/x", uri + "?device_code=secret", uri + "\"", uri + "#secret"])
            check(!Protocol.connectUrl(bad) && !Protocol.browserUrl(bad), "Untrusted/secret-bearing browser URL rejected");
        check(Protocol.connectUrl(uri) && Protocol.browserUrl("https://fareverly.com/analyze") && Protocol.browserUrl("https://fareverly.com/contact"), "Only documented browser destinations allowed");
        var now:Float = 1000, calls = 0, posted:Dynamic = null;
        var flow = new AuthFlow((method, url, body, token) -> {
            calls++; check(method == "POST" && token == "", "Auth requests never carry an existing key");
            var data = Json.parse(body.toString());
            if (calls == 1) {
                posted = data;
                check(url == Protocol.ORIGIN + "/api/v1/auth/device" && data.action == "link" && data.account_id == "test-account" && data.code_challenge_method == "S256", "Initial signup follows the exact contract");
                check(!Reflect.hasField(data, "code_verifier") && !Reflect.hasField(data, "access_token"), "Start sends only the PKCE challenge");
                return device();
            }
            check(url == Protocol.ORIGIN + "/api/v1/auth/token" && Protocol.challenge(data.code_verifier) == posted.code_challenge, "Original verifier proves the token exchange");
            return calls == 2 ? response(202, {status:"authorization_pending"}, "12") : complete();
        }, () -> now, () -> 0);
        var random = entropy(); random.set(0, 42);
        flow.begin("test-account", false, random);
        check(random.get(0) == 0, "Entropy buffer is cleared after encoding");
        flow.step(); check(calls == 1 && flow.userCode == "ABCD-1234" && flow.verificationUri == uri, "Code and verified browser URL are available to the UI");
        now += 4.99; flow.step(); check(calls == 1, "Never poll faster than five seconds");
        now += .01; flow.step(); now += 11; flow.step(); check(calls == 2, "Pending response honors Retry-After");
        now++; flow.step(); check(!flow.active && flow.credential.accessToken == key && flow.userCode == "" && flow.verificationUri == "", "One-time credential delivery clears flow secrets/UI code");
        flow.step(); check(calls == 3, "Completed flow never polls again");
        flow.clearCredential(); check(flow.credential == null, "Saved credential response can be released");
        var action = "";
        flow = new AuthFlow((m,u,b,t) -> { action = Json.parse(b.toString()).action; return device(); }, () -> now);
        flow.begin("test-account", true, entropy()); flow.step(); check(action == "rotate", "Regeneration always starts fresh Steam approval");
        flow.cancel(); now += 600; flow.step(); check(!flow.active && flow.credential == null && flow.userCode == "", "Cancellation clears the pending flow");
        flow = new AuthFlow((m,u,b,t) -> device("https://example.invalid/connect/test"), () -> now);
        flow.begin("test-account", false, entropy()); flow.step(); check(!flow.active && flow.verificationUri == "", "Foreign verification URI never reaches browser");
        calls = 0;
        flow = new AuthFlow((m,u,b,t) -> ++calls == 1 ? device() : complete("other-account"), () -> now);
        flow.begin("test-account", false, entropy()); flow.step(); now += 5; flow.step(); check(!flow.active && flow.credential == null && flow.message.indexOf("another Farever account") >= 0, "Mismatched credential cannot be saved");
        for (code in ["access_denied", "account_not_linked", "account_conflict", "invalid_grant", "already_consumed", "invalid_request"]) {
            flow = new AuthFlow((m,u,b,t) -> response(409, {error:code, message:"Do not echo private server text"}), () -> now);
            flow.begin("test-account", false, entropy()); flow.step();
            check(!flow.active && flow.message == Protocol.error(code) && flow.message.indexOf("private") < 0, "Server error is terminal and has a safe English explanation");
        }
        for (rotate in [false, true]) {
            calls = 0; var actions:Array<String> = [];
            flow = new AuthFlow((m,u,b,t) -> {
                calls++; actions.push(Json.parse(b.toString()).action);
                return calls == 1 ? response(409, {error:rotate ? "account_not_linked" : "already_linked"}, "7") : device();
            }, () -> now);
            flow.begin("test-account", rotate, entropy()); flow.step();
            now += 6; flow.step(); check(calls == 1, "Generate Key fallback respects Retry-After");
            now++; flow.step();
            check(calls == 2 && flow.active && flow.verificationUri == uri && actions[0] != actions[1], "One button handles signup and lost-key rotation with fresh browser approval");
        }
        calls = 0; flow = new AuthFlow((m,u,b,t) -> {calls++; return response(503, {});}, () -> now, () -> 0);
        flow.begin("test-account", false, entropy());
        for (_ in 0...10) { flow.step(); now += 30; }
        check(calls == 4 && !flow.active, "Transient errors have a bounded retry budget");
        calls = 0; flow = new AuthFlow((m,u,b,t) -> {calls++; return calls == 1 ? device() : response(429, {error:"slow_down"}, "90");}, () -> now, () -> 0);
        flow.begin("test-account", false, entropy()); var deadline = flow.expiresAt; flow.step(); now += 5; flow.step();
        now += 89; flow.step(); check(calls == 2 && flow.expiresAt == deadline, "Rate limits delay polling without extending expiry");
        now = deadline; flow.step(); check(!flow.active && calls == 2, "Ten-minute expiry stops pending flow");
        uploads(); diagnostics();
        Sys.println("Fareverly accounts: " + checks + " checks passed");
    }
    static function uploads():Void {
        var root = "build/account-upload-test-" + Std.random(0x3fffffff);
        var now = Date.fromString("2026-10-15 12:00:00").getTime() / 1000;
        var value = "", calls = 0, posts = 0;
        var transport:Transport = (method, url, body, token) -> {
            calls++;
            if (method == "GET") { check(token == "", "Catalog never receives the key"); return response(200, {encounters:[{bossKind:"TestBoss", category:"boss-dungeons", ranked:true}]}); }
            posts++; check(token == value && token != "", "Only ranked uploads receive the selected bearer key");
            return posts == 1 ? response(401, {error:"unauthorized", message:"localized/private detail"}) : response(201, {status:"accepted", url:"/reports/test"});
        };
        var queue = new FareverlyUploader(root, transport, _ -> {}, () -> now, () -> 0, () -> value);
        queue.enqueue(RecoveryTest.fixture()); queue.step(); check(calls == 0, "Missing key pauses without any network request");
        value = key; queue.step(); check(posts == 1 && queue.authMessage.indexOf("Generate Key") >= 0, "401 pauses and offers regeneration");
        now += 1000; queue.step(); check(posts == 1, "Invalid key is not retried");
        queue = new FareverlyUploader(root, transport, _ -> {}, () -> now, () -> 0, () -> value);
        queue.step(); check(posts == 1, "401 pause survives restart");
        value = key; value = "fv1_" + StringTools.lpad("", "N", 43); queue.step();
        check(posts == 2 && queue.state(queue.reportPath("offline-test")).status == "accepted", "New key resumes pending queued victory");
        check(FileSystem.exists(queue.reportPath("offline-test")), "Local report is retained after success");
        var serialized = File.getContent(root + "/fareverly/auth-paused.json");
        check(serialized.indexOf(key) < 0 && serialized.indexOf("localized") < 0, "Pause file contains no key or raw server text");
        RecoveryTest.remove(root);
        root += "-forbidden"; value = key;
        queue = new FareverlyUploader(root, (m,u,b,t) -> m == "GET" ? response(200, {encounters:[{bossKind:"TestBoss",category:"boss-dungeons",ranked:true}]}) : response(403, {error:"account_mismatch"}), _ -> {}, () -> now, () -> 0, () -> value);
        queue.enqueue(RecoveryTest.fixture()); queue.step(); check(queue.authMessage.indexOf("another Farever account") >= 0 && FileSystem.exists(queue.reportPath("offline-test")), "403 explains the mismatch and preserves local log");
        RecoveryTest.remove(root);
    }
    static function diagnostics():Void {
        var root = "build/diagnostics-test-" + Std.random(0x3fffffff);
        FileSystem.createDirectory(root);
        var path = root + "/uploader.log", log = new DiagnosticLog(root);
        File.saveContent(path, StringTools.lpad("", "x", DiagnosticLog.LIMIT + 1));
        log.maintain(); check(!FileSystem.exists(path), "Oversized legacy diagnostics are cleaned without loading them");
        log.write("A safe message " + key + "\nsecond line");
        check(File.getContent(path).indexOf(key) < 0 && File.getContent(path).split("\n").length == 2, "Keys are redacted and newlines cannot forge entries");
        File.saveContent(path, StringTools.lpad("", "x", DiagnosticLog.LIMIT)); log.write("Rotate");
        check(FileSystem.stat(path).size < 200 && FileSystem.stat(path + ".1").size == DiagnosticLog.LIMIT, "Rotation retains one bounded previous file");
        File.saveContent(path, StringTools.lpad("", "y", DiagnosticLog.LIMIT)); log.write("Rotate again");
        check(File.getContent(path + ".1").charAt(0) == "y", "Older rotated diagnostics are deleted");
        var config = MeterConfig.defaults();
        config.transparency = 41;
        check(FareverlyConfig.apply(config, credential(), ""), "Generated key applies to the expected normal config value");
        File.saveContent(root + "/config.json", Json.stringify(config));
        check(FareverlyConfig.read(root + "/config.json") == key, "Uploader reads only the ordinary DPS Meter API key");
        check([for (name in Reflect.fields(config)) if (StringTools.startsWith(name, "fareverly")) name].join(",") == "fareverlyApiKey",
            "Only the API-key field is stored, with no account, Steam, expiry or fingerprint metadata");
        check(config.transparency == 41, "Saving a key preserves other settings");
        config.fareverlyApiKey = "edited after browser opened";
        check(!FareverlyConfig.apply(config, credential(), key), "Late authorization cannot overwrite a newer textbox edit");
        check(config.fareverlyApiKey == "edited after browser opened", "A rejected save keeps the user's newer text");
        File.saveContent(root + "/legacy.json", Json.stringify(credential()));
        File.saveContent(root + "/config.json", "{\"transparency\":41}");
        check(FareverlyConfig.read(root + "/config.json") == "", "Missing API key stays empty even when an old credential file exists");
        for (field in ["fareverlyAccountId", "fareverlySteamId", "fareverlyExpiresAt", "fareverlyKeyFingerprint"]) {
            var old:Dynamic = {fareverlyApiKey:key, transparency:41}; Reflect.setField(old, field, "old value");
            File.saveContent(root + "/config.json", Json.stringify(old)); config.fareverlyApiKey = key;
            check(FareverlyConfig.read(root + "/config.json") == "", "Uploader rejects old credentials even before cleanup is saved");
            check(FareverlyConfig.discardUnsupported(config, root + "/config.json") && config.fareverlyApiKey == "",
                "Rejected metadata format does not preserve or import its API key");
        }
        check(config.transparency == 41, "Removing unsupported credential state keeps unrelated settings");
        FareverlyConfig.apply(config, credential(), "");
        File.saveContent(root + "/config.json", Json.stringify(config));
        check(!FareverlyConfig.discardUnsupported(config, root + "/config.json") && config.fareverlyApiKey == key,
            "A new key-only config survives later startups");
        config.fareverlyApiKey = ""; File.saveContent(root + "/config.json", Json.stringify(config));
        check(FareverlyConfig.read(root + "/config.json") == "", "A cleared key stays cleared");
        File.saveContent(root + "/config.json", "{invalid secret-data"); var failed = false;
        try FareverlyConfig.read(root + "/config.json") catch (error:Dynamic) {failed = true; check(Std.string(error).indexOf("secret-data") < 0, "Invalid config error never echoes its contents");}
        check(failed, "Corrupt config fails safely");
        RecoveryTest.remove(root);
    }
}
