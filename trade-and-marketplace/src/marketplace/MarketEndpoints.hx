package marketplace;
class MarketEndpoints {
    public static function validUrl(url:String):Bool {
        if (!StringTools.startsWith(url,fareverly.Protocol.ORIGIN+"/api/")) return false;
        var path=url.substr(fareverly.Protocol.ORIGIN.length).split("?")[0];
        return ["/api/v1/account","/api/v1/auth/device","/api/v1/auth/token","/api/v1/marketplace/heartbeat",
            "/api/v1/marketplace/listings","/api/v1/marketplace/presence"].indexOf(path)>=0
            || ~/^\/api\/v1\/marketplace\/listings\/[a-f0-9-]{36}$/.match(path);
    }
    public static function requiresKey(method:String,path:String):Bool
        return method!="GET"||path.indexOf("mine=true")>=0||path.split("?")[0]=="/api/v1/marketplace/presence";
}
