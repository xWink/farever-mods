import marketplace.MarketWindow;
import marketplace.MarketText;
import marketplace.MarketController;
import trade.GameAccess;
import trade.TradeFrame;
class MarketplaceUiTest {
 static var checks=0;
 static function check(b:Bool):Void {checks++;if(!b)throw "Marketplace UI assertion "+checks;}
 static function searchUncovered(search:Dynamic):Bool {
  var children:Array<Dynamic>=search.parent.children;
  for(child in children.slice(children.indexOf(search)+1)) {
   var shapes:Array<Dynamic>=GameAccess.field(child,"shapes");
   if(shapes==null)continue;
   for(shape in shapes)if(shape.alpha==1&&shape.x<search.x+search.width&&shape.x+shape.width>search.x
       &&shape.y<search.y+search.height&&shape.y+shape.height>search.y)return false;
  }
  return true;
 }
 static function main():Void {
  // The successful listing shape, including a detached item and ISO presence expiry.
  var row:Dynamic=haxe.Json.parse('{"id":"test","price":{"mode":"fixed","silverTrays":1},"item":{"baseId":"Shield_OrbitWater","name":"Test shield","quantity":1,"rarity":"Epic","category":"Equipment","subcategory":"Armour","upgradeLevel":0,"native":{"flags":0,"level":25,"upgrade":0,"rarity":"Epic","infusion":"","bonus":"","mastery":"","slots":[],"effects":[]},"detail":"Epic"},"seller":{"accountId":"seller","characterName":"Tester","onlineUntil":"2099-01-01T00:00:00.000Z"}}');
  var c=new MarketController();c.rows=[for(i in 0...MarketController.PAGE_SIZE)row];c.total=c.rows.length;
  var view=new MarketWindow(c);c.view=view;view.open();view.update();check(TradeFrame.active==1);
  check(!c.filtersExpanded&&c.pageSize()==8&&c.filters["online"]=="false");
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0).length==0);
  var collapsedRow=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketRow")==0)[0];
  check(collapsedRow.y==0&&collapsedRow.parent.parent.y==224);
  var filterToggle=GameAccess.buttons.filter(b->b.text=="Show filters")[0];
  var originalSearch=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  check(searchUncovered(originalSearch));
  filterToggle.action();
  GameAccess.nodes=[];GameAccess.labels=[];GameAccess.buttons=[];view.update();
  check(c.filtersExpanded&&c.pageSize()==8);
  check(GameAccess.buttons.filter(b->b.text=="Hide filters")[0]==filterToggle&&GameAccess.removed.indexOf(filterToggle)<0);
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0]==originalSearch&&GameAccess.removed.indexOf(originalSearch)<0);
  check(searchUncovered(originalSearch));
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketRow")==0)[0].parent.parent.y==388);
  check(GameAccess.buttons.filter(b->Std.string(b.text).indexOf("details unavailable")>=0).length==0);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Item details, price")>=0||l.text=="Select a listing").length==0);
  check(GameAccess.labels.filter(l->l.text=="Fareverly connected").length==0);
  var name=GameAccess.labels.filter(l->l.text==row.item.name)[0];
  check(name!=null&&name.lineBreak==false&&name.useEllipsis==false&&name.maxWidthText==null);
  var iconFill:Array<Dynamic>=[];
  for(child in (cast collapsedRow.children:Array<Dynamic>))if(child.shapes!=null)
   for(shape in (cast child.shapes:Array<Dynamic>))
    if(shape.width==42&&shape.x==9)iconFill.push(shape);
  check(iconFill.length==1&&iconFill[0].color==trade.TradeRarity.fill("Epic"));
  check(GameAccess.labels.filter(l->l.text=="Epic"&&l.parent==collapsedRow).length==0);
  check(GameAccess.labels.filter(l->l.text=="500").length==MarketController.PAGE_SIZE);
  var prices=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketMoneyContent")==0),money=prices[0];
  var moneyLabels=GameAccess.labels.filter(l->l.parent==money);
  var moneyIcons=(cast money.children:Array<Dynamic>).filter(n->n.nativeType=="h2d.Bitmap");
  check(moneyLabels[0].text=="500"&&moneyLabels[1].text=="/"&&moneyLabels[2].text=="1");
  check(moneyIcons.length==2&&moneyIcons[0].tile.id=="Gold"&&moneyIcons[1].tile.id=="SilverTray");
  check(money.x>0);
  var shortPriceWidth=GameAccess.number(money.parent.x)+GameAccess.number(money.x)-14-GameAccess.number(name.x);
  check(shortPriceWidth>350&&name.x<130&&GameAccess.number(name.x)+shortPriceWidth+14<=GameAccess.number(money.parent.x)+GameAccess.number(money.x));
  moneyLabels[0].bounds={xMin:0.,yMin:4.,xMax:120.,yMax:22.};moneyLabels[2].bounds={xMin:0.,yMin:4.,xMax:70.,yMax:22.};
  money.parent.onAfterReflow();
  check(GameAccess.number(money.parent.x)+GameAccess.number(money.x)-14-GameAccess.number(name.x)<shortPriceWidth&&GameAccess.number(name.x)+Std.string(name.text).length*8+14<=GameAccess.number(money.parent.x)+GameAccess.number(money.x));
  check(moneyLabels[0].x<moneyIcons[0].x&&moneyIcons[0].x<moneyLabels[1].x&&moneyLabels[2].x<moneyIcons[1].x);
  check(GameAccess.labels.filter(l->l.text=="Region: North America").length==1);
  var region=GameAccess.labels.filter(l->l.text=="Region: North America")[0];
  check(region.parent.y==12&&region.y+13==18);
  check(GameAccess.buttons.filter(b->b.text=="Sell").length==1&&GameAccess.buttons.filter(b->b.text=="Sell an item").length==0);
  check(TradeFrame.latest.header.children.length==2);
  var holder:Dynamic=TradeFrame.latest.header.children[1],cart:Dynamic=holder.children[0];check(holder.x>TradeFrame.latest.title.x+11*8);
  check(cart.nativeType=="h2d.Bitmap"&&cart.smooth==true&&cart.blendMode=="AlphaAdd");
  check(GameAccess.textures.length==5&&GameAccess.textures[0].sourcePng&&GameAccess.textures[4].width==32&&GameAccess.maskWhitened);
  check(GameAccess.textures.filter(t->t.clearAlpha!=0.0).length==0);
  check(GameAccess.textures.slice(0,4).filter(t->t.disposed!=true).length==0&&GameAccess.textures[4].disposed!=true);
  check(cart.color.x==0xEE/255.0&&cart.color.y==0xDD/255.0&&cart.color.z==0xCC/255.0);
  var next=GameAccess.buttons.filter(b->b.text=="Next")[0],page=GameAccess.labels.filter(l->l.text=="Page 1")[0];
  check(next.parent==page.parent&&next.x-6*8==18);
  check(GameAccess.buttons.filter(b->b.text=="Refresh")[0].x==970);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("on this page")>=0||Std.string(l.text).indexOf("tradable items")>=0).length==0);
  check(MarketText.price(haxe.Json.parse('{"mode":"fixed","silverTrays":12500}'))=="12,500 Silver Trays");
  check(MarketText.price({mode:"offers"})=="Open to offers");
  check(MarketText.count(1,"listing")=="1 listing"&&MarketText.count(2,"listing")=="2 listings");
  var online=GameAccess.nodes.filter(n->n.fmtText.text=="Online only")[0];
  check(online!=null&&online.selected==false);online.onValueChange(true);check(c.filters["online"]=="true");
  var hideMine=GameAccess.nodes.filter(n->n.fmtText.text=="Hide mine")[0];
  check(hideMine!=null&&!hideMine.selected&&!c.hideMine);
  check(hideMine.y==online.y&&hideMine.x+hideMine.width+16==online.x);
  var requestsBeforeHide=c.refreshes;
  c.busy=true;hideMine.onValueChange(true);
  check(c.hideMine&&c.refreshes==requestsBeforeHide);
  c.busy=false;hideMine.onValueChange(false);check(!c.hideMine);
  var search=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  check(search.input.x==search.inputHint.x&&search.input.x>0);
  var select=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0)[0];
  check(select.arrow.x+select.arrow.width<select.width&&select.selectText.y+15.0==18.0);
  var selects=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0);
  check(selects.length==4&&selects.filter(n->n.y!=190).length==0);
  var classButton=GameAccess.buttons.filter(b->b.text=="Warrior")[0],clear=GameAccess.buttons.filter(b->b.text=="Clear filters")[0];
  check(select.y-search.y==classButton.y-select.y&&search.width>750);
  check(online.y==clear.y&&online.x+online.width<clear.x&&clear.x-(online.x+online.width)==16);
  check(GameAccess.labels.filter(l->l.text=="Sort by").length==0);
  var browse=GameAccess.buttons.filter(b->b.text=="Browse")[0];check(browse.selected==true&&browse.kind=="");
  search.input.text="ore";search.input.onEnter();check(c.filters["search"]=="ore"&&c.refreshes==2&&search.input.ignoreEnter);
  c.message="Loading...";c.busy=true;view.dirty=true;GameAccess.labels=[];GameAccess.buttons=[];GameAccess.nodes=[];view.update();
  check(GameAccess.labels.filter(l->l.text=="Loading...").length==0);
  var searchButton=GameAccess.buttons.filter(b->b.text=="Search")[0];
  check(searchButton.enable==true);searchButton.action();search.input.onEnter();check(c.refreshes==4);
  // Safe UI controls must remain responsive while requests are loading.
  GameAccess.buttons.filter(b->b.text=="Hide filters")[0].action();check(!c.filtersExpanded);
  GameAccess.buttons.filter(b->b.text=="Hide filters")[0].action();check(c.filtersExpanded);
  GameAccess.buttons.filter(b->b.text=="Sell")[0].action();check(c.tab=="Sell");
  browse.action();check(c.tab=="Browse");
  var filterRequests=c.refreshes;
  classButton.action();check(c.filters["classes"]=="Warrior"&&c.refreshes==filterRequests+1);
  c.filters["classes"]="";
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0&&n.enable!=true).length==0);
  check(GameAccess.buttons.filter(b->b.text=="Refresh").length==1&&GameAccess.buttons.filter(b->b.text=="Loading...").length==0);
  check(GameAccess.nodes.indexOf(search)>=0&&GameAccess.nodes.indexOf(select)>=0&&GameAccess.nodes.indexOf(online)>=0&&GameAccess.buttons.indexOf(classButton)>=0);
  var retained:Array<Dynamic>=[search,select,online,classButton,filterToggle];
  check(retained.filter(control->GameAccess.removed.indexOf(control)>=0).length==0);
  check(searchUncovered(search)&&search.input.text=="ore"&&search.x==28&&search.y==108&&search.width==792);
  var backgrounds=(cast search.parent.children:Array<Dynamic>).filter(n->GameAccess.field(n,"shapes")!=null
      &&(cast n.shapes:Array<Dynamic>).filter(s->s.y==64&&s.width==1072).length>0);
  check(backgrounds.length==1&&backgrounds[0].shapes.length==2);
  c.busy=false;
  var sellers=GameAccess.labels.filter(l->l.text=="Seller: Tester"),seller=sellers[0],sellerBox=seller.parent;
  var dot:Dynamic=sellerBox.children.filter(n->n.shapes!=null)[0];
  check(GameAccess.labels.filter(l->l.text=="Online").length==MarketController.PAGE_SIZE);
  check(sellers.length==MarketController.PAGE_SIZE&&dot.shapes[0].color==0x426138&&dot.shapes[0].radius==5);
  check(dot.x==seller.x+14*8+6&&dot.y+5==12);
  check(sellers[sellers.length-1].parent.parent.y+sellerBox.parent.height<=806);
  seller.inkBounds={xMin:2.0,yMin:5.0,xMax:202.0,yMax:29.0};seller.scaleX=0.75;seller.scaleY=0.75;sellerBox.onAfterReflow();
  check(dot.x==156&&GameAccess.number(seller.y)+29*0.75<=24&&GameAccess.number(dot.x)+10<=GameAccess.number(sellerBox.width));
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketRow")==0&&n.getTip!=null).length==0);
  GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketRow")==0)[0].action();check(c.selected==row);
  GameAccess.nodes=[];GameAccess.labels=[];view.update();@:privateAccess view.advanceDetails(haxe.Timer.stamp()+1);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Category: Equipment")>=0&&Std.string(l.text).indexOf("Subcategory: Armour")>=0).length==1);
  var detailSeller=GameAccess.labels.filter(l->l.text=="Seller: Tester"&&l.parent.x==754)[0];
  check(detailSeller==null&&GameAccess.labels.filter(l->l.text=="Asking price:").length==0);
  var meta=GameAccess.labels.filter(l->Std.string(l.text).indexOf("Category: Equipment")>=0)[0];
  check(meta.scaleX==0.85&&meta.textColor==0xC9BEB5);
  var viewport=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketDetailViewport")==0)[0];
  check(viewport.y+viewport.height==726);
  check(viewport.verticalAlign=="Top"&&viewport.horizontalAlign=="Left");
  check(meta.parent.flowProperties.verticalAlign=="Top"&&meta.parent.flowProperties.horizontalAlign=="Left"&&meta.parent.flowProperties.isAbsolute==false);
  var onlineStatus=GameAccess.labels.filter(l->l.text=="Online")[0];
  var statusDot=onlineStatus.parent.children.filter(n->n.shapes!=null)[0];
  check(onlineStatus.x==statusDot.x+16);
  row.seller.onlineUntil=null;GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  check(GameAccess.labels.filter(l->l.text=="Seller: Tester").filter(l->l.parent.children.filter(n->n.shapes!=null)[0].shapes[0].color!=0x888888).length==0);
  check(GameAccess.labels.filter(l->l.text=="Offline").length==MarketController.PAGE_SIZE);
  var picture=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketDetailsIcon")==0)[0];
  check(picture.getTip!=null&&picture.width==60&&picture.height==60&&picture.showTipOnOver);
  check(picture.interactive!=null&&picture.interactive.onOver!=null);
  picture.interactive.onOver();check(picture.displayedTip!=null&&picture.displayedTip.item.kind==row.item.baseId);
  // A failing details tooltip must not close the window or remove listing actions.
  GameAccess.failNextTooltip=true;view.dirty=true;view.update();
  check(TradeFrame.active==1);check(!GameAccess.failNextTooltip);
  c.tab="My listings";GameAccess.buttons=[];view.dirty=true;view.update();
  check(GameAccess.buttons.filter(b->b.text=="Save price"||b.text=="Mark sold").length==0);
  check(GameAccess.buttons.filter(b->b.text=="Remove listing").length==1);
  check(GameAccess.buttons.filter(b->b.x==1048||b.text=="Search item").length==0);
  c.tab="Sell";view.dirty=true;GameAccess.nodes=[];GameAccess.buttons=[];view.update();
  var bank=GameAccess.buttons.filter(b->b.text=="Bank")[0];
  check(bank!=null);bank.action();check(c.bankOnly);
  var inventory=GameAccess.buttons.filter(b->b.text=="Inventory")[0];inventory.action();check(!c.bankOnly);
  check(inventory.selected==true&&inventory.kind==""&&bank.selected==false);
  var sellHint=GameAccess.labels.filter(l->Std.string(l.text).indexOf("Choose an unlocked,")==0).pop();
  check(sellHint.y>inventory.y+36&&sellHint.y<146);
  var sellSearch=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  sellSearch.input.text="shield";sellSearch.onChange();
  check(GameAccess.buttons.filter(b->b.text=="Search").length==0);
  view.update();check(GameAccess.removed.indexOf(sellSearch)<0);
  check(c.sellSearch=="shield"&&c.inventorySearches==1);
  sellSearch.input.text="bow";sellSearch.onChange();sellSearch.input.onEnter();check(c.sellSearch=="bow"&&c.inventorySearches==2&&sellSearch.input.ignoreEnter);
  view.update();check(GameAccess.removed.indexOf(sellSearch)<0);
  // Native fonts and bounds arrive after controls are constructed.
  select.selectText.inkBounds={xMin:0.0,yMin:10.0,xMax:90.0,yMax:28.0};
  select.selectText.y=100.;select.arrow.x=select.width;
  select.select.onAfterReflow();
  check(select.selectText.y+19.0==18.0&&select.arrow.x+22==select.width-10);
  check(MarketText.detail("549 ETAAttribute(Armor)")=="549 Armor");
  check(MarketText.detail("Infusion: Infusion_Manfish_DPS",trade.TradeInventory.skillName)=="Infusion: Overwhelming Tides");
  check(MarketText.detail("549 ETAttribute(Armor), 12 ETAttribute(Strength)")=="549 Armor, 12 Strength");
  check(MarketText.askingPrice(row.price)=="Asking price: 500 gold / 1 Silver Tray");
  check(MarketText.unitPrice({mode:"fixed",silverTrays:5},10)=="250 gold each");
  check(MarketText.unitPrice({mode:"fixed",silverTrays:1},3)=="166.7 gold each");
  check(MarketText.unitPrice({mode:"offers"},10)==""&&MarketText.unitPrice({mode:"fixed",silverTrays:1},1)=="");
  check(MarketText.conversion(5)=="5 Silver Trays = 2,500 gold");
  c.chosen=marketplace.MarketExport.offer(row);c.chosen.detail="Epic\n50 ETAttribute(Vitality)\n10 ETAttribute(Strength)";
  GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  var sameItem=GameAccess.buttons.filter(b->b.x==1048)[0];
  check(sameItem.enable&&sameItem.y==153&&sameItem.width==28&&sameItem.height==28&&sameItem.text=="");
  sameItem.action();check(c.searchedItem);
  var detailName=GameAccess.labels.filter(l->l.text==c.chosen.name&&Std.string(l.parent.id).indexOf("marketDetails")==0)[0];
  check(detailName.lineBreak==true&&detailName.useEllipsis==false&&detailName.maxWidth==212);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Vitality")>=0||Std.string(l.text).indexOf("Strength")>=0).length==1);
  detailName.bounds={xMin:0.,yMin:4.,xMax:200.,yMax:70.};detailName.parent.onAfterReflow();
  var count=GameAccess.labels.filter(l->l.text=="Quantity: 1")[0];check(count.y>70);
  var level=GameAccess.labels.filter(l->l.text=="Level 15"&&l.parent==detailName.parent)[0];
  check(level.y>70&&count.y==level.y+24);
  // Rarity is now communicated by the icon background, not by a text label.
  check(GameAccess.labels.filter(l->l.text=="Epic"&&l.parent==detailName.parent).length==0);
  var sellViewport=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketDetailViewport")==0)[0];
  check(sellViewport.height>270&&sellViewport.y+sellViewport.height<500);
  var buyout=GameAccess.buttons.filter(b->b.text=="Buyout").pop(),negotiable=GameAccess.buttons.filter(b->b.text=="Open to offers").pop();
  check(buyout.width==152&&negotiable.width==152&&buyout.selected&&!negotiable.selected&&negotiable.x>buyout.x+buyout.width);
  var inputs=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0),quantityBox=inputs[1],priceBox=inputs[2];
  priceBox.input.text="5";priceBox.onChange();
  check(GameAccess.labels.filter(l->l.text=="5 Silver Trays").length==1&&GameAccess.labels.filter(l->l.text=="2,500 gold").length==1);
  var conversion=GameAccess.labels.filter(l->l.text=="5 Silver Trays")[0].parent;
  var conversionIcons=(cast conversion.children:Array<Dynamic>).filter(n->n.nativeType=="h2d.Bitmap");
  check(conversionIcons[0].tile.id=="SilverTray"&&conversionIcons[1].tile.id=="Gold");
  check(!view.dirty); // Updating a price must not rebuild/focus-reset the input.
  var arrows=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketCounterArrow")==0);
  check(arrows.length==2);
  check(arrows[0].iconBmp.visible==false&&arrows[0].children.filter(n->n.points!=null).length==1);
  var up:Array<Dynamic>=arrows[0].children.filter(n->n.points!=null)[0].points;
  var down:Array<Dynamic>=arrows[1].children.filter(n->n.points!=null)[0].points;
  // Every triangle has mirrored vertices, the same winding and a closed path.
  for(layer in 0...3) {
   var k=layer*4;
   check(up[k][0]+up[k+2][0]==28&&up[k+1][0]==14&&up[k][1]==up[k+2][1]);
   check(up[k][1]+down[k][1]==17&&up[k+1][1]+down[k+2][1]==17);
   check(up[k][0]==up[k+3][0]&&up[k][1]==up[k+3][1]);
  }
  var plus=GameAccess.buttons.filter(b->b.text=="+1").pop(),minus=GameAccess.buttons.filter(b->b.text=="-1").pop();
  var plusTen=GameAccess.buttons.filter(b->b.text=="+10").pop(),minusTen=GameAccess.buttons.filter(b->b.text=="-10").pop();
  check(plus.btnText.flowProperties.isAbsolute==true&&plus.onAfterReflow!=null);
  plus.onAfterReflow();var buttonX=plus.btnText.x,buttonY=plus.btnText.y;
  plus.btnText.x=15;plus.btnText.y=15;plus.btnText.needUpdateScale=true;plus.onAfterReflow();
  check(plus.btnText.x==buttonX&&plus.btnText.y==buttonY);
  check(GameAccess.labels.filter(l->l.text=="Silver Trays").length==0);
  plus.action();check(priceBox.input.text=="6");minus.action();check(priceBox.input.text=="5");
  plusTen.action();check(priceBox.input.text=="15");minusTen.action();check(priceBox.input.text=="5");
  priceBox.input.text="nope";priceBox.onChange();check(priceBox.input.text=="5");
  priceBox.input.text="9999999999999999999999999999";priceBox.onChange();check(priceBox.input.text=="200000");
  plus.action();check(priceBox.input.text=="200000");
  priceBox.input.text="0";priceBox.onChange();minus.action();check(priceBox.input.text=="1");
  priceBox.input.text="";priceBox.onChange();priceBox.input.onFocusLost({});check(priceBox.input.text=="1");
  quantityBox.input.text="9999";quantityBox.onChange();check(quantityBox.input.text=="1");
  priceBox.input.text="25";priceBox.onChange();c.page=2;c.sellSearch="bow";var selected=c.chosen;
  view.close();GameAccess.nodes=[];view.open();view.update();
  var reopened=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0);
  check(c.chosen==selected&&c.page==2&&reopened[0].input.text=="bow"&&reopened[2].input.text=="25");
  c.inventory=[for(i in 0...21)selected];c.inventorySlots=[for(i in 0...120)i==1?null:selected];c.page=1;c.total=21;c.pages=1;
  GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  var sellSlots=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventorySlot")==0);
  check(sellSlots.length==120&&sellSlots[2].x==128&&sellSlots[10].y==64);
  check(sellSlots[0].item.kind==selected.kind&&sellSlots[0].stack.count==selected.count);
  check(sellSlots[0].component=="item-slot"&&sellSlots[0].innerSlot.nativeRarity=="Epic"&&sellSlots[0].innerSlot.width==58);
  check(sellSlots[1].stack==null&&sellSlots[1].innerSlot.nativeRarity==null&&sellSlots[1].action==null);
  check(sellSlots[0].button.width==52&&sellSlots[0].button.parent.x==3&&sellSlots[0].button.getTip!=null);
  var stackCount=sellSlots[0].button.countTxt;
  check(stackCount.parent==sellSlots[0]);
  // Native count glyphs can extend past their line box, especially after scaling.
  stackCount.inkBounds={xMin:-2.,yMin:5.,xMax:30.,yMax:26.};stackCount.scaleX=0.8;stackCount.scaleY=0.8;
  sellSlots[0].onAfterReflow();
  check(Math.abs(stackCount.x+30*0.8-53)<0.001&&Math.abs(stackCount.y+26*0.8-53)<0.001);
  c.busy=true;c.chosen=null;
  sellSlots[0].button.action();check(c.chosen==selected&&view.dirty);
  c.chosen=null;sellSlots[0].action();check(c.chosen==selected);c.busy=false;
  GameAccess.nodes=[];view.update();
  c.atLimit=true;GameAccess.buttons=[];view.dirty=true;view.update();
  var limitButton=GameAccess.buttons.filter(b->b.text=="Too many listings").pop();check(limitButton!=null&&!limitButton.enable);
  c.atLimit=false;GameAccess.buttons=[];view.dirty=true;view.update();check(GameAccess.buttons.filter(b->b.text=="List item for sale").pop().enable);
  c.listed=true;GameAccess.buttons=[];GameAccess.labels=[];view.dirty=true;view.update();
  check(GameAccess.labels.filter(l->l.text=="For sale").length==119&&GameAccess.labels.filter(l->l.text=="Already for sale").length==1);
  var sevenSlots=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventorySlot")==0);
  check(sevenSlots[6].x==384&&sevenSlots[6].y==0&&sevenSlots[7].x==0&&sevenSlots[7].y==64);
  var selectedGrid=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventoryGrid")==0)[0];
  check(selectedGrid.width==442&&selectedGrid.flowProperties.horizontalAlign=="Middle");
  var overlays=(cast selectedGrid.children:Array<Dynamic>).filter(n->n.nativeType=="h2d.Object");
  check(overlays.length==1&&overlays[0].parent==selectedGrid&&overlays[0].children[0].nativeType=="h2d.Graphics");
  check(selectedGrid.children[selectedGrid.children.length-1]==overlays[0]);
  // A styled native frame may have an offset and exceed the nominal 58px box.
  var selectedSlot=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventorySlot")==0).pop();
  selectedSlot.innerSlot.inkBounds={xMin:60.,yMin:70.,xMax:122.,yMax:131.};selectedGrid.onAfterReflow();
  var outline=overlays[0].children[0],points:Array<Dynamic>=outline.points;
  check(overlays[0].x==60&&overlays[0].y==70);
  check(points[0][0]==0&&points[0][1]==0&&points[1][0]<62/3);
  check(points.filter(p->p[0]==62).length>0);
  // No polygon spans the centre of any edge; every corner has both arms.
  for(i in 0...12){var poly=points.slice(i*7,i*7+7);check(poly.length==7);check(poly.filter(p->p[0]>20&&p[0]<42||p[1]>20&&p[1]<41).length==0);}
  check(points.filter(p->p[1]==61).length>0); // All four native edges, not the old fixed square.
  var saleBadge=GameAccess.labels.filter(l->l.text=="For sale")[0];
  saleBadge.needUpdateScale=true;saleBadge.parent.onAfterReflow();
  check(saleBadge.scaleX==0.65&&saleBadge.x>3&&saleBadge.y+4*0.65>=0&&saleBadge.y+22*0.65<=16);
  check(GameAccess.buttons.filter(b->b.text=="List item for sale").length==0);
  c.locked=true;GameAccess.labels=[];GameAccess.buttons=[];view.dirty=true;view.update();
  check(GameAccess.labels.filter(l->l.text=="Locked").length==119&&GameAccess.labels.filter(l->l.text=="Item is locked").length==1&&GameAccess.labels.filter(l->l.text=="For sale").length==0);
  check(GameAccess.buttons.filter(b->b.text=="List item for sale").length==0);
  var lockBadge=GameAccess.labels.filter(l->l.text=="Locked")[0];lockBadge.parent.onAfterReflow();
  check(lockBadge.scaleX==0.65&&lockBadge.parent.width==saleBadge.parent.width&&lockBadge.parent.height==saleBadge.parent.height);
  c.locked=false;c.bound=true;GameAccess.labels=[];GameAccess.buttons=[];view.dirty=true;view.update();
  check(GameAccess.labels.filter(l->l.text=="Bound").length==119&&GameAccess.labels.filter(l->l.text=="Item cannot be traded").length==1&&GameAccess.labels.filter(l->l.text=="For sale").length==0);
  check(GameAccess.buttons.filter(b->b.text=="List item for sale").length==0);
  var boundBadge=GameAccess.labels.filter(l->l.text=="Bound")[0];boundBadge.parent.onAfterReflow();
  check(boundBadge.scaleX==0.65&&boundBadge.parent.width==saleBadge.parent.width&&boundBadge.parent.height==saleBadge.parent.height);
  c.bound=false;
  c.listed=false;GameAccess.nodes=[];view.dirty=true;view.update();
  var gridViewport=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventoryViewport")==0)[0];
  check(gridViewport.component=="flow"&&gridViewport.overflow=="Scroll"
   &&gridViewport.layout=="Vertical"&&gridViewport.multiline==false);
  check(gridViewport.y+gridViewport.height<806&&gridViewport.height<sellSlots[118].parent.height);
  // Preserve full normal-flow height so the native scrollbar can measure overflow.
  check(sellSlots[118].parent.flowProperties.isAbsolute==false);
  var scrollBar:Dynamic=gridViewport.scrollBar,scrollCursor:Dynamic=gridViewport.scrollBarCursor;
  check(scrollBar!=null&&scrollCursor.parent==scrollBar&&scrollBar.parent==gridViewport);
  check(scrollBar.width==10&&scrollCursor.width==10);
  check(scrollBar.flowProperties.isAbsolute&&scrollBar.flowProperties.horizontalAlign==null&&scrollBar.flowProperties.verticalAlign==null);
  check(scrollBar.x==gridViewport.width-14&&scrollBar.x>=0&&scrollBar.x+scrollBar.width<=gridViewport.width);
  check(scrollBar.y==0);
  check((cast scrollBar.dom.classes:Array<String>).indexOf("scrollbar")>=0);
  check((cast scrollBar.dom.classes:Array<String>).indexOf("market-inventory-scrollbar")<0);
  check((cast scrollCursor.dom.classes:Array<String>).indexOf("cursor")>=0);
  // A real flowing grid must make the native track visible when it overflows.
  check(gridViewport.contentHeight>gridViewport.height&&scrollBar.visible==true);
  // Unlike an invisible native tile, the sibling Graphics paint has its own
  // explicit rounded track/thumb while native children remain unchanged.
  var scrollbarPaint:Dynamic=@:privateAccess view.sellScrollbar.paint;
  check(scrollbarPaint.parent==TradeFrame.latest.container&&scrollbarPaint.visible==true);
  check(scrollbarPaint.x==gridViewport.x+scrollBar.x&&scrollbarPaint.y==gridViewport.y+scrollBar.y);
  check(scrollbarPaint.shapes.length==3);
  check(scrollbarPaint.shapes[0].color==0xEFE3D1&&scrollbarPaint.shapes[1].color==0xB69B7F
   &&scrollbarPaint.shapes[1].radius==5&&scrollbarPaint.shapes[2].color==0x806B5B
   &&scrollbarPaint.shapes[2].height<gridViewport.height);
  check(scrollBar.children.length==1&&scrollBar.children[0]==scrollCursor);
  check(scrollBar.onAfterReflow==null&&scrollCursor.onAfterReflow==null);
  gridViewport.scrollPosY=128.;view.update();
  check(scrollbarPaint.shapes[2].y>0&&scrollbarPaint.shapes[1].height==gridViewport.height);
  sellSlots[0].action();GameAccess.nodes=[];view.update();
  var newGrid=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventoryViewport")==0)[0];newGrid.onAfterReflow();check(newGrid.scrollPosY==128);
  // Selection refresh must reconstruct the same native vertical scrolling
  // hierarchy; painting/reparenting the scrollbar is not needed.
  check(newGrid.layout=="Vertical"&&newGrid.multiline==false);
  check(newGrid.scrollBar.parent==newGrid&&newGrid.scrollBarCursor.parent==newGrid.scrollBar);
  check(newGrid.scrollBar.children.length==1&&newGrid.scrollBar.children[0]==newGrid.scrollBarCursor);
  check(newGrid.scrollBar.x==newGrid.width-14&&newGrid.scrollBar.flowProperties.horizontalAlign==null);
  var selectedPaint:Dynamic=@:privateAccess view.sellScrollbar.paint;
  check(selectedPaint==scrollbarPaint&&GameAccess.removed.indexOf(scrollbarPaint)<0);
  GameAccess.nodes=[];GameAccess.buttons=[];GameAccess.labels=[];c.bankOnly=true;view.dirty=true;view.update();
  var bankSlots=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventorySlot")==0);
  check(bankSlots[9].x==576&&bankSlots[9].y==0&&bankSlots[10].x==0&&bankSlots[10].y==64);
  check(bankSlots[0].parent.width==634&&bankSlots[0].parent.flowProperties.horizontalAlign=="Middle");
  var bankViewport:Dynamic=bankSlots[0].parent.parent;
  check(bankViewport.component=="flow"&&bankViewport.overflow=="Scroll"
   &&bankViewport.layout=="Vertical"&&bankViewport.multiline==false);
  check(bankSlots[0].parent.flowProperties.isAbsolute==false&&bankSlots[0].parent.height>bankViewport.height);
  check(bankViewport.scrollBar.width==10&&bankViewport.scrollBarCursor.width==10);
  check(bankViewport.contentHeight>bankViewport.height&&bankViewport.scrollBar.visible==true);
  var bankPaint:Dynamic=@:privateAccess view.sellScrollbar.paint;
  check(bankPaint==scrollbarPaint&&scrollbarPaint.shapes.length==3
   &&scrollbarPaint.shapes[2].height<scrollbarPaint.shapes[1].height);
  check(bankViewport.scrollBar.flowProperties.isAbsolute&&bankViewport.scrollBar.flowProperties.horizontalAlign==null
   &&bankViewport.scrollBar.flowProperties.verticalAlign==null);
  check(bankViewport.scrollBar.x==bankViewport.width-14
   &&bankViewport.scrollBar.x+bankViewport.scrollBar.width<=bankViewport.width);
  check((cast bankViewport.scrollBar.dom.classes:Array<String>).indexOf("scrollbar")>=0);
  check(bankViewport.scrollBar.children.length==1&&bankViewport.scrollBar.children[0]==bankViewport.scrollBarCursor);
  var tabs=GameAccess.buttons.filter(b->b.y==820&&b.x<704);
  check(tabs.length==2&&tabs[0].text=="First tab"&&tabs[1].text=="Second tab"&&tabs[0].selected);
  tabs[1].action();GameAccess.nodes=[];view.update();check(c.bankTab==1);
  newGrid=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInventoryViewport")==0)[0];newGrid.onAfterReflow();check(newGrid.scrollPosY==0);
  check(GameAccess.buttons.filter(b->b.text=="Previous"||b.text=="Next").length==0);
  c.bankOnly=false;
  negotiable.action();GameAccess.nodes=[];GameAccess.buttons=[];GameAccess.labels=[];view.update();
  check(GameAccess.labels.filter(l->l.text=="Buyers can contact you to agree on a price.").length==1);
  buyout=GameAccess.buttons.filter(b->b.text=="Buyout")[0];negotiable=GameAccess.buttons.filter(b->b.text=="Open to offers")[0];
  check(!buyout.selected&&negotiable.selected);
  negotiable.action();check(!view.dirty);
  buyout.action();GameAccess.nodes=[];GameAccess.buttons=[];view.update();
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketCounterArrow")==0).length==2);
  c.tab="Browse";c.filters["rarity"]="Epic";c.filters["search"]="shield";c.filters["online"]="false";
  GameAccess.buttons=[];view.dirty=true;view.update();
  GameAccess.buttons.filter(b->b.text=="Hide filters")[0].action();GameAccess.nodes=[];view.update();
  check(!c.filtersExpanded&&c.filters["rarity"]=="Epic"&&c.filters["search"]=="shield"&&c.filters["online"]=="false");
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0).length==0);
  // Reused controls must receive current values and fresh category-dependent callbacks.
  var toggle=GameAccess.buttons.filter(b->b.text=="Show filters")[0];
  var searchField=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0)[0];
  toggle.action();view.update();
  var dropdowns=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketSelect")==0);
  var category=dropdowns[0],subcategory=dropdowns[1];
  category.selectedIndex=2;category.onSelectOption(null);view.update();
  check(c.filters["category"]=="Weapon"&&subcategory.options[1].name=="Sword");
  check(category.options[2].name=="Weapons"&&category.options[3].name=="Armors"&&category.options[4].name=="Accessories");
  subcategory.selectedIndex=20;subcategory.select.action();
  var popup=subcategory.listWindow.content;
  check(GameAccess.field(subcategory.listWindow,"filter")==null);
  check(popup.overflow=="Scroll"&&popup.maxHeight==300&&popup.minHeight==300&&subcategory.items.length>10);
  popup.onAfterReflow();check(popup.scrollPosY==330&&popup.verticalSpacing==0);
  var currentHolder=TradeFrame.latest.header.children[1];
  // The final header font is wider than the default font used during creation.
  TradeFrame.latest.title.glyphWidth=14.;TradeFrame.latest.header.onAfterReflow();
  check(currentHolder.x==28+11*14+8);
  var oldX=currentHolder.x,oldY=currentHolder.y;
  TradeFrame.latest.title.bounds={xMin:0.,yMin:0.,xMax:1000.,yMax:60.};
  TradeFrame.latest.title.x=0;TradeFrame.latest.title.scaleX=0.5;TradeFrame.latest.header.onAfterReflow();
  check(currentHolder.x==oldX&&currentHolder.y==oldY&&currentHolder.children[0].x==0);
  GameAccess.call("ui.comp.Dropdown","close",subcategory,[null]);
  check(GameAccess.nodes.indexOf(category)>=0&&GameAccess.nodes.indexOf(subcategory)>=0);
  category.selectedIndex=5;category.onSelectOption(null);view.update();
  check(c.filters["category"]=="Consumables"&&subcategory.options[1].name=="Food");
  subcategory.selectedIndex=1;subcategory.onSelectOption(null);view.update();check(c.filters["subcategory"]=="Food");
  check(GameAccess.removed.indexOf(category)<0&&GameAccess.removed.indexOf(subcategory)<0);
  check(GameAccess.nodes.indexOf(searchField)>=0&&GameAccess.buttons.indexOf(toggle)>=0);
  check(category.options[6].name=="Collectibles");
  category.selectedIndex=6;category.onSelectOption(null);view.update();
  check(c.filters["category"]=="Collections"&&subcategory.options[1].name=="Recipes");
  var rarityFilter=dropdowns[2];
  check(rarityFilter.options[4].name=="Epic"&&rarityFilter.options[5].name=="Epic (Prismatic)"&&rarityFilter.options[6].name=="Legendary");
  rarityFilter.selectedIndex=5;rarityFilter.onSelectOption(null);view.update();
  check(c.filters["rarity"]=="Epic"&&c.filters["prismatic"]=="true"&&rarityFilter.selectedIndex==5);
  rarityFilter.selectedIndex=4;rarityFilter.onSelectOption(null);view.update();
  check(c.filters["rarity"]=="Epic"&&c.filters["prismatic"]=="");
  toggle.action();view.update();
  check(!c.filtersExpanded&&GameAccess.removed.indexOf(category)>=0&&GameAccess.removed.indexOf(toggle)<0);
  row.item.itemLevel=35;row.item.requiredLevel=15;row.item.category="Collections";c.rows=[row];c.selected=row;
  GameAccess.nodes=[];GameAccess.labels=[];GameAccess.buttons=[];view.dirty=true;view.update();
  var levelCell=GameAccess.labels.filter(l->l.text=="15")[0];
  check(levelCell!=null&&Std.string(levelCell.parent.id).indexOf("marketRow")==0);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Category: Collectibles")>=0).length==1);
  check(GameAccess.buttons.filter(b->b.x==1048||b.text=="Search item"||StringTools.startsWith(b.text,"Level")).length==0);
  var levelHeader=GameAccess.nodes.filter(n->n.id=="marketSortrequired-level")[0];
  check(levelHeader.component=="element"&&levelHeader.x==420&&GameAccess.labels.filter(l->l.parent==levelHeader&&l.text=="LEVEL").length==1);
  var levelTitle=GameAccess.labels.filter(l->l.parent==levelHeader&&l.text=="LEVEL")[0];
  levelCell.inkBounds={xMin:3.,yMin:4.,xMax:29.,yMax:22.};levelCell.scaleX=0.8;
  levelTitle.inkBounds={xMin:1.,yMin:4.,xMax:45.,yMax:22.};levelTitle.scaleX=0.9;
  levelCell.parent.onAfterReflow();levelHeader.onAfterReflow();
  var cellCenter=22+GameAccess.number(levelCell.parent.x)+GameAccess.number(levelCell.x)+16*0.8;
  var titleCenter=GameAccess.number(levelHeader.x)+GameAccess.number(levelTitle.x)+23*0.9;
  check(Math.abs(cellCenter-titleCenter)<0.5); // Allow subpixel rounding in native text positions.
  levelHeader.action();view.update();check(c.listingSort()=="required-level-asc");
  GameAccess.nodes.filter(n->n.id=="marketSortrequired-level")[0].action();view.update();
  check(c.listingSort()=="required-level-desc"&&GameAccess.labels.filter(l->l.text=="LEVEL ↓").length==1);
  GameAccess.nodes.filter(n->n.id=="marketSortrequired-level")[0].action();view.update();
  check(c.listingSort()==""&&GameAccess.labels.filter(l->l.text=="LEVEL").length==1);
  GameAccess.nodes.filter(n->n.id=="marketSortprice")[0].action();view.update();
  check(c.listingSort()=="price-asc"&&GameAccess.labels.filter(l->l.text=="TOTAL PRICE ↑").length==1);
  GameAccess.nodes.filter(n->n.id=="marketSortprice")[0].action();view.update();
  check(c.listingSort()=="price-desc"&&GameAccess.labels.filter(l->l.text=="TOTAL PRICE ↓").length==1);
  GameAccess.nodes.filter(n->n.id=="marketSortprice")[0].action();view.update();check(c.listingSort()=="");
  // Presence refreshes the existing label/dot without rebuilding focused controls.
  var statuses=GameAccess.labels.filter(l->l.text=="Offline");check(statuses.length>0);
  c.presenceOverride=true;@:privateAccess view.presenceCheckAt=0;view.update();
  check(statuses[0].text=="Online"&&GameAccess.labels.indexOf(statuses[0])>=0);
  c.presenceOverride=false;@:privateAccess view.presenceCheckAt=0;view.update();
  check(statuses[0].text=="Offline"&&!view.dirty);c.presenceOverride=null;
  // Only the item-information viewport receives the dark tooltip background.
  var panel=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketDetailViewport")==0)[0];
  var detailBacks:Array<Dynamic>=[];
  for(child in (cast panel.parent.children:Array<Dynamic>))
   if(child.shapes!=null)for(shape in (cast child.shapes:Array<Dynamic>))if(shape.color==0x4A423C&&shape.alpha==1)detailBacks.push(shape);
  check(detailBacks.length==1&&detailBacks[0].y==panel.y-8&&detailBacks[0].y+detailBacks[0].height<752);
  var info=GameAccess.labels.filter(l->Std.string(GameAccess.field(l.parent,"id")).indexOf("marketDetails")==0);
  check(info.filter(l->l.text==row.item.name&&l.textColor==0xFFFFFF).length==1);
  // Browse, My listings and Sell use the same coloured icon backgrounds as
  // native Inventory/Bank slots, without repeated English rarity labels.
  function detailIconFill():Dynamic {
   var picture=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketDetailsIcon")==0)[0];
   check(picture!=null);
   for(child in (cast picture.children:Array<Dynamic>))if(child.shapes!=null)
    for(shape in (cast child.shapes:Array<Dynamic>))if(shape.width==58)return shape;
   return null;
  }
  for(tab in ["Browse","My listings","Sell"]) {
   c.tab=tab;c.selected=row;
   c.chosen=cast {uid:"selected",kind:row.item.baseId,name:row.item.name,count:1,
    detail:"Epic",color:0,fingerprint:"",preview:row.item.native};
   row.item.native.flags=2;row.item.prismatic=false;
   GameAccess.labels=[];view.dirty=true;view.update();
   check(detailIconFill().color==trade.TradeRarity.fill("Epic"));
   check(GameAccess.labels.filter(l->l.text=="Epic"||l.text=="Epic (Prismatic)").length==0);
   row.item.native.flags=0;GameAccess.labels=[];view.dirty=true;view.update();
   check(detailIconFill().color==trade.TradeRarity.fill("Epic"));
  }
  var originalRarity=row.item.rarity,originalDescription=row.item.detail;
  row.item.rarity="Legendary";row.item.detail="+63 Vitality\n+27 Strength";
  for(tab in ["Browse","My listings"]) {
   c.tab=tab;c.selected=row;GameAccess.labels=[];view.dirty=true;view.update();
   check(detailIconFill().color==trade.TradeRarity.fill("Legendary"));
   check(GameAccess.labels.filter(l->l.text=="Legendary").length==0);
   check(GameAccess.labels.filter(l->Std.string(GameAccess.field(l.parent,"id")).indexOf("marketDetails")==0
    &&Std.string(l.text).indexOf("+63 Vitality")>=0
    &&Std.string(l.text).indexOf("+27 Strength")>=0).length==1);
  }
  row.item.detail="Legendary\n+63 Vitality";
  c.tab="Browse";GameAccess.labels=[];view.dirty=true;view.update();
  check(detailIconFill().color==trade.TradeRarity.fill("Legendary"));
  check(GameAccess.labels.filter(l->l.text=="Legendary").length==0);
  check(GameAccess.labels.filter(l->l.text=="+63 Vitality"
   &&Std.string(GameAccess.field(l.parent,"id")).indexOf("marketDetails")==0).length==1);
  c.tab="Sell";c.chosen=cast {uid:"selected",kind:row.item.baseId,name:row.item.name,count:1,
   detail:"+63 Vitality\n+27 Strength",color:0,fingerprint:"",preview:row.item.native};
  c.chosen.preview.rarity="";
  GameAccess.labels=[];view.dirty=true;view.update();
  check(detailIconFill().color==trade.TradeRarity.fill("Epic"));
  check(GameAccess.labels.filter(l->l.text=="Epic").length==0);
  check(GameAccess.labels.filter(l->Std.string(GameAccess.field(l.parent,"id")).indexOf("marketDetails")==0
   &&Std.string(l.text).indexOf("+63 Vitality")>=0).length==1);
  row.item.rarity=originalRarity;row.item.detail=originalDescription;row.item.native.rarity="Epic";
  c.tab="Browse";row.item.prismatic=true;GameAccess.labels=[];view.dirty=true;view.update();
  check(detailIconFill().color==trade.TradeRarity.fill("Epic"));
  row.item.prismatic=false;
  // The Browse row and details must use the viewer's translated item name.
  trade.TradeInventory.localizedNames[row.item.baseId]="Bouclier des marées";
  GameAccess.labels=[];view.dirty=true;view.update();
  check(GameAccess.labels.filter(l->l.text=="Bouclier des marées").length>=2);
  trade.TradeInventory.localizedNames.remove(row.item.baseId);
  // Native detail formatting retains source-specific values and colour markup.
  var nativeId:Dynamic={token:"gift-id"};
  trade.TradeInventory.definitions["Gift"]={id:nativeId,skills:[]};GameAccess.slotIds=[nativeId];
  var nativeItem:Dynamic={nativeType:"st.item.Weapon",slots:["Gift"]};
  var offer=marketplace.MarketExport.offer(row);
  var rich=marketplace.MarketDetails.text(offer,nativeItem);
  check(rich.indexOf("75 Vitality")>=0&&rich.indexOf("[!Gift]")>=0&&GameAccess.slotReads==1);
  check(rich.indexOf("-40</font> Magic Penetration")>=0&&rich.indexOf("+40</font> Armor Penetration")>=0);
  check(rich.indexOf("#3399ff")>=0&&rich.indexOf("Enchant: Flaming Weapon")>=0);
  check(marketplace.MarketDetails.text(offer,{nativeType:"st.Item"})==null);
  c.tab="Browse";row.item.requiredLevel=25;row.item.native.upgrade=5;row.item.detail="Epic\nLevel 25  |  Upgrade +5\n75 Vitality";
  GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  var stars=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketUpgrade")==0);
  var level25=GameAccess.labels.filter(l->l.text=="Level 25")[0];
  check(stars.length==5&&stars[0].fmtText.text=="GearUpgrade"&&stars[0].x>level25.x+64&&stars[0].y==level25.y-1);
  check(GameAccess.labels.filter(l->Std.string(l.text).indexOf("Upgrade +")>=0).length==0);
  for(i in 1...stars.length)check(stars[i].x-(stars[i-1].x+stars[i-1].width)==4);
  row.item.native.upgrade=0;view.dirty=true;view.update();
  check(GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketUpgrade")==0).length==0);
  c.connectionIssue=true;view.update();view.update();check(GameAccess.dialogs==1);
  // A page-level error keeps navigation available, and reopening clears recovery state.
  c.selected=null;view.recover("Injected page failure");GameAccess.buttons=[];view.update();
  check(TradeFrame.active==1);check(GameAccess.buttons.filter(b->b.text=="My listings").length==1);
  c.connectionIssue=false;view.close();check(TradeFrame.active==0);view.open();view.update();check(TradeFrame.active==1);
  view.close();check(TradeFrame.active==0);
  check(GameAccess.textures.filter(t->t.disposed!=true).length==0);
  c.tab="Browse";c.filters["search"]="shield";view.open();view.update();
  var browseSearch=GameAccess.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput"))[0];
  var clearSearch=GameAccess.nodes.filter(n->n.id=="marketSearchClear")[0],searches=c.refreshes;
  check(clearSearch.visible&&clearSearch.parent==browseSearch&&clearSearch.x+clearSearch.width<browseSearch.width);
  clearSearch.action();view.update();check(c.filters["search"]==""&&browseSearch.input.text==""&&c.refreshes==searches+1);
  check(GameAccess.nodes.filter(n->n.id=="marketSearchClear").length==1&&clearSearch.visible);
  view.close();c.tab="Sell";c.sellSearch="sword";view.open();view.update();
  var sellInput=GameAccess.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput"))[0];
  clearSearch=GameAccess.nodes.filter(n->n.id=="marketSearchClear")[0];var localSearches=c.inventorySearches;
  clearSearch.action();view.update();check(c.sellSearch==""&&sellInput.input.text==""&&c.inventorySearches==localSearches+1);
  check(GameAccess.nodes.filter(n->n.id=="marketSearchClear").length==1&&c.refreshes==searches+1);
  sellInput.input.text="new";sellInput.onChange();check(clearSearch.visible);view.close();
  MarketplaceDrawerTest.run(row);
  view.open();c.tab="My listings";c.selected=row;c.rows=[row];row.item.quantity=5;row.price={mode:"fixed",silverTrays:7};
  GameAccess.buttons=[];GameAccess.nodes=[];view.dirty=true;view.update();
  GameAccess.buttons.filter(b->b.text=="Edit listing")[0].action();GameAccess.buttons=[];GameAccess.nodes=[];view.update();
  check(c.editingListingId==row.id&&GameAccess.buttons.filter(b->b.text=="Save changes").length==1);
  var editInputs=GameAccess.nodes.filter(n->Std.string(n.id).indexOf("marketInput")==0);
  check(editInputs.length==2&&editInputs[0].input.text=="5"&&editInputs[1].input.text=="7");
  GameAccess.buttons.filter(b->b.text=="Save changes")[0].action();check(c.edited.quantity==5&&c.edited.trays==7&&!c.edited.offers);
  GameAccess.buttons.filter(b->b.text=="Cancel")[0].action();check(c.editingListingId=="");
  c.tab="Sell";c.availableQuantity=9;c.editingListingId="";c.listed=false;c.locked=false;c.bound=false;
  GameAccess.nodes=[];GameAccess.labels=[];view.dirty=true;view.update();
  var totalCounter=GameAccess.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput")&&n.x==754&&n.y==536)[0];
  totalCounter.input.text="99";totalCounter.onChange();check(totalCounter.input.text=="9");
  check(GameAccess.labels.filter(l->l.text=="of 9 available").length==1);
  Sys.println("Marketplace UI recovery checks passed: "+checks);
 }
}
