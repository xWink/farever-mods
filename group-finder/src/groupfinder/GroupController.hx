package groupfinder;

import groupfinder.GameAccess as G;
import groupfinder.GroupTypes;

class GroupController {
    public final mock=new MockGroupService();
    public final api:GroupService;
    public final requests=new GroupRequests();
    public final view:GroupWindow;
    public var party:Null<GroupParty>;
    public var rows:Array<GroupListing>=[];
    public var category="Dungeons";
    public var page="browse";
    public var editingId:Null<String>;
    public var draftTitle="";
    public var draftCategory="Dungeons";
    public var message="";
    public var busy=false;
    public var opened=false;
    public var pendingDelete:Null<String>;
    var nextParty=0.0;
    var seenRevision=-1;
    var seenRequests=-1;
    var loading=false;
    var generation=0;
    var partyKey="";
    var now=0.0;
    var nextRequests=0.0;
    var sampleNumber=0;

    public function new() {api=mock;view=new GroupWindow(this);}
    public function mine():Null<GroupListing> return party==null?null:mock.mine(party.accountId);
    public function update(app:Dynamic,time:Float):Void {
        now=time;
        if(!GroupFinderMod.enabled()) {if(party!=null||opened)disconnect();return;}
        if(time>=nextParty) {
            nextParty=time+0.5;
            var next=GroupGame.capture(G.field(app,"me"));
            if(next!=null) {
                if(party!=null&&(party.accountId!=next.accountId||party.region!=next.region))disconnect();
                var before=mine();party=next;
                var key=haxe.Json.stringify(next);
                if(key!=partyKey){partyKey=key;view.dirty=true;}
                mock.observe(next);mock.examples(next.region,GroupFinderMod.examples());
                if(before!=null&&mine()==null) {
                    message=next.members.length>=GroupRules.CAPACITY?"Your party is full. Your listing has been closed.":"Your party changed. Your listing has been closed.";
                    if(page=="edit"){page="browse";editingId=null;}
                    view.dirty=true;
                }
            }
        }
        mock.tick(time);
        if(time>=nextRequests){nextRequests=time+0.5;requests.tick(time,mock.find);}
        if(seenRequests!=requests.revision){seenRequests=requests.revision;view.dirty=true;}
        if(opened&&party!=null&&seenRevision!=mock.revision&&!loading)refresh();
        view.update(opened);
    }
    public function toggle():Void {if(opened)close();else open();}
    public function open():Void {if(!GroupFinderMod.enabled())return;opened=true;view.dirty=true;refresh();}
    public function close():Void {opened=false;view.dispose();}
    public function refresh():Void {
        if(party==null||loading)return;
        loading=true;var token=generation,revision=mock.revision;
        api.list(party.region,result->{
            if(token!=generation)return;
            loading=false;
            if(result.error!="")message=result.error;else {rows=result.value;seenRevision=revision;}
            view.dirty=true;
        });
    }
    public function choose(value:String):Void {if(busy)return;category=value;page="browse";pendingDelete=null;view.resetScroll();view.dirty=true;}
    public function edit(?listing:GroupListing):Void {
        if(busy||party==null)return;
        if(listing==null)listing=mine();
        editingId=listing==null?null:listing.id;
        draftTitle=listing==null?"":listing.title;
        draftCategory=listing==null?category:listing.category;
        page="edit";message="";pendingDelete=null;view.dirty=true;
    }
    public function save():Void {
        if(busy)return;
        var error=GroupRules.partyError(party);
        if(error=="")error=GroupRules.titleError(draftTitle);
        if(error!=""){message=error;view.dirty=true;return;}
        busy=true;message="";view.dirty=true;var token=generation;
        api.save(party,editingId,draftTitle,draftCategory,result->{
            if(token!=generation)return;
            busy=false;
            if(result.error!="")message=result.error;
            else {category=result.value.category;page="browse";message=editingId==null?"Your listing has been created.":"Your listing has been updated.";editingId=null;view.resetScroll();}
            refresh();view.dirty=true;
        });
    }
    public function remove(id:String):Void {
        if(busy||party==null)return;
        if(pendingDelete!=id){pendingDelete=id;view.dirty=true;return;}
        busy=true;var token=generation;
        api.remove(party.accountId,id,result->{
            if(token!=generation)return;
            busy=false;pendingDelete=null;
            message=result.error==""?"Your listing has been closed.":result.error;
            page="browse";refresh();view.dirty=true;
        });
    }
    public function request(listing:GroupListing):Void {
        if(party==null)return;
        if(party.members.length>1){message="Leave your current party before requesting to join another group.";view.dirty=true;return;}
        var member:Null<GroupMember>=null;
        for(m in party.members)if(m.accountId==party.accountId)member=m;
        if(member==null)return;
        var error=requests.add(mock.find(listing.id),member,false,now);
        message=error==""?"Request pending. This sample group is a local preview.":error;view.dirty=true;
    }
    public function previewRequest():Void {
        var listing=mine();if(listing==null)return;
        var index=sampleNumber++%3;
        var error=requests.add(listing,{accountId:"preview-applicant-"+index,name:["Willow","Flint","Coral"][index],className:["Mage","Warrior","Rogue"][index],level:25},true,now);
        message=error==""?"A sample join request has arrived.":error;page="requests";view.resetScroll();view.dirty=true;
    }
    public function answer(request:JoinRequest,accept:Bool):Void {
        var error=requests.answer(request.id,accept,mock.find(request.listingId),party,now);
        message=error!=""?error:accept?"Invitation preview sent to "+request.member.name+".":"Request declined. The requester would see a rejection.";
        view.dirty=true;
    }
    public function cancel(request:JoinRequest):Void {requests.cancel(request.id);message="Request cancelled.";view.dirty=true;}
    public function showRequests():Void {page="requests";pendingDelete=null;view.resetScroll();view.dirty=true;}
    public function disconnect():Void {
        if(party!=null)mock.disconnect(party.accountId);
        generation++;party=null;partyKey="";rows=[];seenRevision=-1;busy=loading=false;
        requests.rows.resize(0);page="browse";editingId=null;message="";pendingDelete=null;close();
    }
    public function fail(error:Dynamic):Void {GroupFinderMod.report(Std.string(error));close();}
}
