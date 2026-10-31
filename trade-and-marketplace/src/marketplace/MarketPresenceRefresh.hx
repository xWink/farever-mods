package marketplace;

import fareverly.Protocol;

/** Fresh server acknowledgements for peers, shared by their buy/sell rows.
    Scheduling uses monotonic time; onlineUntil remains server wall-clock time. */
class MarketPresenceRefresh {
    public static inline var INTERVAL=60.0;
    public var next=0.0;
    var failures=0;
    var peers:Map<String,{deadline:Float,checked:Float,busy:Bool}>=[];
    var missing:Map<String,Float>=[];
    public function new() {}
    static function text(value:Dynamic):String return Std.isOfType(value,String)?value:"";
    static function key(row:Dynamic):String {
        if(row==null||row.seller==null||!MarketPresence.validServer(text(row.server)))return "";
        var account=text(row.seller.accountId);
        return Protocol.validAccount(account)?row.server+"/"+account:"";
    }
    static function listingKey(row:Dynamic):String return row==null?"":text(row.server)+"/"+text(row.id);
    public function observe(data:Dynamic,now:Float):Void {
        if(data==null)return;
        var rows:Array<Dynamic>=Std.isOfType(data.listings,Array)?data.listings:[data];
        for(row in rows) {
            var id=key(row);
            if(id==""||!Std.isOfType(row.seller.online,Bool))continue;
            peers[id]={deadline:row.seller.online==true?Protocol.expiry(text(row.seller.onlineUntil)):0,checked:now,busy:row.seller.busy==true};
            missing.remove(listingKey(row));
        }
        // Query changes should not retain every player browsed this session.
        if(Lambda.count(peers)>512) {
            var keys=[for(id in peers.keys())id];keys.sort((a,b)->Reflect.compare(peers[b].checked,peers[a].checked));
            for(id in keys.slice(512))peers.remove(id);
        }
        for(id in [for(id=>until in missing)if(until<=now)id])missing.remove(id);
    }
    public function deadline(row:Dynamic):Null<Float> {
        var value=peers[key(row)];return value==null?null:value.deadline;
    }
    public function busy(row:Dynamic):Null<Bool> {
        var value=peers[key(row)];return value==null?null:value.busy;
    }
    public function due(row:Dynamic,now:Float):Bool {
        var id=key(row),until=missing[listingKey(row)];
        if(id==""||until!=null&&now<until)return false;
        var value=peers[id];return value==null||now>=value.checked+INTERVAL;
    }
    /** A removed listing says nothing about that player's other listings. */
    public function unavailable(row:Dynamic,now:Float):Void {
        for(id in [for(id=>until in missing)if(until<=now)id])missing.remove(id);
        missing[listingKey(row)]=now+INTERVAL;
    }
    public function completed(status:Int,retryAfter:String,now:Float,wall:Float):Void {
        if(status==200||status==404){failures=0;next=now+2;return;}
        failures++;
        next=now+Math.max(Protocol.retryAfter(retryAfter,wall),Math.min(900,60*Math.pow(2,Math.min(failures-1,4))));
    }
}
