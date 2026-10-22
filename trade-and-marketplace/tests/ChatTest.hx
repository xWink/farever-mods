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
        check(TradeChat.isLocalMarketWhisper(client,player,echo));
        // Received whispers have Player channel addressing the sender, not
        // the recipient. Both this case and the sender's echo must localize.
        var incoming:Dynamic={sender:{uid:"seller"},
            channel:G.enumValue("st.Channel","Player",["seller","Seller"]),notify:null};
        check(TradeChat.isLocalMarketWhisper(client,player,incoming));
        incoming.channel=G.enumValue("st.Channel","Player",["other","Other"]);
        check(!TradeChat.isLocalMarketWhisper(client,player,incoming));
        incoming.channel=G.enumValue("st.Channel","Global",[]);
        check(!TradeChat.isLocalMarketWhisper(client,player,incoming));
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
        var listing:Dynamic={id:"listing-1",item:{baseId:"Sword_Epic",name:"Buyer's English name",
            quantity:2,rarity:"Epic",native:{upgrade:5,slots:["A","B"],infusion:"Skill"}},
            price:{mode:"fixed",silverTrays:5}};
        var text=marketplace.MarketWhisperMessage.message(listing);
        check(text=="Hi! I'm interested in your marketplace listing: Sword_Epic x2 for 5 Silver Trays.");
        check(text.length<160&&text.indexOf("winkmarket")==-1);
        check(marketplace.MarketWhisperMessage.isMessage(text));
        check(marketplace.MarketWhisperMessage.localize(text,id->"Épée légendaire")
            =="Hi! I'm interested in your marketplace listing: Épée légendaire x2 for 5 Silver Trays.");
        check(marketplace.MarketWhisperMessage.localize(text,id->"Legendary Sword")
            =="Hi! I'm interested in your marketplace listing: Legendary Sword x2 for 5 Silver Trays.");
        check(marketplace.MarketWhisperMessage.localize(text,id->id)==null);
        check(marketplace.MarketWhisperMessage.localize(text,id->"")==null);
        check(!marketplace.MarketWhisperMessage.isMessage("Ordinary private message"));
        check(!marketplace.MarketWhisperMessage.isMessage("Hi! I'm interested in your marketplace listing: NotValid x0 for 5 Silver Trays."));
        check(!marketplace.MarketWhisperMessage.isMessage("Hi! I'm interested in your marketplace listing: Sword_Epic x2 for 5 Silver Trays. extra"));
        listing.price={mode:"offers"};
        check(marketplace.MarketWhisperMessage.message(listing)
            =="Hi! I'm interested in your marketplace listing: Sword_Epic x2 (open to offers).");
        listing.price={mode:"fixed",silverTrays:1000};listing.item.quantity=10000;
        check(marketplace.MarketWhisperMessage.localize(marketplace.MarketWhisperMessage.message(listing),id->"Épée")
            =="Hi! I'm interested in your marketplace listing: Épée x10000 for 1,000 Silver Trays.");
        listing.item.baseId="Bad\nID";
        var failed=false;try marketplace.MarketWhisperMessage.message(listing)catch(_:Dynamic)failed=true;
        check(failed);
        Sys.println("Whisper checks passed: "+checks);
    }
}
