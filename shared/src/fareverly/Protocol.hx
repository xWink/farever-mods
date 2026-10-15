package fareverly;

import haxe.io.Bytes;

typedef Response = {status:Int, body:String, retryAfter:String, error:String};
typedef Transport = (String, String, Bytes, String)->Response;
typedef Credential = {accessToken:String, accountId:String, steamId:String, expiresAt:String};

class Protocol {
    public static inline var ORIGIN = "https://fareverly.com";
    public static function validKey(value:String):Bool return value != null && ~/^fv1_[A-Za-z0-9_-]{43}$/.match(value);
    public static function validAccount(value:String):Bool return value != null && ~/^[A-Za-z0-9:_-]{1,128}$/.match(value);
    public static function connectUrl(value:String):Bool
        return value != null && ~/^https:\/\/fareverly\.com\/connect\/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/.match(value);
    public static function browserUrl(value:String):Bool
        return value == ORIGIN + "/analyze" || value == ORIGIN + "/contact" || connectUrl(value) || localUrl(value);
    public static function localUrl(value:String):Bool {
        var pattern = ~/^https:\/\/fareverly\.com\/analyze#desktop=v1\.([0-9]{1,5})\.[a-f0-9]{64}$/;
        if (value == null || !pattern.match(value)) return false;
        var port = Std.parseInt(pattern.matched(1));
        return port != null && port >= 1024 && port <= 65535;
    }
    public static function base64url(bytes:Bytes):String
        return StringTools.replace(StringTools.replace(haxe.crypto.Base64.encode(bytes, false), "+", "-"), "/", "_");
    public static function challenge(verifier:String):String return base64url(haxe.crypto.Sha256.make(Bytes.ofString(verifier)));
    public static function empty():Credential return {accessToken:"", accountId:"", steamId:"", expiresAt:""};
    public static function expiry(value:String):Float {
        if (value == null || !~/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d{3})?Z$/.match(value)) return 0;
        try {
            var d = Date.fromString(value.substr(0, 10) + " " + value.substr(11, 8));
            return (d.getTime() - d.getTimezoneOffset() * 60000) / 1000;
        } catch (_:Dynamic) return 0;
    }
    public static function retryAfter(value:String, now:Float):Float {
        if (value == null) return 0;
        value = StringTools.trim(value);
        if (~/^[0-9]+$/.match(value)) { var n = Std.parseFloat(value); return Math.isFinite(n) ? n : 0; }
        var re = ~/^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$/;
        if (!re.match(value)) return 0;
        var month = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"].indexOf(re.matched(2));
        if (month < 0) return 0;
        try {
            var d = new Date(Std.parseInt(re.matched(3)), month, Std.parseInt(re.matched(1)), Std.parseInt(re.matched(4)), Std.parseInt(re.matched(5)), Std.parseInt(re.matched(6)));
            return Math.max(0, (d.getTime() - d.getTimezoneOffset() * 60000) / 1000 - now);
        } catch (_:Dynamic) return 0;
    }
    public static function error(code:String):String return switch (code) {
        case "already_linked": "This account is already linked. Choose Generate API key.";
        case "account_not_linked": "This account is not linked yet. Choose Generate API key.";
        case "account_conflict": "This Steam or Farever account is linked to another account. Contact Fareverly support.";
        case "account_mismatch": "The Fareverly key belongs to another Farever account. Contact Fareverly support.";
        case "already_consumed": "The key was already delivered. Choose Generate API key if it was not saved.";
        case "invalid_grant", "request_expired": "The sign-in request expired or is invalid. Start again.";
        case "access_denied": "Steam sign-in was declined.";
        case "invalid_request": "Fareverly rejected the sign-in request format. Please report this error.";
        case "unauthorized": "The Fareverly key is invalid, expired, or revoked. Choose Generate API key.";
        default: "Fareverly sign-in is unavailable. Please try again later.";
    }
}
