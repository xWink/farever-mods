package groupfinder;

import fareverly.Protocol;
import groupfinder.GroupTransport;
import haxe.io.Bytes;
import sys.thread.Deque;
import sys.thread.Mutex;
import sys.thread.Thread;

/** HTTP, TLS and auth run off the game thread. No native game object crosses this boundary. */
class GroupWorker implements GroupTransport {
    final jobs=new Deque<GroupJob>();
    final events=new Deque<GroupEvent>();
    final mutex=new Mutex();
    var generation=0;
    var started=false;
    public function new() {}
    public function session(account:String,key:String,server:String):Int {
        mutex.acquire();var id=++generation;mutex.release();
        if(!started){started=true;Thread.create(run);}
        send({generation:id,op:"session",account:account,key:key,server:server});return id;
    }
    public function send(job:GroupJob):Void jobs.add(job);
    public function receive():Null<GroupEvent> return events.pop(false);
    function current(id:Int):Bool {mutex.acquire();var yes=id==generation;mutex.release();return yes;}
    function run():Void {
        var id=0,account="",key="",server="",verified=false,verifyAt=0.,verifyFailures=0,verifyRequested=false;
        var presence=new GroupPresence(),presenceAccount="",opened="",lastMessage="";
        var http=new GroupHttp(()->{});
        var auth=new fareverly.AuthFlow((m,u,b,k)->http.authenticated(m,u,b,k),()->Date.now().getTime()/1000);
        var cleanup:Array<{job:GroupJob,at:Float,until:Float}>=[];
        while(true) {
            var now=Date.now().getTime()/1000,job=jobs.pop(false);
            if(job!=null)try {
                if(job.op=="cleanup")cleanup.push({job:job,at:now,until:now+86400});
                else if(current(job.generation)) {
                    if(job.op=="session") {
                        id=job.generation;account=job.account;key=job.key;server=job.server;verified=false;verifyAt=0;verifyFailures=0;verifyRequested=false;
                        auth.cancel();opened="";lastMessage="";presence.stopped=false;
                        if(presenceAccount!=account){presence.reset();presenceAccount=account;}
                    } else switch(job.op) {
                        case "auth": auth.begin(account,key!="",job.entropy);opened="";lastMessage="";
                        case "cancel-auth":auth.cancel();
                        case "verify":
                            if(Math.isFinite(verifyAt)&&verifyAt>now)events.add({generation:id,op:"verification",message:"Fareverly is temporarily unavailable. Please try again shortly."});
                            else {verifyRequested=true;verifyAt=0;}
                        case "request":
                            var publicBadges=job.method=="POST"&&job.path==GroupProtocol.BADGES;
                            var response:Response=verified||publicBadges?http.authenticated(job.method,Protocol.ORIGIN+job.path,job.body==null?null:Bytes.ofString(job.body),publicBadges?"":key,job.headers)
                                :{status:401,body:"",retryAfter:"",error:""};
                            if(current(id))events.add({generation:id,op:"request",ticket:job.ticket,response:response});
                            else if(job.method=="POST"&&job.path==GroupProtocol.BASE+"/listings") {
                                // Consume late create responses, even after logout/region/character changes.
                                // An uncertain response is replayed with its ORIGINAL idempotency key solely to close it.
                                var listingId="";try {var d:Dynamic=haxe.Json.parse(response.body);if(GroupProtocol.uuid(d.id))listingId=d.id;}catch(_:Dynamic){}
                                if(listingId!=""||response.status==0||response.status>=500)
                                    cleanup.push({job:{generation:id,op:"cleanup",key:key,method:listingId==""?"POST":"DELETE",
                                        path:listingId==""?job.path:GroupProtocol.BASE+"/listings/"+listingId,body:listingId==""?job.body:null,headers:job.headers},at:now,until:now+86400});
                            }
                        default:
                    }
                }
            } catch(_:Dynamic) {
                if(job!=null&&current(job.generation))events.add({generation:job.generation,op:job.op=="request"?"request":"error",ticket:job.ticket,
                    message:"Could not complete the Fareverly request. Please try again.",response:{status:0,body:"",retryAfter:"",error:"Request failed"}});
            }
            // Cleanup is authenticated with the original key and is never attached to a newer session.
            for(task in cleanup.copy())if(now>=task.at) {
                if(now>=task.until){cleanup.remove(task);continue;}
                var j=task.job,r=http.authenticated(j.method==null?"DELETE":j.method,Protocol.ORIGIN+j.path,j.body==null?null:Bytes.ofString(j.body),j.key,j.headers);
                if(j.method=="POST"&&r.status>=200&&r.status<300) {
                    try {var d:Dynamic=haxe.Json.parse(r.body);if(GroupProtocol.uuid(d.id)){j.method="DELETE";j.path=GroupProtocol.BASE+"/listings/"+d.id;j.body=null;j.headers=null;}}catch(_:Dynamic){}
                } else if(r.status==204||r.status==404||r.status==410||r.status==401||r.status==403){cleanup.remove(task);continue;}
                task.at=now+Math.max(5,Protocol.retryAfter(r.retryAfter,now));break;
            }
            if(current(id)&&account!="")try {
                if(auth.active) {
                    auth.step();
                    if(!current(id)){auth.cancel();continue;}
                    if(auth.verificationUri!=""&&opened!=auth.verificationUri) {
                        opened=auth.verificationUri;
                        try GroupNative.open(opened)catch(_:Dynamic)auth.finish("Could not open the browser. Try signing in again.");
                    }
                    if(lastMessage!=auth.message&&auth.credential==null) {
                        lastMessage=auth.message;events.add({generation:id,op:auth.active?"auth":"auth-end",message:lastMessage,code:auth.userCode});
                    }
                    if(auth.credential!=null){events.add({generation:id,op:"credential",credential:auth.credential,expectedKey:key});auth.clearCredential();}
                } else if(Protocol.validKey(key)&&(!verified||verifyRequested)&&now>=verifyAt) {
                    var r=http.authenticated("GET",Protocol.ORIGIN+"/api/v1/account",null,key),data:Dynamic=null;
                    if(!current(id))continue;
                    try data=haxe.Json.parse(r.body)catch(_:Dynamic){}
                    var scopes:Array<String>=data!=null&&Std.isOfType(data.scopes,Array)?data.scopes:[];
                    if(r.status==200&&r.error==""&&data!=null&&data.account_id==account
                        &&scopes.indexOf("groups:read")>=0&&scopes.indexOf("groups:write")>=0&&scopes.indexOf("marketplace:presence")>=0) {
                        verified=true;verifyAt=0;verifyFailures=0;events.add({generation:id,op:"ready"});
                        if(verifyRequested)events.add({generation:id,op:"verification",message:Protocol.CONNECTED});
                    } else if(r.status==401||r.status==403||r.status==200) {
                        verified=false;verifyAt=Math.POSITIVE_INFINITY;events.add({generation:id,op:"error",message:Protocol.LOGIN_REQUIRED});
                        if(verifyRequested)events.add({generation:id,op:"verification",message:Protocol.LOGIN_REQUIRED});
                    } else {
                        verifyAt=now+Math.max(Protocol.retryAfter(r.retryAfter,now),Math.min(900,30*Math.pow(2,Math.min(verifyFailures++,5))));
                        events.add({generation:id,op:verifyRequested?"verification":"connection-error",message:GroupProtocol.error(r)});
                    }
                    verifyRequested=false;
                } else if(verified&&GroupPresence.validServer(server)&&presence.due(now)) {
                    var r=http.authenticated("POST",Protocol.ORIGIN+"/api/v1/marketplace/heartbeat",Bytes.ofString(GroupPresence.body(server,fareverly.PresenceConfig.busy())),key);
                    if(!current(id))continue;
                    var completed=Date.now().getTime()/1000;
                    presence.completed(r.status,completed,Protocol.retryAfter(r.retryAfter,completed),Math.random()*5);
                    // A 429 does NOT prove presence on this region. Creation still has to pass the API's presence check.
                    if(r.status==200||r.status==429)events.add({generation:id,op:"heartbeat-attempted"});
                    if(presence.stopped){verified=false;verifyAt=Math.POSITIVE_INFINITY;events.add({generation:id,op:"error",message:Protocol.LOGIN_REQUIRED});}
                }
            }catch(_:Dynamic){verifyAt=now+60;auth.cancel();events.add({generation:id,op:"error",message:"Could not complete the Fareverly connection. Please try again."});}
            Sys.sleep(0.1);
        }
    }
}
