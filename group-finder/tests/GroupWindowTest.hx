import groupfinder.GroupTypes;
import groupfinder.GroupController;
import groupfinder.GroupFrame;
import groupfinder.GameAccess as G;

class GroupWindowTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function button(label:String):Dynamic {
        var rows=G.buttons.filter(b->b.text==label);check(rows.length>0,"Missing button: "+label);return rows[rows.length-1];
    }
    static function render(c:GroupController):Void c.view.update(true);
    static function pump(c:GroupController):Void {c.mock.tick(c.mock.now+0.2);render(c);}
    static function main():Void {
        var c=new GroupController(new groupfinder.MockGroupService());
        c.party={accountId:"me",partyId:"party",leaderId:"me",region:"europe",members:[{accountId:"me",name:"Tester",className:"Mage",level:25}]};
        c.mock.observe(c.party);c.mock.examples("europe",true);c.open();pump(c);
        check(G.labels.filter(l->["LOCAL PREVIEW","YOUR PARTY","Only visible to you","Sample group"].indexOf(l.text)>=0).length==0,"Removed redundant labels");
        check(G.buttons.filter(b->b.text=="Create listing").length==1&&button("Create listing").y==620,"Create listing only at sidebar bottom");
        check(button("Requests").y==574&&!button("Requests").enable,"Requests at bottom, disabled without listing");
        button("Requests").action();check(c.page=="browse","Disabled request button cannot navigate");
        c.showRequests();check(c.page=="browse","Controller guards request navigation too");
        check(G.nodes.filter(n->StringTools.startsWith(n.id,"groupClass")&&n.tile.id=="MageBanner").length>0,"Native coloured class pennant replaces the emblem");
        for(icon in G.nodes.filter(n->StringTools.startsWith(n.id,"groupClass"))) {
            check(icon.scaleX==icon.scaleY&&icon.tile.width*icon.scaleX<=20&&icon.tile.height*icon.scaleY<=28,"Class pennants keep their aspect ratio and fit the row");
            check(icon.parent.y+icon.y+icon.tile.dy*icon.scaleY==66,"Native tile offsets do not shift the banner");
        }
        for(box in G.nodes.filter(n->StringTools.startsWith(n.id,"groupMemberDetails"))) {
            var icon=(cast box.children:Array<Dynamic>).filter(n->G.field(n,"tile")!=null)[0];
            var level=(cast box.children:Array<Dynamic>).filter(n->G.field(n,"testLabel")==true)[0];
            var center=G.number(icon.tile.height)*G.number(icon.scaleY)/2;
            check(Math.abs(G.number(level.y)+13*G.number(level.scaleY)-center)<0.001,"Level glyphs are centered with the class banner");
            level.inkBounds={xMin:0.,xMax:40.,yMin:3.,yMax:21.};level.nativeScale=0.65;level.needUpdateScale=true;
            box.onAfterReflow();
            check(Math.abs(G.number(level.y)+12*0.65-center)<0.001,"Level alignment follows native font scaling and glyph offsets");
        }
        check(groupfinder.GroupGame.classBanner("Unknown")==null,"Unknown class does not invent a banner");
        check(groupfinder.GroupGame.classBanner("Cleric").id=="PriestBanner","Cleric resolves the native Priest artwork");
        var heading=G.labels.filter(l->l.text=="Heroic dungeon runs")[0];
        check(heading.textColor==0x5B4334&&heading.parent.scaleX==1.25&&heading.maxWidthText*heading.parent.scaleX==530&&(cast heading.dom.classes:Array<String>).indexOf("bold-16")>=0,"Listing titles keep their larger size and match Marketplace item-name colour");
        check(G.labels.filter(l->l.text=="Mage • Lv. 25").length==0,"Class name removed from member details");
        check(G.buttons.filter(b->StringTools.startsWith(b.text,"World Events")).length==1,"Three categories");
        var viewport=G.nodes.filter(n->StringTools.startsWith(n.id,"groupViewport"))[0];
        check(viewport.overflow=="Scroll"&&viewport.scrollBar.visible==true,"Long lists scroll");
        check(viewport.y+viewport.height<644,"Scrollbar clears footer");
        var paints=(cast viewport.parent.children:Array<Dynamic>).filter(n->G.field(n,"shapes")!=null&&G.field(n,"visible")==true);
        check(paints.length==1&&paints[0].shapes[0].color==0xD0BBB2,"Scrollbar cap backing matches the surrounding window body");
        check(button("Request to join").enable&&button("Request to join").kind=="","Solo browsing uses the default enabled join button");
        GroupBadgeTest.run(c);
        var dungeonButton=button("Dungeons  (8)"),eventButton=button("World Events  (3)"),side=dungeonButton.parent;
        eventButton.action();pump(c);
        check(button("World Events  (3)")==eventButton&&eventButton.parent==side&&eventButton.selected,"Category click preserves the hovered native button");
        c.view.dirty=true;render(c);
        check(button("Dungeons  (8)")==dungeonButton&&button("World Events  (3)")==eventButton,"Data refresh preserves category controls");
        eventButton.action();check(!c.view.dirty,"Clicking the current category does not rebuild the UI");
        dungeonButton.action();pump(c);
        button("Create listing").action();render(c);
        var input=G.nodes.filter(n->n.id=="groupTitleInput")[0];
        check(!button("Create listing").enable,"Empty title disables submission");
        check(G.labels.filter(l->l.text=="Listing preview"||StringTools.startsWith(l.text,"Members update with your party")).length==0,"Editor preview and helper text removed");
        input.input.text="badword <img> [token] $token";input.input.cursorIndex=6;input.onChange();render(c);
        check(G.nodes.indexOf(input)>=0,"Typing preserves focused input");
        button("World Events").action();render(c);
        check(G.nodes.indexOf(input)>=0&&input.input.cursorIndex==6&&input.input.text==c.draftTitle,"Category selection preserves input, text, and caret");
        check(button("World Events").selected&&!button("Dungeons").selected,"Category updates in place");
        check(button("Create listing").enable,"Valid title enables submission");
        input.input.text=[for(_ in 0...50)"x"].join("");input.onChange();render(c);
        check(button("Create listing").enable&&G.labels.filter(l->l.text=="50 / 50").length==1,"Editor accepts and counts a 50-character title");
        input.input.text=[for(_ in 0...51)"x"].join("");input.onChange();render(c);
        check(button("Create listing").enable&&c.draftTitle.length==50&&input.input.text==c.draftTitle,"Extra text is clipped at 50 instead of invalidating submission");
        var fifty:String=input.input.text;
        input.input.cursorIndex=10;
        check(c.view.insertTitle(input.input,"y")&&input.input.text==fifty&&input.input.cursorIndex==10,"Typing at the limit is blocked without changing text or caret");
        input.input.selectionRange={start:10,length:2};
        check(c.view.insertTitle(input.input,"ABCDE")&&input.input.text==fifty.substr(0,10)+"AB"+fifty.substr(12)&&input.input.cursorIndex==12,"Pasting over a selection fills available room and preserves the suffix");
        input.input.text="BeforeAfter";input.input.cursorIndex=6;input.input.selectionRange=null;input.onChange();
        check(c.view.insertTitle(input.input,[for(_ in 0...50)"🌟"].join("")),"Long Unicode paste is intercepted");
        check(GroupRules.count(c.draftTitle)==50&&StringTools.endsWith(c.draftTitle,"After")&&input.input.cursorIndex==45,"Unicode paste counts characters and preserves text after the caret");
        check(!c.view.insertTitle({text:fifty},"y"),"Unrelated game text inputs are unaffected");
        input.input.text="badword <img> [token] $token";input.onChange();button("Create listing").action();pump(c);pump(c);
        check(c.mine()!=null,"Create appears locally");
        var join=button("Request to join"),beforeRequests=c.requests.rows.length;
        check(!join.enable&&join.kind=="","Owning a listing disables join buttons without green styling");
        join.action();check(c.requests.rows.length==beforeRequests,"Disabled join button cannot send a request");
        c.request(c.rows.filter(row->row.ownerId!=c.party.accountId)[0]);
        check(c.requests.rows.length==beforeRequests&&c.message=="Close your listing before requesting to join another group.","Request handler also rejects joining while a listing is open");
        check(G.cleaned.indexOf(input.input.text)>=0,"Listing title passes through native profanity filter");
        check(G.labels.filter(l->l.text=="******* &lt;img&gt; &#91;token] &#36;token").length==1,"Listing escapes markup and native tokens");
        check(button("Requests").enable&&button("My listing").y==620,"Own listing enables Requests and changes bottom button");
        button("Edit").action();render(c);
        input=G.nodes.filter(n->n.id=="groupTitleInput")[0];input.input.text="Changed title";input.onChange();
        button("World Events").action();render(c);button("Save changes").action();pump(c);pump(c);
        check(c.mine().title=="Changed title"&&c.category=="World Events","Editing changes category and title");
        c.showRequests();render(c);button("Add sample request").action();render(c);
        check(c.requests.rows.length==1,"Sample request appears");
        var notification=G.text(G.notifications[0].text);
        check(G.notifications.length==1&&notification.indexOf("Willow")>=0&&notification.indexOf("Mage")>=0&&notification.indexOf("25")>=0,"New request sends chat notification with name, class and level");
        check(G.notifications[0].channel=="AllSystem"&&G.notifications[0].sender==null&&G.notifications[0].localStamp!=null,"Alert enters native system-message timestamp and layout pipeline without impersonating a sender");
        c.receiveRequest(c.mine().id,c.requests.rows[0].member);check(G.notifications.length==1,"Duplicate request does not duplicate notification");
        button("Decline").action();render(c);check(c.requests.rows[0].state=="declined","Decline updates request");
        button("Add sample request").action();render(c);
        var requestName=G.nodes.filter(n->StringTools.startsWith(n.id,"groupMemberName"))[0];
        check((cast requestName.children:Array<Dynamic>).filter(n->G.field(n,"nativeType")=="h2d.Bitmap").length==1,"Incoming request also displays its Fareverly badge");
        button("Accept").action();render(c);
        check(c.requests.rows[0].state=="invited"&&c.party.members.length==1,"Accept stays simulated");
        for(i in 0...10) {c.previewRequest();c.answer(c.requests.rows[0],true);}
        render(c);
        check(c.requests.rows.length==12&&c.requests.rows.filter(r->r.state=="invited").length==11,"Sample request identities and invitation count are unlimited");
        check(G.notifications.length==12,"Each new sample request notifies exactly once");
        c.choose("World Events");render(c);button("Close").action();render(c);
        check(c.mine()!=null,"Close requires confirmation");button("Confirm").action();pump(c);pump(c);
        check(c.mine()==null,"Delete removes local listing");
        check(c.requestError()==""&&button("Request to join").enable,"Closing a listing restores the ability to request to join");
        check(c.requests.rows.length==0&&!button("Requests").enable,"Closing listing clears inbox and disables Requests");
        button("Create listing").action();render(c);input=G.nodes.filter(n->n.id=="groupTitleInput")[0];
        input.input.text="Second listing";input.onChange();button("Create listing").action();pump(c);pump(c);
        c.previewRequest();render(c);check(c.requests.rows.length==1,"Reposted listing starts with a fresh inbox");
        c.party.leaderId="someone else";c.mock.observe(c.party);c.syncListing();render(c);
        check(c.requests.rows.length==0&&c.page=="browse"&&!button("Requests").enable,"Automatic leadership closure resets requests and leaves tab");
        c.party.leaderId=c.party.accountId;c.mock.observe(c.party);c.edit();c.draftTitle="Third listing";c.save();pump(c);pump(c);
        c.close();c.receiveRequest(c.mine().id,{accountId:"while-closed",name:"Night Owl",className:"Cleric",level:17});
        check(G.text(G.notifications[G.notifications.length-1].text).indexOf("Night Owl")>=0&&!c.opened,"Notification also works with finder closed");
        c.close();check(G.textures.filter(t->t.disposed!=true).length==0,"Closing releases badge textures");
        check(GroupFrame.active==0,"Closing disposes native window");
        GroupSocialTest.run();
        GroupLiveTest.run();
        GroupTravelTest.run();
        GroupCountdownTest.run();
        trace('Group Finder UI passed ($checks checks)');
    }
}
