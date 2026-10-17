package trade;
class TradeExchange {
 public var status=""; public var collectionTarget:Dynamic;
 public function new(s:TradeSession,i:TradeInventory,p:Void->String) {throw "Preview created exchange";}
 public function announced(p:Dynamic,n:Float):Void throw "Preview announced drop";
 public function collected(p:Dynamic,n:Float):Void throw "Preview collected item";
 public function update(n:Float):Void throw "Preview updated exchange";
 public static function authorizesPickup(t:Dynamic):Bool throw "Preview authorized pickup";
}
