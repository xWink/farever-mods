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
        var c=new GroupController();
        c.party={accountId:"me",partyId:"party",leaderId:"me",region:"europe",members:[{accountId:"me",name:"Tester",className:"Mage",level:25}]};
        c.mock.observe(c.party);c.mock.examples("europe",true);c.open();pump(c);
        check(G.labels.filter(l->["LOCAL PREVIEW","YOUR PARTY","Only visible to you","Sample group"].indexOf(l.text)>=0).length==0,"Removed redundant labels");
        check(G.buttons.filter(b->b.text=="Create listing").length==1&&button("Create listing").y==620,"Create listing only at sidebar bottom");
        check(button("Requests").y==574&&!button("Requests").enable,"Requests at bottom, disabled without listing");
        button("Requests").action();check(c.page=="browse","Disabled request button cannot navigate");
        c.showRequests();check(c.page=="browse","Controller guards request navigation too");
        check(G.nodes.filter(n->StringTools.startsWith(n.id,"groupClass")&&n.icon=="MageBanner").length>0,"Native class icon replaces class label");
        check(G.labels.filter(l->l.text=="Mage • Lv. 25").length==0,"Class name removed from member details");
        check(G.buttons.filter(b->StringTools.startsWith(b.text,"World Events")).length==1,"Three categories");
        var viewport=G.nodes.filter(n->StringTools.startsWith(n.id,"groupViewport"))[0];
        check(viewport.overflow=="Scroll"&&viewport.scrollBar.visible==true,"Long lists scroll");
        check(viewport.y+viewport.height<644,"Scrollbar clears footer");
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
        input.input.text=[for(_ in 0...31)"x"].join("");input.onChange();render(c);
        check(!button("Create listing").enable,"Too-long title disables submission");
        input.input.text="badword <img> [token] $token";input.onChange();button("Create listing").action();pump(c);pump(c);
        check(c.mine()!=null,"Create appears locally");
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
        c.receiveRequest(c.mine().id,c.requests.rows[0].member);check(G.notifications.length==1,"Duplicate request does not duplicate notification");
        button("Decline").action();render(c);check(c.requests.rows[0].state=="declined","Decline updates request");
        button("Add sample request").action();render(c);button("Accept").action();render(c);
        check(c.requests.rows[0].state=="invited"&&c.party.members.length==1,"Accept stays simulated");
        for(i in 0...10) {c.previewRequest();c.answer(c.requests.rows[0],true);}
        render(c);
        check(c.requests.rows.length==12&&c.requests.rows.filter(r->r.state=="invited").length==11,"Sample request identities and invitation count are unlimited");
        check(G.notifications.length==12,"Each new sample request notifies exactly once");
        c.choose("World Events");render(c);button("Close").action();render(c);
        check(c.mine()!=null,"Close requires confirmation");button("Confirm").action();pump(c);pump(c);
        check(c.mine()==null,"Delete removes local listing");
        check(c.requests.rows.length==0&&!button("Requests").enable,"Closing listing clears inbox and disables Requests");
        button("Create listing").action();render(c);input=G.nodes.filter(n->n.id=="groupTitleInput")[0];
        input.input.text="Second listing";input.onChange();button("Create listing").action();pump(c);pump(c);
        c.previewRequest();render(c);check(c.requests.rows.length==1,"Reposted listing starts with a fresh inbox");
        c.party.leaderId="someone else";c.mock.observe(c.party);c.syncListing();render(c);
        check(c.requests.rows.length==0&&c.page=="browse"&&!button("Requests").enable,"Automatic leadership closure resets requests and leaves tab");
        c.party.leaderId=c.party.accountId;c.mock.observe(c.party);c.edit();c.draftTitle="Third listing";c.save();pump(c);pump(c);
        c.close();c.receiveRequest(c.mine().id,{accountId:"while-closed",name:"Night Owl",className:"Cleric",level:17});
        check(G.text(G.notifications[G.notifications.length-1].text).indexOf("Night Owl")>=0&&!c.opened,"Notification also works with finder closed");
        c.close();check(GroupFrame.active==0,"Closing disposes native window");
        trace('Group Finder UI passed ($checks checks)');
    }
}
