import marketplace.MarketController;
import marketplace.MarketWorker;
import trade.TradeInventory;
class MarketplaceStateTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace state assertion "+checks;}
    static function reply(c:MarketController,app:Dynamic,listing:Dynamic,cursor:Null<String>):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({listings:[listing],nextCursor:cursor})}});
        c.update(app,0);
    }
    static function ownReply(c:MarketController,app:Dynamic,rows:Array<Dynamic>):Void {
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({listings:rows,nextCursor:null})}});c.update(app,0);
    }
    static function main():Void {
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        c.open();check(c.view.shown&&MarketWorker.current.sent.length==1);
        reply(c,app,{id:"first"},"next-page");
        c.page=2;c.refresh();check(Std.string(MarketWorker.current.sent[1].path).indexOf("cursor=next-page")>=0);
        reply(c,app,{id:"second"},null);c.selected=c.rows[0];
        var selected=c.selected;
        c.view.close();c.open();
        check(MarketWorker.current.sent.length==3&&!c.busy);
        check(c.page==2&&c.selected==selected&&c.rows[0]==selected&&c.view.shown);
        c.chooseTab("Sell");check(c.busy&&c.inventory.length==0);ownReply(c,app,[]);c.chosen=c.inventory[0];var chosen=c.chosen;
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
        c.tab="My listings";c.ready=true;c.selected=c.rows[0];
        var sent=MarketWorker.current.sent.length;
        c.page=2;c.remove();
        var deletion=MarketWorker.current.sent[sent];
        check(deletion.method=="DELETE"&&deletion.path=="/api/v1/marketplace/listings/delete-me");
        var headers:Map<String,String>=deletion.headers;
        check(headers["If-Match"]=='"7"'&&deletion.body==null);
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:204,error:"",retryAfter:"",body:""}});
        c.update(app,0);
        check(MarketWorker.current.sent.length==sent+2&&MarketWorker.current.sent[sent+1].method=="GET");
        check(c.selected==null&&c.page==1&&Std.string(MarketWorker.current.sent[sent+1].path).indexOf("limit=9")>=0);
        reply(c,app,{id:"remaining",revision:1},null);
        check(!c.busy&&c.selected==null&&c.rows.length==1&&c.rows[0].id=="remaining");
        c.selected=c.rows[0];sent=MarketWorker.current.sent.length;c.remove();
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:409,error:"HTTP Error #409",retryAfter:"",body:'{"error":{"code":"stale_revision"}}'}});
        c.update(app,0);
        check(!c.busy&&c.rows[0].id=="remaining"&&MarketWorker.current.sent.length==sent+1);
        check(c.message=="This listing changed. Refresh before removing it.");
        c.filters["search"]="shield";c.filters["rarity"]="Epic";c.filters["online"]="false";c.tab="Browse";
        c.toggleFilters();check(c.filtersExpanded&&c.pageSize()==6&&c.page==1);
        check(Std.string(MarketWorker.current.sent[MarketWorker.current.sent.length-1].path).indexOf("limit=6")>=0);
        var previous=c.selected;
        ownReply(c,app,[{id:"remaining",revision:2}]);
        check(c.selected==c.rows[0]&&c.selected!=previous&&c.selected.revision==2);
        c.toggleFilters();check(!c.filtersExpanded&&c.pageSize()==8&&c.filters["rarity"]=="Epic"&&c.filters["online"]=="false");
        ownReply(c,app,[{id:"other"},{id:"remaining",revision:3}]);
        check(c.selected==c.rows[1]&&c.selected.revision==3);
        c.filters["search"]="new search";c.refresh();ownReply(c,app,[{id:"remaining",revision:4}]);
        check(c.selected==c.rows[0]&&c.selected.revision==4);
        c.refresh();MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:400,error:"HTTP Error #400",retryAfter:"",body:'{"error":{"code":"invalid_query"}}'}});
        c.update(app,0);check(c.selected==c.rows[0]&&!c.busy);
        c.filters["search"]="filtered out";c.refresh();ownReply(c,app,[{id:"other"}]);
        check(c.selected==null);
        var stack=c.inv.stacks()[0],offer=TradeInventory.describe(stack.item,stack.count);
        var listed=marketplace.MarketExport.itemData(stack.item,offer,1);
        c.chooseTab("Sell");
        var path=Std.string(MarketWorker.current.sent[MarketWorker.current.sent.length-1].path);
        check(path=="/api/v1/marketplace/listings?mine=true&limit=50");
        ownReply(c,app,[{item:listed}]);check(c.inventory.length==1&&c.isListed(c.inventory[0]));
        c.inv.hero.loadout.banks=[{content:[{item:{uid:"bank-item",inf:{}},count:20}]}];
        c.setBankOnly(true);check(c.inventory.length==1&&c.isListed(c.inventory[0]));
        // Refresh after cancellation/expiry restores the same bank item.
        c.refresh();ownReply(c,app,[]);check(c.inventory.length==1&&c.inventory[0].count==20);
        var firstBank=c.inv.hero.loadout.banks[0];
        c.inv.hero.loadout.banks=[firstBank,{content:[null,{item:{uid:"tab-two",inf:{}},count:3},{item:{uid:"locked",locked:true,inf:{}},count:1}]}];
        player.accountProgress={nbBanks:1,bankTabs:[{name:"Crafting"},{name:"Equipment"}]};
        c.loadInventory();check(c.bankNames.length==1);
        player.accountProgress.nbBanks=2;
        c.loadInventory();check(c.bankNames.join(",")=="Crafting,Equipment"&&c.inventory[0].uid=="bank-item");
        c.setBankTab(1);check(c.inventory.length==1&&c.inventory[0].uid=="tab-two"&&c.inventorySlots.length==3);
        check(c.inventorySlots[0]==null&&c.inventorySlots[1].uid=="tab-two"&&c.inventorySlots[2]==null);
        check(c.inventoryStack(c.inventory[0]).item.uid=="tab-two");
        c.chosen=c.inventory[0];c.loadInventory();check(c.chosen.uid=="tab-two");
        c.sellSearch="not found";c.searchInventory();check(c.inventorySlots.length==3&&c.inventorySlots[1]==null&&c.chosen==null);
        c.sellSearch="";c.searchInventory();check(c.inventorySlots[1].uid=="tab-two");
        c.setBankOnly(false);check(c.bankTab==1&&c.inventory.length==1&&c.inventory[0].uid!="tab-two");
        c.setBankOnly(true);check(c.bankTab==1&&c.inventorySlots[1].uid=="tab-two");
        c.setBankTab(5);check(c.bankTab==1);
        c.inv.hero.loadout.banks=[firstBank];c.loadInventory();check(c.bankTab==0&&c.inventory[0].uid=="bank-item");
        c.refresh();MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:503,error:"HTTP Error #503",retryAfter:"60",body:'{"error":{"code":"unavailable"}}'}});
        c.update(app,0);check(!c.busy&&c.inventory.length==0&&c.message!="");
        c.tab="Browse";c.selected={id:"whisper",server:"europe",seller:{accountId:"seller",characterName:"Wink"}};
        c.contact();
        MarketWorker.current.incoming.push({generation:MarketWorker.current.generation,op:"request",
            response:{status:200,error:"",retryAfter:"",body:haxe.Json.stringify({seller:{accountId:"seller",characterName:"Wink"},item:{baseId:"Sword",quantity:12},price:{mode:"fixed",silverTrays:5}})}});
        c.update(app,0);
        check(trade.TradeChat.lastEcho);
        check(trade.TradeChat.lastText.indexOf(" x12 for 5 Silver Trays.")>=0);
        check(c.message.indexOf("Whisper sent to Wink.")==0);
        Sys.println("Marketplace state checks passed: "+checks);
        MarketplaceCacheTest.run();
    }
}
