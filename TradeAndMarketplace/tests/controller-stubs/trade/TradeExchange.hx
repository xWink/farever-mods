package trade;
/** Actual exchange behavior is tested separately in ExchangeTest. */
class TradeExchange {
    public var status = "";
    public var collectionTarget:Dynamic;
    public function new(s:TradeSession, i:TradeInventory, p:Void->String) { throw "Unexpected exchange"; }
    public function announced(p:Dynamic, n:Float):Void {}
    public function collected(p:Dynamic, n:Float):Void {}
    public function update(n:Float):Void {}
    public static function authorizesPickup(t:Dynamic):Bool return false;
}
