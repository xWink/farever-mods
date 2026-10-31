import groupfinder.GroupController;
import groupfinder.GroupApi;
import groupfinder.GroupLogin;
import groupfinder.GroupProtocol;
import groupfinder.GroupWire;
import groupfinder.GameAccess as G;
import GroupApiTest.FakeGroups;

@:access(GroupApiTest)
class GroupInviteTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function setup(id:String,owned:Bool):{c:GroupController,w:FakeGroups,me:Dynamic,app:Dynamic,row:Dynamic} {
        var w=new FakeGroups(),c=new GroupController(null,new GroupApi(w));
        c.live.random=()->haxe.io.Bytes.ofHex("00112233445566778899aabbccddeeff00");
        var me:Dynamic={uid:id,name:id,isMe:true,hero:{removed:false},heroData:{kind:"Mage",level:25},chatClient:{},whispers:{__host:{}},accountProgress:{social:{ignoreList:{array:[]}}}};
        me.group={__uid:"group-"+id,groupId:"0",players:{array:[{uid:id,name:id,heroData:{kind:"Mage",level:25}}]}};
        var app:Dynamic={me:me};c.update(app,0);w.event("ready");w.event("heartbeat-attempted");c.update(app,.1);
        var row=GroupApiTest.row(GroupApiTest.ID,id);row.partyId=c.party.partyId;row.members[0].name=id;
        w.reply(w.take("GET","categories"),GroupApiTest.metadata());w.reply(w.take("GET","mine"),{listing:owned?row:null});c.update(app,.2);
        return {c:c,w:w,me:me,app:app,row:row};
    }
    static function receive(c:GroupController,me:Dynamic,from:String,wire:String):Void {
        c.receive(me.chatClient,{sender:{uid:from,name:from},channel:G.enumValue("st.Channel","Player",[from,from]),notify:null},wire);
    }
    static function lastWire():String return G.enumArgument(G.sent[G.sent.length-1].packet,0).text;
    public static function run():Void {
        GroupLogin.key=GroupApiTest.KEY;
        var owner=setup("leader",true),applicant=setup("applicant",false),listing=GroupProtocol.listing(owner.row);
        var member=applicant.c.party.members[0];
        applicant.c.requests.add(listing,member,false,.2,GroupApiTest.ID2,"leader","leader");
        receive(owner.c,owner.me,"applicant",GroupWire.encode("request",GroupApiTest.ID2,listing.id,member));
        var incoming=owner.c.requests.rows[0],outgoing=applicant.c.requests.rows[0];owner.c.answer(incoming,true);
        var invited=lastWire();receive(applicant.c,applicant.me,"leader",invited);
        check(incoming.state=="invited"&&outgoing.state=="invited","Both clients record the native invitation");
        var native:Dynamic={kind:"PlayerGroupInvited",targetPlayer:applicant.me,fromPlayer:owner.me,args:{leader:"leader"}};
        applicant.c.invitationSelected(native,true,"Ok");applicant.c.invitationSelected(native,false,"NotAllowed_");
        native.kind="SomethingElse";applicant.c.invitationSelected(native,false,"Ok");native.kind="PlayerGroupInvited";
        native.targetPlayer=owner.me;applicant.c.invitationSelected(native,false,"Ok");native.targetPlayer=applicant.me;
        native.fromPlayer={uid:"unrelated"};applicant.c.invitationSelected(native,false,"Ok");native.fromPlayer=owner.me;
        check(outgoing.state=="invited","Accepted, invalid, unrelated, and another player's notifications are unaffected");
        applicant.c.invitationSelected(native,false,"Ok");var refused=lastWire();
        check(outgoing.state=="invite-declined"&&GroupWire.decode(refused).op=="invite-declined","Native refusal becomes a distinct application state and protocol response");
        receive(owner.c,owner.me,"spoofed",refused);check(incoming.state=="invited","Unrelated accounts cannot withdraw another applicant's invitation");
        receive(owner.c,owner.me,"applicant",refused);check(incoming.state=="invite-declined","Owner history records Invitation declined");
        receive(applicant.c,applicant.me,"leader",invited);check(outgoing.state=="invite-declined","Late invitation acknowledgments cannot restore the refused state");
        check(!owner.c.requests.isDeclined(listing.id,"applicant")&&!applicant.c.requests.isDeclined(listing.id,"applicant"),"Refusing an invitation does not apply the leader's decline lockout");
        applicant.c.request(listing);applicant.w.reply(applicant.w.take("GET","/listings/"+listing.id+"?"),owner.row);applicant.c.update(applicant.app,.3);
        var replacement=applicant.c.requests.rows[0];receive(owner.c,owner.me,"applicant",lastWire());
        check(replacement.id!=outgoing.id&&replacement.state=="pending"&&owner.c.requests.rows[0].state=="pending"&&owner.c.requests.rows.length==2,"Immediate reapplication creates a fresh pending row on both clients");
        owner.c.answer(owner.c.requests.rows[0],true);receive(applicant.c,applicant.me,"leader",lastWire());
        native.fromPlayer=null;applicant.c.invitationSelected(native,false,"Ok");
        check(replacement.state=="invite-declined","Cross-zone invitations correlate an unambiguous leader name");
        receive(owner.c,owner.me,"applicant",lastWire());
        var other=GroupProtocol.listing(GroupApiTest.row(GroupApiTest.ID2,"other-leader"));
        applicant.c.requests.add(other,member,false,.3,"00000000-0000-4000-8000-000000000003","other-leader","leader");
        applicant.c.requests.add(listing,member,false,.3,"00000000-0000-4000-8000-000000000004","leader","leader");
        var pending=applicant.c.requests.rows[0],sent=G.sent.length;
        applicant.c.invitationSelected(native,false,"Ok");
        check(pending.state=="pending"&&G.sent.length==sent,"Ambiguous cross-zone leader names do not change or notify the wrong application");
        native.fromPlayer=owner.me;applicant.c.invitationSelected(native,false,"Ok");
        check(pending.state=="invite-declined"&&applicant.c.requests.rows[1].state=="pending","Native sender ID resolves the right application even before its invitation acknowledgment arrives");
        owner.w.reply(owner.w.take("PATCH","/party"),{id:listing.id,revision:2,closed:false});owner.c.update(owner.app,.3);
        owner.row.revision=2;owner.w.reply(owner.w.take("GET","mine"),{listing:owner.row});owner.c.update(owner.app,.4);
        var rows=owner.c.requests.rows.copy();owner.c.showRequests();owner.c.refreshRequests();
        var refresh=owner.w.take("GET","mine");check(refresh!=null&&owner.c.page=="requests","Refresh checks the current owned listing with Fareverly");
        owner.w.reply(refresh,{listing:owner.row});owner.c.update(owner.app,.5);
        check(owner.c.requests.rows.length==rows.length&&owner.c.requests.rows[0]==rows[0],"Refresh preserves request history instead of turning invitations into applications");
        owner.c.disconnect();applicant.c.disconnect();GroupLogin.key="";
        trace('Group Finder invitation replies passed ($checks checks)');
    }
}
