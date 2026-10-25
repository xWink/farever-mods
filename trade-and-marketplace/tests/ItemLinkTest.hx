import trade.ItemLinkCodec;
import trade.TradeTypes;

class ItemLinkTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    public static function fixture():TradeItem return {uid:"not-transmitted",kind:"Sword",count:2,name:"not-transmitted",
        detail:"not-transmitted",color:123,fingerprint:"not-transmitted",preview:{flags:3,level:30,upgrade:5,
            rarity:"Epic",infusion:"Warrior_Smash",bonus:"Power",mastery:"",slots:["CorruptedGift","","CorruptedGift"],
            effects:[{skill:"Rogue_Poison",source:"RoguePoison"}]}};
    static function packet(value:Dynamic):String return ItemLinkCodec.PREFIX + haxe.crypto.Base64.urlEncode(
        haxe.zip.Compress.run(haxe.io.Bytes.ofString(haxe.Json.stringify(value)),9)) + "~";
    static function main():Void {
        var source = fixture(), token = ItemLinkCodec.encode(source), decoded = ItemLinkCodec.decode(token);
        check(token != null && token.length < 230,"A fully modified item leaves space in native chat");
        check(decoded != null && decoded.kind == source.kind && decoded.count == 2,"Item identity and stack quantity survive");
        check(haxe.Json.stringify(trade.TradePreview.canonical(decoded.preview)) == haxe.Json.stringify(trade.TradePreview.canonical(source.preview)),
            "Flags, level, upgrades, rarity, infusion, bonus, ordered sockets and effects roundtrip");
        check(decoded.uid == "" && decoded.fingerprint == "" && decoded.name == "" && decoded.color == 0,
            "No player UID, sender's localized name, supplied colour or fingerprint is trusted");
        source.preview.level = 1;
        check(decoded.preview.level == 30,"The link is a snapshot");
        source.preview.mastery = "Mage_Fire";
        check(ItemLinkCodec.decode(ItemLinkCodec.encode(source)).preview.mastery == "Mage_Fire","Mastery item details survive");
        var draft = "Selling café ", combined = ItemLinkCodec.append(draft,token,250);
        check(StringTools.startsWith(combined,draft+token) && StringTools.endsWith(combined," "),"Existing draft survives with room to continue typing");
        check(ItemLinkCodec.append("Selling",token,250) == "Selling "+token+" ","Space separates the token from existing text");
        check(ItemLinkCodec.append("",token,token.length) == token,"Exact-fit links are never clipped");
        check(ItemLinkCodec.append("x",token,token.length) == null,"Full drafts fail atomically");
        check(ItemLinkCodec.append(StringTools.lpad("x","x",250),token,1000) == null,"The server chat limit is respected even with a larger input limit");
        check(ItemLinkCodec.append("",null,250) == null,"Failed encoding never changes the draft");
        check(ItemLinkCodec.tokens("before "+token+" middle "+token+" after").length == 0,
            "Over-limit incoming messages are not parsed");
        var small = fixture(); small.preview.slots=[];small.preview.effects=[];
        small.preview.infusion=small.preview.bonus=small.preview.rarity="";
        var short = ItemLinkCodec.encode(small), message="A "+short+" B "+short;
        check(ItemLinkCodec.tokens(message).length == 1,"Repeated tokens decode only once per row");
        check(ItemLinkCodec.decode("~i2:YWJj~") == null && ItemLinkCodec.decode("~i1:a~") == null,"Unknown versions and invalid base64 remain plain text");
        for (bad in [token.substr(0,token.length-1),"~i1:!!!!~","~i1:"+StringTools.lpad("a","a",260)+"~"])
            check(ItemLinkCodec.decode(bad) == null,"Malformed or oversized token is rejected");
        var data:Array<Dynamic> = ["Sword",1,0,30,0,"Epic","","","",[],[]];
        for (index in 0...11) {
            var broken = data.copy(); broken[index] = {};
            check(ItemLinkCodec.decode(packet(broken)) == null,"Invalid field type "+index+" is rejected");
        }
        for (index in [1,2,3,4]) {
            var broken=data.copy();broken[index]=1.5;
            check(ItemLinkCodec.decode(packet(broken)) == null,"Fractional integer field "+index+" is rejected");
        }
        var broken=data.copy();broken[9]=["<b>bad</b>"];
        check(ItemLinkCodec.decode(packet(broken)) == null,"Markup cannot enter database IDs");
        broken=data.copy();broken[10]=[for (_ in 0...9) "Rogue_Poison"];
        check(ItemLinkCodec.decode(packet(broken)) == null,"Effect count is bounded");
        check(ItemLinkCodec.decode(packet(StringTools.lpad("x","x",100000))) == null,"A compressed expansion bomb is bounded");
        var raw = haxe.crypto.Base64.urlDecode(token.substring(4,token.length-1));
        var trailing=haxe.io.Bytes.alloc(raw.length+1);trailing.blit(0,raw,0,raw.length);trailing.set(raw.length,7);
        check(ItemLinkCodec.decode("~i1:"+haxe.crypto.Base64.urlEncode(trailing)+"~") == null,"Trailing compressed-stream data is rejected");
        raw.set(raw.length-1,raw.get(raw.length-1)^1);
        check(ItemLinkCodec.decode("~i1:"+haxe.crypto.Base64.urlEncode(raw)+"~") == null,"A damaged checksum cannot produce a tooltip");
        var markup=ItemLinkCodec.markup("Sword <evil>& name",0x1ab45f,0);
        check(markup=='<a href="wink-item:0"><font color="#1AB45F"><b>Sword &lt;evil&gt;&amp; name</b></font></a>',
            "Only a safely escaped item name receives bold rarity markup");
        Sys.println("Item link codec checks passed: "+checks+"; modified-item token: "+token.length+" characters");
    }
}
