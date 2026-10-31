package groupfinder;

typedef GroupMember = {accountId:String, name:String, className:String, level:Int};
typedef GroupParty = {accountId:String, partyId:String, leaderId:String, region:String, members:Array<GroupMember>};
typedef GroupListing = {
    id:String, ownerId:String, partyId:String, region:String, category:String, title:String,
    members:Array<GroupMember>, updatedAt:Float, expiresAt:Float, sample:Bool
};
typedef GroupResult<T> = {value:Null<T>, error:String};
typedef JoinRequest = {
    id:String, listingId:String, member:GroupMember, incoming:Bool, state:String, expiresAt:Float
};

/** UI-facing service boundary. The prototype implementation is entirely local. */
interface GroupService {
    public function list(region:String, done:GroupResult<Array<GroupListing>>->Void):Void;
    public function save(party:GroupParty, id:Null<String>, title:String, category:String, done:GroupResult<GroupListing>->Void):Void;
    public function remove(accountId:String, id:String, done:GroupResult<Bool>->Void):Void;
}

class GroupRules {
    public static final categories = ["Dungeons", "World Events", "Other"];
    public static inline var CAPACITY = 4;
    public static function count(text:String):Int {
        var length=0;
        for (_ in new haxe.iterators.StringIteratorUnicode(text)) length++;
        return length;
    }
    public static function titleError(text:String):String {
        if(StringTools.trim(text)=="")return "Enter a listing title.";
        if(count(StringTools.trim(text))>30)return "Listing titles can contain up to 30 characters.";
        if(text.indexOf("\n")>=0||text.indexOf("\r")>=0||text.indexOf("\t")>=0)return "Use a single line for your title.";
        return "";
    }
    public static function partyError(party:Null<GroupParty>):String {
        if(party==null||party.accountId==""||party.region==""||party.partyId==""||party.members.length==0)
            return "Enter the game with your character to create a listing.";
        if(party.leaderId!=party.accountId)return "Only the party leader can create a listing.";
        if(party.members.length>=CAPACITY)return "Your party is full.";
        return "";
    }
    public static function clone<T>(value:T):T return haxe.Json.parse(haxe.Json.stringify(value));
    public static function memberText(member:GroupMember):String
        return (member.className==""?"Class unavailable":member.className)+" • "+(member.level>0?"Lv. "+member.level:"Level unavailable");
}
