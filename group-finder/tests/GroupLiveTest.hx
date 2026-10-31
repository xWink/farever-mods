import groupfinder.GroupTypes;
import groupfinder.GroupController;
import groupfinder.GroupApi;
import groupfinder.GroupLogin;
import groupfinder.GroupProtocol;
import groupfinder.GroupWire;
import groupfinder.GameAccess as G;
import GroupApiTest.FakeGroups;
@:access(GroupApiTest)
class GroupLiveTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    public static function run():Void {
        GroupLogin.key=GroupApiTest.KEY;
        var w=new FakeGroups(),api=new GroupApi(w),c=new GroupController(null,api);
        api.random=()->haxe.io.Bytes.ofHex("00112233445566778899aabbccddeeff00");
        var me:Dynamic={uid:"self",name:"Wink",isMe:true,hero:{removed:false},heroData:{kind:"Mage",level:25},chatClient:{},whispers:{__host:{}},accountProgress:{social:{ignoreList:{array:[]}}}};
        me.group={groupId:"native-solo",players:{array:[{uid:"self",name:"Wink",heroData:{kind:"Mage",level:25}}]}};
        var initialParty=groupfinder.GroupGame.capture(me).partyId;
        var app:Dynamic={me:me};c.update(app,0);w.event("ready");w.event("heartbeat-attempted");c.update(app,.1);
        w.reply(w.take("GET","categories"),GroupApiTest.metadata());w.reply(w.take("GET","mine"),{listing:null});c.update(app,.2);c.open();
        var peer=GroupApiTest.row(GroupApiTest.ID,"leader");w.reply(w.take("GET","listings?"),{listings:[peer],nextCursor:null,categoryCounts:{dungeons:1}});c.update(app,.3);
        check(c.message==""&&c.rows.length==1,"Successful browsing leaves no footer status");
        check(G.buttons.filter(b->b.text=="Add sample request").length==0,"Production UI has no sample controls");
        G.sent=[];c.request(c.rows[0]);check(G.sent.length==0,"No whisper before uncached listing check");
        var detail=w.take("GET","/listings/"+GroupApiTest.ID+"?");w.reply(detail,peer);c.update(app,.4);
        check(G.sent.length==1&&G.sent[0].to=="leader","Fresh listing sends exactly one native private request");
        var request=c.requests.rows[0];check(request.state=="pending"&&c.message=="","Pending state stays on card without footer information");
        var message:Dynamic={sender:{uid:"wrong",name:"Wrong"},channel:G.enumValue("st.Channel","Player",["wrong","Wrong"]),notify:null};
        var wire=GroupWire.encode("declined",request.id,request.listingId);
        c.receive(me.chatClient,message,wire);check(request.state=="pending","Unrelated account cannot answer another leader's request");
        message.sender={uid:"leader",name:"Leader"};message.channel=G.enumValue("st.Channel","Player",["leader","Leader"]);
        c.receive(me.chatClient,message,wire);check(request.state=="declined","Leader decline updates requester state");
        check(G.notifications.filter(n->G.text(n.text).indexOf("declined your request")>=0).length==1,"Decline appears in native message UI");
        c.update(app,11);c.request(c.rows[0]);detail=w.take("GET","/listings/"+GroupApiTest.ID+"?");
        // Change native party while detail is in flight, before the half-second snapshot poll.
        me.group.players.array.push({uid:"new-member",name:"Member",heroData:{kind:"Rogue",level:25}});check(groupfinder.GroupGame.capture(me).partyId==initialParty,"Solo party ID stays stable when the first member joins");w.reply(detail,peer);c.update(app,11.1);
        check(G.sent.length==1,"No stale request after joining during detail HTTP call");
        me.group.players.array.pop();c.update(app,12);c.request(c.rows[0]);w.reply(w.take("GET","/listings/"+GroupApiTest.ID+"?"),peer);c.update(app,12.1);
        check(c.requests.rows[0].state=="pending","Fresh request after cooldown succeeds");c.close();
        me.group.players.array.push({uid:"new-member",name:"Member",heroData:{kind:"Rogue",level:25}});c.update(app,13);
        check(c.requests.rows[0].state=="cancelled"&&G.sent.length==3,"Joining while closed sends cancellation to the leader");
        check(GroupWire.decode(G.enumArgument(G.sent[2].packet,0).text).op=="cancel","Cancellation is a protocol packet");
        c.disconnect();GroupLogin.key="";
        trace('Group Finder live controller passed ($checks checks)');
    }
}
