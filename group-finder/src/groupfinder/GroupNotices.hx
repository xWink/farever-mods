package groupfinder;

import groupfinder.GameAccess as G;

/** Restyle only client-local Group Finder rows, retaining native history/layout. */
class GroupNotices {
    public static inline var ORANGE=0xFFA64D;
    public static function decorate(row:Dynamic,?now:Float,?wallTime:Float):Void {
        var message=G.field(row,"message"),label=G.field(row,"msgText");
        if(label==null||G.field(message,"sender")!=null||G.field(message,"notify")!=null
            ||G.enumName(G.field(message,"channel"))!="AllSystem"
            ||G.field(G.field(message,"args"),"groupFinderNotice")!=true)return;
        if(now==null)now=haxe.Timer.stamp();if(wallTime==null)wallTime=Date.now().getTime();
        var stamp=G.number(G.field(message,"localStamp"),now);
        var elapsed=Math.isFinite(stamp)?Math.max(0,now-stamp):0;
        var date=Date.fromTime(wallTime-elapsed*1000);
        var timestamp="["+StringTools.lpad(Std.string(date.getHours()),"0",2)+":"+StringTools.lpad(Std.string(date.getMinutes()),"0",2)+"] ";
        // Keep the native receipt timestamp, omit only its [System] label, and
        // filter/escape player names before adding our own colour markup.
        var content=GroupGame.filtered(timestamp+G.text(G.field(message,"text")));
        G.call("ui.comp.FmtText","set_text",label,['<font color="#'+StringTools.hex(ORANGE,6)+'">'+content+'</font>']);
    }
}
