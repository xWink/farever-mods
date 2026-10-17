package trade;
class TradeMovement {
    public function new() {}
    public function release():Void {}
    public function holding(c:Dynamic, h:Dynamic, s:TradeSession):Bool return true;
    public function ready(n:Float):Bool return true;
    public function drive(c:Dynamic, h:Dynamic, p:Dynamic, s:TradeSession, t:Dynamic, n:Float):String return "";
}
