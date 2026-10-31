import groupfinder.GroupController;
import groupfinder.GroupLogin;
import groupfinder.GroupProtocol;
import groupfinder.GroupWire;
import groupfinder.GameAccess as G;
import GroupApiTest.FakeGroups;

@:access(GroupInviteTest)
@:access(GroupApiTest)
@:access(groupfinder.GroupController)
class GroupApplicantBadgeTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function badgeJobs(w:FakeGroups):Int return w.jobs.filter(j->j.path==GroupProtocol.BADGES).length;
    static function add(c:GroupController,account:String):Void c.receiveRequest(c.mine().id,{accountId:account,name:account,className:"Mage",level:25});
    static function pump(c:GroupController,time:Float):Void {c.now=time;c.live.tick(time);c.updateApplicantBadges();}
    public static function run():Void {
        GroupLogin.key=GroupApiTest.KEY;
        var f=GroupInviteTest.setup("leader",true),c=f.c,w=f.w;
        var spoof=GroupWire.PREFIX+haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(haxe.Json.stringify(
            ["request",GroupApiTest.ID2,c.mine().id,"Mage",25,"supporter-diamond"])));
        GroupInviteTest.receive(c,f.me,"applicant",spoof);
        var applicant=c.requests.rows[0];
        check(applicant.member.badge==null&&applicant.state=="pending","Earlier six-field applications still work, but cannot claim their own badge");
        add(c,"ordinary");add(c,"unknown");pump(c,1);
        check(badgeJobs(w)==0,"Closed window performs no badge lookups");
        c.opened=true;c.page="browse";pump(c,2);check(badgeJobs(w)==0,"Browse does not look up applicants");
        c.showRequests();pump(c,3);var j=w.take("POST",GroupProtocol.BADGES),ids:Array<String>=haxe.Json.parse(j.body).accounts;
        check(ids.length==3&&ids.indexOf("applicant")>=0&&ids.indexOf("ordinary")>=0,"Visible applicants are batched using native account IDs");
        pump(c,4);check(badgeJobs(w)==0,"Only one badge batch is in flight");
        w.reply(j,{badges:{applicant:"supporter-silver",unknown:"invalid",unrequested:"supporter-gold"}});pump(c,5);
        check(applicant.member.badge=="supporter-silver"&&c.badgeCache["ordinary"].badge==null&&c.badgeCache["unknown"].badge==null
            &&!c.badgeCache.exists("unrequested"),"Only requested, recognized badges are used; absent badges are cached too");
        c.view.update(true);
        var names=G.nodes.filter(n->StringTools.startsWith(n.id,"groupMemberName")),images:Array<Dynamic>=[];
        for(n in names)for(child in (cast n.children:Array<Dynamic>))if(G.field(child,"nativeType")=="h2d.Bitmap")images.push(child);
        check(images.length==1&&images[0].tile.texture.resourceName=="supporter-silver.png","Fetched badge renders beside the applicant in Requests");
        c.view.dispose();pump(c,6);pump(c,100);check(badgeJobs(w)==0,"Positive and negative cache entries avoid repeated fetches");
        applicant.state="cancelled";add(c,"applicant");var replacement=c.requests.rows[0];pump(c,101);
        check(replacement.member.badge=="supporter-silver"&&badgeJobs(w)==0,"Reapplications inherit the cached badge without a lookup");
        pump(c,306);j=w.take("POST",GroupProtocol.BADGES);ids=haxe.Json.parse(j.body).accounts;
        check(ids.length==3,"Expired cache refresh deduplicates multiple requests from the same account");
        w.reply(j,{badges:{}});pump(c,307);
        check(applicant.member.badge==null&&replacement.member.badge==null,"A removed badge is cleared from all applications after cache refresh");
        add(c,"later");pump(c,309);j=w.take("POST",GroupProtocol.BADGES);w.reply(j,{error:"rate_limited"},429,"90");pump(c,310);
        check(c.message==""&&c.live.ready&&c.requests.rows[0].state=="pending","Lookup failures do not affect requests or login and do not show an error");
        c.live.list(c.party.region,(_)->{});var browse=w.take("GET","listings?");check(browse!=null,"Badge rate limits leave listing reads available");
        pump(c,340);pump(c,399);check(badgeJobs(w)==0,"Badge retries respect Retry-After");
        pump(c,430);j=w.take("POST",GroupProtocol.BADGES);
        c.live.remove(c.party.accountId,c.mine().id,(_)->{});var close=w.take("DELETE","/listings/");w.reply(close,null,204);pump(c,431);c.syncListing();
        w.reply(j,{badges:{later:"supporter-gold"}});pump(c,432);
        check(c.requests.rows.length==0&&!c.badgesLoading&&!c.badgeCache.exists("later"),"Closing a listing invalidates in-flight badge callbacks and clears its cache");
        c.disconnect();

        f=GroupInviteTest.setup("leader",true);c=f.c;w=f.w;add(c,"guest");c.opened=true;c.showRequests();pump(c,1);j=w.take("POST",GroupProtocol.BADGES);
        c.reconnect();w.reply(j,{badges:{guest:"supporter-gold"}});pump(c,2);
        check(!c.badgesLoading&&!c.badgeCache.exists("guest"),"Reconnect resets the in-flight lookup and ignores results from the old session");c.disconnect();

        var apiFixture=GroupApiTest.setup(),a=apiFixture.a;w=apiFixture.w;
        var result:Map<String,String>=null,errors=0;a.onError=(_)->errors++;
        var accounts=[for(i in 0...55)"guest-"+i];accounts.unshift("invalid account");accounts.unshift("guest-0");
        a.applicantBadges(accounts,r->result=r);j=w.take("POST",GroupProtocol.BADGES);ids=haxe.Json.parse(j.body).accounts;
        check(ids.length==50&&ids.filter(id->id=="guest-0").length==1&&ids.indexOf("invalid account")<0,"API limits requests to 50 valid, unique accounts");
        w.reply(j,{badges:{}});GroupApiTest.tick(a);check(result!=null&&!result.iterator().hasNext(),"An empty badge map is a valid no-badge result");
        for(data in ([{badges:[]},{badges:"wrong"},{badges:2},{},"wrong",false]:Array<Dynamic>)) {
            a.applicantBadges(["guest"],r->result=r);j=w.take("POST",GroupProtocol.BADGES);w.reply(j,data);GroupApiTest.tick(a);
            check(result==null&&errors==0&&a.ready,"Malformed badge data fails quietly without invalidating authentication: "+haxe.Json.stringify(data)+", errors="+errors+", ready="+a.ready);
        }
        a.applicantBadges(["guest"],r->result=r);j=w.take("POST",GroupProtocol.BADGES);w.reply(j,{error:"invalid_origin"},403);GroupApiTest.tick(a);
        check(result==null&&a.ready&&errors==0,"Public badge denial never signs the user out");
        check(GroupProtocol.validUrl(fareverly.Protocol.ORIGIN+GroupProtocol.BADGES)&&!GroupProtocol.validUrl("https://example.com"+GroupProtocol.BADGES),"Badge endpoint is restricted to Fareverly");
        a.disconnect();GroupLogin.key="";trace('Group Finder applicant badges passed ($checks checks)');
    }
}
