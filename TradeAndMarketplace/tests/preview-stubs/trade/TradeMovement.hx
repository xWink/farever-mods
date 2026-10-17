package trade;
class TradeMovement {
 public function new() {} public function release():Void {}
 public function holding(c:Dynamic,h:Dynamic,s:TradeSession):Bool throw "Preview checked movement lock";
 public function ready(n:Float):Bool throw "Preview read movement readiness";
 public function drive(c:Dynamic,h:Dynamic,p:Dynamic,s:TradeSession,t:Dynamic,n:Float):String throw "Preview moved player";
}
