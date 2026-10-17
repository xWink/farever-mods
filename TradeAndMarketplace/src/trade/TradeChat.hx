package trade;
import trade.GameAccess as G;
class TradeChat {
    public static function isLocalClient(client:Dynamic,player:Dynamic):Bool return client != null && player != null
        && G.field(player,"isMe") == true && G.field(player,"chatClient") == client;
    public static function sender(message:Dynamic):String {
        var channel = G.field(message,"channel");
        if (channel == null || G.field(message,"notify") != null || G.enumName(channel) != "Player") return "";
        var uid = G.text(G.field(G.field(message,"sender"),"uid"));
        return uid != "" && G.text(G.enumArgument(channel,0)) == uid ? uid : "";
    }
    public static function send(player:Dynamic,to:String,name:String,text:String,reply:Bool->Void):Void {
        var whispers = G.field(player,"whispers");
        if (whispers == null || to == "" || to == G.text(G.field(player,"uid"))) { reply(false); return; }
        if (G.field(whispers,"__host") == null) throw "Private whisper service is not connected.";
        var data:Dynamic = {sender:{uid:G.text(G.field(player,"uid")),name:G.text(G.call("st.Player","getName",player))},
            channel:G.enumValue("st.Channel","Player",[to,name]),text:text,args:null,localStamp:null,localTextId:null,notify:null};
        var message = G.enumValue("st.player.Message","ChatMessage",[data]);
        if (G.enumName(message) != "ChatMessage") throw "Could not create the native trade whisper.";
        var check = G.enumArgument(message,0), channel = G.field(check,"channel");
        if (G.text(G.field(check,"text")) != text || G.enumName(channel) != "Player" || G.text(G.enumArgument(channel,0)) != to
            || G.text(G.field(G.field(check,"sender"),"uid")) != G.text(G.field(player,"uid"))) throw "The native trade whisper lost its address or content.";
        G.call("st.player.Whispers","sendMessage",whispers,[to,message,reply]);
    }
}
