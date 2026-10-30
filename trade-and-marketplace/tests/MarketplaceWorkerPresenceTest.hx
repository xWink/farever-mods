import marketplace.MarketWorker;
import marketplace.MarketHttp;
import marketplace.MarketTradePresence;
import fareverly.Protocol;
import sys.thread.Lock;

class MarketplaceWorkerPresenceTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function event(worker:MarketWorker,op:String):MarketEvent {
        var until=haxe.Timer.stamp()+5;
        while(haxe.Timer.stamp()<until) {
            var e=worker.receive();if(e!=null&&e.op==op)return e;Sys.sleep(.01);
        }
        throw "Worker event timed out: "+op;
    }
    static function call():Dynamic {
        var until=haxe.Timer.stamp()+5;
        while(haxe.Timer.stamp()<until) {
            var c=MarketHttp.calls.pop(false);if(c!=null)return c;Sys.sleep(.01);
        }
        throw "Worker HTTP call timed out";
    }
    static function main():Void {
        var worker=new MarketWorker(),key="fv1_"+StringTools.rpad("x","x",43);
        var generation=worker.session("sender",key,"europe");
        event(worker,"ready");event(worker,"presence");
        var account=call(),heartbeat=call();
        check(account.method=="GET"&&account.url==Protocol.ORIGIN+"/api/v1/account"&&account.token==key,"Worker first verifies the sender credential");
        check(heartbeat.method=="POST"&&heartbeat.url==Protocol.ORIGIN+"/api/v1/marketplace/heartbeat"&&heartbeat.token==key
            &&haxe.Json.parse(heartbeat.body).server=="europe","A signed-in session sends a heartbeat without listing activity or an open marketplace");
        var path=MarketTradePresence.path("peer:ABC","europe");
        worker.send({generation:generation,op:"trade-presence",ticket:1,method:"GET",path:path});
        var result=event(worker,"trade-presence"),lookup=call();
        check(lookup.method=="GET"&&lookup.url==Protocol.ORIGIN+path&&lookup.token==key&&lookup.body==null,"Presence GET uses the existing bearer key, exact receiver and connected server");
        check(result.ticket==1&&result.generation==generation&&result.response.body=='{"online":true}',"Worker preserves response ticket and session generation");
        // Hold an in-flight read so the next read is deterministically cancelled
        // before the worker can send it to Fareverly.
        var hold=new Lock();MarketHttp.holdPresence=hold;
        worker.send({generation:generation,op:"trade-presence",ticket:2,method:"GET",path:path});call();
        worker.send({generation:generation,op:"trade-presence",ticket:3,method:"GET",path:path});
        worker.cancelTradePresence();hold.release();event(worker,"trade-presence");
        Sys.sleep(.25);
        check(MarketHttp.calls.pop(false)==null&&worker.receive()==null,"Cancelled queued checks never reach HTTP");
        MarketHttp.response={status:403,body:'{"error":"insufficient_scope"}',error:"HTTP 403",retryAfter:""};
        worker.send({generation:generation,op:"trade-presence",ticket:4,method:"GET",path:path});
        result=event(worker,"trade-presence");call();check(result.response.status==403,"Authorization errors are delivered to the game thread");
        worker.send({generation:generation,op:"trade-presence",ticket:5,method:"GET",path:path});
        result=event(worker,"trade-presence");
        check(result.response.status==401&&MarketHttp.calls.pop(false)==null,"Revoked permission stops HTTP retries and heartbeat authorization");
        worker.session("","");
        Sys.println('Marketplace worker presence checks passed: $checks');
    }
}
