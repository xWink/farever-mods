package groupfinder;
import groupfinder.GroupTypes;
typedef GroupPacket={op:String,id:String,listingId:String,className:String,level:Int,?badge:String};
/** Small, single-whisper protocol. Identity and name always come from native chat. */
class GroupWire {
    public static inline var PREFIX="[FGL1]";
    public static function isPacket(text:String):Bool return text!=null&&StringTools.startsWith(text,PREFIX);
    public static function encode(op:String,id:String,listingId:String,?member:GroupMember):String {
        var values:Array<Dynamic>=[op,id,listingId];
        if(op=="request") {
            values.push(member.className);values.push(member.level);
            var badge=GroupProtocol.badge(member.badge);if(badge!=null)values.push(badge);
        }
        var result=PREFIX+haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(haxe.Json.stringify(values)));
        if(result.length>300)throw "Group request is too long";
        return result;
    }
    public static function decode(text:String):Null<GroupPacket> {
        if(!isPacket(text)||text.length>300)return null;
        try {
            var data:Dynamic=haxe.Json.parse(haxe.crypto.Base64.decode(text.substr(PREFIX.length)).toString());
            if(!Std.isOfType(data,Array))return null;
            var a:Array<Dynamic>=data;
            if(a.length<3||!Std.isOfType(a[0],String)||["request","cancel","invited","declined","closed","invite-declined"].indexOf(a[0])<0
                ||!Std.isOfType(a[1],String)||!GroupProtocol.uuid(a[1])||!Std.isOfType(a[2],String)||!GroupProtocol.uuid(a[2]))return null;
            if(a[0]=="request") {
                if((a.length!=5&&a.length!=6)||!Std.isOfType(a[3],String)||["","Warrior","Rogue","Mage","Cleric"].indexOf(a[3])<0
                    ||!Std.isOfType(a[4],Int)||a[4]<0||a[4]>10000)return null;
            }else if(a.length!=3)return null;
            return {op:a[0],id:a[1],listingId:a[2],className:a[0]=="request"?a[3]:"",level:a[0]=="request"?a[4]:0,
                badge:a[0]=="request"&&a.length==6?GroupProtocol.badge(a[5]):null};
        }catch(_:Dynamic)return null;
    }
}
