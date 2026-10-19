import marketplace.MarketWindow;
import marketplace.MarketText;
import marketplace.MarketController;
import trade.GameAccess;
import trade.TradeFrame;
class MarketplaceUiTest {
 static var checks=0;
 static function check(b:Bool):Void {checks++;if(!b)throw "Marketplace UI assertion "+checks;}
 static function main():Void {
  // The successful listing shape, including a detached item and ISO presence expiry.
  var row:Dynamic=haxe.Json.parse('{"id":"test","price":{"mode":"fixed","silverTrays":1},"item":{"baseId":"Shield_OrbitWater","name":"Test shield","quantity":1,"rarity":"Epic","upgradeLevel":0,"native":{"flags":0,"level":25,"upgrade":0,"rarity":"Epic","infusion":"","bonus":"","mastery":"","slots":[],"effects":[]},"detail":"Epic"},"seller":{"accountId":"seller","characterName":"Tester","onlineUntil":"2099-01-01T00:00:00.000Z"}}');
  var c=new MarketController();c.rows=[for(i in 0...MarketController.PAGE_SIZE)row];c.total=c.rows.length;
  var view=new MarketWindow(c);view.open();view.update();check(TradeFrame.active==1);
  check(GameAccess.buttons.filter(b->Std.string(b.text).indexOf("details unavailable")>=0).length==0);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Item details, price")>=0||l.text=="Select a listing").length==0);
  check(GameAccess.labels.filter(l->l.text=="Fareverly connected").length==0);
  var name=GameAccess.labels.filter(l->l.text==trade.TradeInventory.itemName("Shield_OrbitWater"))[0];
  check(name!=null&&name.lineBreak==false&&name.useEllipsis==true);
  check(GameAccess.labels.filter(l->l.text=="1 Silver Tray").length==MarketController.PAGE_SIZE);
  check(MarketText.price(haxe.Json.parse('{"mode":"fixed","silverTrays":12500}'))=="12,500 Silver Trays");
  check(MarketText.price({mode:"offers"})=="Open to offers");
  check(MarketText.count(1,"listing")=="1 listing"&&MarketText.count(2,"listing")=="2 listings");
  var online=GameAccess.nodes.filter(n->n.fmtText.text=="Online only")[0];
  check(online!=null&&online.selected==false);online.onValueChange(true);check(c.filters["online"]=="true");
  var search=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  check(search.input.x==search.inputHint.x&&search.input.x>0);
  var select=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0)[0];
  check(select.arrow.x+select.arrow.width<select.width&&select.selectText.y+4.0==9.0);
  var selects=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0);
  check(selects.length==4&&selects.filter(n->n.y!=190).length==0);
  var classButton=GameAccess.buttons.filter(b->b.text=="Warrior")[0],clear=GameAccess.buttons.filter(b->b.text=="Clear filters")[0];
  check(select.y-search.y==classButton.y-select.y&&search.width>900);
  check(online.y==clear.y&&online.x+online.width<clear.x&&clear.x-(online.x+online.width)==16);
  check(GameAccess.labels.filter(l->l.text=="Sort by").length==0);
  var browse=GameAccess.buttons.filter(b->b.text=="Browse")[0];check(browse.selected==true&&browse.kind=="");
  c.message="Loading...";view.dirty=true;GameAccess.labels=[];view.update();
  var loading=GameAccess.labels.filter(l->l.text=="Loading...")[0];
  check(loading.y+18<TradeFrame.latest.container.height);
  var statuses=GameAccess.labels.filter(l->l.text=="Status: Online"),status=statuses[0];
  check(status.x<502&&status.y+22<=status.parent.height-7);
  check(GameAccess.labels.filter(l->l.text=="Seller: Tester").length==MarketController.PAGE_SIZE);
  check(statuses[statuses.length-1].parent.y+status.parent.height<=806);
  status.bounds={xMin:0.0,yMin:5.0,xMax:130.0,yMax:29.0};status.parent.onAfterReflow();
  check(status.y+29<=status.parent.height-7);
  // One failing row must not close the window or stop the remaining rows.
  GameAccess.buttons=[];GameAccess.failNextTooltip=true;view.dirty=true;view.update();
  check(TradeFrame.active==1);check(!GameAccess.failNextTooltip);
  var fallbacks=GameAccess.buttons.filter(b->Std.string(b.text).indexOf("details unavailable")>=0);
  check(fallbacks.length==1);fallbacks[0].action();check(c.selected==row);
  c.tab="My listings";GameAccess.buttons=[];view.dirty=true;view.update();
  check(GameAccess.buttons.filter(b->b.text=="Save price"||b.text=="Mark sold").length==0);
  check(GameAccess.buttons.filter(b->b.text=="Remove listing").length==1);
  c.tab="Sell an item";view.dirty=true;GameAccess.nodes=[];GameAccess.buttons=[];view.update();
  var bank=GameAccess.buttons.filter(b->b.text=="Bank")[0];
  check(bank!=null);bank.action();check(c.bankOnly);
  var inventory=GameAccess.buttons.filter(b->b.text=="Inventory")[0];inventory.action();check(!c.bankOnly);
  check(inventory.selected==true&&inventory.kind==""&&bank.selected==false);
  var sellSearch=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  sellSearch.input.text="shield";sellSearch.onChange();GameAccess.buttons.filter(b->b.text=="Search")[0].action();
  check(c.sellSearch=="shield"&&c.inventorySearches==1);
  // Native fonts and bounds arrive after controls are constructed.
  select.selectText.bounds={xMin:0.0,yMin:6.0,xMax:90.0,yMax:30.0};
  select.selectText.y=100.;select.arrow.x=select.width;
  select.select.onAfterReflow();
  check(select.selectText.y+6.0==6.0&&select.arrow.x+22==select.width-10);
  check(MarketText.detail("549 ETAAttribute(Armor)")=="549 Armor");
  check(MarketText.detail("549 ETAttribute(Armor), 12 ETAttribute(Strength)")=="549 Armor, 12 Strength");
  check(MarketText.askingPrice(row.price)=="Asking price: 500 gold / 1 Silver Tray");
  check(MarketText.conversion(5)=="5 Silver Trays = 2,500 gold");
  c.chosen=marketplace.MarketExport.offer(row);GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  var inputs=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0),quantityBox=inputs[1],priceBox=inputs[2];
  priceBox.input.text="5";priceBox.onChange();
  check(GameAccess.labels.filter(l->l.text=="5 Silver Trays = 2,500 gold").length==1);
  check(!view.dirty); // Updating a price must not rebuild/focus-reset the input.
  var arrows=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketCounterArrow")==0);
  check(arrows.length==4);
  arrows[2].action();check(priceBox.input.text=="6");arrows[3].action();check(priceBox.input.text=="5");
  priceBox.input.text="nope";priceBox.onChange();check(priceBox.input.text=="5");
  priceBox.input.text="9999999999999999999999999999";priceBox.onChange();check(priceBox.input.text=="200000");
  arrows[2].action();check(priceBox.input.text=="200000");
  priceBox.input.text="0";priceBox.onChange();arrows[3].action();check(priceBox.input.text=="1");
  priceBox.input.text="";priceBox.onChange();priceBox.input.onFocusLost({});check(priceBox.input.text=="1");
  quantityBox.input.text="9999";quantityBox.onChange();check(quantityBox.input.text=="1");
  c.connectionIssue=true;view.update();view.update();check(GameAccess.dialogs==1);
  // A page-level error keeps navigation available, and reopening clears recovery state.
  c.selected=null;view.recover("Injected page failure");GameAccess.buttons=[];view.update();
  check(TradeFrame.active==1);check(GameAccess.buttons.filter(b->b.text=="My listings").length==1);
  c.connectionIssue=false;view.close();check(TradeFrame.active==0);view.open();view.update();check(TradeFrame.active==1);
  view.close();check(TradeFrame.active==0);
  Sys.println("Marketplace UI recovery checks passed: "+checks);
 }
}
