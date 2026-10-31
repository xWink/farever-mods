import groupfinder.GroupTypes;
import groupfinder.GroupController;
import groupfinder.GroupFrame;
import groupfinder.GameAccess as G;

class GroupWindowTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function button(label:String):Dynamic {
        var rows=G.buttons.filter(b->b.text==label);check(rows.length>0,"Missing button: "+label);return rows[0];
    }
    static function render(c:GroupController):Void c.view.update(true);
    static function pump(c:GroupController):Void {c.mock.tick(c.mock.now+0.2);render(c);}
    static function main():Void {
        var c=new GroupController();
        c.party={accountId:"me",partyId:"party",leaderId:"me",region:"europe",members:[{accountId:"me",name:"Tester",className:"Mage",level:25}]};
        c.mock.observe(c.party);c.mock.examples("europe",true);c.open();pump(c);
        check(G.labels.filter(l->l.text=="LOCAL PREVIEW").length==1,"Local preview label");
        check(G.buttons.filter(b->StringTools.startsWith(b.text,"World Events")).length==1,"Three categories");
        var viewport=G.nodes.filter(n->StringTools.startsWith(n.id,"groupViewport"))[0];
        check(viewport.overflow=="Scroll"&&viewport.scrollBar.visible==true,"Long lists scroll");
        check(viewport.y+viewport.height<644,"Scrollbar clears footer");
        button("Create listing").action();render(c);
        var input=G.nodes.filter(n->n.id=="groupTitleInput")[0];
        check(!button("Create listing").enable,"Empty title disables submission");
        input.input.text="badword <img> [token] $token";input.onChange();render(c);
        check(G.cleaned.indexOf(input.input.text)>=0,"Title passes through native profanity filter");
        check(G.labels.filter(l->l.text=="******* &lt;img&gt; &#91;token] &#36;token").length==1,"Plain-text preview escapes markup and native tokens");
        check(G.nodes.indexOf(input)>=0,"Typing preserves focused input");
        check(button("Create listing").enable,"Valid title enables submission");
        input.input.text=[for(_ in 0...31)"x"].join("");input.onChange();render(c);
        check(!button("Create listing").enable,"Too-long title disables submission");
        input.input.text="Local test";input.onChange();button("Create listing").action();pump(c);pump(c);
        check(c.mine()!=null&&c.mine().title=="Local test","Create appears locally");
        button("Edit listing").action();render(c);
        input=G.nodes.filter(n->n.id=="groupTitleInput")[0];input.input.text="Changed title";input.onChange();
        button("World Events").action();render(c);button("Save changes").action();pump(c);pump(c);
        check(c.mine().title=="Changed title"&&c.category=="World Events","Editing changes category and title");
        c.showRequests();render(c);button("Add sample request").action();render(c);
        check(c.requests.rows.length==1,"Sample request appears");
        button("Decline").action();render(c);check(c.requests.rows[0].state=="declined","Decline updates request");
        button("Add sample request").action();render(c);button("Accept").action();render(c);
        check(c.requests.rows[0].state=="invited"&&c.party.members.length==1,"Accept stays simulated");
        c.choose("World Events");render(c);button("Close listing").action();render(c);
        check(c.mine()!=null,"Close requires confirmation");button("Confirm close").action();pump(c);pump(c);
        check(c.mine()==null,"Delete removes local listing");
        c.close();check(GroupFrame.active==0,"Closing disposes native window");
        trace('Group Finder UI passed ($checks checks)');
    }
}
