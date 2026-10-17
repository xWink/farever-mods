package trade;
import trade.TradeTypes;
class TradeInventory {
 public var inventory:Dynamic={}; public var hero:Dynamic;
 public function new(player:Dynamic) hero=GameAccess.field(player,"hero");
 public function stacks():Array<Dynamic> return [{item:{uid:"1"},count:4}];
 public function fromSlot(slot:Dynamic):Dynamic return stacks()[0];
 public static function describe(item:Dynamic,count:Int):TradeItem return {uid:"1",kind:"Copper",count:count,name:"Copper",detail:"",color:0,fingerprint:"fp",preview:null};
 public static function distance(a:Dynamic,b:Dynamic):Float throw "Preview checked remote player";
 public function validate(items:Array<TradeItem>):String throw "Preview entered real validation";
 public function freeSlotsAfterOffering(items:Array<TradeItem>):Int throw "Preview checked capacity";
 public function canDrop(s:Dynamic,n:Int):Bool throw "Preview checked drop permission";
}
