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
        var sequence=0;api.random=()->{var bytes=haxe.io.Bytes.ofHex("00112233445566778899aabbccddeeff00");bytes.set(15,++sequence);return bytes;};
        var me:Dynamic={uid:"self",name:"Wink",isMe:true,hero:{removed:false},heroData:{kind:"Mage",level:25},chatClient:{},whispers:{__host:{}},accountProgress:{social:{ignoreList:{array:[]}}}};
        me.group={__uid:"native-solo",groupId:"0",players:{array:[{uid:"self",name:"Wink",heroData:{kind:"Mage",level:25}}]}};
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
        c.update(app,11);c.request(c.rows[0]);
        check(c.message==groupfinder.GroupRequests.DECLINED&&G.sent.length==1&&!c.busy,"Declined applicant cannot request the same listing after cooldown");
        c.view.update(true);check(G.buttons.filter(b->b.text=="Request declined"&&!b.enable).length==1,"Declined listing displays a disabled request control");
        peer.id=GroupApiTest.ID2;c.request(GroupProtocol.listing(peer));detail=w.take("GET","/listings/"+GroupApiTest.ID2+"?");
        // Change native party while detail is in flight, before the half-second snapshot poll.
        me.group.players.array.push({uid:"new-member",name:"Member",heroData:{kind:"Rogue",level:25}});check(groupfinder.GroupGame.capture(me).partyId==initialParty,"Solo party ID stays stable when the first member joins");w.reply(detail,peer);c.update(app,11.1);
        check(G.sent.length==1,"No stale request after joining during detail HTTP call");
        me.group.players.array.pop();c.update(app,12);c.request(GroupProtocol.listing(peer));w.reply(w.take("GET","/listings/"+GroupApiTest.ID2+"?"),peer);c.update(app,12.1);
        check(c.requests.rows[0].state=="pending","Fresh request after cooldown succeeds");c.close();
        me.group.players.array.push({uid:"new-member",name:"Member",heroData:{kind:"Rogue",level:25}});c.update(app,13);
        check(c.requests.rows[0].state=="cancelled"&&G.sent.length==3,"Joining while closed sends cancellation to the leader");
        check(GroupWire.decode(G.enumArgument(G.sent[2].packet,0).text).op=="cancel","Cancellation is a protocol packet");
        me.group.players.array.pop();c.update(app,24);c.request(GroupProtocol.listing(peer));w.reply(w.take("GET","/listings/"+GroupApiTest.ID2+"?"),peer);c.update(app,24.1);
        var accepted=c.requests.rows[0],before=G.sent.length;
        c.receive(me.chatClient,message,GroupWire.encode("invited",accepted.id,accepted.listingId));
        check(accepted.state=="invited","Native invitation acknowledgment updates the request");
        me.group={__uid:"leader-group",groupId:"0",players:{array:[{uid:"leader",name:"Leader",heroData:{kind:"Rogue",level:25}},{uid:"self",name:"Wink",heroData:{kind:"Mage",level:25}}]}};
        c.update(app,25);
        check(accepted.state=="joined"&&G.sent.length==before,"Joining the requested group never sends a cancellation whisper");
        c.disconnect();
        // Leader-side native invitation, legacy cancellation, and repeat rejection.
        w=new FakeGroups();api=new GroupApi(w);c=new GroupController(null,api);
        me.group={__uid:"own-group",groupId:"0",players:{array:[{uid:"self",name:"Wink",heroData:{kind:"Mage",level:25}}]}};
        var own=GroupApiTest.row(GroupApiTest.ID,"self");own.partyId=groupfinder.GroupGame.capture(me).partyId;
        c.update(app,0);w.event("ready");w.event("heartbeat-attempted");c.update(app,.1);
        w.reply(w.take("GET","categories"),GroupApiTest.metadata());w.reply(w.take("GET","mine"),{listing:own});c.update(app,.2);
        var guest={accountId:"guest",name:"Guest",className:"Rogue",level:25};
        message.sender={uid:"guest",name:"Guest"};message.channel=G.enumValue("st.Channel","Player",["guest","Guest"]);
        c.receive(me.chatClient,message,GroupWire.encode("request",GroupApiTest.ID2,own.id,guest));
        var incoming=c.requests.rows[0];c.answer(incoming,true);
        check(incoming.state=="invited"&&G.invites[G.invites.length-1]=="guest","Accept sends the native invitation and retains accepted history");
        c.receive(me.chatClient,message,GroupWire.encode("cancel",incoming.id,own.id));
        check(incoming.state=="invited","An older requester cannot overwrite accepted history with automatic cancellation");
        me.group.players.array.push({uid:"guest",name:"Guest",heroData:{kind:"Rogue",level:25}});c.update(app,1);
        check(incoming.state=="joined"&&c.mine()!=null,"Replicated roster marks the accepted request as Joined group");
        var rejected={accountId:"rejected",name:"Rejected",className:"Mage",level:17};
        c.receiveRequest(own.id,rejected,"00000000-0000-4000-8000-000000000003");c.answer(c.requests.rows[0],false);
        var alerts=G.notifications.length,count=c.requests.rows.length,sent=G.sent.length;
        var retryId="00000000-0000-4000-8000-000000000004";
        c.receiveRequest(own.id,rejected,retryId);
        var response=GroupWire.decode(G.enumArgument(G.sent[G.sent.length-1].packet,0).text);
        check(G.notifications.length==alerts&&c.requests.rows.length==count&&G.sent.length==sent+1,"Declined requester with a new ID is rejected without another alert or inbox entry");
        check(response.op=="declined"&&response.id==retryId,"Leader returns a decline for the replacement request ID");
        c.disconnect();GroupLogin.key="";
        trace('Group Finder live controller passed ($checks checks)');
    }
}
