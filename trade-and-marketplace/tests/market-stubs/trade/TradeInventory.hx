package trade;
import trade.TradeTypes;
class TradeInventory {
 public var player:Dynamic;
 public var hero:Dynamic;
 public var inventory:Dynamic;
 public var stack:Dynamic={item:{inf:{}},count:10};
 public var allowed=true;
 public static var fp="fp";
 public function new(?owner:Dynamic){
  player=owner==null?{hero:{loadout:{banks:[]}}}:owner;hero=player.hero;
  inventory={};
 }
 public function find(uid:String):Dynamic return Reflect.hasField(inventory,"content")?findStored(uid):stack;
 function findStored(uid:String):Dynamic {
  for(s in (cast inventory.content:Array<Dynamic>))if(s.item.uid==uid)return s;
  return null;
 }
 public function canDrop(s:Dynamic,count:Int):Bool return allowed&&Reflect.field(s.item,"locked")!=true&&Reflect.field(s.item,"bound")!=true&&count>0&&count<=s.count;
 public static function fingerprint(i:Dynamic):String return fp;
 public static function definition(s:String):Dynamic return {};
 public static function itemName(s:String):String return s;
 public static function preview(i:Dynamic):TradeItemPreview return {flags:2,level:35,upgrade:2,rarity:"",infusion:"Infusion_Manfish_DPS",bonus:"",mastery:"",slots:["DivinedEmbroidery"],effects:[]};
 public static function describe(i:Dynamic,count:Int):Dynamic return {detail:"8 Intellect\n7 Faith"};
}
