import groupfinder.GroupTypes;
import groupfinder.MockGroupService;
import groupfinder.GroupRequests;

class GroupFinderTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic):Void {checks++;if(actual!=expected)throw 'Expected $expected, got $actual';}
    static function ok(value:Bool):Void eq(value,true);
    static function member(id:String):GroupMember return {accountId:id,name:id,className:"Mage",level:25};
    static function party(id="owner",group="party",region="europe"):GroupParty return {accountId:id,partyId:group,region:region,leaderId:id,members:[member(id)]};
    static function flush(api:MockGroupService):Void api.tick(api.now+0.2);
    static function create(api:MockGroupService,p:GroupParty,title="Heroic runs"):GroupListing {
        api.observe(p);var result:Null<GroupResult<GroupListing>>=null;
        api.save(p,null,title,"Dungeons",r->result=r);flush(api);
        eq(result.error,"");return result.value;
    }
    static function main():Void {
        eq(GroupRules.count("🌟 hello"),7);
        eq(GroupRules.titleError("   "),"Enter a listing title.");
        eq(GroupRules.titleError([for(_ in 0...30)"🌟"].join("")),"");
        ok(GroupRules.titleError([for(_ in 0...31)"x"].join(""))!="");
        ok(GroupRules.titleError("hello\nworld")!="");
        var api=new MockGroupService(),p=party();api.observe(p);
        var result:Null<GroupResult<GroupListing>>=null;
        api.save(p,null,"  Hello world  ","Dungeons",r->result=r);
        eq(result,null);flush(api);eq(result.error,"");eq(result.value.title,"Hello world");
        var id=result.value.id;
        api.save(p,null,"Second","Other",r->result=r);flush(api);ok(result.error!="");
        api.save(p,id,"Changed","Other",r->result=r);flush(api);eq(result.error,"");eq(api.mine("owner").category,"Other");
        result.value.title="mutated response";eq(api.mine("owner").title,"Changed");
        p.members.push(member("friend"));api.observe(p);eq(api.mine("owner").members.length,2);
        p.members[1].level=30;api.observe(p);eq(api.mine("owner").members[1].level,30);
        var fakeLeader=party("other","party");api.observe(fakeLeader);
        api.save(fakeLeader,null,"Duplicate","Dungeons",r->result=r);flush(api);ok(result.error!="");
        var removed:Null<GroupResult<Bool>>=null;
        api.remove("other",id,r->removed=r);flush(api);ok(removed.error!="");ok(api.mine("owner")!=null);
        // A leadership change during the mock round trip must invalidate save.
        api.save(p,id,"Too late","Other",r->result=r);p.leaderId="friend";api.observe(p);flush(api);
        ok(result.error!="");eq(api.mine("owner"),null);
        p=party();var listing=create(api,p);
        p.partyId="new-party";api.observe(p);eq(api.mine("owner"),null);
        listing=create(api,p);p.members=[member("owner"),member("a"),member("b"),member("c")];api.observe(p);eq(api.mine("owner"),null);
        p.members.pop();api.observe(p);eq(api.mine("owner"),null); // no automatic repost
        listing=create(api,p);api.tick(api.now+121);eq(api.mine("owner"),null);
        listing=create(api,p);api.disconnect("owner");eq(api.mine("owner"),null);
        api.observe(p);api.save(p,null,"Logout race","Other",r->result=r);api.disconnect("owner");flush(api);ok(result.error!="");
        api.observe(p);api.save(p,null,"Reconnect race","Other",r->result=r);api.disconnect("owner");api.observe(p);flush(api);ok(result.error!="");eq(api.mine("owner"),null);
        p=party();listing=create(api,p);
        api.remove(p.accountId,listing.id,r->removed=r);flush(api);eq(removed.error,"");eq(api.mine("owner"),null);
        api.examples("europe",true);api.examples("north-america",true);
        var rows:Array<GroupListing>=[];api.list("europe",r->rows=r.value);flush(api);eq(rows.length,13);
        ok(rows.filter(r->r.region!="europe").length==0);
        listing=create(api,p);api.examples("europe",false);api.list("europe",r->rows=r.value);flush(api);eq(rows.length,1);eq(rows[0].id,listing.id);
        var requests=new GroupRequests();
        eq(requests.add(listing,member("owner"),true,api.now),"You are already in this party.");
        eq(requests.add(listing,member("guest"),true,api.now),"");
        ok(requests.add(listing,member("guest"),true,api.now)!="");
        var request=requests.rows[0];eq(requests.answer(request.id,true,listing,p,api.now),"");eq(request.state,"invited");
        for(id in ["guest2","guest3"]) {
            requests.add(listing,member(id),true,api.now);
            eq(requests.answer(requests.rows[0].id,true,listing,p,api.now),"");
        }
        requests.add(listing,member("guest4"),true,api.now);
        ok(requests.answer(requests.rows[0].id,true,listing,p,api.now)!="");
        eq(requests.answer(requests.rows[0].id,false,listing,p,api.now),"");eq(requests.rows[0].state,"declined");
        requests.add(listing,member("guest5"),false,api.now);requests.cancel(requests.rows[0].id);eq(requests.rows[0].state,"cancelled");
        ok(requests.add(listing,member("guest5"),false,api.now)!="");
        requests.add(listing,member("guest6"),false,api.now);requests.tick(api.now+61,api.find);eq(requests.rows[0].state,"expired");
        requests.add(listing,member("guest7"),true,api.now);api.disconnect("owner");requests.tick(api.now,api.find);eq(requests.rows[0].state,"closed");
        trace('Group Finder passed ($checks checks)');
    }
}
