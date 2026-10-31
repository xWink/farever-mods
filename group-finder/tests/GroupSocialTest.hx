import groupfinder.GroupController;
import groupfinder.GroupFrame;
import groupfinder.GameAccess as G;

/** Real controller polling with native-shaped party and ignore-list snapshots. */
class GroupSocialTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function member(id:String):Dynamic return {uid:id,name:"Same Name",heroData:{kind:"Mage",level:25}};
    static function player(id:String):Dynamic {
        var p:Dynamic={uid:id,name:"Same Name",heroData:{kind:"Mage",level:25},accountProgress:{social:{ignoreList:{array:[]}}}};
        p.group={__uid:"solo-"+id,groupId:"0",players:{array:[member(id)]}};return p;
    }
    static function titleVisible(title:String):Bool return G.labels.filter(l->l.text==title).length>0;
    public static function run():Void {
        var a:Dynamic=player("leader-a"),b:Dynamic=player("leader-b");
        var ga=groupfinder.GroupGame.capture(a),gb=groupfinder.GroupGame.capture(b);
        check(ga.partyId!=gb.partyId,"Unreplicated groupId zero cannot collide across solo players");
        b.group.__uid=a.group.__uid;gb=groupfinder.GroupGame.capture(b);
        check(ga.partyId!=gb.partyId,"Same network UID on another server is scoped to its leader");
        a.group.players.array.push(member("leader-b"));b.group=a.group;
        check(groupfinder.GroupGame.capture(a).partyId==ga.partyId&&groupfinder.GroupGame.capture(b).partyId==ga.partyId,"All party members agree and roster growth retains identity");
        a.group.players.array.pop();b.group={__uid:a.group.__uid,groupId:"0",players:{array:[member("leader-b")]}};
        check(groupfinder.GroupGame.capture(a).partyId==ga.partyId&&groupfinder.GroupGame.capture(b).partyId!=ga.partyId,"Leaving creates an independent identity without changing the original leader's listing");
        a.group.__uid="9223372036854775807";var full=groupfinder.GroupGame.capture(a);
        a.group.__uid="9223372032559808511";var other=groupfinder.GroupGame.capture(a);
        check(full.partyId!=other.partyId&&full.partyId.length<=128&&full.nativePartyId=="9223372036854775807","Party identity preserves all 64 bits and fits the API bound");
        var c=new GroupController(new groupfinder.MockGroupService()),me=player("social-tester"),app:Dynamic={me:me};
        c.update(app,0);c.open();c.update(app,0.2);
        check(c.rows.length==13&&c.visibleListings().length==13,"Initial listings are available");
        check(G.labels.filter(l->l.text=="Choose a group and request to join."||~/^\d+ groups?$/.match(G.text(l.text))).length==0,"Browse helper and group-count text are removed");
        var viewport=G.nodes.filter(n->StringTools.startsWith(n.id,"groupViewport"))[0];
        check(viewport.y==70&&viewport.height==558,"Listings use the freed header space");
        var hidden=c.rows[0],sameName=c.rows[4],otherMember=c.rows[2].members[1];
        me.accountProgress.social.ignoreList.array=[{uid:hidden.ownerId,name:"An old character name"},{uid:otherMember.accountId,name:"Same Name"}];
        var sourceRevision=c.mock.revision;
        c.update(app,0.5);
        check(c.rows.length==13&&c.visibleListings().length==12,"Ignore hides the owner's listing without destroying fetched data");
        check(!titleVisible(hidden.title)&&titleVisible(sameName.title)&&titleVisible(c.rows[2].title),"Filtering uses the owner's account ID, not display names or other party members");
        check(G.buttons.filter(b->b.text=="Dungeons  (7)").length==1,"Category count excludes hidden listings");
        me.accountProgress.social.ignoreList.array=[];c.update(app,1.0);
        check(c.visibleListings().length==13&&titleVisible(hidden.title)&&c.mock.revision==sourceRevision,"Unignore restores a listing without another API update");
        // An ignore made after render must also invalidate a stale click.
        me.accountProgress.social.ignoreList.array=[{uid:hidden.ownerId,name:"Ignored"}];c.request(hidden);
        check(c.requests.rows.length==0&&c.message=="This listing is no longer available.","Request handler rechecks the native ignore list");
        me.accountProgress.social.ignoreList.array=[];c.open();c.update(app,1.2);
        var join=G.buttons.filter(b->b.text=="Request to join")[0];
        var x=G.number(join.x),y=G.number(join.y),width=G.number(join.width);
        join.action();c.view.update(true);
        var cancel=G.buttons.filter(b->b.text=="Cancel request")[0];
        check(cancel.x==x&&cancel.y==y&&cancel.width==width,"Request and Cancel buttons occupy the same position");
        var status=G.nodes.filter(n->StringTools.startsWith(n.id,"groupRequestStatus"))[0];
        check(status.y>=cancel.y+cancel.height&&G.number(status.y)+G.number(status.height)*G.number(status.scaleY)<100,"Compact pending status fits below the button inside the listing");
        c.request(c.rows[1]);check(c.requests.rows.filter(r->r.state=="pending").length==2,"Several outgoing requests can be pending");
        c.close();var leader:Dynamic=member("leader");me.group={__uid:"joined-party",groupId:"0",players:{array:[leader,member("social-tester")]}};
        c.update(app,1.5);
        check(!c.opened&&c.requests.rows.filter(r->r.state=="cancelled").length==2,"Joining cancels all outgoing requests while the window is closed");
        var revision=c.requests.revision;c.update(app,2.0);
        check(c.requests.revision==revision,"Continued party polling does not repeatedly cancel requests");
        me.group={__uid:"solo-again",groupId:"0",players:{array:[member("social-tester")]}};c.update(app,12.0);c.request(c.rows[0]);
        check(c.requests.rows[0].state=="pending","Leaving a party permits a fresh request after cooldown");
        me.group.__uid="new-group-before-roster";c.update(app,12.5);
        check(c.requests.rows[0].state=="cancelled","Party-ID transition cancels even before the roster arrives");
        c.update(app,24);c.request(c.rows[1]);me.group.players.array.push(leader);c.update(app,24.5);
        check(c.requests.rows[0].state=="cancelled","Growing from solo to a group also cancels without a party-ID change");
        c.disconnect();check(GroupFrame.active==0,"Social tests leave no open window");
        trace('Group Finder social and request UI passed ($checks checks)');
    }
}
