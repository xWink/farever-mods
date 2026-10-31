package groupfinder;

import groupfinder.GroupTypes;
import fareverly.Protocol;

/** Strict wire adapters. Game snapshots and returned badges never become write fields. */
class GroupProtocol {
    public static inline var BASE="/api/v1/group-finder";
    public static inline var BADGES="/api/v1/badges";
    public static function uuid(value:String):Bool return value!=null&&~/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.match(value);
    public static function newId(bytes:haxe.io.Bytes):String {
        var b=bytes.sub(0,16);b.set(6,(b.get(6)&15)|64);b.set(8,(b.get(8)&63)|128);
        var h=b.toHex();return h.substr(0,8)+"-"+h.substr(8,4)+"-"+h.substr(12,4)+"-"+h.substr(16,4)+"-"+h.substr(20,12);
    }
    public static function validUrl(url:String):Bool {
        if(!StringTools.startsWith(url,Protocol.ORIGIN+"/api/"))return false;
        var p=url.substr(Protocol.ORIGIN.length).split("?")[0];
        return ["/api/v1/account","/api/v1/auth/device","/api/v1/auth/token","/api/v1/marketplace/heartbeat",
            BADGES,BASE+"/categories",BASE+"/listings",BASE+"/listings/mine"].indexOf(p)>=0
            || ~/^\/api\/v1\/group-finder\/listings\/[a-f0-9-]{36}(\/party)?$/.match(p);
    }
    public static function categoryId(name:String):String return switch(name) {case "Dungeons":"dungeons";case "World Events":"world-events";case "Other":"other";default:"";};
    public static function categoryName(id:String):String return switch(id) {case "dungeons":"Dungeons";case "world-events":"World Events";case "other":"Other";default:id;};
    public static function roster(p:GroupParty):Dynamic return {
        server:p.region,partyId:p.partyId,leaderAccountId:p.leaderId,
        members:[for(m in p.members) {accountId:m.accountId,name:m.name,
            className:["Warrior","Rogue","Mage","Cleric"].indexOf(m.className)>=0?m.className:null,
            level:m.level>0&&m.level<=10000?cast(m.level,Null<Int>):null}]
    };
    public static function badge(value:Dynamic):Null<String> {
        return Std.isOfType(value,String)&&["supporter-bronze","supporter-silver","supporter-gold","supporter-ruby",
            "supporter-emerald","supporter-diamond","fareverly-creator"].indexOf(value)>=0?value:null;
    }
    public static function payload(p:GroupParty,title:String,category:String,subcategory:String):String {
        var d=roster(p);Reflect.setField(d,"title",StringTools.trim(title));
        Reflect.setField(d,"category",category);Reflect.setField(d,"subcategory",subcategory);
        var body=haxe.Json.stringify(d);if(haxe.io.Bytes.ofString(body).length>4096)throw "The party information is too large to send.";
        return body;
    }
    static function string(d:Dynamic,k:String):String {
        var v=Reflect.field(d,k);if(!Std.isOfType(v,String))throw "Invalid "+k;return v;
    }
    public static function listing(d:Dynamic):GroupListing {
        var id=string(d,"id"),owner=string(d,"leaderAccountId"),region=string(d,"server");
        if(!uuid(id)||!Protocol.validAccount(owner)||!GroupPresence.validServer(region)||!Std.isOfType(d.revision,Int)||d.revision<1
            ||!Std.isOfType(d.members,Array))throw "Invalid listing";
        var members:Array<GroupMember>=[],ids:Map<String,Bool>=[];
        for(m in (cast d.members:Array<Dynamic>)) {
            var account=string(m,"accountId"),name=string(m,"name"),kind=m.className,level=m.level;
            if(!Protocol.validAccount(account)||ids.exists(account)||GroupRules.count(name)>128
                ||kind!=null&&["Warrior","Rogue","Mage","Cleric"].indexOf(kind)<0
                ||level!=null&&(!Std.isOfType(level,Int)||level<1||level>10000))throw "Invalid member";
            ids[account]=true;
            members.push({accountId:account,name:name,className:kind==null?"":kind,level:level==null?0:level,
                badge:Std.isOfType(m.badge,String)?m.badge:null});
        }
        if(members.length<1||members.length>=GroupRules.CAPACITY||!ids.exists(owner))throw "Invalid roster";
        var title=string(d,"title"),expiry=Protocol.expiry(string(d,"onlineUntil"));
        if(GroupRules.titleError(title)!=""||expiry<=0)throw "Invalid title or presence";
        return {id:id,revision:d.revision,ownerId:owner,partyId:string(d,"partyId"),region:region,
            category:categoryName(string(d,"category")),subcategory:string(d,"subcategory"),title:title,members:members,
            updatedAt:Protocol.expiry(string(d,"updatedAt")),expiresAt:expiry,sample:false};
    }
    public static function error(r:Response):String {
        var code="";try {var d:Dynamic=haxe.Json.parse(r.body);code=Std.isOfType(d.error,String)?d.error:d.error.code;}catch(_:Dynamic){}
        if(r.status==401)return "Sign into Fareverly in the Group Finder settings to continue.";
        if(r.status==403)return "Your Fareverly connection cannot manage this listing. Verify your connection in Group Finder settings.";
        if(r.status==404||r.status==410)return "This listing is no longer available.";
        if(r.status==412)return "Your listing changed. It has been refreshed; review it and try again.";
        if(r.status==429)return "Fareverly is receiving requests too quickly. Please try again shortly.";
        if(r.status==0||r.status>=500)return "Fareverly is temporarily unavailable. Please try again shortly.";
        return switch(code) {
            case "presence_required","presence_unavailable","not_online","missing_presence": "Waiting for your Fareverly presence. Please try again shortly.";
            case "party_full": "Your party is full.";
            case "duplicate_listing","listing_exists","party_already_listed": "Your account or party already has a listing.";
            case "leader_mismatch": "Only the party leader can create a listing.";
            default: "Fareverly could not save this listing. Refresh and check the title and party before trying again.";
        };
    }
}
