import groupfinder.GroupTypes;
import groupfinder.GroupTransport;
import groupfinder.GroupApi;
import groupfinder.GroupProtocol as P;
import groupfinder.GroupPresence;
import groupfinder.GroupWire;
import groupfinder.GroupRequests;
import fareverly.Protocol;

class FakeGroups implements GroupTransport {
    public var generation=0;
    public var jobs:Array<GroupJob>=[];
    public var events:Array<GroupEvent>=[];
    public function new() {}
    public function session(a:String,k:String,s:String):Int return ++generation;
    public function send(j:GroupJob):Void jobs.push(j);
    public function receive():Null<GroupEvent> return events.shift();
    public function event(op:String):Void events.push({generation:generation,op:op});
    public function take(method:String,part:String):GroupJob {
        for(j in jobs)if(j.op=="request"&&j.method==method&&j.path.indexOf(part)>=0){jobs.remove(j);return j;}
        throw 'Missing $method $part: '+haxe.Json.stringify(jobs);
    }
    public function reply(j:GroupJob,data:Dynamic,status=200,retry=""):Void events.push({generation:j.generation,op:"request",ticket:j.ticket,
        response:{status:status,body:data==null?"":haxe.Json.stringify(data),retryAfter:retry,error:""}});
}

class GroupApiTest {
    static var checks=0;
    static var time=0.;
    static inline var ID="00000000-0000-4000-8000-000000000001";
    static inline var ID2="00000000-0000-4000-8000-000000000002";
    static final KEY="fv1_"+StringTools.lpad("","a",43);
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function eq(a:Dynamic,b:Dynamic,why:String):Void check(haxe.Json.stringify(a)==haxe.Json.stringify(b),why+': '+haxe.Json.stringify(a)+' != '+haxe.Json.stringify(b));
    static function party():GroupParty return {accountId:"self",leaderId:"self",partyId:"solo-self",region:"europe",members:[{accountId:"self",name:"Wink",className:"",level:0,badge:"supporter-gold"}]};
    static function row(id=ID,owner="self",revision=1):Dynamic return {id:id,revision:revision,leaderAccountId:owner,partyId:"solo-"+owner,
        server:"europe",category:"dungeons",subcategory:"dungeons",title:"Heroic runs",members:[{accountId:owner,name:"Wink",className:null,level:null,badge:"supporter-gold"}],
        capacity:4,createdAt:"2026-10-30T00:00:00.000Z",updatedAt:"2026-10-30T00:00:00.000Z",onlineUntil:"2099-01-01T00:00:00.000Z"};
    static function metadata():Dynamic return {categories:[for(id in ["dungeons","world-events","other"]){id:id,name:P.categoryName(id),subcategories:[{id:id,name:P.categoryName(id)}]}],capacity:4,maxTitleLength:50,requestTimeoutSeconds:300};
    static function tick(a:GroupApi,step=0.01):Void {time+=step;a.tick(time);}
    static function setup():{a:GroupApi,w:FakeGroups} {
        time=0;var w=new FakeGroups(),a=new GroupApi(w);a.random=()->haxe.io.Bytes.ofHex("00112233445566778899aabbccddeeff00");a.connect(party(),KEY);
        w.event("ready");w.event("heartbeat-attempted");tick(a);
        w.reply(w.take("GET","categories"),metadata());w.reply(w.take("GET","mine"),{listing:null});tick(a);
        check(a.available()=="","Verified session with metadata and mine becomes usable");return {a:a,w:w};
    }
    static function save(f:{a:GroupApi,w:FakeGroups},?done:GroupResult<GroupListing>->Void):GroupJob {
        f.a.save(party(),null,"Heroic runs","Dungeons",done==null?(_)->{}:done);return f.w.take("POST","listings");
    }
    static function main():Void {
        var p=party(),body:Dynamic=haxe.Json.parse(P.payload(p,"  Heroic runs  ","dungeons","dungeons"));
        eq(Reflect.fields(body).length,7,"Only documented listing fields");eq(body.title,"Heroic runs","Trim title");
        eq(body.members[0].className,null,"Unknown class normalized to null");eq(body.members[0].level,null,"Unknown level normalized to null");
        check(!Reflect.hasField(body.members[0],"badge")&&!Reflect.hasField(body,"accountId"),"No client badge or owner fields");
        check(P.uuid(P.newId(haxe.io.Bytes.alloc(32))),"Version-4 UUID idempotency token");
        check(P.validUrl(Protocol.ORIGIN+P.BASE+"/listings/"+ID+"/party"),"Party route allowed");
        for(url in ["https://evil.test/api/v1/account",Protocol.ORIGIN+".evil.test/api/v1/account",Protocol.ORIGIN+P.BASE+"/unknown"])check(!P.validUrl(url),"Credentials cannot leave approved API endpoints");
        var parsed=P.listing(row());check(parsed.members[0].className==""&&parsed.members[0].level==0,"Null API member data displays as unknown");eq(parsed.members[0].badge,"supporter-gold","Server badge retained");
        var bad=row();bad.members.push(bad.members[0]);var rejected=false;try P.listing(bad)catch(_:Dynamic)rejected=true;check(rejected,"Duplicate roster IDs rejected");
        var f=setup(),a=f.a,w=f.w,result:GroupResult<Array<GroupListing>>=null;
        a.accept=r->r.ownerId!="ignored";a.list("europe",r->result=r);
        var first=w.take("GET","?server=europe&category=dungeons&limit=24");w.reply(first,{listings:[row(ID,"ignored")],nextCursor:"opaque+/=",categoryCounts:{dungeons:8,other:2,"world-events":1}});tick(a);
        check(result==null,"An entirely ignored page consumes the next page");var second=w.take("GET","cursor=opaque%2B%2F%3D");
        w.reply(second,{listings:[row(ID2,"peer")],nextCursor:null,categoryCounts:{dungeons:8,other:2,"world-events":1}});tick(a);
        check(result.error==""&&result.value.length==2,"Fetched data preserved for unignore");eq(a.categoryCount("Dungeons"),8,"Counts remain server totals");
        a.list("europe",r->result=r);var stale=w.take("GET","listings?");a.resetBrowse();result=null;w.reply(stale,{listings:[row()],nextCursor:null,categoryCounts:{}});tick(a);check(result==null,"Old category page cannot overwrite new navigation");
        f=setup();a=f.a;w=f.w;var saved:GroupResult<GroupListing>=null,j=save(f,r->saved=r),token=j.headers["Idempotency-Key"];
        w.reply(j,null,0);tick(a);check(saved.error!=""&&a.own==null,"Lost response remains an error");
        tick(a,20);var retry=save(f,r->saved=r);eq(retry.headers["Idempotency-Key"],token,"Lost create response reuses its idempotency key");eq(retry.body,j.body,"Lost create response reuses exact payload");
        w.reply(retry,{id:ID,revision:1,closed:false,replayed:true});tick(a);check(saved.error==""&&a.own.id==ID,"Replayed create adopts returned ID");
        var mine=w.take("GET","mine");w.reply(mine,{listing:row()});tick(a);
        var changed=party();changed.members[0].level=26;a.observe(changed);tick(a,1.1);
        var patch=w.take("PATCH","/party");eq(patch.headers["If-Match"],'"1"',"Party PATCH uses current revision");eq(Reflect.fields(haxe.Json.parse(patch.body)).length,4,"Party PATCH excludes title/category");
        changed.members[0].level=27;a.observe(changed);tick(a,0.1);check(w.jobs.filter(j->j.method=="PATCH").length==0,"Roster bursts coalesce behind one in-flight write");
        w.reply(patch,{id:ID,revision:2,closed:false});tick(a);mine=w.take("GET","mine");var row2=row(ID,"self",2);row2.members[0].level=26;w.reply(mine,{listing:row2});tick(a);
        tick(a,1.1);patch=w.take("PATCH","/party");eq(patch.headers["If-Match"],'"2"',"Next roster update uses acknowledged revision");eq(haxe.Json.parse(patch.body).members[0].level,27,"Latest roster wins coalescing");
        w.reply(patch,{error:{code:"revision_conflict"}},412);tick(a);mine=w.take("GET","mine");w.reply(mine,{listing:row(ID,"self",7)});tick(a,1.1);
        patch=w.take("PATCH","/party");eq(patch.headers["If-Match"],'"7"',"412 refetches before retrying with new revision");w.reply(patch,{id:ID,revision:8,closed:true,closeReason:"party_full"});tick(a);check(a.own==null,"Closed mutation is never reposted");
        f=setup();a=f.a;w=f.w;j=save(f);var joined=party();joined.partyId="new-party";joined.members.push({accountId:"guest",name:"Guest",className:"Mage",level:25});a.observe(joined);w.reply(j,{id:ID,revision:1,closed:false});tick(a);
        check(a.own==null&&w.jobs.filter(j->j.op=="cleanup"&&j.path==P.BASE+"/listings/"+ID).length==1,"Create finishing after party change is closed");
        f=setup();a=f.a;w=f.w;j=save(f);a.disconnect();w.reply(j,{id:ID,revision:1,closed:false});tick(a);check(a.own==null&&!a.ready,"Stale callback cannot affect disconnected session");
        var cleanup=w.jobs.filter(j->j.op=="cleanup")[0];eq(cleanup.headers["Idempotency-Key"],j.headers["Idempotency-Key"],"Abandoned create replay uses original key");eq(cleanup.key,KEY,"Cleanup retains original credential");
        f=setup();a=f.a;w=f.w;a.list("europe",r->result=r);j=w.take("GET","listings?");w.reply(j,{error:{code:"rate_limited"}},429,"90");tick(a);
        a.list("europe",r->result=r);check(w.jobs.filter(j->j.op=="request").length==0,"429 suppresses immediate read retries");tick(a,89);a.list("europe",r->result=r);check(w.jobs.filter(j->j.op=="request").length==0,"Retry-After is a minimum");tick(a,10);a.list("europe",r->result=r);check(w.jobs.length==1,"Polling resumes after cooldown");
        var heartbeat=new GroupPresence();heartbeat.completed(429,100,75,2);check(!heartbeat.due(176)&&heartbeat.due(177),"Shared heartbeat honors cooldown and jitter");
        check(GroupPresence.deadline(429,'{"onlineUntil":"2099-01-01T00:00:00.000Z"}',"")==0,"429 is not acknowledged presence");eq(haxe.Json.parse(GroupPresence.body("europe")),{server:"europe",busy:false},"Both mods send identical heartbeat shape");heartbeat.completed(401,200,0,0);check(!heartbeat.due(1000),"Invalid credentials stop heartbeats");
        var member={accountId:"self",name:"Wink",className:"Warrior",level:25},wire=GroupWire.encode("request",ID2,ID,member),packet=GroupWire.decode(wire);
        check(wire.length<300&&packet!=null&&packet.level==25,"Join request fits one whisper");check(GroupWire.decode(GroupWire.PREFIX+"invalid")==null,"Malformed protocol ignored");check(GroupWire.decode(GroupWire.encode("declined",ID2,ID)).op=="declined","Decline roundtrip");
        check(packet.badge==null,"Existing requests without a badge remain compatible");
        for(badge in ["supporter-bronze","supporter-silver","supporter-gold","supporter-ruby","supporter-emerald","supporter-diamond","fareverly-creator"]) {
            var token=GroupWire.encode("request",ID2,ID,{accountId:"self",name:"Wink",className:"Warrior",level:10000,badge:badge});
            check(token.length<=300&&GroupWire.decode(token).badge==badge,"Optional applicant badge roundtrips in one whisper");
        }
        var unknown=GroupWire.PREFIX+haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(haxe.Json.stringify(["request",ID2,ID,"Mage",25,"<img src=bad>"])));
        check(GroupWire.decode(unknown).badge==null,"Unrecognized badge data is ignored without dropping the application");
        var requests=new GroupRequests(),listing=P.listing(row(ID,"leader"));eq(requests.add(listing,member,false,0,ID2,"leader","Leader"),"","Outgoing request recorded");requests.tick(299,null);eq(requests.get(ID2).state,"pending","Request lasts five minutes");
        check(!requests.respond(ID2,ID,"spoofed","declined",299),"Responses match native sender");check(!requests.respond(ID2,"wrong","leader","declined",299),"Responses match listing");check(requests.respond(ID2,ID,"leader","declined",299),"Expected leader can decline");eq(requests.get(ID2).state,"declined","Rejection reaches requester");
        requests.reset(true);requests.add(listing,member,false,0,ID2,"leader","Leader");requests.tick(300,null);eq(requests.get(ID2).state,"expired","Five-minute expiry enforced");
        trace('Group Finder API and wire passed ($checks checks)');
    }
}
