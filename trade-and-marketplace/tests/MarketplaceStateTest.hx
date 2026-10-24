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
        c.toggle();check(c.view.shown&&MarketWorker.current.sent.length==1);
        reply(c,app,{id:"first"},"next-page");
        c.loadMore();var batch=MarketWorker.current.sent[1];
        check(batch.op=="prefetch"&&Std.string(batch.path).indexOf("cursor=next-page")>=0&&!c.busy);
        MarketWorker.current.incoming.push({generation:batch.generation,op:batch.op,ticket:batch.ticket,
            response:{status:200,error:"",retryAfter:"",body:'{"listings":[{"id":"second"}],"nextCursor":null}'}});
        c.update(app,0);c.selected=c.rows[1];var selected=c.selected;
        c.toggle();check(!c.view.shown);c.toggle();
        check(MarketWorker.current.sent.length==2&&!c.busy);
        check(c.selected==selected&&c.rows[1]==selected&&c.rows.length==2&&c.view.shown);
        c.chooseTab("Sell");check(c.busy&&c.inventory.length==1);ownReply(c,app,[]);c.chosen=c.inventory[0];var chosen=c.chosen;
        c.sellSearch="should";c.searchInventory();c.toggle();check(!c.view.shown);c.toggle();
        check(c.tab=="Sell"&&c.chosen==chosen&&c.sellSearch=="should"&&c.inventory[0]==chosen);
        c.sellSearch="no match";c.searchInventory();check(c.chosen==null&&c.total==0);
        c.sellSearch="";c.searchInventory();check(c.total==1&&c.page==1);
        c.inv.inventory={content:[for(i in 0...21){item:{uid:Std.string(i),inf:{}},count:1}]};
        c.loadInventory();check(c.total==21&&c.pages==1&&c.inventorySlots.length==21);
        c.page=3;c.refresh();ownReply(c,app,[]);check(c.page==1&&c.pages==1&&c.total==21);
        c.chooseTab("Browse");c.refresh();reply(c,app,{id:"third"},null);c.selected=c.rows[0];c.page=2;
        c.disconnect();check(c.selected==null&&c.rows.length==0&&c.page==1&&!c.view.shown);
        c.player=player;c.inv=new TradeInventory(player);c.server="europe";
        // Browse requires a valid API key even while verification is pending.
        c.key="fv1_"+StringTools.rpad("a","a",43);
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
        c.toggleFilters();check(c.filtersExpanded&&!c.busy&&c.selected==previous);
        check(MarketWorker.current.sent.length==noFetch);
        c.toggleFilters();check(!c.filtersExpanded&&!c.navigationPending);
        check(MarketWorker.current.sent.length==noFetch&&c.filters["rarity"]=="Epic"&&c.filters["online"]=="false");
        c.selected=c.rows[0];
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
        check(trade.TradeChat.lastText=="Hi! I'm interested in your marketplace listing: Sword x12 for 5 Silver Trays.");
        check(trade.TradeChat.sends==1);
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
        var own={server:"europe",seller:{accountId:"self",onlineUntil:"2000-01-01T00:00:00.000Z"}},other={seller:{accountId:"other",onlineUntil:"2000-01-01T00:00:00.000Z"}};
        check(!c.listingOnline(own));
        var calls=MarketWorker.current.sent.length,until=Date.now().getTime()/1000+180;
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"presence",server:"europe",onlineUntil:until});c.update(app,0);
        check(c.listingOnline(own)&&!c.listingOnline(other));
        own.server="north-america";check(!c.listingOnline(own));own.server="europe";
        check(!c.listingOnline({server:"europe",seller:{accountId:"other",online:false,onlineUntil:"2099-01-01T00:00:00.000Z"}}));
        check(!c.listingOnline(own,until)&&MarketWorker.current.sent.length==calls);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation-1,op:"presence",server:"europe",onlineUntil:until+180});c.update(app,0);
        check(!c.listingOnline(own,until+1));
        c.disconnect();c.account="self";check(!c.listingOnline(own));
        var capped=new MarketController();capped.player=player;capped.inv=new TradeInventory(player);capped.ready=true;capped.server="europe";capped.tab="Sell";
        capped.refresh();ownReply(capped,app,[for(i in 0...40){id:Std.string(i),revision:1,server:i<20?"europe":"north-america"}]);
        check(capped.listingLimitReached());
        capped.chosen=capped.inventory[0];var limitCalls=MarketWorker.current.sent.length;capped.list(1,1,false);
        check(MarketWorker.current.sent.length==limitCalls);
        capped.chooseTab("My listings");capped.selected=capped.rows[0];capped.remove();
        ownReply(capped,app,[]);check(!capped.listingLimitReached());
        var editor=new MarketController();editor.player=player;editor.inv=new TradeInventory(player);editor.server="europe";editor.ready=true;editor.tab="My listings";
        editor.inv.hero.loadout.banks=[];
        var held:Dynamic={uid:"edit-item",kind:"Shoulders_EManfish_WizCle",inf:{}};
        editor.inv.inventory={content:[{item:held,count:6},{item:{uid:"edit-copy",kind:"Shoulders_EManfish_WizCle",inf:{}},count:6}]};
        var export:Dynamic={schemaVersion:2,server:"europe",gameVersion:"test",character:{id:"original-character",name:"Original name"},
            item:marketplace.MarketExport.itemData(held,TradeInventory.describe(held,12),5),price:{mode:"fixed",silverTrays:4}};
        var listing:Dynamic={id:"edit-me",revision:3,server:"europe",expiresAt:"2099-01-01T00:00:00.000Z",item:haxe.Json.parse(haxe.Json.stringify(export.item)),price:export.price};
        Reflect.setField(listing,"export",export);
        editor.ownedRows=[listing];editor.ownedKnown=true;editor.ownedListingCount=20;editor.rows=[listing];editor.selected=listing;
        check(editor.beginEdit()&&editor.editQuantityLimit==12);
        var edits=MarketWorker.current.sent.length;editor.edit(13,4,false);check(MarketWorker.current.sent.length==edits&&editor.message.indexOf("Not enough")>=0);
        held.locked=true;editor.edit(10,4,false);check(MarketWorker.current.sent.length==edits);held.locked=false;
        editor.edit(10,8,false);var update=MarketWorker.current.sent[edits],payload=haxe.Json.parse(update.body),match:Map<String,String>=update.headers;
        check(update.method=="PUT"&&match["If-Match"]=='"3"'&&payload.item.quantity==10&&payload.price.silverTrays==8);
        check(payload.character.id=="original-character"&&payload.character.name=="Original name"&&payload.server=="europe");
        check(export.item.quantity==5&&export.price.silverTrays==4); // Never mutate the stored snapshot before success.
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",response:{status:200,error:"",retryAfter:"",body:'{"id":"edit-me","revision":4}'}});editor.update(app,0);
        check(editor.selected.item.quantity==10&&editor.selected.price.silverTrays==8&&editor.selected.revision==4&&editor.editingListingId=="");
        check(editor.selected.expiresAt==listing.expiresAt&&editor.ownedRows.length==1&&MarketWorker.current.sent.length==edits+1);
        check(editor.beginEdit());editor.edit(4,1,true);
        payload=haxe.Json.parse(MarketWorker.current.sent[edits+1].body);check(payload.price.mode=="offers"&&!Reflect.hasField(payload.price,"silverTrays"));
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",response:{status:409,error:"Conflict",retryAfter:"",body:'{"error":{"code":"stale_revision"}}'}});editor.update(app,0);
        check(editor.selected.item.quantity==10&&editor.selected.revision==4&&!editor.ownedKnown&&editor.editingListingId=="");
        check(editor.message=="This listing changed. Refresh before editing it again.");
        navigationDuringRequests();
        Sys.println("Marketplace state checks passed: "+checks);
        MarketplaceCacheTest.run();
        MarketplaceRecoveryTest.run();
    }

    static function navigationDuringRequests():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player,connectionInfo:{heroID:"test-hero"}};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;

        // A Browse fetch must never block switching tabs, and its response
        // cannot replace Sell/My listings after the switch.
        c.refresh();check(c.busy);
        var original=MarketWorker.current.sent.length;
        c.chooseTab("Sell");check(c.tab=="Sell"&&c.inventory.length==1&&c.busy&&c.navigationPending);
        c.chooseTab("My listings");check(c.tab=="My listings"&&c.rows.length==0&&c.busy);
        c.chooseTab("Sell");check(c.tab=="Sell"&&c.busy);
        reply(c,app,{id:"browse-result"},null);
        check(c.tab=="Sell"&&c.busy&&c.rows.length==0);
        check(MarketWorker.current.sent.length==original+1
            &&Std.string(MarketWorker.current.sent[original].path).indexOf("mine=true")>=0);
        ownReply(c,app,[]);check(!c.busy&&c.tab=="Sell"&&c.ownedKnown);

        // POST requests are never cancelled, and must not drag the user back to
        // Sell or reset the Browse page after a successful listing.
        c.chosen=c.inventory[0];
        var start=MarketWorker.current.sent.length;c.list(1,1,false);
        check(c.busy&&MarketWorker.current.sent.length==start+1
            &&MarketWorker.current.sent[start].method=="POST");
        c.chooseTab("Browse");
        check(c.tab=="Browse"&&c.busy&&c.navigationPending);
        ownReply(c,app,[]);
        check(c.tab=="Browse"&&c.busy&&!c.navigationPending);
        check(MarketWorker.current.sent.length==start+2
            &&Std.string(MarketWorker.current.sent[start+1].path).indexOf("mine=true")<0);
        reply(c,app,{id:"shopping"},null);
        check(!c.busy&&c.tab=="Browse"&&c.rows.length==1&&c.rows[0].id=="shopping");

        // Changing Browse filters repeatedly while the old query runs keeps
        // the latest filter only; stale responses can cache but never display.
        c.filters["search"]="first";c.refresh();check(c.busy);
        var first=MarketWorker.current.sent.length;
        c.filters["search"]="second";c.refresh();check(c.navigationPending);
        c.toggleFilters();check(c.filtersExpanded&&c.busy);
        reply(c,app,{id:"stale-filter"},null);
        check(c.tab=="Browse"&&c.busy&&c.rows[0].id=="shopping"
            &&MarketWorker.current.sent.length==first+1);
        var latest=MarketWorker.current.sent[first];
        check(Std.string(latest.path).indexOf("search=second")>=0
            &&Std.string(latest.path).indexOf("limit=24")>=0);
        reply(c,app,{id:"latest-filter"},null);
        check(!c.busy&&c.rows[0].id=="latest-filter"&&!c.navigationPending);

        // A second tab change can supersede a queued filter request.
        c.refresh();check(c.busy);c.chooseTab("My listings");check(c.tab=="My listings"&&c.busy);
        reply(c,app,{id:"old-query"},null);
        check(c.busy&&c.tab=="My listings"&&c.rows.length==0);
        check(Std.string(MarketWorker.current.sent[MarketWorker.current.sent.length-1].path).indexOf("mine=true")>=0);
        ownReply(c,app,[]);
        check(!c.busy&&c.tab=="My listings"&&c.rows.length==0);

        // An in-flight append is cancellable and does not block navigation.
        var p=new MarketController();p.player=player;p.inv=new TradeInventory(player);p.server="europe";p.ready=true;
        p.refresh();reply(p,app,{id:"paged"},"second-page");
        p.loadMore();var prefetch=p.prefetch;check(prefetch!=null&&!p.busy&&p.rows[0].id=="paged");
        p.chooseTab("Sell");check(p.tab=="Sell"&&!p.navigationPending&&p.busy);
        ownReply(p,app,[]);check(!p.busy&&p.tab=="Sell");
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"prefetch",
            ticket:prefetch.ticket,response:{status:200,error:"",retryAfter:"",body:'{"listings":[{"id":"late"}],"nextCursor":null}'}});
        p.update(app,0);check(p.tab=="Sell"&&!p.busy);
        // Catalog browsing is local, including when a foreground listing read
        // finishes after the player has already switched to Buy.
        p.chooseTab("Browse");p.refresh();check(p.busy);
        var sent=MarketWorker.current.sent.length;
        p.chooseTab("Buy");p.refresh();
        check(p.tab=="Buy"&&p.busy&&!p.navigationPending&&MarketWorker.current.sent.length==sent);
        reply(p,app,{id:"late-browse"},null);
        check(p.tab=="Buy"&&!p.busy&&p.rows.length==0&&MarketWorker.current.sent.length==sent);
        p.refresh();check(!p.busy&&MarketWorker.current.sent.length==sent);
    }
}
