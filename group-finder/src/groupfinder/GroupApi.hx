package groupfinder;

import groupfinder.GroupTypes;
import groupfinder.GroupTransport;
import fareverly.Protocol;

/** Game-thread state machine over the serialized HTTP worker. */
class GroupApi implements GroupService {
    public final worker:GroupTransport;
    public var own(default,null):Null<GroupListing>;
    public var revision(default,null)=0;
    public var ready(default,null)=false;
    public var mineKnown(default,null)=false;
    public var category="Dungeons";
    public var counts:Map<String,Int>=[];
    public var hasMore(default,null)=false;
    public var loading(default,null)=false;
    public var accept:GroupListing->Bool=(_)->true;
    public var onError:String->Void=(_)->{};
    public var onEvent:GroupEvent->Void=(_)->{};
    public var random:Void->haxe.io.Bytes=GroupNative.random;
    var generation=0;
    var key="";
    var party:Null<GroupParty>;
    var ticket=0;
    var pending:Map<Int,{method:String,path:String,done:(Response,Dynamic)->Void}>=[];
    var cooldown:Map<String,Float>=[];
    var failures:Map<String,Int>=[];
    var metadata=false;
    var categories:Map<String,String>=[];
    var heartbeatAttempted=false;
    var mineLoading=false;
    var writing=false;
    var now=0.;
    var nextMine=0.;
    var nextParty=0.;
    var appliedParty="";
    var createBody="";
    var createId="";
    var createAt=0.;
    var browseEpoch=0;
    var cursor:Null<String>;
    var loadedPages=1;
    var cached:Array<GroupListing>=[];
    public function new(?transport:GroupTransport)worker=transport==null?new GroupWorker():transport;
    public function connect(p:GroupParty,credential:String,closeOld=true):Void {
        disconnect(closeOld);party=GroupRules.clone(p);key=credential;
        generation=worker.session(p.accountId,key,p.region);
    }
    public function disconnect(closeOwned=true):Void {
        if(closeOwned&&own!=null)cleanup(own.id);
        // Resolve a lost create reply with the same key, then close it. Never let an abandoned create reappear.
        if(createId!="")worker.send({generation:generation,op:"cleanup",key:key,method:"POST",path:GroupProtocol.BASE+"/listings",
            body:createBody,headers:["Idempotency-Key"=>createId]});
        generation=worker.session("","","");party=null;key="";own=null;ready=mineKnown=metadata=heartbeatAttempted=false;
        pending.clear();cooldown.clear();failures.clear();categories.clear();counts.clear();mineLoading=writing=false;
        nextMine=nextParty=0;appliedParty="";createBody=createId="";resetBrowse();revision++;
    }
    function cleanup(id:String):Void worker.send({generation:generation,op:"cleanup",key:key,path:GroupProtocol.BASE+"/listings/"+id});
    public function pauseBrowse():Void {browseEpoch++;loading=false;}
    public function resetBrowse():Void {browseEpoch++;cached=[];cursor=null;hasMore=loading=false;loadedPages=1;}
    public function available():String {
        if(!Protocol.validKey(key))return "Sign into Fareverly in the Group Finder settings to continue.";
        if(!ready||!metadata||!mineKnown)return "Your Fareverly connection is not ready. Please try again shortly.";
        return "";
    }
    public function auth(op:String,?entropy:haxe.io.Bytes):Void worker.send({generation:generation,op:op,entropy:entropy});
    public function categoryCount(name:String):Int return counts.exists(name)?counts[name]:0;
    function bucket(method:String,path:String):String return path==GroupProtocol.BADGES?"badges":method=="DELETE"?"close":method=="GET"?"read":StringTools.endsWith(path,"/party")?"party":"write";
    function allowed(method:String,path:String):Bool {var t=cooldown[bucket(method,path)];return t==null||now>=t;}
    function request(method:String,path:String,body:Null<String>,headers:Null<Map<String,String>>,done:(Response,Dynamic)->Void):Void {
        if(!allowed(method,path)){done({status:429,body:"",error:"",retryAfter:""},null);return;}
        var id=++ticket;pending[id]={method:method,path:path,done:done};
        worker.send({generation:generation,op:"request",ticket:id,method:method,path:path,body:body,headers:headers});
    }
    static function ok(r:Response):Bool return r.status>=200&&r.status<300&&r.error=="";
    public function tick(time:Float):Void {
        now=time;var e=worker.receive();
        while(e!=null) {
            if(e.generation==generation)switch(e.op) {
                case "ready":ready=true;nextMine=0;
                case "heartbeat-attempted":heartbeatAttempted=true;
                case "error":ready=false;onError(e.message);onEvent(e);
                case "connection-error":onError(e.message);
                case "request":
                    var p=pending[e.ticket];pending.remove(e.ticket);
                    if(p!=null) {
                        var r=e.response,d:Dynamic=null;
                        try {if(r.body!="")d=haxe.Json.parse(r.body);}catch(_:Dynamic){}
                        if(ok(r)&&r.status!=204&&d==null)r={status:0,body:"",error:"Invalid response",retryAfter:""};
                        var b=bucket(p.method,p.path);
                        if(r.status==429||r.status==0||r.status>=500) {
                            var count=failures.exists(b)?failures[b]+1:1;failures[b]=count;
                            cooldown[b]=now+Math.max(Protocol.retryAfter(r.retryAfter,Date.now().getTime()/1000),Math.min(300,5*Math.pow(2,Math.min(count-1,6))))+Math.random()*3;
                        } else if(ok(r)){failures.remove(b);}
                        if(b!="badges"&&(r.status==401||r.status==403))ready=false;
                        try p.done(r,d)catch(_:Dynamic){cooldown[b]=now+60;onError("Unsupported Fareverly response. Update Group Finder and try again.");}
                    }
                default:onEvent(e);
            }
            e=worker.receive();
        }
        if(party==null||!ready)return;
        if(!metadata&&allowed("GET",GroupProtocol.BASE+"/categories")&&!hasPending(GroupProtocol.BASE+"/categories"))loadMetadata();
        if((own!=null||!mineKnown)&&!mineLoading&&now>=nextMine&&allowed("GET",GroupProtocol.BASE+"/listings/mine"))loadMine();
        if(own!=null&&!writing&&!mineLoading&&now>=nextParty&&allowed("PATCH",GroupProtocol.BASE+"/listings/"+own.id+"/party"))syncParty();
    }
    function hasPending(path:String):Bool {for(p in pending)if(p.path==path)return true;return false;}
    /** Public, optional decoration: a failed lookup must not interrupt group requests. */
    public function applicantBadges(accounts:Array<String>,done:Null<Map<String,String>>->Void):Void {
        var ids:Array<String>=[];
        for(id in accounts)if(Protocol.validAccount(id)&&ids.indexOf(id)<0&&ids.length<50)ids.push(id);
        if(ids.length==0){done([]);return;}
        request("POST",GroupProtocol.BADGES,haxe.Json.stringify({accounts:ids}),null,(r,d)->{
            if(!ok(r)||!Reflect.isObject(d)||Std.isOfType(d,Array)||Std.isOfType(d,String)){done(null);return;}
            var badges:Dynamic=Reflect.field(d,"badges");
            if(!Reflect.isObject(badges)||Std.isOfType(badges,Array)||Std.isOfType(badges,String)){done(null);return;}
            var result:Map<String,String>=[];
            for(id in ids){var badge=GroupProtocol.badge(Reflect.field(badges,id));if(badge!=null)result[id]=badge;}
            done(result);
        });
    }
    function loadMetadata():Void request("GET",GroupProtocol.BASE+"/categories",null,null,(r,d)->{
        if(!ok(r)){onError(GroupProtocol.error(r));return;}
        if(d.capacity!=GroupRules.CAPACITY||d.maxTitleLength!=GroupRules.MAX_TITLE_LENGTH||d.requestTimeoutSeconds!=GroupRules.REQUEST_TIMEOUT
            ||!Std.isOfType(d.categories,Array))throw "Unsupported metadata";
        var pairs:Map<String,String>=[];
        for(c in (cast d.categories:Array<Dynamic>))if(Std.isOfType(c.id,String)&&Std.isOfType(c.subcategories,Array))
            for(s in (cast c.subcategories:Array<Dynamic>))if(s.id==c.id)pairs[c.id]=s.id;
        for(name in GroupRules.categories)if(!pairs.exists(GroupProtocol.categoryId(name)))throw "Missing category";
        categories=pairs;metadata=true;revision++;
    });
    public function loadMine(?done:Void->Void):Void {
        if(mineLoading||writing)return;
        mineLoading=true;nextMine=now+15;
        request("GET",GroupProtocol.BASE+"/listings/mine",null,null,(r,d)->{
            mineLoading=false;
            if(ok(r)&&Reflect.hasField(d,"listing")) {
                var row=d.listing==null?null:GroupProtocol.listing(d.listing);
                if(row!=null&&row.ownerId!=party.accountId)throw "Owner mismatch";
                if(row!=null&&!validOwner(row)){cleanup(row.id);row=null;}
                var changed=!mineKnown||haxe.Json.stringify(own)!=haxe.Json.stringify(row);own=row;mineKnown=true;if(changed)revision++;
                if(own!=null){createBody=createId="";}
                if(done!=null)done();
            } else onError(GroupProtocol.error(r));
        });
    }
    function validOwner(row:GroupListing):Bool return party!=null&&GroupRules.partyError(party)==""&&party.partyId==row.partyId&&party.region==row.region&&party.accountId==row.ownerId;
    public function observe(p:GroupParty):Void {
        party=GroupRules.clone(p);
        if(own!=null&&!validOwner(own)){cleanup(own.id);own=null;revision++;}
    }
    function syncParty():Void {
        var body=haxe.Json.stringify(GroupProtocol.roster(party));if(body==appliedParty)return;
        var row=own;writing=true;nextParty=now+1;
        request("PATCH",GroupProtocol.BASE+"/listings/"+row.id+"/party",body,["If-Match"=>'"'+row.revision+'"'],(r,d)->{
            writing=false;nextParty=now+1;
            if(own==null||own.id!=row.id)return;
            if(ok(r)){applyMutation(d,row);appliedParty=body;}
            else {if(r.status==412){appliedParty="";loadMine();}else if(r.status==404||r.status==410){own=null;revision++;}onError(GroupProtocol.error(r));}
        });
    }
    function applyMutation(d:Dynamic,row:GroupListing):Void {
        if(d.id!=row.id||!Std.isOfType(d.revision,Int)||!Std.isOfType(d.closed,Bool))throw "Invalid mutation";
        if(d.closed||!validOwner(row)){if(!d.closed)cleanup(row.id);own=null;}
        else {row.revision=d.revision;own=row;nextMine=0;}
        revision++;
    }
    public function list(region:String,done:GroupResult<Array<GroupListing>>->Void):Void {
        if(available()!=""){done({value:null,error:available()});return;}
        if(loading)return;
        var epoch=++browseEpoch;loading=true;
        fetchPage(region,category,null,[],loadedPages,epoch,done);
    }
    function fetchPage(region:String,category:String,page:Null<String>,rows:Array<GroupListing>,remaining:Int,epoch:Int,done:GroupResult<Array<GroupListing>>->Void):Void {
        var path=GroupProtocol.BASE+"/listings?server="+StringTools.urlEncode(region)+"&category="+GroupProtocol.categoryId(category)+"&limit=24";
        if(page!=null)path+="&cursor="+StringTools.urlEncode(page);
        request("GET",path,null,null,(r,d)->{
            if(epoch!=browseEpoch)return;
            if(!ok(r)){loading=false;done({value:null,error:GroupProtocol.error(r)});return;}
            try {
                if(!Std.isOfType(d.listings,Array)||(d.nextCursor!=null&&!Std.isOfType(d.nextCursor,String)))throw "Invalid page";
                var ids=[for(row in rows)row.id=>true];
                for(value in (cast d.listings:Array<Dynamic>)) {
                    var row=GroupProtocol.listing(value);
                    if(row.region!=region||row.category!=category)throw "Wrong page";
                    if(!ids.exists(row.id)){rows.push(row);ids[row.id]=true;}
                }
                var next:Null<String>=d.nextCursor;
                if(next!=null&&(next==page||next.length>4096))throw "Invalid cursor";
                if(d.categoryCounts!=null)for(name in GroupRules.categories) {
                    var n=Reflect.field(d.categoryCounts,GroupProtocol.categoryId(name));if(Std.isOfType(n,Int)&&n>=0)counts[name]=n;
                }
                if(next!=null&&(remaining>1||rows.filter(accept).length==0))fetchPage(region,category,next,rows,remaining-1,epoch,done);
                else {cached=rows;cursor=next;hasMore=next!=null;loading=false;done({value:rows,error:""});}
            }catch(_:Dynamic){loading=false;done({value:null,error:"Unsupported Fareverly listing response. Please update Group Finder."});}
        });
    }
    public function canMore():Bool return !loading&&hasMore&&party!=null&&allowed("GET",GroupProtocol.BASE+"/listings");
    public function more(done:GroupResult<Array<GroupListing>>->Void):Void {
        if(loading||!hasMore||party==null)return;
        if(!allowed("GET",GroupProtocol.BASE+"/listings")){done({value:cached,error:""});return;}loading=true;loadedPages++;
        fetchPage(party.region,category,cursor,cached.copy(),1,++browseEpoch,done);
    }
    public function detail(id:String,done:GroupResult<GroupListing>->Void):Void {
        if(!GroupProtocol.uuid(id)||party==null||available()!=""){done({value:null,error:available()==""?"This listing is no longer available.":available()});return;}
        request("GET",GroupProtocol.BASE+"/listings/"+id+"?server="+StringTools.urlEncode(party.region),null,null,(r,d)->{
            if(!ok(r)){done({value:null,error:GroupProtocol.error(r)});return;}
            try {var row=GroupProtocol.listing(d.listing==null?d:d.listing);if(row.id!=id||row.region!=party.region)throw "Wrong listing";done({value:row,error:""});}
            catch(_:Dynamic)done({value:null,error:"This listing is no longer available."});
        });
    }
    public function save(p:GroupParty,id:Null<String>,title:String,category:String,done:GroupResult<GroupListing>->Void):Void {
        var error=available();if(error=="")error=GroupRules.partyError(p);if(error=="")error=GroupRules.titleError(title);
        if(error==""&&!heartbeatAttempted)error="Waiting for your Fareverly presence. Please try again shortly.";
        if(error==""&&writing)error="Your party information is being updated. Please try again shortly.";
        if(error!=""){done({value:null,error:error});return;}
        var categoryId=GroupProtocol.categoryId(category),body:String;
        try {if(!categories.exists(categoryId))throw "Choose a content category.";body=GroupProtocol.payload(p,title,categoryId,categories[categoryId]);}
        catch(e:Dynamic){done({value:null,error:Std.string(e)});return;}
        var row=id==null?null:own;
        if(id!=null&&(row==null||row.id!=id)){done({value:null,error:"This listing is no longer available."});return;}
        var headers:Map<String,String>=[];
        if(id==null) {
            if(createId!=""&&(body!=createBody||now-createAt>86400)) {loadMine();done({value:null,error:"A previous create request may still have succeeded. Refresh your listing before changing it."});return;}
            if(createId==""){createId=GroupProtocol.newId(random());createBody=body;createAt=now;}
            headers["Idempotency-Key"]=createId;
        }else headers["If-Match"]='"'+row.revision+'"';
        var snapshot=GroupRules.clone(p);writing=true;
        request(id==null?"POST":"PUT",GroupProtocol.BASE+"/listings"+(id==null?"":"/"+id),body,headers,(r,d)->{
            writing=false;
            if(ok(r)) {
                if(!GroupProtocol.uuid(d.id)||!Std.isOfType(d.revision,Int)||!Std.isOfType(d.closed,Bool)){done({value:null,error:"Unsupported Fareverly save response. Refresh before trying again."});return;}
                var saved:GroupListing={id:d.id,revision:d.revision,ownerId:snapshot.accountId,partyId:snapshot.partyId,region:snapshot.region,
                    title:StringTools.trim(title),category:category,subcategory:categories[categoryId],members:snapshot.members,updatedAt:0,expiresAt:0,sample:false};
                createBody=createId="";applyMutation(d,saved);appliedParty=haxe.Json.stringify(GroupProtocol.roster(snapshot));
                done({value:own,error:own==null?"Your party changed. The listing has been closed.":""});
            }else {
                if(id==null&&r.status!=0&&r.status!=429&&r.status<500){createBody=createId="";}
                if(r.status==412||r.status==409)loadMine();
                if(r.status==404||r.status==410){own=null;revision++;}
                done({value:null,error:GroupProtocol.error(r)});
            }
        });
    }
    public function remove(accountId:String,id:String,done:GroupResult<Bool>->Void):Void {
        request("DELETE",GroupProtocol.BASE+"/listings/"+id,null,null,(r,d)->{
            if(ok(r)||r.status==404||r.status==410){if(own!=null&&own.id==id){own=null;revision++;}done({value:true,error:""});}
            else done({value:false,error:GroupProtocol.error(r)});
        });
    }
}
