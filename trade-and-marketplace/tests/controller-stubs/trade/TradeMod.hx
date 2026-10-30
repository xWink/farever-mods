package trade;
class TradeMod {
    public static var on = true;
    public static var rejectAllRequests = false;
    public static function enabled():Bool return on;
    public static function rejectsRequests():Bool return rejectAllRequests;
    public static var region="europe";
    public static var deferPresence=false;
    public static var presenceChecks:Array<{account:String,region:String,done:(Bool,String)->Void}>=[];
    public static var presenceCancellations=0;
    public static function tradeRegion():String return region;
    public static function checkTradePresence(account:String,region:String,done:(Bool,String)->Void):Void {
        presenceChecks.push({account:account,region:region,done:done});
        if(!deferPresence)done(true,"");
    }
    public static function cancelTradePresence():Void presenceCancellations++;
    public static function resetPresence():Void {region="europe";deferPresence=false;presenceChecks=[];presenceCancellations=0;on=true;}
}
