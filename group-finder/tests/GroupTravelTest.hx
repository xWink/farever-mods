import groupfinder.GroupController;
import groupfinder.GroupApi;
import groupfinder.GroupLogin;
import groupfinder.GroupGame;
import groupfinder.GroupProtocol;
import groupfinder.GameAccess as G;
import GroupApiTest.FakeGroups;

@:access(GroupApiTest)
class GroupTravelTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function setup(owned=true):{c:GroupController,w:FakeGroups,me:Dynamic,app:Dynamic} {
        GroupLogin.key=GroupApiTest.KEY;
        var w=new FakeGroups(),c=new GroupController(null,new GroupApi(w));
        var me:Dynamic={uid:"self",name:"Wink",isMe:true,hero:{removed:false},heroData:{kind:"Mage",level:25},chatClient:{},whispers:{__host:{}},accountProgress:{social:{ignoreList:{array:[]}}}};
        me.group={__uid:"world-group",groupId:"0",players:{array:[{uid:"self",name:"Wink",heroData:{kind:"Mage",level:25}}]}};
        var app:Dynamic={me:me};c.update(app,0);w.event("ready");w.event("heartbeat-attempted");c.update(app,.1);
        var row=GroupApiTest.row();row.partyId=c.party.partyId;
        w.reply(w.take("GET","categories"),GroupApiTest.metadata());w.reply(w.take("GET","mine"),{listing:owned?row:null});c.update(app,.2);
        return {c:c,w:w,me:me,app:app};
    }
    static function cleanups(w:FakeGroups):Int return w.jobs.filter(j->j.op=="cleanup").length;
    public static function run():Void {
        var f=setup(),c=f.c,w=f.w,me=f.me,app=f.app,original=c.mine().id,identity=c.party.partyId;
        c.receiveRequest(original,{accountId:"guest",name:"Guest",className:"Mage",level:25},GroupApiTest.ID2);
        var incoming=c.requests.rows[0],generation=w.generation;
        c.beginTravel();app.me=null;c.update(app,1);
        check(c.traveling&&c.mine().id==original&&cleanups(w)==0&&w.generation==generation,"World teardown preserves listing and Fareverly heartbeat session");
        check(c.requests.rows[0]==incoming&&incoming.state=="pending","Travel retains incoming requests");
        me.group.__uid="dungeon-group";me.hero.removed=true;app.me=me;c.update(app,2);
        check(c.mine().id==original&&c.party.partyId==identity,"Partially synchronized destination cannot replace the party snapshot");
        me.hero.removed=false;c.finishTravel();c.update(app,3);
        check(!c.traveling&&c.mine().id==original&&c.party.partyId==identity&&c.party.nativePartyId=="dungeon-group"&&cleanups(w)==0,"Dungeon arrival rebinds the native party without closing or recreating the listing");
        c.update(app,4);check(c.mine().id==original&&c.party.partyId==identity,"Subsequent polling retains the rebound identity");
        c.answer(incoming,true);check(incoming.state=="invited"&&G.invites[G.invites.length-1]=="guest","Accept after travel validates the retained listing identity");
        c.beginTravel();app.me=null;c.update(app,5);me.group.__uid="rift-group";app.me=me;c.finishTravel();c.update(app,6);
        check(c.mine().id==original&&c.party.partyId==identity&&cleanups(w)==0,"A second instance transition retains the same listing");
        me.group.__uid="genuinely-new-party";c.update(app,7);
        check(c.mine()==null&&cleanups(w)==1,"A new group outside a transfer still closes the listing");c.disconnect();

        f=setup();c=f.c;w=f.w;me=f.me;app=f.app;
        c.beginTravel();me.group.players.array.unshift({uid:"new-leader",name:"Leader",heroData:{kind:"Rogue",level:25}});me.group.__uid="changed-leader";c.finishTravel();c.update(app,1);
        check(c.mine()==null&&cleanups(w)==1,"Leadership loss during transfer still closes the listing");c.disconnect();

        f=setup();c=f.c;w=f.w;c.beginTravel();c.disconnect();
        check(c.party==null&&!c.traveling&&cleanups(w)==1,"Logout/disposal during transfer still closes the listing");

        f=setup();c=f.c;w=f.w;c.beginTravel();c.endSession();generation=w.generation;c.update(f.app,1);
        check(c.party==null&&w.generation==generation&&cleanups(w)==1,"Failed transfer closes the listing and does not reconnect behind the leave-game dialog");c.disconnect();

        f=setup(false);c=f.c;w=f.w;me=f.me;app=f.app;
        var peer=GroupProtocol.listing(GroupApiTest.row(GroupApiTest.ID,"leader"));
        c.requests.add(peer,c.party.members[0],false,.2,GroupApiTest.ID2,"leader","Leader");
        var request=c.requests.rows[0],sent=G.sent.length;
        c.beginTravel();app.me=null;c.update(app,1);me.group.__uid="destination-solo";app.me=me;c.finishTravel();c.update(app,2);
        check(request.state=="pending"&&G.sent.length==sent,"Applicant travel does not cancel an unrelated pending request");
        c.disconnect();GroupLogin.key="";
        trace('Group Finder instance transitions passed ($checks checks)');
    }
}
