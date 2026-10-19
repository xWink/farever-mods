import marketplace.MarketPresence;
import marketplace.MarketExport;
import marketplace.MarketEndpoints;
import trade.TradeInventory;
import trade.TradeTypes;
class MarketplaceTest {
 static var checks=0;
 static function check(b:Bool):Void {checks++;if(!b)throw "Marketplace assertion "+checks;}
 static function fails(f:Void->Void):Void {var failed=false;try f()catch(_:Dynamic)failed=true;check(failed);}
 static function main():Void {
  var p=new MarketPresence();check(p.due(0));p.completed(200,100,0,4);check(!p.due(163));check(p.due(164));
  p.completed(429,200,90,2);check(!p.due(291));check(p.due(292));
  p.completed(503,300,0,0);check(p.next==360);p.completed(0,360,0,0);check(p.next==480);
  for(i in 0...10)p.completed(503,0,0,0);check(p.next==900);
  p.completed(401,1000,0,0);check(!p.due(100000));p.reset();check(p.due(0));p.completed(403,0,0,0);check(!p.due(99999));
  for(pair in [["na","north-america"],["eu","europe"],["sa","latin-america"],["as","asia"],["cn","mainland-china"],["local",""],["invented",""]])check(MarketExport.server(pair[0])==pair[1]);
  check(MarketEndpoints.validUrl("https://fareverly.com/api/v1/marketplace/listings?server=europe"));
  for(url in ["http://fareverly.com/api/v1/account","https://fareverly.com.evil/api/v1/account","https://elsewhere/api/v1/account","https://fareverly.com/contact"])check(!MarketEndpoints.validUrl(url));
  var inv=new TradeInventory(),item:TradeItem={uid:"item",kind:"Shoulders_EManfish_WizCle",count:10,name:"Shoulders",detail:"",color:0,fingerprint:"fp",preview:null};
  var app={connectionInfo:{heroID:"987654321012345678"}},value=MarketExport.snapshot(inv,item,3,8,false,"europe",app);
  check(value.schemaVersion==2);check(value.character.id=="987654321012345678");check(value.item.quantity==3);check(value.item.native.slots[0]=="DivinedEmbroidery");check(value.price.silverTrays==8);
  var offers=MarketExport.snapshot(inv,item,1,0,true,"europe",app);check(offers.price.mode=="offers");check(!Reflect.hasField(offers.price,"silverTrays"));
  inv.allowed=false;fails(()->MarketExport.snapshot(inv,item,1,1,false,"europe",app));inv.allowed=true;
  TradeInventory.fp="changed";fails(()->MarketExport.snapshot(inv,item,1,1,false,"europe",app));TradeInventory.fp="fp";
  fails(()->MarketExport.snapshot(inv,item,11,1,false,"europe",app));fails(()->MarketExport.snapshot(inv,item,1,200001,false,"europe",app));
  fails(()->MarketExport.snapshot(inv,item,1,1,false,"",app));fails(()->MarketExport.snapshot(inv,item,1,1,false,"europe",{connectionInfo:{heroID:0}}));
  inv.stack=null;fails(()->MarketExport.snapshot(inv,item,1,1,false,"europe",app));
  Sys.println("Marketplace checks passed: "+checks);
 }
}
