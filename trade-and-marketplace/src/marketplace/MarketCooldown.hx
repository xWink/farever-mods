package marketplace;

/** Match the API's separate read and listing-write quotas. */
class MarketCooldown {
    var deadlines:Map<String,Float>=[];
    public function new() {}
    public function clear():Void deadlines=[];
    static function scope(method:String,path:String):String {
        if(method!="GET")return "write";
        return "read";
    }
    public function remaining(method:String,path:String,now:Float):Int {
        var deadline=deadlines[scope(method,path)];
        return deadline==null?0:Std.int(Math.ceil(Math.max(0,deadline-now)));
    }
    public function record(method:String,path:String,status:Int,retryAfter:String,now:Float,wallTime:Float):Void {
        if(status!=429&&status<500)return;
        var delay=fareverly.Protocol.retryAfter(retryAfter,wallTime);
        if(delay<=0)delay=status==429&&method!="GET"?10:60;
        var bucket=scope(method,path),previous=deadlines[bucket];
        deadlines[bucket]=Math.max(previous==null?0:previous,now+delay);
    }
    public function message(method:String,path:String,now:Float):String {
        var seconds=remaining(method,path,now);
        return "Please wait "+seconds+" second"+(seconds==1?"":"s")+" before "+
            (method=="GET"?"loading listings again.":"creating, editing, or removing another listing.");
    }
}
