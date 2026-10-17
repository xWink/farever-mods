package trade;
class TradeWire {
    public static inline var PREFIX = "!winktrade1:";
    public static inline var INVITE_TEXT = " is requesting a trade. If you can see this message, you need to install the Trade+Marketplace mod at https://www.nexusmods.com --- ";
    var salt:String;
    var sequence = 0;
    public var diagnostic = "";
    var partial:Map<String,{expires:Float,parts:Array<String>,total:Int}> = [];
    public function new(salt:String) this.salt = salt;
    public static function packetText(text:String):String {
        if (text == null) return null;
        if (StringTools.startsWith(text,PREFIX)) return text;
        if (text.length > 512) return null;
        var index = text.indexOf(INVITE_TEXT);
        if (index < 1 || index > 80 || ~/[\r\n\t<>]/.match(text.substr(0,index))) return null;
        var packet = text.substr(index+INVITE_TEXT.length);
        return StringTools.startsWith(packet,PREFIX) ? packet : null;
    }
    public static function isPacket(text:String):Bool return packetText(text) != null;
    public function encode(packet:Dynamic,?senderName:String):Array<String> {
        var data = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(haxe.Json.stringify(packet)));
        var total = Math.ceil(data.length/180);
        if (total < 1 || total > 96) throw "Trade offer is too large.";
        var id = salt+StringTools.hex(++sequence), prefix = "";
        if (packet.op == "invite" && senderName != null) {
            var name = ~/<[^>]*>/g.replace(senderName,"");
            name = StringTools.trim(~/[\r\n\t<>]/g.replace(name," ")).substr(0,80);
            prefix = (name == "" ? "Player" : name)+INVITE_TEXT;
        }
        return [for(i in 0...total) prefix+PREFIX+id+":"+i+":"+total+":"+data.substr(i*180,180)];
    }
    public function receive(sender:String,text:String,now:Float):Dynamic {
        diagnostic = "invalid packet header";
        var raw = packetText(text);
        if (raw == null || text.length > 512 || raw.length > 240) return null;
        var a = raw.substr(PREFIX.length).split(":");
        if (a.length != 4 || !~/^[0-9A-Za-z]{1,24}$/.match(a[0]) || !~/^[0-9]{1,2}$/.match(a[1])
            || !~/^[0-9]{1,2}$/.match(a[2]) || !~/^[A-Za-z0-9+\/=]*$/.match(a[3]) || a[3].length > 180) return null;
        var index = Std.parseInt(a[1]), total = Std.parseInt(a[2]);
        if (total < 1 || total > 96 || index < 0 || index >= total) return null;
        for (k in partial.keys()) if (partial[k].expires < now) partial.remove(k);
        var key = sender+"/"+a[0], p = partial[key];
        if (p == null) {
            var count = 0; for (_ in partial) count++;
            if (count >= 16) { diagnostic = "too many incomplete messages"; return null; }
            var parts:Array<String> = []; parts.resize(total);
            p = {expires:now+45,parts:parts,total:total}; partial[key] = p;
        }
        if (p.total != total || (p.parts[index] != null && p.parts[index] != a[3])) {
            diagnostic = "conflicting fragments"; partial.remove(key); return null;
        }
        p.parts[index] = a[3]; diagnostic = "fragment "+(index+1)+"/"+total+"; waiting";
        for (part in p.parts) if (part == null) return null;
        partial.remove(key);
        try {
            var packet:Dynamic = haxe.Json.parse(haxe.crypto.Base64.decode(p.parts.join("")).toString());
            if (packet == null || !Reflect.isObject(packet) || Std.isOfType(packet,String) || Std.isOfType(packet,Array)
                || !TradeOffer.str(packet.id,48) || !TradeOffer.str(packet.to,80) || !TradeOffer.str(packet.op,16)) return null;
            diagnostic = "complete "+haxe.Json.stringify(packet.op); return packet;
        } catch (_:Dynamic) return null;
    }
}
