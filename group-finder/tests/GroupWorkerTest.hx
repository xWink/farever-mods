import groupfinder.GroupWorker;
import groupfinder.GroupHttp;
import groupfinder.GroupTransport;
import groupfinder.GroupProtocol;
import sys.thread.Lock;
class GroupWorkerTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function awaitEvent(w:GroupWorker,op:String):GroupEvent {
        var until=haxe.Timer.stamp()+4;
        while(haxe.Timer.stamp()<until){var e=w.receive();if(e!=null&&e.op==op)return e;Sys.sleep(.01);}throw "Missing event "+op;
    }
    static function awaitCall(method:String,suffix:String):Dynamic {
        var until=haxe.Timer.stamp()+4;
        while(haxe.Timer.stamp()<until){var c=GroupHttp.calls.pop(false);if(c!=null&&c.method==method&&StringTools.endsWith(c.url,suffix))return c;Sys.sleep(.01);}throw "Missing call "+method+suffix;
    }
    static function main():Void {
        var w=new GroupWorker(),key="fv1_"+StringTools.lpad("","a",43),id=w.session("self",key,"europe");
        check(awaitEvent(w,"ready").generation==id,"Required scopes and account verified");
        var heartbeat=awaitCall("POST","/heartbeat"),body=haxe.Json.parse(heartbeat.body);check(body.server=="europe"&&body.busy==false&&heartbeat.token==key,"Standalone heartbeat uses shared endpoint and hidden key");
        check(awaitEvent(w,"heartbeat-attempted").generation==id,"Shared heartbeat rate limit is quiet");
        w.send({generation:id,op:"request",ticket:1,method:"GET",path:GroupProtocol.BASE+"/listings?server=europe"});
        var e=awaitEvent(w,"request");check(e.ticket==1&&e.response.status==200,"Read authenticated after verification");
        var hold=new Lock();GroupHttp.holdCreate=hold;
        w.send({generation:id,op:"request",ticket:2,method:"POST",path:GroupProtocol.BASE+"/listings",body:'{"title":"test"}',headers:["Idempotency-Key"=>"00000000-0000-4000-8000-000000000002"]});
        awaitCall("POST","/listings");w.session("","","");hold.release();
        var cleanup=awaitCall("DELETE","/listings/00000000-0000-4000-8000-000000000001");
        check(cleanup.token==key,"Late create is closed with original credential after session change");
        check(w.receive()==null,"Late create does not reach the new client session");
        GroupHttp.scopes=["groups:read","marketplace:presence"];
        id=w.session("self",key,"europe");check(awaitEvent(w,"error").generation==id,"Missing write scope rejected");
        w.send({generation:id,op:"request",ticket:3,method:"GET",path:GroupProtocol.BASE+"/categories"});
        e=awaitEvent(w,"request");check(e.response.status==401,"Unverified key never sends API work");
        trace('Group Finder worker passed ($checks checks)');Sys.exit(0);
    }
}
