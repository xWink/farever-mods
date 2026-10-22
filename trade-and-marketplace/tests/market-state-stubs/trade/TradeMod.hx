package trade;
class TradeMod {
    public static var lastError="";
    public static function chatError(message:String):Void lastError=message;
    public static function enabled():Bool return true;
    public static var savedHideMine=false;
    public static var savedOnlineOnly=false;
    public static function marketplaceFilters():{hideMine:Bool,onlineOnly:Bool}
        return {hideMine:savedHideMine,onlineOnly:savedOnlineOnly};
    public static function saveMarketplaceFilters(hideMine:Bool,onlineOnly:Bool):Void {
        savedHideMine=hideMine;savedOnlineOnly=onlineOnly;
    }
}
