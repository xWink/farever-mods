package marketplace;
class MarketController {
 public static inline var PAGE_SIZE=6;
 public var filtersExpanded=false;public var view:MarketWindow;
 public function pageSize():Int return tab=="Browse"?(filtersExpanded?PAGE_SIZE:8):9;
 public function toggleFilters():Void {if(busy)return;filtersExpanded=!filtersExpanded;page=1;refresh();if(view!=null)view.dirty=true;}
 public var bankOnly=false;
 public var sellSearch="";
 public var inventorySlots:Array<trade.TradeTypes.TradeItem>=[];
 public var bankTab=0;
 public var bankNames:Array<String>=["First tab","Second tab"];
 public function setBankTab(i:Int):Void {bankTab=i;if(view!=null)view.dirty=true;}
 public function inventoryStack(i:trade.TradeTypes.TradeItem):Dynamic return {item:{kind:i.kind,inf:trade.TradeInventory.definition(i.kind)},count:i.count};
 public var inventorySearches=0;
 public var refreshes=0;
 public var connectionIssue=false;
 public var ready=true; public var busy=false; public var signingIn=false;
 public var server="north-america"; public var account="tester"; public var tab="Browse"; public var message="";
 public var rows:Array<Dynamic>=[]; public var inventory:Array<trade.TradeTypes.TradeItem>=[];
 public var page=1; public var pages=1; public var total=0; public var selected:Dynamic; public var chosen:trade.TradeTypes.TradeItem;
 public var inv:trade.TradeInventory=null;
 public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"true","sort"=>"price-asc"];
 public function new(){}
 public function chooseTab(s:String):Void tab=s;
 public function refresh():Void {refreshes++;}
 public function searchInventory():Void {inventorySearches++;}
 public function cancelSignIn():Void{}
 public function signIn():Void{}
 public function list(q:Int,t:Int,o:Bool):Void{}
 public function setBankOnly(v:Bool):Void {bankOnly=v;chosen=null;page=1;}
 public function inventoryLocation(i:trade.TradeTypes.TradeItem):String return bankOnly?"In bank":"In backpack";
 public function remove():Void{}
 public function contact():Void{}
}
