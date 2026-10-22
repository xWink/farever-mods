package marketplace;

import haxe.crypto.Base64;
import haxe.io.Bytes;

/**
 * Private-chat transport for marketplace inquiries. The protocol carries the
 * listing's complete exported item and price, never its sender-localized name
 * as the identity. Only the final, validated fragment becomes a chat line.
 */
class MarketWhisperWire {
    public static inline var PREFIX="!winkmarket1:";
    static inline var PART_SIZE=180;
    static inline var MAX_PARTS=128;
    static inline var MAX_BYTES=16384;
    static inline var TIMEOUT=60.0;
    static var sequence=0;
    var partial:Map<String,{parts:Array<String>,total:Int,expires:Float}>=[];
    var completed:Map<String,Float>=[];

    public function new() {}

    public static function isPacket(text:String):Bool return text!=null&&StringTools.startsWith(text,PREFIX);

    public static function packet(listing:Dynamic,to:String):Dynamic {
        if(listing==null||!Std.isOfType(to,String)||to=="")throw "Invalid marketplace whisper recipient.";
        var item=Reflect.field(listing,"item"),price=Reflect.field(listing,"price"),id=Reflect.field(listing,"id");
        var packet:Dynamic={v:1,to:to,id:id,item:item,price:price};
        if(!valid(packet))throw "Invalid marketplace whisper listing.";
        return packet;
    }

    static function valid(p:Dynamic):Bool {
        if(p==null||!Reflect.isObject(p)||Std.isOfType(p,Array)||Std.isOfType(p,String)
            ||Reflect.field(p,"v")!=1||!trade.TradeOffer.str(Reflect.field(p,"to"),128)
            ||Reflect.field(p,"to")==""||!trade.TradeOffer.str(Reflect.field(p,"id"),128)
            ||Reflect.field(p,"id")=="")return false;
        var item=Reflect.field(p,"item"),price=Reflect.field(p,"price");
        if(item==null||price==null||!Reflect.isObject(item)||!Reflect.isObject(price)
            ||Std.isOfType(item,Array)||Std.isOfType(price,Array)
            ||!trade.TradeOffer.str(Reflect.field(item,"baseId"),120)
            ||Reflect.field(item,"baseId")==""||!trade.TradePreview.integer(Reflect.field(item,"quantity"),1,10000))return false;
        var mode=Reflect.field(price,"mode");
        return mode=="offers"||(mode=="fixed"&&trade.TradePreview.integer(Reflect.field(price,"silverTrays"),1,200000));
    }

    public static function encode(packet:Dynamic):Array<String> {
        if(!valid(packet))throw "Invalid marketplace whisper listing.";
        // The original item object, including native modifiers and detailed
        // exported information, is serialized without truncation.
        var bytes=Bytes.ofString(haxe.Json.stringify(packet));
        if(bytes.length>MAX_BYTES)throw "Marketplace listing is too large to whisper.";
        var encoded=Base64.encode(bytes);
        var count=Std.int(Math.ceil(encoded.length/PART_SIZE));
        if(count<1||count>MAX_PARTS)throw "Marketplace listing is too large to whisper.";
        var id=haxe.crypto.Md5.encode(Std.string(Date.now().getTime())+":"+Std.string(++sequence)+":"+Std.string(Math.random())).substr(0,16);
        return [for(i in 0...count)PREFIX+id+":"+i+":"+count+":"+encoded.substr(i*PART_SIZE,PART_SIZE)];
    }

    public function receive(sender:String,text:String,now:Float):Dynamic {
        if(sender==null||sender==""||!isPacket(text)||text.length>240)return null;
        var pieces=text.substr(PREFIX.length).split(":");
        if(pieces.length!=4||!~/^[a-f0-9]{16}$/.match(pieces[0])
            ||!~/^\d{1,3}$/.match(pieces[1])||!~/^\d{1,3}$/.match(pieces[2])
            ||pieces[3].length>PART_SIZE||!~/^[A-Za-z0-9+\/=]*$/.match(pieces[3]))return null;
        var index=Std.parseInt(pieces[1]),total=Std.parseInt(pieces[2]);
        if(index==null||total==null||total<1||total>MAX_PARTS||index<0||index>=total)return null;
        for(key in partial.keys())if(partial[key].expires<now)partial.remove(key);
        for(key in completed.keys())if(completed[key]<now)completed.remove(key);
        var id=sender+"/"+pieces[0];
        if(completed.exists(id))return null;
        var pending=partial[id];
        if(pending==null) {
            var count=0;for(_ in partial)count++;
            if(count>=16)return null;
            var parts:Array<String>=[];parts.resize(total);
            pending={parts:parts,total:total,expires:now+TIMEOUT};partial[id]=pending;
        }
        if(pending.total!=total||(pending.parts[index]!=null&&pending.parts[index]!=pieces[3])){partial.remove(id);return null;}
        pending.parts[index]=pieces[3];
        for(part in pending.parts)if(part==null)return null;
        partial.remove(id);
        try {
            var data=Base64.decode(pending.parts.join(""));
            if(data.length>MAX_BYTES)return null;
            var packet:Dynamic=haxe.Json.parse(data.toString());
            if(!valid(packet))return null;
            completed[id]=now+TIMEOUT;
            return packet;
        }catch(_:Dynamic)return null;
    }

    public static function display(packet:Dynamic,localizedItem:String->String):String {
        if(!valid(packet))throw "Invalid marketplace whisper.";
        var item=Reflect.field(packet,"item"),name=localizedItem(item.baseId);
        if(name==null||name==""||name==item.baseId) {
            var original=Reflect.field(item,"name");
            name=Std.isOfType(original,String)?original:item.baseId;
        }
        name=~/<[^>]*>/g.replace(name,"");
        name=~/[\r\n\t]/g.replace(name," ").substr(0,160);
        var quantity:Int=item.quantity,price=Reflect.field(packet,"price");
        return "Hi! I'm interested in your marketplace listing: "+name+" x"+MarketText.number(quantity)
            +(price.mode=="offers"?" (open to offers).":" for "+MarketText.price(price)+".");
    }
}
