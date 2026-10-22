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
        TradeChat.echo(player,"seller","Seller","Localized item x2 for 5 Silver Trays.");
        check(G.history.length==2&&G.history[1].text=="Localized item x2 for 5 Silver Trays.");
        var wire=new marketplace.MarketWhisperWire();
        var listing:Dynamic={id:"listing-1",item:{baseId:"Sword",name:"Buyer's Language",
            quantity:2,rarity:"Epic",native:{upgrade:5,slots:["A","B"],infusion:"Skill"}},
            price:{mode:"fixed",silverTrays:5}};
        var packet=marketplace.MarketWhisperWire.packet(listing,"seller");
        var parts=marketplace.MarketWhisperWire.encode(packet);
        check(parts.length>=2&&parts[0].indexOf(marketplace.MarketWhisperWire.PREFIX)==0);
        var complete:Dynamic=null;
        for(i in 0...parts.length) {
            var p=parts.length-1-i,found=wire.receive("buyer",parts[p],100);
            if(found!=null)complete=found;
        }
        check(complete!=null&&complete.item.native.slots[1]=="B"&&complete.item.native.upgrade==5);
        check(complete.price.silverTrays==5&&complete.item.name=="Buyer's Language");
        check(marketplace.MarketWhisperWire.display(complete,kind->"Seller's translated sword")
            =="Hi! I'm interested in your marketplace listing: Seller's translated sword x2 for 5 Silver Trays.");
        for(part in parts)check(wire.receive("buyer",part,101)==null); // Duplicate native chat delivery.
        check(wire.receive("other","!winkmarket1:not-real:0:1:!!",101)==null);
        check(!marketplace.MarketWhisperWire.isPacket("Hi, ordinary whisper"));
        var longItem:Dynamic={id:"big",item:{baseId:"Sword",quantity:1,detail:StringTools.rpad("x","x",18000)},
            price:{mode:"offers"}};
        var tooLarge=false;try marketplace.MarketWhisperWire.encode(marketplace.MarketWhisperWire.packet(longItem,"seller"))catch(_:Dynamic)tooLarge=true;
        check(tooLarge);
        Sys.println("Whisper checks passed: "+checks);
    }
}
