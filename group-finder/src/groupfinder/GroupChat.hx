package groupfinder;
import groupfinder.GameAccess as G;
class GroupChat {
    public static function sender(client:Dynamic,player:Dynamic,message:Dynamic):String {
        if(client==null||player==null||G.field(player,"chatClient")!=client||G.field(player,"isMe")!=true)return "";
        var channel=G.field(message,"channel"),uid=G.text(G.field(G.field(message,"sender"),"uid"));
        if(uid==""||uid==G.text(G.field(player,"uid"))||G.field(message,"notify")!=null||G.enumName(channel)!="Player"
            ||G.text(G.enumArgument(channel,0))!=uid)return "";
        return uid;
    }
    public static function send(player:Dynamic,to:String,name:String,text:String,reply:Bool->Void):Void {
        var whispers=G.field(player,"whispers");
        if(whispers==null||G.field(whispers,"__host")==null||to==""||to==G.text(G.field(player,"uid"))){reply(false);return;}
        var data:Dynamic={sender:{uid:G.text(G.field(player,"uid")),name:G.text(G.call("st.Player","getName",player))},
            channel:G.enumValue("st.Channel","Player",[to,name]),text:text,args:null,localStamp:null,localTextId:null,notify:null};
        var packet=G.enumValue("st.player.Message","ChatMessage",[data]);
        if(G.enumName(packet)!="ChatMessage"||G.text(G.field(G.enumArgument(packet,0),"text"))!=text)throw "Could not create the group request whisper.";
        var completed=false;
        G.call("st.player.Whispers","sendMessage",whispers,[to,packet,(ok:Bool)->{if(!completed){completed=true;reply(ok);}}]);
    }
    public static function invite(player:Dynamic,accountId:String):Bool {
        var whispers=G.field(player,"whispers"),group=G.field(player,"group");
        if(whispers==null||group==null||G.field(whispers,"__host")==null)return false;
        // This native method looks up the player on the current server, otherwise
        // sends the game's cross-zone InviteGroup message. No proximity requirement.
        var reason=G.call("st.Group","hasInvitePlayerAllowed",group);
        if(G.enumName(reason)!="Ok")return false;
        G.call("st.player.Whispers","sendInviteGroup",whispers,[accountId]);return true;
    }
}
