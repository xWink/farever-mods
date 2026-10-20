package marketplace;

/** Display formatting shared by listing rows and their details. */
class MarketText {
    public static inline var CONNECTION_ERROR = "Could not connect to Fareverly. You need a valid Fareverly API key, which you can set up in Game Menu → Mod Settings → Trade and Marketplace. If you already have a key, try connecting again shortly.";
    public static function number(value:Dynamic):String {
        // Convert API numbers explicitly: Dynamic + String can cast i32 to String on HL.
        var text=Std.string(value);
        if(!~/^[0-9]+$/.match(text))return text;
        var result="",end=text.length;
        while(end>3) {result=","+text.substr(end-3,3)+result;end-=3;}
        return text.substr(0,end)+result;
    }
    public static function count(value:Int,noun:String):String return number(value)+" "+noun+(value==1?"":"s");
    public static function price(value:Dynamic):String {
        if(value==null)return "Price unavailable";
        if(Reflect.field(value,"mode")=="offers")return "Open to offers";
        var amount=Reflect.field(value,"silverTrays");
        return number(amount)+(Std.string(amount)=="1"?" Silver Tray":" Silver Trays");
    }
    public static function askingPrice(value:Dynamic):String {
        if(value==null||Reflect.field(value,"mode")=="offers")return "Asking price: "+price(value);
        var trays:Float=Reflect.field(value,"silverTrays");
        return "Asking price: "+number(trays*500)+" gold / "+price(value);
    }
    public static function conversion(trays:Int):String return count(trays,"Silver Tray")+" = "+number(trays*500)+" gold";
    public static function expiry(iso:String):String {
        var pattern=~/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z$/;
        if(iso==null||!pattern.match(iso))return "Unavailable";
        var year=Std.parseInt(pattern.matched(1)),month=Std.parseInt(pattern.matched(2)),day=Std.parseInt(pattern.matched(3));
        var hour=Std.parseInt(pattern.matched(4)),minute=Std.parseInt(pattern.matched(5)),second=Std.parseInt(pattern.matched(6));
        var leap=year%4==0&&(year%100!=0||year%400==0);
        var monthDays=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31];
        if(year<1970||month<1||month>12||day<1||day>monthDays[month-1]||hour>23||minute>59||second>59)return "Unavailable";
        // DateTools.makeUtc is unimplemented on HashLink. Construct the UTC epoch
        // directly, then let Date apply the OS timezone/DST for the expiry instant.
        // Parsing as a local date first misinterprets instants around DST changes.
        var last=year-1;
        var days=365.0*(year-1970)+Math.floor(last/4)-492-Math.floor(last/100)+19+Math.floor(last/400)-4+day-1;
        for(i in 0...month-1)days+=monthDays[i];
        var local=Date.fromTime((days*86400+hour*3600+minute*60+second)*1000);
        var months=["Jan.","Feb.","Mar.","Apr.","May","Jun.","Jul.","Aug.","Sep.","Oct.","Nov.","Dec."];
        return months[local.getMonth()]+" "+local.getDate()+", "+local.getFullYear()+" - "
            +StringTools.lpad(Std.string(local.getHours()),"0",2)+":"+StringTools.lpad(Std.string(local.getMinutes()),"0",2)+" (local)";
    }

    public static function detail(text:String):String {
        // Older exports contain the enum's debug name instead of the attribute label.
        text=~/ETA?Attribute\(([^()]+)\)/g.replace(text,"$1");
        var lines=[];
        for(line in text.split("\n")) {
            line=~/(?:[ \t]*[|·][ \t]*)?Upgrade \+0$/.replace(StringTools.rtrim(line),"");
            if(StringTools.trim(line)!="")lines.push(line);
        }
        return lines.join("\n");
    }

    public static function itemName(kind:String,name:String):String {
        name=~/<[^>]*>/g.replace(name,"");
        var gift=~/^DemonGearUpgrade(?:Rare)?_([A-Za-z]+)To([A-Za-z]+)$/;
        if(!gift.match(kind)||name.indexOf(" (+")>=0)return name;
        var loss=giftStat(gift.matched(1)),gain=giftStat(gift.matched(2));
        return loss==""||gain==""?name:name+" (+"+gain+"/-"+loss+")";
    }
    static function giftStat(code:String):String return switch(code.toLowerCase()) {
        case "ferv":"Fervor";case "crit":"Crit";
        case "ap":"Armor Pen";case "mp":"Magic Pen";default:"";
    };
}
