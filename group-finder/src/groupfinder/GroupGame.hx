package groupfinder;

import groupfinder.GameAccess as G;
import groupfinder.GroupTypes;

class GroupGame {
    static var classIcons:Map<String,String>=[];
    /** Use the class's own banner icon from the native unit definition. */
    public static function classIcon(className:String):String {
        if(classIcons.exists(className))return classIcons[className];
        var units=G.field(G.current("Data","unit"),"byId");if(units==null)return "";
        var ids=className=="Cleric"?["Cleric","Priest"]:[className];
        for(id in ids) {
            var unit=G.call("haxe.ds.StringMap","get",units,[id]);
            var icon=G.text(G.field(G.field(unit,"props"),"bannerIcon"));
            if(icon!=""){classIcons[className]=icon;return icon;}
        }
        return "";
    }
    public static function notifyRequest(member:GroupMember):Void {
        var ui=G.current("ui.BaseUI","current");if(ui==null||!G.isA(ui,"ui.GameUI"))return;
        var chat=G.call("ui.GameUI","get_chat",ui);if(chat==null)return;
        var line=G.create("ui.hud.ChatBoxLine",[G.field(chat,"messages")]),label=G.field(line,"msgText");
        var message="[Group Finder] "+member.name+" ("+GroupRules.memberText(member)+") requested to join your group. Open /lfg to review.";
        G.call("ui.comp.FmtText","set_text",label,[filtered(message)]);
        G.call("h2d.Text","set_textColor",label,[0xF1D28A]);GroupUi.style(label,"color",0xF1D28A);
        G.set(label,"dropShadow",{color:0,alpha:0.9,dx:1.0,dy:1.0});
    }
    public static function capture(player:Dynamic):Null<GroupParty> {
        var account=G.text(G.field(player,"uid")),group=G.field(player,"group");
        if(account==""||group==null)return null;
        var players=G.array(G.field(group,"players"),true);
        if(players.length==0)return null;
        var members=[for(p in players)member(p)];
        var leader=G.call("st.Group","get_leader",group);
        var region=regionId(G.text(G.current("Options","serverRegion")));
        return {accountId:account,partyId:G.text(G.field(group,"groupId")),leaderId:G.text(G.field(leader,"uid")),region:region,members:members};
    }
    public static function member(player:Dynamic):GroupMember {
        var hero=G.field(player,"hero"),data=G.field(player,"heroData");
        var kind=G.text(G.field(data,"kind"));
        if(kind=="")kind=G.text(G.field(G.field(hero,"inf"),"id"));
        if(kind=="")kind=G.text(G.field(hero,"kind"));
        var className="";
        for(name in ["Warrior","Rogue","Mage","Cleric"])if(kind.toLowerCase().indexOf(name.toLowerCase())>=0)className=name;
        if(className==""&&kind.toLowerCase().indexOf("priest")>=0)className="Cleric";
        var level=G.integer(G.field(data,"level"));
        if(level<=0&&hero!=null)level=G.integer(G.call("ent.Unit","get_level",hero));
        return {accountId:G.text(G.field(player,"uid")),name:G.text(G.field(player,"name"),"Unknown player"),className:className,level:level};
    }
    public static function regionId(value:String):String return switch(value.toLowerCase()) {
        case "northamerica","north-america","na": "north-america";
        case "europe","eu": "europe";
        case "southamerica","latinamerica","latin-america","sa": "latin-america";
        case "asia","as": "asia";
        case "cn","china","mainlandchina","mainland-china": "mainland-china";
        default: "";
    };
    public static function regionName(value:String):String return switch(value) {
        case "north-america": "North America";
        case "europe": "Europe";
        case "latin-america": "Latin America";
        case "asia": "Asia";
        case "mainland-china": "Mainland China";
        default: "Connecting…";
    };
    /** Native filtering runs on display and therefore honors More Settings too. */
    public static function filtered(value:String):String {
        var clean=G.text(G.staticCall("HText","cleanPlayerText",[value]));
        // cleanPlayerText already escapes HTML. Also disable FmtText's extra tokens.
        return StringTools.replace(StringTools.replace(clean,"[","&#91;"),"$","&#36;");
    }
}
