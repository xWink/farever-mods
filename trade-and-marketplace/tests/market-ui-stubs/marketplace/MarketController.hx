package marketplace;
class MarketController {
 public static inline var PAGE_SIZE=8;
 public var filtersExpanded=false;public var view:MarketWindow;
 public var hideMine=false;
 public function setHideMine(value:Bool):Void {hideMine=value;if(view!=null)view.dirty=true;}
 public function saveFilterPreferences():Void {}
 public function canBrowse():Bool return true;
 public function pageSize():Int return tab=="Browse"?8:9;
 public function toggleFilters():Void {filtersExpanded=!filtersExpanded;if(view!=null)view.dirty=true;}
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
 public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","prismatic"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"false","sort"=>""];
 public function new(){}
 public var presenceOverride:Null<Bool>;
 public function listingOnline(row:Dynamic):Bool return presenceOverride!=null?presenceOverride:fareverly.Protocol.expiry(trade.GameAccess.text(trade.GameAccess.field(trade.GameAccess.field(row,"seller"),"onlineUntil")))>Date.now().getTime()/1000;
 public function chooseTab(s:String):Void tab=s;
 public function toggleListing(row:Dynamic):Void {selected=selected!=null&&selected.id==row.id?null:row;view.dirty=true;}
 public var searchedItem=false;
 public function searchSelectedItem():Void {searchedItem=true;}
 public function listingSort():String return filters["sort"];
 public function sortByLevel():Void cycleSort("required-level");
 public function sortByPrice():Void cycleSort("price");
 function cycleSort(column:String):Void {var s=listingSort();filters["sort"]=s==column+"-asc"?column+"-desc":s==column+"-desc"?"":column+"-asc";if(view!=null)view.dirty=true;}
 public function goPage(value:Int):Void {page=value;refresh();}
 public function refresh():Void {refreshes++;}
 public function searchInventory():Void {inventorySearches++;if(view!=null)view.dirty=true;}
 public function cancelSignIn():Void{}
 public function signIn():Void{}
 public var availableQuantity:Null<Int>;
 public function availableToList(item:trade.TradeTypes.TradeItem):Int return availableQuantity==null?item.count:availableQuantity;
 public function list(q:Int,t:Int,o:Bool):Void{}
 public function setBankOnly(v:Bool):Void {bankOnly=v;chosen=null;page=1;}
 public var atLimit=false;
 public function listingLimitReached():Bool return atLimit;
 public var listed=false;
 public var bound=false;
 public function isBound(item:trade.TradeTypes.TradeItem):Bool return bound;
 public var locked=false;
 public function isLocked(item:trade.TradeTypes.TradeItem):Bool return locked;
 public function isListed(item:trade.TradeTypes.TradeItem):Bool return listed;
 public function inventoryLocation(i:trade.TradeTypes.TradeItem):String return bankOnly?"In bank":"In backpack";
 public var editingListingId="";
 public var editQuantityLimit=10000;
 public function beginEdit():Bool {editingListingId=selected.id;view.dirty=true;return true;}
 public function cancelEdit():Void {editingListingId="";view.dirty=true;}
 public var edited:Dynamic;
 public function edit(q:Int,t:Int,o:Bool):Void {edited={quantity:q,trays:t,offers:o};}
 public function remove():Void{}
 public function contact():Void{}
}
