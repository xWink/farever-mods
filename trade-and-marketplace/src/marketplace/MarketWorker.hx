package marketplace;
import fareverly.Protocol;
import haxe.io.Bytes;
import sys.thread.Deque;
import sys.thread.Mutex;
import sys.thread.Thread;
typedef MarketJob={generation:Int,op:String,?ticket:Int,?account:String,?server:String,?key:String,?method:String,?path:String,?body:String,?headers:Map<String,String>,?entropy:Bytes};
typedef MarketEvent={generation:Int,op:String,?ticket:Int,?response:Response,?message:String,?url:String,?code:String,?credential:Credential,?expectedKey:String,?onlineUntil:Float,?server:String};
/** Foreground work takes priority over one background listing batch; presence/auth share the worker. Native objects never leave the game thread. */
class MarketWorker {
    final jobs=new Deque<MarketJob>();
    final events=new Deque<MarketEvent>();
    final background=new Deque<MarketJob>();
    final presenceReads=new Deque<MarketJob>();
    var presenceTicket=-1;
    var prefetchTicket=-1;
    final mutex=new Mutex();
    var generation=0;
    var started=false;
    public function new() {}
    public function session(account:String,key:String,server=""):Int {
        mutex.acquire(); var id=++generation; mutex.release();
        if (!started) { started=true; Thread.create(run); }
        jobs.add({generation:id,op:"session",account:account,key:key,server:server}); return id;
    }
    public function cancelPrefetch():Void {
        mutex.acquire();prefetchTicket=-1;mutex.release();
        while(background.pop(false)!=null){}
    }
    public function send(job:MarketJob):Void {
        if(job.op=="prefetch") {
            mutex.acquire();prefetchTicket=job.ticket;mutex.release();background.add(job);
        } else if(job.op=="presence-read") {
            mutex.acquire();presenceTicket=job.ticket;mutex.release();presenceReads.add(job);
        } else jobs.add(job);
    }
    public function cancelPresenceRead():Void {
        mutex.acquire();presenceTicket=-1;mutex.release();
        while(presenceReads.pop(false)!=null){}
    }
    function wanted(job:MarketJob):Bool {
        mutex.acquire();var yes=job.ticket==(job.op=="presence-read"?presenceTicket:prefetchTicket);mutex.release();return yes;
    }
    public function receive():MarketEvent return events.pop(false);
    function current(id:Int):Bool { mutex.acquire();var yes=id==generation;mutex.release();return yes; }
    function run():Void {
        var id=0,account="",server="",presenceAccount="",key="",verified=false,verifyAt=0.0,verifyFailures=0;
        var presence=new MarketPresence(),opened="",message="",verifyRequested=false;
        var http=new MarketHttp(()->{if(!current(id))throw "Session ended";});
        var auth=new fareverly.AuthFlow((m,u,b,k)->http.authenticated(m,u,b,k),()->Date.now().getTime()/1000);
        while(true) {
            var job=jobs.pop(account=="");
            if(job==null)job=background.pop(false);
            if(job==null)job=presenceReads.pop(false);
            if(job!=null&&(job.op=="prefetch"||job.op=="presence-read")&&!wanted(job))job=null;
            if(job!=null && current(job.generation)) try {
                if(job.op=="session") {
                    id=job.generation; account=job.account; server=job.server; key=job.key; verified=false;verifyAt=0;verifyFailures=0;
                    auth.cancel();presence.stopped=false;verifyRequested=false;
                    if(account!=""&&account!=presenceAccount){presence.reset();presenceAccount=account;}
                    opened="";message="";
                } else if(job.generation==id) switch(job.op) {
                    case "auth":
                        auth.begin(account,key!="",job.entropy);opened="";message="";
                    case "cancel-auth": auth.cancel();
                    case "verify":
                        if(Math.isFinite(verifyAt)&&verifyAt>Date.now().getTime()/1000)
                            events.add({generation:id,op:"verification",message:"Fareverly is temporarily unavailable. Please wait before verifying again."});
                        else {verifyRequested=true;verifyAt=0;}
                    case "request","prefetch","presence-read":
                        var needsKey=job.method!="GET" || job.path.indexOf("mine=true")>=0;
                        var response:Response=needsKey&&!verified?{status:401,body:'{"error":"sign_in_required"}',retryAfter:"",error:""}:
                            http.authenticated(job.method,Protocol.ORIGIN+job.path,job.body==null?null:Bytes.ofString(job.body),needsKey?key:"",job.headers);
                        if(needsKey&&!verified)MarketApiLog.unexpected(job.method,job.path,401,"Account verification required",key);
                        if(current(id))events.add({generation:id,op:job.op,ticket:job.ticket,response:response});
                    default:
                }
            } catch(e:Dynamic) { if(current(id)) {
                MarketApiLog.unexpected(job.method==null?job.op:job.method,job.path==null?"/api/v1/auth/":job.path,0,"Worker failure: "+Std.string(e),key);
                events.add({generation:id,op:job.op=="request"||job.op=="prefetch"||job.op=="presence-read"?job.op:job.op=="auth"?"auth-end":"connection-error",ticket:job.ticket,message:"Could not complete the marketplace request. Try again.",response:{status:0,body:"",error:"Request failed",retryAfter:""}});
            } }
            if(!current(id)||account=="") { Sys.sleep(0.1);continue; }
            var now=Date.now().getTime()/1000;
            if(auth.active) {
                try auth.step() catch(_:Dynamic) {
                    MarketApiLog.unexpected("AUTH","/api/v1/auth/",0,"Could not process sign-in response");
                    auth.finish("Could not complete Steam sign-in. Try again.");
                }
                if(!current(id)){auth.cancel();continue;}
                if(auth.verificationUri!="" && auth.verificationUri!=opened) {
                    opened=auth.verificationUri;
                    try MarketNative.open(opened) catch(_:Dynamic) auth.finish("Could not open the browser. Try signing in again.");
                }
                if(message!=auth.message) { message=auth.message;events.add({generation:id,op:auth.active?"auth":"auth-end",message:message,code:auth.userCode}); }
                if(auth.credential!=null) {events.add({generation:id,op:"credential",credential:auth.credential,expectedKey:key});auth.clearCredential();}
            } else if(Protocol.validKey(key) && (!verified||verifyRequested) && now>=verifyAt) {
                var response=http.authenticated("GET",Protocol.ORIGIN+"/api/v1/account",null,key);
                if(!current(id))continue;
                var data:Dynamic=null;try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
                var scopes:Array<String>=data!=null&&Std.isOfType(data.scopes,Array)?data.scopes:[];
                if(response.status==200 && response.error=="" && data!=null && data.account_id==account && scopes.indexOf("marketplace:write")>=0 && scopes.indexOf("marketplace:presence")>=0) {
                    verified=true;verifyFailures=0;verifyAt=0;events.add({generation:id,op:"ready",message:Protocol.CONNECTED});
                    if(verifyRequested)events.add({generation:id,op:"verification",message:Protocol.CONNECTED});
                } else if(response.status==401||response.status==403||response.status==200) {
                    if(response.status==200)MarketApiLog.unexpected("GET","/api/v1/account",200,
                        data==null?"Expected a JSON account response":data.account_id!=account?"API key belongs to a different account":"Missing marketplace:write or marketplace:presence scope",key);
                    verified=false;verifyAt=Math.POSITIVE_INFINITY;events.add({generation:id,op:"error",message:Protocol.LOGIN_REQUIRED});
                    if(verifyRequested)events.add({generation:id,op:"verification",message:Protocol.LOGIN_REQUIRED});
                } else { verifyFailures++;
                    if(verifyFailures==1)events.add({generation:id,op:"connection-error",message:MarketText.TEMPORARY_ERROR});
                    if(verifyRequested)events.add({generation:id,op:"verification",message:"Could not verify Fareverly connection. Try again later."});
                    verifyAt=now+Math.max(Protocol.retryAfter(response.retryAfter,now),Math.min(900,60*Math.pow(2,Math.min(verifyFailures-1,4)))); }
                verifyRequested=false;
            } else if(verified && MarketPresence.validServer(server) && presence.due(now)) {
                var response=http.authenticated("POST",Protocol.ORIGIN+"/api/v1/marketplace/heartbeat",Bytes.ofString(MarketPresence.body(server)),key);
                if(!current(id))continue;
                var completed=Date.now().getTime()/1000;
                var deadline=MarketPresence.deadline(response.status,response.body,response.error);
                if(deadline>completed)events.add({generation:id,op:"presence",onlineUntil:deadline,server:server});
                presence.completed(response.status,completed,Protocol.retryAfter(response.retryAfter,completed),Math.random()*5);
                if(presence.stopped) {verified=false;verifyAt=Math.POSITIVE_INFINITY;events.add({generation:id,op:"error",message:"Fareverly sign-in expired. Sign in again to list items."});}
            }
            Sys.sleep(0.1);
        }
    }
}
