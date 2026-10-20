import trade.TradeChat;
import trade.GameAccess as G;
class ChatTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Chat assertion "+checks;}
    static function main():Void {
        var client:Dynamic={removed:false};
        var player:Dynamic={uid:"buyer",isMe:true,chatClient:client,whispers:{__host:{}},removed:false};
        var replies=0,result=false;
        function reply(ok:Bool):Void {replies++;result=ok;}
        TradeChat.send(player,"seller","Seller","I'd like to buy this.",reply,true);
        check(G.history.length==0&&replies==0);
        G.delivery(true);
        check(replies==1&&result&&G.history.length==1);
        var echo=G.history[0];
        check(echo.text=="I'd like to buy this."&&echo.sender.uid=="buyer"&&echo.sender.name=="Buyer");
        check(G.enumName(echo.channel)=="Player"&&G.enumArgument(echo.channel,0)=="seller"&&G.enumArgument(echo.channel,1)=="Seller");
        check(G.enumArgument(G.sent,0)==echo);
        G.delivery(true);check(G.history.length==1&&replies==1);
        TradeChat.send(player,"seller","Seller","Failed delivery",reply,true);G.delivery(false);
        check(!result&&G.history.length==1);
        TradeChat.send(player,"seller","Seller","Private protocol packet",reply);G.delivery(true);
        check(result&&G.history.length==1);
        TradeChat.send(player,"seller","Seller","Old session",reply,true);
        player.chatClient={};G.delivery(true);check(result&&G.history.length==1);
        player.chatClient=client;
        TradeChat.send(player,"seller","Seller","Removed player",reply,true);
        player.removed=true;G.delivery(true);check(result&&G.history.length==1);
        player.removed=false;
        TradeChat.send(player,"buyer","Buyer","Self",reply,true);check(!result&&G.history.length==1);
        Sys.println("Whisper checks passed: "+checks);
    }
}
