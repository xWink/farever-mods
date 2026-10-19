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
    public static function detail(text:String):String {
        // Older exports contain the enum's debug name instead of the attribute label.
        return ~/ETAAttribute\(([^()]+)\)/g.replace(text,"$1");
    }

}
