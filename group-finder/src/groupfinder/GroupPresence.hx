package groupfinder;
/** Completion-based scheduling; a rejected heartbeat never implies online status. */
class GroupPresence {
    public static function validServer(server:String):Bool return ["north-america","europe","latin-america","asia","mainland-china"].indexOf(server)>=0;
    public static function body(server:String,busy=false):String {
        if(!validServer(server))throw "Unknown game server";
        return haxe.Json.stringify({server:server,busy:busy});
    }
    public var next = 0.0;
    public var stopped = false;
    var failures = 0;
    /** Only an acknowledged heartbeat may extend the locally displayed presence. */
    public static function deadline(status:Int,body:String,error:String):Float {
        if(status!=200||error!="")return 0;
        try {
            var data:Dynamic=haxe.Json.parse(body),value:Dynamic=Reflect.field(data,"onlineUntil");
            if(Std.isOfType(value,String))return fareverly.Protocol.expiry(value);
        }catch(_:Dynamic){}
        return 0;
    }
    public function new() {}
    public function reset():Void { next=0; stopped=false; failures=0; }
    public function due(now:Float):Bool return !stopped && now>=next;
    public function completed(status:Int, now:Float, retry:Float, jitter:Float):Void {
        if (status==401 || status==403) { stopped=true; return; }
        if (status==200) { failures=0; next=now+Math.max(60,retry)+jitter; }
        else if (status==429) next=now+Math.max(60,retry)+jitter;
        else { failures++; next=now+Math.max(retry,Math.min(900,60*Math.pow(2,Math.min(failures-1,4))))+jitter; }
    }
}
