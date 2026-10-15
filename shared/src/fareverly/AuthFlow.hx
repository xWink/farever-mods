package fareverly;

import haxe.io.Bytes;
import fareverly.Protocol;

/** Worker-owned device authorization. No game objects, passwords, or secret URLs. */
class AuthFlow {
    public var active(default, null) = false;
    public var message(default, null) = "";
    public var userCode(default, null) = "";
    public var verificationUri(default, null) = "";
    public var credential(default, null):Credential;
    public var expiresAt(default, null):Float = 0;
    public var accountId(default, null) = "";
    final request:Transport;
    final clock:Void->Float;
    final random:Void->Float;
    var verifier = "";
    var deviceCode = "";
    var action = "link";
    var switchedAction = false;
    var nextRequest:Float = 0;
    var interval:Float = 5;
    var failures = 0;
    public function new(request:Transport, clock:Void->Float, ?random:Void->Float) {
        this.request = request; this.clock = clock; this.random = random == null ? Math.random : random;
    }
    public function begin(account:String, rotate:Bool, entropy:Bytes):Void {
        if (active) throw "Steam sign-in is already in progress.";
        if (!Protocol.validAccount(account) || entropy == null || entropy.length != 32) throw "A local Farever account and secure random verifier are required.";
        accountId = account; action = rotate ? "rotate" : "link"; switchedAction = false;
        verifier = Protocol.base64url(entropy); entropy.fill(0, entropy.length, 0);
        deviceCode = ""; userCode = ""; verificationUri = ""; credential = null;
        failures = 0; interval = 5; active = true; nextRequest = clock(); expiresAt = clock() + 600;
        message = "Preparing Steam sign-in...";
    }
    public function cancel():Void finish("Steam sign-in cancelled.");
    public function finish(text:String):Void {
        active = false; message = text; verifier = ""; deviceCode = ""; verificationUri = ""; userCode = "";
    }
    public function clearCredential():Void credential = null;
    public function step():Void {
        if (!active) return;
        var now = clock();
        if (now >= expiresAt) { finish("Steam sign-in expired. Start again."); return; }
        if (now < nextRequest) return;
        var starting = deviceCode == "";
        var body:Dynamic = starting ? {account_id:accountId, action:action, code_challenge:Protocol.challenge(verifier), code_challenge_method:"S256"}
            : {device_code:deviceCode, code_verifier:verifier};
        var response:Response;
        var bytes = Bytes.ofString(haxe.Json.stringify(body));
        try response = request("POST", Protocol.ORIGIN + (starting ? "/api/v1/auth/device" : "/api/v1/auth/token"), bytes, "")
        catch (_:Dynamic) response = {status:0, body:"", retryAfter:"", error:"Network error"};
        bytes.fill(0, bytes.length, 0); body = null;
        if (!active) return;
        now = clock();
        if (now >= expiresAt) { finish("Steam sign-in expired. Start again."); return; }
        var data:Dynamic = null; try data = haxe.Json.parse(response.body) catch (_:Dynamic) {}
        response.body = "";
        if (response.status == 201 && starting && response.error == "") {
            if (data == null || !Std.isOfType(data.device_code, String) || !~/^[A-Za-z0-9_-]{43}$/.match(data.device_code)
                || !Std.isOfType(data.user_code, String) || !~/^[A-Z0-9]{4}-[A-Z0-9]{4}$/.match(data.user_code)
                || !Std.isOfType(data.verification_uri, String) || !Protocol.connectUrl(data.verification_uri)
                || !number(data.expires_in) || data.expires_in <= 0 || !number(data.interval) || data.interval < 5) {
                finish("Fareverly returned an unsupported sign-in response. Please report this error."); return;
            }
            deviceCode = data.device_code; userCode = data.user_code; verificationUri = data.verification_uri;
            expiresAt = Math.min(expiresAt, now + data.expires_in); interval = Math.max(5, data.interval);
            nextRequest = now + Math.max(interval, Protocol.retryAfter(response.retryAfter, now));
            message = "Match this code in your browser, then approve Steam sign-in.";
            return;
        }
        if (!starting && response.status == 202 && response.error == "" && data != null && data.status == "authorization_pending") {
            nextRequest = now + Math.max(interval, Protocol.retryAfter(response.retryAfter, now)); return;
        }
        if (!starting && response.status == 200 && response.error == "" && data != null && data.status == "complete") {
            if (data.account_id != accountId) { finish(Protocol.error("account_mismatch")); return; }
            if (!Std.isOfType(data.access_token, String) || !Protocol.validKey(data.access_token) || data.token_type != "Bearer"
                || !Std.isOfType(data.steam_id, String) || !~/^[0-9]{17}$/.match(data.steam_id)
                || !Std.isOfType(data.expires_at, String) || Protocol.expiry(data.expires_at) <= now
                || !Std.isOfType(data.scope, String) || (cast data.scope:String).split(" ").indexOf("logs:upload") < 0
                || (cast data.scope:String).split(" ").indexOf("account:read") < 0) {
                finish("Fareverly returned an unsupported key response. Generate a new key and report this error."); return;
            }
            credential = {accessToken:data.access_token, accountId:data.account_id, steamId:data.steam_id, expiresAt:data.expires_at};
            finish("Steam sign-in approved. Saving your key..."); return;
        }
        // One Generate Key action covers first signup and replacement of a lost
        // key. Both still require a fresh Steam approval; no key is changed here.
        if (starting && response.status == 409 && !switchedAction && data != null
            && ((action == "link" && data.error == "already_linked") || (action == "rotate" && data.error == "account_not_linked"))) {
            action = action == "link" ? "rotate" : "link"; switchedAction = true;
            nextRequest = now + Math.max(5, Protocol.retryAfter(response.retryAfter, now)); return;
        }
        if (response.status == 0 || response.status == 429 || response.status >= 500) {
            failures++;
            if (failures >= 4) { finish("Steam sign-in stopped after repeated connection failures. Try again later."); return; }
            var floor = response.status == 429 ? (data != null && data.error == "slow_down" ? 5 : 60) : 5;
            nextRequest = now + Math.max(Protocol.retryAfter(response.retryAfter, now), Math.max(floor, Math.pow(2, failures - 1) * 5 + random() * 3));
            message = "Waiting before retrying Steam sign-in..."; return;
        }
        finish(Protocol.error(data != null && Std.isOfType(data.error, String) ? data.error : ""));
    }
    static function number(value:Dynamic):Bool return (Std.isOfType(value, Int) || Std.isOfType(value, Float)) && Math.isFinite(value);
}
