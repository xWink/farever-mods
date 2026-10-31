import groupfinder.GroupGame;
import groupfinder.GroupNotices;
import groupfinder.GameAccess as G;

class GroupNoticeTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    public static function run():Void {
        GroupGame.notify("badword <img> [icon] $token wants to join.");
        var message=G.notifications[G.notifications.length-1];message.localStamp=100.;
        var label:Dynamic={text:"Original native [System] line"},row:Dynamic={message:message,msgText:label};
        GroupNotices.decorate(row,160.,new Date(2026,9,30,12,34,0).getTime());
        var text=G.text(label.text);
        check(text.indexOf('color="#FFA64D"')>=0&&text.indexOf("[System]")<0,"Group Finder notification uses orange without the System prefix");
        check(text.indexOf("12:33")>=0&&text.indexOf("Group Finder")>=0,"Receipt timestamp and mod label remain visible");
        check(text.indexOf("*******")>=0&&text.indexOf("&lt;img&gt;")>=0&&text.indexOf("&#91;icon]")>=0&&text.indexOf("&#36;token")>=0,"Notification names still use profanity filtering and safe native text escaping");
        check(G.text(message.text).indexOf("badword")>=0&&message.channel=="AllSystem"&&message.sender==null,"Display styling preserves native message history and channel");
        GroupNotices.decorate(row,160.,new Date(2026,9,30,12,34,0).getTime());check(label.text==text,"Rebuilding a native chat row does not duplicate timestamps or colour tags");
        message.args=null;label.text="Unrelated system message";GroupNotices.decorate(row);
        check(label.text=="Unrelated system message","Ordinary game system messages keep their native appearance");
        trace('Group Finder notification styling passed ($checks checks)');
    }
}
