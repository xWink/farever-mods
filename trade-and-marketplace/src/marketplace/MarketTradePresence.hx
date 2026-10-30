package marketplace;

import fareverly.Protocol;

/** A fresh, authenticated lookup per trade attempt; never cache an online answer. */
class MarketTradePresence {
    public static inline var OFFLINE="This player does not have the Trade and Marketplace mod or is not signed into Fareverly.";
    public static inline var FAILED="Could not verify this player's Fareverly connection. Please try again later.";
    public static inline var LOGIN="Sign into Fareverly in the Trade and Marketplace settings before sending a trade request.";
    public var next=0.0;
    public var blocked=false;
    public function new() {}

    public static function path(account:String,server:String):Null<String> {
        if(account==null||!~/^[A-Za-z0-9:_-]{1,128}$/.match(account)||!MarketPresence.validServer(server))return null;
        return "/api/v1/marketplace/presence?accountId="+StringTools.urlEncode(account)+"&server="+StringTools.urlEncode(server);
    }
    public function unavailable(now:Float):String {
        if(blocked)return LOGIN;
        var seconds=Std.int(Math.ceil(Math.max(0,next-now)));
        return seconds==0?"":"Please wait "+seconds+" second"+(seconds==1?"":"s")+" before checking another trade request.";
    }
    public function completed(response:Response,now:Float,wall:Float):{online:Bool,message:String} {
        if(response.status==200&&response.error=="")try {
            var data:Dynamic=haxe.Json.parse(response.body),online:Dynamic=Reflect.field(data,"online");
            if(Std.isOfType(online,Bool))return {online:online,message:online?"":OFFLINE};
        }catch(_:Dynamic){}
        var retry=Protocol.retryAfter(response.retryAfter,wall);
        if(response.status==401||response.status==403)blocked=true;
        // Separate from listing quotas. Even a cancelled lookup may have used
        // this endpoint's quota, so its response still updates the cooldown.
        next=Math.max(next,now+(retry>0?retry:response.status==429||response.status>=500?60:5));
        return {online:false,message:blocked?LOGIN:FAILED};
    }
}
