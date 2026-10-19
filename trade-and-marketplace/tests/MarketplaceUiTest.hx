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
  var c=new MarketController();c.rows=[row,row];c.total=2;
  var view=new MarketWindow(c);view.open();view.update();check(TradeFrame.active==1);
  check(GameAccess.buttons.filter(b->Std.string(b.text).indexOf("details unavailable")>=0).length==0);
  var paragraph=GameAccess.labels.filter(l->l.text=="Item details, price, and seller information will appear here.")[0];
  check(paragraph!=null&&paragraph.maxWidthText==null&&paragraph.maxWidth==300.0&&paragraph.lineBreak==true);
  var name=GameAccess.labels.filter(l->l.text==trade.TradeInventory.itemName("Shield_OrbitWater"))[0];
  check(name!=null&&name.lineBreak==false&&name.useEllipsis==true);
  check(GameAccess.labels.filter(l->l.text=="1 Silver Tray").length==2);
  check(MarketText.price(haxe.Json.parse('{"mode":"fixed","silverTrays":12500}'))=="12,500 Silver Trays");
  check(MarketText.price({mode:"offers"})=="Open to offers");
  check(MarketText.count(1,"listing")=="1 listing"&&MarketText.count(2,"listing")=="2 listings");
  // One failing row must not close the window or stop the remaining rows.
  GameAccess.buttons=[];GameAccess.failNextTooltip=true;view.dirty=true;view.update();
  check(TradeFrame.active==1);check(!GameAccess.failNextTooltip);
  var fallbacks=GameAccess.buttons.filter(b->Std.string(b.text).indexOf("details unavailable")>=0);
  check(fallbacks.length==1);fallbacks[0].action();check(c.selected==row);
  c.tab="My listings";GameAccess.buttons=[];view.dirty=true;view.update();
  check(GameAccess.buttons.filter(b->b.text=="Save price").length==1);
  check(GameAccess.buttons.filter(b->b.text=="Remove").length==1);
  // A page-level error keeps navigation available, and reopening clears recovery state.
  c.selected=null;view.recover("Injected page failure");GameAccess.buttons=[];view.update();
  check(TradeFrame.active==1);check(GameAccess.buttons.filter(b->b.text=="My listings").length==1);
  view.close();check(TradeFrame.active==0);view.open();view.update();check(TradeFrame.active==1);
  view.close();check(TradeFrame.active==0);
  Sys.println("Marketplace UI recovery checks passed: "+checks);
 }
}
