package groupfinder;

import groupfinder.GameAccess as G;
import groupfinder.GroupTypes;

class GroupController {
    public final mock:Null<MockGroupService>;
    public final live:Null<GroupApi>;
    public final api:GroupService;
    public final requests=new GroupRequests();
    public final view:GroupWindow;
    public final login:Null<GroupLogin>;
    public var party:Null<GroupParty>;
    public var rows:Array<GroupListing>=[];
    public var category="Dungeons";
    public var page="browse";
    public var editingId:Null<String>;
    public var draftTitle="";
    public var draftCategory="Dungeons";
    /** Only errors belong in the window footer. Success/pending state lives on its control. */
    public var message="";
    public var busy=false;
    public var opened=false;
    public var pendingDelete:Null<String>;
    var nextParty=0.;
    var nextBrowse=0.;
    var seenRevision=-1;
    var seenRequests=-1;
    var loading=false;
    var generation=0;
    var partyKey="";
    var now=0.;
    var nextRequests=0.;
    var sampleNumber=0;
    var ownedListingId:Null<String>;
    var localPlayer:Dynamic;
    var ignored:Map<String,Bool>=[];
    var ignoredKey="";
    var received:Map<String,Float>=[];

    public function new(?mock:MockGroupService,?live:GroupApi) {
        this.mock=mock;this.live=mock==null?(live==null?new GroupApi():live):null;
        api=mock==null?this.live:mock;view=new GroupWindow(this);
        login=mock==null?new GroupLogin(this,this.live):null;
        if(this.live!=null) {
            this.live.onError=error;
            this.live.accept=row->!ignored.exists(row.ownerId);
        }
    }
    public function error(value:String):Void {message=value;view.dirty=true;}
    public function mine():Null<GroupListing> return party==null?null:mock!=null?mock.mine(party.accountId):live.own;
    public function count(category:String):Int return live==null?visibleListings(category).length:live.categoryCount(category);
    public function visibleListings(?category:String):Array<GroupListing>
        return rows.filter(row->!ignored.exists(row.ownerId)&&(category==null||row.category==category));
    function syncIgnored():Void {
        var ids=GroupGame.ignoredAccounts(localPlayer);ids.sort(Reflect.compare);
        var key=ids.join("\n");if(key==ignoredKey)return;
        ignoredKey=key;ignored=[for(id in ids)id=>true];view.dirty=true;
    }
    public function update(app:Dynamic,time:Float):Void {
        now=time;
        if(!GroupFinderMod.enabled()){if(party!=null||opened)disconnect();if(live!=null)live.tick(time);return;}
        if(time>=nextParty) {
            nextParty=time+0.5;
            var me=G.field(app,"me"),next=GroupGame.capture(me);
            if(live!=null&&!GroupGame.connected(me))next=null;
            if(next==null) {if(party!=null)disconnect();}
            else {
                if(party!=null&&(party.accountId!=next.accountId||party.region!=next.region))disconnect();
                localPlayer=me;syncIgnored();
                if(next.members.length>1||(party!=null&&(party.partyId!=next.partyId||party.nativePartyId!=next.nativePartyId)))cancelOutgoing();
                var first=party==null;party=next;
                var key=haxe.Json.stringify(next);if(key!=partyKey){partyKey=key;view.dirty=true;}
                if(mock!=null){mock.observe(next);mock.examples(next.region,true);}
                else {
                    if(first)live.connect(next,GroupLogin.readKey());
                    live.observe(next);
                }
            }
        }
        if(mock!=null)mock.tick(time);else live.tick(time);
        syncListing();
        if(time>=nextRequests) {
            nextRequests=time+0.5;requests.tick(time,mock==null?null:mock.find);
            for(id in received.keys())if(received[id]<=now)received.remove(id);
        }
        if(seenRequests!=requests.revision){seenRequests=requests.revision;view.dirty=true;}
        var revision=mock!=null?mock.revision:live.revision;
        if(opened&&page=="browse"&&party!=null&&!loading&&(live==null?seenRevision!=revision:time>=nextBrowse&&live.available()==""))refresh();
        if(seenRevision!=revision){seenRevision=revision;view.dirty=true;}
        view.update(opened);
    }
    public function reconnect():Void {
        if(live==null||party==null)return;
        generation++;busy=loading=false;live.connect(party,GroupLogin.readKey(),false);nextBrowse=0;view.dirty=true;
    }
    public function toggle():Void {if(opened)close();else open();}
    public function open():Void {
        if(!GroupFinderMod.enabled())return;syncIgnored();opened=true;view.dirty=true;nextBrowse=0;
        if(live==null||live.available()=="")refresh();
        else if(party!=null&&!fareverly.Protocol.validKey(GroupLogin.readKey()))error(live.available());
    }
    public function close():Void {opened=false;if(live!=null){live.pauseBrowse();loading=false;}view.dispose();}
    public function syncListing():Void {
        var listing=mine(),id=listing==null?null:listing.id;
        if(ownedListingId!=null&&ownedListingId!=id) {
            for(r in requests.rows)if(r.incoming&&(r.state=="pending"||r.state=="invited"))sendState(r,"closed");
            requests.reset();sampleNumber=0;
            if(page=="requests"||page=="edit"&&editingId!=null){page="browse";editingId=null;pendingDelete=null;view.resetScroll();}
            nextBrowse=0;view.dirty=true;
        }
        ownedListingId=id;
    }
    public function refresh():Void {
        if(party==null||loading)return;
        loading=true;nextBrowse=now+10;var token=generation,revision=mock!=null?mock.revision:live.revision;
        if(live!=null)live.category=category;
        api.list(party.region,result->{
            if(token!=generation)return;loading=false;
            if(result.error!=""){error(result.error);nextBrowse=now+15+Math.random()*5;}
            else {rows=result.value;seenRevision=revision;message="";}
            view.dirty=true;
        });
    }
    public function more():Void {
        if(live==null||!opened||page!="browse"||loading||!live.canMore())return;
        loading=true;var token=generation;
        live.more(result->{if(token!=generation)return;loading=false;if(result.error!="")error(result.error);else rows=result.value;view.dirty=true;});
    }
    public function choose(value:String):Void {
        if(busy)return;category=value;page="browse";pendingDelete=null;message="";view.resetScroll();view.dirty=true;
        if(live!=null){live.category=value;live.resetBrowse();rows=[];loading=false;nextBrowse=0;refresh();}
    }
    public function edit(?listing:GroupListing):Void {
        if(busy||party==null)return;if(listing==null)listing=mine();
        editingId=listing==null?null:listing.id;draftTitle=listing==null?"":listing.title;
        draftCategory=listing==null?category:listing.category;page="edit";message="";pendingDelete=null;view.dirty=true;
    }
    public function save():Void {
        if(busy)return;var reason=GroupRules.partyError(party);if(reason=="")reason=GroupRules.titleError(draftTitle);
        if(reason!=""){error(reason);return;}
        busy=true;message="";view.dirty=true;var token=generation;
        api.save(party,editingId,draftTitle,draftCategory,result->{
            if(token!=generation)return;busy=false;
            if(result.error!="")error(result.error);
            else {syncListing();category=result.value.category;page="browse";message="";editingId=null;view.resetScroll();refresh();}
            view.dirty=true;
        });
    }
    public function remove(id:String):Void {
        if(busy||party==null)return;if(pendingDelete!=id){pendingDelete=id;view.dirty=true;return;}
        busy=true;var token=generation;
        api.remove(party.accountId,id,result->{
            if(token!=generation)return;busy=false;pendingDelete=null;syncListing();
            message=result.error;if(result.error==""){page="browse";refresh();}view.dirty=true;
        });
    }
    public function requestError():String {
        if(party==null)return "Enter the game with your character to request to join a group.";
        if(mine()!=null)return "Close your listing before requesting to join another group.";
        if(party.members.length!=1)return "Leave your current party before requesting to join another group.";
        return live==null?"":live.available();
    }
    public function request(listing:GroupListing):Void {
        if(busy)return;syncIgnored();
        if(listing==null||ignored.exists(listing.ownerId)){error("This listing is no longer available.");return;}
        var reason=requestError();if(reason!=""){error(reason);return;}
        if(live==null){addOutgoing(mock.find(listing.id));return;}
        busy=true;view.dirty=true;var token=generation,expectedParty=party.partyId;
        live.detail(listing.id,result->{
            if(token!=generation)return;busy=false;syncIgnored();
            // Recheck game state after the HTTP round trip, not just at button press.
            var current=GroupGame.capture(localPlayer);
            if(result.error!="")error(result.error);
            else if(current==null||current.partyId!=expectedParty||current.members.length!=1||requestError()!=""||ignored.exists(result.value.ownerId))error("Your party or this listing changed. Please try again.");
            else addOutgoing(result.value);
            view.dirty=true;
        });
    }
    function addOutgoing(listing:GroupListing):Void {
        var member:Null<GroupMember>=null;for(m in party.members)if(m.accountId==party.accountId)member=m;if(member==null)return;
        var owner:GroupMember=null;if(listing!=null)for(m in listing.members)if(m.accountId==listing.ownerId)owner=m;
        var id=live==null?null:GroupProtocol.newId(live.random());
        var reason=requests.add(listing,member,false,now,id,owner==null?null:owner.accountId,owner==null?null:owner.name);
        message=reason;view.dirty=true;if(reason!=""||live==null)return;
        var request=requests.get(id),token=generation;
        try GroupChat.send(localPlayer,owner.accountId,owner.name,GroupWire.encode("request",id,listing.id,member),ok->{
            if(token!=generation)return;if(!ok){requests.cancel(id);error("Could not deliver the join request. The player may be offline.");}
        })catch(_:Dynamic){requests.cancel(id);error("Could not deliver the join request. Please try again.");}
    }
    public function previewRequest():Void {
        if(mock==null)return;var listing=mine();if(listing==null)return;
        var index=sampleNumber++,names=["Willow","Flint","Coral","Aspen","Lark","Rowan","Cinder","Brook"];
        var name=names[index%names.length]+(index<names.length?"":" "+(1+Std.int(index/names.length)));
        receiveRequest(listing.id,{accountId:"preview-applicant-"+index,name:name,className:["Mage","Warrior","Rogue","Cleric"][index%4],level:25,badge:MockGroupService.sampleBadge(index)});
        page="requests";view.resetScroll();view.dirty=true;
    }
    public function receiveRequest(listingId:String,member:GroupMember,?id:String):Void {
        syncIgnored();var listing=mine();if(listing==null||listing.id!=listingId||ignored.exists(member.accountId))return;
        var reason=requests.add(listing,member,true,now,id,member.accountId,member.name);
        if(reason=="")try GroupGame.notifyRequest(member)catch(e:Dynamic)GroupFinderMod.report("Request notification: "+Std.string(e));
        view.dirty=true;
    }
    public function receive(client:Dynamic,message:Dynamic,text:String):Void {
        if(live==null||party==null||!GroupFinderMod.enabled())return;
        var sender=GroupChat.sender(client,localPlayer,message);if(sender=="")return;syncIgnored();if(ignored.exists(sender))return;
        var packet=GroupWire.decode(text);if(packet==null)return;
        var name=G.text(G.field(G.field(message,"sender"),"name"),"Player");
        if(packet.op=="request") {
            var dedup=sender+":"+packet.id;if(received.exists(dedup))return;received[dedup]=now+GroupRules.REQUEST_TIMEOUT+30;
            receiveRequest(packet.listingId,{accountId:sender,name:name,className:packet.className,level:packet.level},packet.id);
        } else if(requests.respond(packet.id,packet.listingId,sender,packet.op=="cancel"?"cancelled":packet.op,now)) {
            if(packet.op=="declined")GroupGame.notify(name+" declined your request to join their group.");
            else if(packet.op=="closed")GroupGame.notify("The group listing for your request to "+name+" has closed.");
            view.dirty=true;
        }
    }
    public function answer(request:JoinRequest,accept:Bool):Void {
        if(request.state!="pending")return;
        if(live!=null) {
            var current=GroupGame.capture(localPlayer);
            if(current==null||mine()==null||current.partyId!=mine().partyId||current.leaderId!=current.accountId){error("You no longer lead this group.");return;}
            party=current;
        }
        var reason=requests.answer(request.id,accept,mine(),party,now);message=reason;
        if(reason==""&&live!=null) {
            if(accept&&!GroupChat.invite(localPlayer,request.member.accountId)){request.state="pending";error("The game could not send this invitation. Check your party and try again.");return;}
            sendState(request,accept?"invited":"declined",true);
        }
        view.dirty=true;
    }
    function sendState(request:JoinRequest,state:String,reportFailure=false):Void {
        if(live==null||localPlayer==null||request.peerId==null)return;
        var token=generation;
        try GroupChat.send(localPlayer,request.peerId,request.peerName,GroupWire.encode(state,request.id,request.listingId),ok->{
            if(!ok&&reportFailure&&token==generation)error("Could not deliver the response to this player.");
        })catch(_:Dynamic){if(reportFailure)error("Could not deliver the response to this player.");}
    }
    public function cancel(request:JoinRequest):Void {sendState(request,"cancel");requests.cancel(request.id);message="";view.dirty=true;}
    function cancelOutgoing():Void {
        for(r in requests.rows)if(!r.incoming&&(r.state=="pending"||r.state=="invited"))sendState(r,"cancel");
        if(requests.cancelOutgoing()>0)view.dirty=true;
    }
    public function showRequests():Void {if(mine()==null)return;page="requests";pendingDelete=null;message="";view.resetScroll();view.dirty=true;}
    public function disconnect():Void {
        cancelOutgoing();
        for(r in requests.rows)if(r.incoming&&(r.state=="pending"||r.state=="invited"))sendState(r,"closed");
        if(mock!=null&&party!=null)mock.disconnect(party.accountId);if(live!=null)live.disconnect();
        if(login!=null)login.end();generation++;party=null;partyKey="";rows=[];seenRevision=-1;busy=loading=false;
        localPlayer=null;ignored.clear();ignoredKey="";received.clear();
        requests.reset();ownedListingId=null;sampleNumber=0;page="browse";editingId=null;message="";pendingDelete=null;close();
    }
    public function fail(error:Dynamic):Void {GroupFinderMod.report(Std.string(error));close();}
}
