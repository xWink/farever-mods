import groupfinder.GroupController;
import groupfinder.GroupTypes;
import groupfinder.GameAccess as G;

@:access(groupfinder.GroupController)
class GroupCountdownTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function label():Dynamic return G.labels.filter(l->StringTools.startsWith(l.text,"Request pending"))[0];
    public static function run():Void {
        var c=new GroupController(new groupfinder.MockGroupService());
        c.party={accountId:"timer",partyId:"timer-party",leaderId:"timer",region:"europe",members:[{accountId:"timer",name:"Timer",className:"Mage",level:25}]};
        c.mock.observe(c.party);c.mock.examples("europe",true);c.open();c.mock.tick(.2);c.view.update(true);
        c.request(c.rows[0]);c.view.update(true);
        var caption=label(),cancel=G.buttons.filter(b->b.text=="Cancel request")[0];
        var pendingColor=caption.textColor;
        check(caption.text=="Request pending • 5:00"&&(cast caption.dom.classes:Array<String>).indexOf("bold-14")>=0,"Applicant sees a bold pending label with the five-minute timer");
        var request=c.requests.rows[0],expiry=request.expiresAt;
        c.now=1;c.view.update(true);
        check(label()==caption&&caption.text=="Request pending • 4:59"&&G.buttons.indexOf(cancel)>=0,"Countdown updates in place without rebuilding hovered controls");
        c.now=61;c.view.update(true);check(caption.text=="Request pending • 3:59"&&request.expiresAt==expiry,"Timer reflects elapsed time without extending expiry");
        c.now=305;c.view.update(true);check(caption.text=="Request pending • 0:00","Remaining time clamps at zero");
        c.requests.tick(c.now,null);c.view.dirty=true;c.view.update(true);
        check(label()==null&&G.buttons.filter(b->b.text=="Cancel request").length==0,"Expired requests remove their countdown and cancel action");
        c.close();c.now=0;c.requests.reset();c.edit();c.draftTitle="Timer group";c.save();c.mock.tick(.4);c.syncListing();
        var own=c.mine();c.receiveRequest(own.id,{accountId:"applicant",name:"Applicant",className:"Rogue",level:25});
        c.open();c.showRequests();c.view.update(true);caption=label();
        var accept=G.buttons.filter(b->b.text=="Accept")[0];
        check(caption.textColor==pendingColor&&pendingColor==0x897360,"Applicant pending label and timer match the owner's colour");
        var refresh=G.buttons.filter(b->b.text=="Refresh")[0];check(refresh!=null&&refresh.x==890,"Requests page has its own Refresh button");
        c.message="Old error";refresh.action();c.view.update(true);caption=label();accept=G.buttons.filter(b->b.text=="Accept")[0];
        check(c.page=="requests"&&c.message==""&&c.requests.rows.length==1,"Refreshing preserves the inbox and Requests page");
        check(caption.text=="Request pending • 5:00"&&(cast caption.dom.classes:Array<String>).indexOf("bold-14")>=0,"Owner sees the same bold pending countdown");
        c.now=240;c.view.update(true);
        check(label()==caption&&caption.text=="Request pending • 1:00"&&G.buttons.indexOf(accept)>=0,"Owner countdown ticks without moving or replacing Accept");
        c.answer(c.requests.rows[0],true);c.view.update(true);
        check(label()==null&&G.labels.filter(l->l.text=="Invitation sent").length==1,"Accepting removes the pending timer from history");
        c.disconnect();trace('Group Finder request countdowns passed ($checks checks)');
    }
}
