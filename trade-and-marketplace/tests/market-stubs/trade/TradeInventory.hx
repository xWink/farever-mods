package trade;
import trade.TradeTypes;
class TradeInventory {
 public var player:Dynamic={};
 public var stack:Dynamic={item:{inf:{}},count:10};
 public var allowed=true;
 public static var fp="fp";
 public function new(){}
 public function find(uid:String):Dynamic return stack;
 public function canDrop(s:Dynamic,count:Int):Bool return allowed&&count>0&&count<=s.count;
 public static function fingerprint(i:Dynamic):String return fp;
 public static function definition(s:String):Dynamic return {};
 public static function itemName(s:String):String return s;
 public static function preview(i:Dynamic):TradeItemPreview return {flags:2,level:35,upgrade:2,rarity:"",infusion:"Infusion_Manfish_DPS",bonus:"",mastery:"",slots:["DivinedEmbroidery"],effects:[]};
 public static function describe(i:Dynamic,count:Int):Dynamic return {detail:"8 Intellect\n7 Faith"};
}
