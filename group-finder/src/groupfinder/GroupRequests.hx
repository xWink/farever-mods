package groupfinder;

import groupfinder.GroupTypes;

/** Local request previews. No native invitations or chat packets are sent. */
class GroupRequests {
    public var rows(default,null):Array<JoinRequest>=[];
    public var revision(default,null)=0;
    var sequence=0;
    var cooldown:Map<String,Float>=[];
    public function new() {}
    public function add(listing:GroupListing,member:GroupMember,incoming:Bool,now:Float):String {
        if(listing==null)return "This listing is no longer available.";
        for(m in listing.members)if(m.accountId==member.accountId)return "You are already in this party.";
        var key=listing.id+":"+member.accountId;
        for(r in rows)if(r.listingId==listing.id&&r.member.accountId==member.accountId&&(r.state=="pending"||r.state=="invited"))return "A request is already pending.";
        if(cooldown.exists(key)&&now<cooldown[key])return "Please wait before requesting this group again.";
        rows.unshift({id:"request-"+(++sequence),listingId:listing.id,member:GroupRules.clone(member),incoming:incoming,state:"pending",expiresAt:now+60});
        cooldown[key]=now+10;revision++;
        return "";
    }
    public function answer(id:String,accept:Bool,listing:Null<GroupListing>,party:GroupParty,now:Float):String {
        var request=get(id);
        if(request==null||request.state!="pending"||request.expiresAt<=now)return "This request has expired.";
        if(listing==null||party==null||!request.incoming||request.listingId!=listing.id||listing.ownerId!=party.accountId||party.leaderId!=party.accountId)return "This listing is no longer available.";
        if(accept) {
            var reservations=0;
            for(r in rows)if(r.listingId==listing.id&&r.state=="invited"&&r.expiresAt>now)reservations++;
            if(party.members.length+reservations>=GroupRules.CAPACITY)return "All available places already have invitations pending.";
        }
        request.state=accept?"invited":"declined";request.expiresAt=now+60;revision++;
        return "";
    }
    public function cancel(id:String):Void {
        var request=get(id);if(request==null||request.state!="pending")return;
        request.state="cancelled";revision++;
    }
    public function get(id:String):Null<JoinRequest> {for(r in rows)if(r.id==id)return r;return null;}
    public function outgoing(listingId:String):Null<JoinRequest> {
        for(r in rows)if(!r.incoming&&r.listingId==listingId)return r;return null;
    }
    public function tick(now:Float,find:String->Null<GroupListing>):Void {
        for(r in rows)if(r.state=="pending"||r.state=="invited") {
            var state=find(r.listingId)==null?"closed":r.expiresAt<=now?"expired":r.state;
            if(state!=r.state){r.state=state;revision++;}
        }
    }
}
