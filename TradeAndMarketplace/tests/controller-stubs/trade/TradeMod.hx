package trade;
class TradeMod {
    public static var on = true;
    public static var rejectAllRequests = false;
    public static function enabled():Bool return on;
    public static function rejectsRequests():Bool return rejectAllRequests;
}
