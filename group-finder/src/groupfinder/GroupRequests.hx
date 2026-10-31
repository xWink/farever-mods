package groupfinder;

import groupfinder.GroupTypes;

/** Request lifecycle shared by live whispers and deterministic tests. */
class GroupRequests {
    public var rows(default,null):Array<JoinRequest>=[];
    public var revision(default,null)=0;
    var sequence=0;
    var cooldown:Map<String,Float>=[];
    var declined:Map<String,Bool>=[];
    public static inline var DECLINED="This group declined your request. You cannot apply to this listing again.";
    public function new() {}
    public function add(listing:GroupListing,member:GroupMember,incoming:Bool,now:Float,?id:String,?peerId:String,?peerName:String):String {
        if(listing==null)return "This listing is no longer available.";
        if(isDeclined(listing.id,member.accountId))return DECLINED;
        for(m in listing.members)if(m.accountId==member.accountId)return "You are already in this party.";
        var key=listing.id+":"+member.accountId;
        for(r in rows)if(r.listingId==listing.id&&r.member.accountId==member.accountId&&(r.state=="pending"||r.state=="invited"))return "A request is already pending.";
        if(cooldown.exists(key)&&now<cooldown[key])return "Please wait before requesting this group again.";
        rows.unshift({id:id==null?"request-"+(++sequence):id,listingId:listing.id,member:GroupRules.clone(member),incoming:incoming,state:"pending",expiresAt:now+GroupRules.REQUEST_TIMEOUT,peerId:peerId,peerName:peerName});
        cooldown[key]=now+10;revision++;
        return "";
    }
    public function answer(id:String,accept:Bool,listing:Null<GroupListing>,party:GroupParty,now:Float):String {
        var request=get(id);
        if(request==null||request.state!="pending"||request.expiresAt<=now)return "This request has expired.";
        if(listing==null||party==null||!request.incoming||request.listingId!=listing.id||listing.ownerId!=party.accountId||party.leaderId!=party.accountId)return "This listing is no longer available.";
        // Invitations do not reserve places. The native game owns party capacity.
        if(!accept)declined[request.listingId+":"+request.member.accountId]=true;
        request.state=accept?"invited":"declined";request.expiresAt=now+GroupRules.REQUEST_TIMEOUT;revision++;
        return "";
    }
    public function respond(id:String,listingId:String,sender:String,state:String,now:Float):Bool {
        var r=get(id);if(r==null||r.listingId!=listingId||r.peerId!=sender||r.expiresAt<=now
            ||(r.state!="pending"&&r.state!="invited"))return false;
        if(r.incoming&&state!="cancelled"||!r.incoming&&["invited","declined","closed"].indexOf(state)<0)return false;
        // Accepted requests are history, not pending applications. Older clients
        // send an automatic cancel when they join; it must not undo acceptance.
        if(r.incoming&&r.state=="invited")return false;
        if(state=="declined")declined[r.listingId+":"+r.member.accountId]=true;
        r.state=state;revision++;return true;
    }
    public function isDeclined(listingId:String,accountId:String):Bool return declined.exists(listingId+":"+accountId);
    public function reset(clearDeclines=false):Void {rows=[];cooldown.clear();if(clearDeclines)declined.clear();revision++;}
    public function observeParty(party:GroupParty,listingId:Null<String>):Void {
        if(party==null||listingId==null)return;
        for(r in rows)if(r.incoming&&r.listingId==listingId&&r.state=="invited")
            for(member in party.members)if(member.accountId==r.member.accountId){r.state="joined";revision++;break;}
    }
    public static function joinedGroup(r:JoinRequest,party:Null<GroupParty>):Bool {
        if(party==null||party.members.length<2||r.peerId==null)return false;
        for(member in party.members)if(member.accountId==r.peerId)return true;
        return false;
    }
    public function incoming(listingId:String):Array<JoinRequest>
        return rows.filter(r->r.incoming&&r.listingId==listingId);
    public function cancel(id:String):Void {
        var request=get(id);if(request==null||(request.state!="pending"&&request.state!="invited"))return;
        request.state="cancelled";revision++;
    }
    /** Joining a party ends our outgoing requests, without clearing a leader's inbox. */
    public function cancelOutgoing(?party:GroupParty):Int {
        var count=0;
        for(request in rows)if(!request.incoming&&(request.state=="pending"||request.state=="invited")) {
            request.state=joinedGroup(request,party)?"joined":"cancelled";count++;
        }
        if(count>0)revision++;
        return count;
    }
    public function get(id:String):Null<JoinRequest> {for(r in rows)if(r.id==id)return r;return null;}
    public function outgoing(listingId:String):Null<JoinRequest> {
        for(r in rows)if(!r.incoming&&r.listingId==listingId)return r;return null;
    }
    public function tick(now:Float,find:String->Null<GroupListing>):Void {
        for(r in rows)if(r.state=="pending"||!r.incoming&&r.state=="invited") {
            var state=find!=null&&find(r.listingId)==null?"closed":r.expiresAt<=now?"expired":r.state;
            if(state!=r.state){r.state=state;revision++;}
        }
    }
}
