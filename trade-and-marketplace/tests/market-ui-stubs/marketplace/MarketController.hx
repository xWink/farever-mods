package marketplace;
class MarketController {
 public static inline var PAGE_SIZE=8;
 public var ready=true; public var busy=false; public var signingIn=false;
 public var server="north-america"; public var account="tester"; public var tab="Browse"; public var message="";
 public var rows:Array<Dynamic>=[]; public var inventory:Array<trade.TradeTypes.TradeItem>=[];
 public var page=1; public var pages=1; public var total=0; public var selected:Dynamic; public var chosen:trade.TradeTypes.TradeItem;
 public var inv:trade.TradeInventory=null;
 public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"false","sort"=>"price-asc"];
 public function new(){}
 public function chooseTab(s:String):Void tab=s;
 public function refresh():Void{}
 public function cancelSignIn():Void{}
 public function signIn():Void{}
 public function list(q:Int,t:Int,o:Bool):Void{}
 public function changePrice(t:Int,o:Bool):Void{}
 public function remove(s:Bool):Void{}
 public function contact():Void{}
}
