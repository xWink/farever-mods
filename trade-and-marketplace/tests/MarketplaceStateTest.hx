import marketplace.MarketController;
import marketplace.MarketWorker;
import trade.TradeInventory;
@:access(marketplace.MarketController)
class MarketplaceStateTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace state assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,listing:Dynamic,cursor:Null<String>):Void {
        if(Reflect.field(listing,"server")==null)Reflect.setField(listing,"server",c.server);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({listings:[listing],nextCursor:cursor})}});
        c.update(app,0);
    }
    static function ownReply(c:MarketController,app:Dynamic,rows:Array<Dynamic>):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({listings:rows,nextCursor:null})}});c.update(app,0);
    }
    static function main():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player,connectionInfo:{heroID:"test-hero"}};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        c.open();check(c.view.shown&&MarketWorker.current.sent.length==1);
        reply(c,app,{id:"first"},"next-page");
        c.page=2;c.refresh();check(Std.string(MarketWorker.current.sent[1].path).indexOf("cursor=next-page")>=0);
        reply(c,app,{id:"second"},null);c.selected=c.rows[0];
        var selected=c.selected;
        c.view.close();c.open();
        check(MarketWorker.current.sent.length==3&&!c.busy);
        check(c.page==2&&c.selected==selected&&c.rows[0]==selected&&c.view.shown);
        c.chooseTab("Sell");check(c.busy&&c.inventory.length==1);ownReply(c,app,[]);c.chosen=c.inventory[0];var chosen=c.chosen;
        c.sellSearch="should";c.searchInventory();c.view.close();c.open();
        check(c.tab=="Sell"&&c.chosen==chosen&&c.sellSearch=="should"&&c.inventory[0]==chosen);
        c.sellSearch="no match";c.searchInventory();check(c.chosen==null&&c.total==0);
        c.sellSearch="";c.searchInventory();check(c.total==1&&c.page==1);
        c.inv.inventory={content:[for(i in 0...21){item:{uid:Std.string(i),inf:{}},count:1}]};
        c.loadInventory();check(c.total==21&&c.pages==1&&c.inventorySlots.length==21);
        c.page=3;c.refresh();ownReply(c,app,[]);check(c.page==1&&c.pages==1&&c.total==21);
        c.chooseTab("Browse");reply(c,app,{id:"third"},null);c.selected=c.rows[0];c.page=2;
        c.disconnect();check(c.selected==null&&c.rows.length==0&&c.page==1&&!c.view.shown);
        c.player=player;c.inv=new TradeInventory(player);c.server="europe";
        var before=MarketWorker.current.sent.length;c.open();
        check(MarketWorker.current.sent.length==before+1&&Std.string(MarketWorker.current.sent[before].path).indexOf("cursor=")<0);
        reply(c,app,{id:"delete-me",revision:7},null);
        c.ready=true;c.chooseTab("My listings");ownReply(c,app,[{id:"delete-me",revision:7,server:"europe"},{id:"remaining",revision:1,server:"europe"}]);c.selected=c.rows[0];
        var sent=MarketWorker.current.sent.length;
        c.remove();
        check(c.selected==null&&c.rows.length==1&&c.rows[0].id=="remaining"&&c.busy);
        var deletion=MarketWorker.current.sent[sent];
        check(deletion.method=="DELETE"&&deletion.path=="/api/v1/marketplace/listings/delete-me");
        var headers:Map<String,String>=deletion.headers;
        check(headers["If-Match"]=='"7"'&&deletion.body==null);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:204,error:"",retryAfter:"",body:""}});
        c.update(app,0);
        check(MarketWorker.current.sent.length==sent+1);
        check(c.selected==null&&c.page==1);
        check(!c.busy&&c.selected==null&&c.rows.length==1&&c.rows[0].id=="remaining");
        c.selected=c.rows[0];sent=MarketWorker.current.sent.length;c.remove();
        check(c.rows.length==0&&c.selected==null);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:409,error:"HTTP Error #409",retryAfter:"",body:'{"error":{"code":"stale_revision"}}'}});
        c.update(app,0);
        check(!c.busy&&c.rows[0].id=="remaining"&&MarketWorker.current.sent.length==sent+1);
        check(c.message=="This listing changed. Refresh before removing it.");
        check(c.selected!=null&&c.selected.id=="remaining");
        var blocked=MarketWorker.current.sent.length;c.ready=false;c.remove();
        check(c.rows.length==1&&c.selected.id=="remaining"&&MarketWorker.current.sent.length==blocked&&!c.busy);
        c.ready=true;c.connectionIssue=false;
        c.filters["search"]="shield";c.filters["rarity"]="Epic";c.filters["online"]="false";c.tab="Browse";
        var noFetch=MarketWorker.current.sent.length,previous=c.selected,previousPage=c.page;
        c.toggleFilters();check(c.filtersExpanded&&c.pageSize()==8&&c.page==previousPage);
        check(MarketWorker.current.sent.length==noFetch&&c.selected==previous&&!c.busy);
        c.toggleFilters();check(!c.filtersExpanded&&c.filters["rarity"]=="Epic"&&c.filters["online"]=="false");
        check(MarketWorker.current.sent.length==noFetch&&c.selected==previous);
        c.filters["search"]="new search";c.refresh();ownReply(c,app,[{id:"remaining",revision:4}]);
        check(c.selected==c.rows[0]&&c.selected.revision==4);
        c.refresh();MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:400,error:"HTTP Error #400",retryAfter:"",body:'{"error":{"code":"invalid_query"}}'}});
        c.update(app,0);check(c.selected==c.rows[0]&&!c.busy);
        c.filters["search"]="filtered out";c.refresh();ownReply(c,app,[{id:"other"}]);
        check(c.selected==null);
        var stack=c.inv.stacks()[0],offer=TradeInventory.describe(stack.item,stack.count);
        var listed=marketplace.MarketExport.itemData(stack.item,offer,1);
        c.chooseTab("Sell");c.refresh();
        var path=Std.string(MarketWorker.current.sent[MarketWorker.current.sent.length-1].path);
        check(path=="/api/v1/marketplace/listings?mine=true&limit=50");
        ownReply(c,app,[{item:listed}]);check(c.inventory.length==1&&c.isListed(c.inventory[0]));
        c.inv.hero.loadout.banks=[{content:[{item:{uid:"bank-item",inf:{}},count:20}]}];
        c.setBankOnly(true);check(c.inventory.length==1&&c.isListed(c.inventory[0]));
        // Refresh after cancellation/expiry restores the same bank item.
        c.refresh();check(c.busy&&c.isListed(c.inventory[0]));ownReply(c,app,[]);check(c.inventory.length==1&&c.inventory[0].count==20&&!c.isListed(c.inventory[0]));
        var firstBank=c.inv.hero.loadout.banks[0];
        c.inv.hero.loadout.banks=[firstBank,{content:[null,{item:{uid:"tab-two",inf:{}},count:3},{item:{uid:"locked",locked:true,inf:{}},count:1}]}];
        player.accountProgress={nbBanks:1,bankTabs:[{name:"Crafting"},{name:"Equipment"}]};
        c.loadInventory();check(c.bankNames.length==1);
        player.accountProgress.nbBanks=2;
        c.loadInventory();check(c.bankNames.join(",")=="Crafting,Equipment"&&c.inventory[0].uid=="bank-item");
        c.setBankTab(1);check(c.inventory.length==2&&c.inventory[0].uid=="tab-two"&&c.inventorySlots.length==3);
        check(c.inventorySlots[0]==null&&c.inventorySlots[1].uid=="tab-two"&&c.inventorySlots[2].uid=="locked");
        check(c.isLocked(c.inventorySlots[2])&&!c.isLocked(c.inventorySlots[1]));
        c.chosen=c.inventorySlots[2];var beforeLocked=MarketWorker.current.sent.length;c.list(1,1,false);
        check(MarketWorker.current.sent.length==beforeLocked&&c.message=="This item is locked.");
        c.inv.hero.loadout.banks[1].content[2].item.locked=false;c.loadInventory();
        check(!c.isLocked(c.inventorySlots[2]));
        c.inv.hero.loadout.banks[1].content[2].item.bound=true;c.loadInventory();check(c.inventorySlots[2].uid=="locked"&&c.isBound(c.inventorySlots[2])&&!c.isLocked(c.inventorySlots[2]));
        c.chosen=c.inventorySlots[2];var beforeBound=MarketWorker.current.sent.length;c.list(1,1,false);
        check(MarketWorker.current.sent.length==beforeBound&&c.message=="This item is bound and cannot be traded.");
        c.inv.hero.loadout.banks[1].content[2].item.bound=false;c.inv.hero.loadout.banks[1].content[2].item.locked=true;c.loadInventory();
        check(c.inventoryStack(c.inventory[0]).item.uid=="tab-two");
        c.chosen=c.inventory[0];c.loadInventory();check(c.chosen.uid=="tab-two");
        c.sellSearch="not found";c.searchInventory();check(c.inventorySlots.length==3&&c.inventorySlots[1]==null&&c.chosen==null);
        c.sellSearch="";c.searchInventory();check(c.inventorySlots[1].uid=="tab-two");
        c.setBankOnly(false);check(c.bankTab==1&&c.inventory.length==1&&c.inventory[0].uid!="tab-two");
        c.setBankOnly(true);check(c.bankTab==1&&c.inventorySlots[1].uid=="tab-two");
        c.setBankTab(5);check(c.bankTab==1);
        c.sellSearch="should";c.searchInventory();c.chosen=c.inventory[0];
        var beforeListing=MarketWorker.current.sent.length;c.list(1,1,false);
        check(c.busy&&MarketWorker.current.sent.length==beforeListing+1);
        check(MarketWorker.current.sent[beforeListing].method=="POST");
        ownReply(c,app,[]);
        check(c.tab=="Sell"&&c.bankOnly&&c.bankTab==1&&c.sellSearch=="should"&&c.chosen==null);
        check(c.busy&&c.isListed(c.inventory[0]));
        c.chosen=c.inventory[0];
        ownReply(c,app,[]);
        check(!c.busy&&c.tab=="Sell"&&c.inventorySlots[1].uid=="tab-two"&&c.chosen.uid=="tab-two");
        c.inv.hero.loadout.banks[1].content.push({item:{uid:"next-item",inf:{}},count:2});
        c.loadInventory();c.chosen=c.inventory[0];c.list(1,1,false);
        c.chosen=c.inventorySlots[3];
        ownReply(c,app,[]);
        check(c.busy&&c.chosen.uid=="next-item");
        ownReply(c,app,[]);check(!c.busy&&c.chosen.uid=="next-item");

        c.inv.hero.loadout.banks=[firstBank];c.loadInventory();check(c.bankTab==0&&c.inventory[0].uid=="bank-item");
        c.refresh();MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:0,error:"Connection closed",retryAfter:"",body:'{"error":{"code":"unavailable"}}'}});
        c.update(app,0);check(!c.busy&&c.inventory.length==1&&c.message!="");
        c.tab="Browse";c.selected={id:"whisper",server:"europe",seller:{accountId:"seller",characterName:"Wink"}};
        c.contact();
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({seller:{accountId:"seller",characterName:"Wink"},item:{baseId:"Sword",quantity:12},price:{mode:"fixed",silverTrays:5}})}});
        c.update(app,0);
        check(trade.TradeChat.lastEcho);
        check(trade.TradeChat.lastText.indexOf(" x12 for 5 Silver Trays.")>=0);
        check(c.message.indexOf("Whisper sent to Wink.")==0);
        var whisperRequests=MarketWorker.current.sent.length;
        c.selected={id:"another-item",server:"europe",seller:{accountId:"seller",characterName:"Other character"}};
        c.contact();check(MarketWorker.current.sent.length==whisperRequests);
        check(trade.TradeMod.lastError.indexOf("before whispering this seller again.")>0);
        c.view.close();c.open();c.contact();check(MarketWorker.current.sent.length==whisperRequests);
        c.selected.seller.accountId="different-seller";c.contact();
        check(MarketWorker.current.sent.length==whisperRequests+1);
        c.contact();check(MarketWorker.current.sent.length==whisperRequests+1);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:404,error:"Not found",retryAfter:"",body:'{"error":{"code":"listing_not_found"}}'}});c.update(app,0);
        check(c.contactingSeller=="");
        c.selected.seller.accountId="seller";c.sellerWhisperAfter.set("seller",haxe.Timer.stamp()-0.01);c.contact();
        check(MarketWorker.current.sent.length==whisperRequests+2);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:404,error:"Not found",retryAfter:"",body:'{"error":{"code":"listing_not_found"}}'}});c.update(app,0);
        c.account="self";
        var own={seller:{accountId:"self",onlineUntil:"2000-01-01T00:00:00.000Z"}},other={seller:{accountId:"other",onlineUntil:"2000-01-01T00:00:00.000Z"}};
        check(!c.listingOnline(own));
        var calls=MarketWorker.current.sent.length,until=Date.now().getTime()/1000+180;
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"presence",onlineUntil:until});c.update(app,0);
        check(c.listingOnline(own)&&!c.listingOnline(other));
        check(!c.listingOnline(own,until)&&MarketWorker.current.sent.length==calls);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation-1,op:"presence",onlineUntil:until+180});c.update(app,0);
        check(!c.listingOnline(own,until+1));
        c.disconnect();c.account="self";check(!c.listingOnline(own));
        var capped=new MarketController();capped.player=player;capped.inv=new TradeInventory(player);capped.ready=true;capped.server="europe";capped.tab="Sell";
        capped.refresh();ownReply(capped,app,[for(i in 0...40){id:Std.string(i),revision:1,server:i<20?"europe":"north-america"}]);
        check(capped.listingLimitReached());
        capped.chosen=capped.inventory[0];var limitCalls=MarketWorker.current.sent.length;capped.list(1,1,false);
        check(MarketWorker.current.sent.length==limitCalls);
        capped.chooseTab("My listings");capped.selected=capped.rows[0];capped.remove();
        ownReply(capped,app,[]);check(!capped.listingLimitReached());
        Sys.println("Marketplace state checks passed: "+checks);
        MarketplaceCacheTest.run();
        MarketplaceRecoveryTest.run();
    }
}
