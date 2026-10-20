package marketplace;

/** Bounded diagnostics: never dump credentials, payloads, or query strings. */
class MarketApiLog {
    public static function redact(value:String,token=""):String {
        if(value==null)return "";
        if(token!="")value=StringTools.replace(value,token,"[redacted]");
        value=~/fv1_[A-Za-z0-9_-]+/g.replace(value,"[redacted]");
        value=~/Bearer\s+[^\s,;"']+/gi.replace(value,"Bearer [redacted]");
        value=~/https?:\/\/[^\s?]+\?[^\s]+/gi.replace(value,"[URL query omitted]");
        return StringTools.trim(~/[\x00-\x1f\x7f]+/g.replace(value," ")).substr(0,600);
    }
    static function field(object:Dynamic,name:String):String {
        var value=object==null?null:Reflect.field(object,name);
        return Std.isOfType(value,String)?value:"";
    }
    static function endpoint(url:String):String {
        var path=url.split("?")[0].split("#")[0];
        if(StringTools.startsWith(path,fareverly.Protocol.ORIGIN))path=path.substr(fareverly.Protocol.ORIGIN.length);
        return path;
    }
    public static function context(method:String,url:String,status:Int,reason:String,token=""):String {
        return "Marketplace API "+redact(method,token)+" "+redact(endpoint(url),token)+" HTTP "+Std.string(status)+": "+redact(reason,token);
    }
    public static function failure(method:String,url:String,response:fareverly.Protocol.Response,token="",requestId=""):String {
        if(response.status>=200&&response.status<300&&response.error=="")return "";
        if(response.error=="Session ended")return "";
        var data:Dynamic=null;
        try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
        var error=data==null?null:Reflect.field(data,"error");
        var code=Std.isOfType(error,String)?Std.string(error):field(error,"code");
        if(code!=""&&!~/^[A-Za-z][A-Za-z0-9_-]{0,63}$/.match(code))code="unrecognized_error";
        if(method=="POST"&&endpoint(url)=="/api/v1/marketplace/heartbeat"
            &&response.status==429&&code=="heartbeat_too_soon")return "";
        var auth=endpoint(url).indexOf("/api/v1/auth/")==0;
        if(auth&&(response.status==400||response.status==429)&&(code=="authorization_pending"||code=="slow_down"))return "";
        var parts:Array<String>=[];
        if(code!="")parts.push("code="+code);
        // Auth responses may contain one-time secrets; log only their error code.
        if(!auth) {
            var invalidField=field(error,"field");
            if(invalidField!="")parts.push("field="+invalidField);
            var message=field(error,"message");if(message=="")message=field(data,"message");
            if(message!="")parts.push(message);
        }
        if(response.error!="")parts.push("transport="+response.error);
        if(parts.length==0)parts.push(data==null?"Response was not valid JSON":"Request rejected");
        if(requestId!="")parts.push("requestId="+requestId);
        if(response.retryAfter!="")parts.push("retryAfter="+response.retryAfter);
        return context(method,url,response.status,parts.join("; "),token);
    }
    public static function unexpected(method:String,url:String,status:Int,reason:String,token=""):Void {
        trade.TradeDiagnostics.log(context(method,url,status,reason,token));
    }
}
