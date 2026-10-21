package trade;
class TradeMod {
    public static var lastError="";
    public static function chatError(message:String):Void lastError=message;
    public static function enabled():Bool return true;
}
