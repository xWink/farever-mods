import marketplace.MarketController;
import marketplace.MarketPages;
import marketplace.MarketWorker;
import trade.TradeInventory;

class MarketplaceCacheTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace cache assertion "+checks;}
    static function last():Dynamic return MarketWorker.current.sent[MarketWorker.current.sent.length-1];
    static function respond(c:MarketController,app:Dynamic,job:Dynamic,rows:Array<Dynamic>,next:Null<String>,status=200):Void {
        MarketWorker.current.incoming.push({generation:job.generation,op:job.op,ticket:job.ticket,
            response:{status:status,error:status==200?"":"HTTP Error",retryAfter:"",body:haxe.Json.stringify({listings:rows,nextCursor:next})}});
        c.update(app,0);
    }
    public static function run():Void {
        var cache=new MarketPages("/listings?limit=1",1);
        cache.put(1,{listings:[{id:"1"}],nextCursor:"two"},10);
        cache.put(2,{listings:[{id:"2"}],nextCursor:"three"},10);
        check(cache.get(1,69)!=null&&cache.get(1,70)==null);
        cache.current=3;cache.put(3,{listings:[{id:"3"}],nextCursor:"four"},10);
        cache.put(4,{listings:[{id:"4"}],nextCursor:null},10);
        check(cache.get(1,10)==null&&cache.get(2,10)!=null&&cache.get(3,10)!=null&&cache.get(4,10)!=null);
        check(cache.url(3)=="/listings?limit=1&cursor=three");
        cache.put(2,{listings:[{id:"changed"}],nextCursor:"new-three"},11);
        check(cache.get(3,11)==null&&cache.get(4,11)==null&&cache.cursors[3]==null);
        var invalid=false;try cache.put(2,{listings:[],nextCursor:42},11)catch(_:Dynamic)invalid=true;check(invalid);

        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        c.open();respond(c,app,last(),[{id:"1"}],"two");
        check(last().op=="prefetch"&&Std.string(last().path).indexOf("cursor=two")>=0&&!c.busy);
        c.view.dirty=false;respond(c,app,last(),[{id:"2"}],"three");
        check(c.page==1&&c.rows[0].id=="1"&&!c.view.dirty&&!c.busy);
        c.goPage(2);check(c.page==2&&c.rows[0].id=="2"&&!c.busy&&Std.string(last().path).indexOf("cursor=three")>=0);
        var third=last(),sent=MarketWorker.current.sent.length;
        c.goPage(3);check(c.busy&&MarketWorker.current.sent.length==sent&&c.rows.length==0);
        respond(c,app,third,[{id:"3"}],"four");
        check(!c.busy&&c.rows[0].id=="3"&&Std.string(last().path).indexOf("cursor=four")>=0);
        respond(c,app,last(),[{id:"4"}],null);
        c.goPage(2);check(c.rows[0].id=="2"&&!c.busy&&Std.string(last().path).indexOf("cursor=")<0);
        respond(c,app,last(),[{id:"1"}],"two");
        sent=MarketWorker.current.sent.length;c.goPage(1);
        check(c.rows[0].id=="1"&&!c.busy&&MarketWorker.current.sent.length==sent);

        // Fresh tab caches restore the page/selection, while Sell rereads native stacks.
        c.selected=c.rows[0];c.chooseTab("Sell");
        check(c.busy&&c.inventory.length>0); // Local stacks render before the API reply.
        respond(c,app,last(),[
            {id:"mine",server:"europe",item:{baseId:"a",requiredLevel:20},price:{silverTrays:5}},
            {id:"higher",server:"europe",item:{baseId:"b",requiredLevel:30},price:{silverTrays:2}},
            {id:"expired-mine",server:"europe",expiresAt:"2000-01-01T00:00:00.000Z"},
            {id:"na-mine",server:"north-america"}
        ],null);
        c.chosen=c.inventory[0];var chosen=c.chosen;
        c.chooseTab("Browse");check(c.selected!=null&&c.selected.id=="1"&&!c.busy);
        sent=MarketWorker.current.sent.length;c.inv.inventory={content:[{item:{uid:"fresh",inf:{}},count:3}]};
        c.chooseTab("Sell");check(!c.busy&&MarketWorker.current.sent.length==sent&&c.inventory[0].uid=="fresh"&&c.chosen==null);
        c.chooseTab("My listings");
        check(!c.busy&&c.rows.length==2&&c.rows[0].id=="mine"&&MarketWorker.current.sent.length==sent);
        c.selected=c.rows[0];c.chooseTab("Sell");c.chooseTab("My listings");
        check(c.selected!=null&&c.selected.id=="mine"&&MarketWorker.current.sent.length==sent);
        c.sortByLevel();check(c.listingSort()=="required-level-asc"&&c.rows[0].id=="mine");
        c.sortByLevel();check(c.listingSort()=="required-level-desc"&&c.rows[0].id=="higher");
        c.sortByLevel();check(c.listingSort()==""&&c.rows[0].id=="mine"&&c.filters["sort"]=="");
        c.sortByPrice();check(c.listingSort()=="price-asc"&&c.rows[0].id=="higher");
        c.sortByPrice();check(c.listingSort()=="price-desc"&&c.rows[0].id=="mine");
        c.sortByPrice();check(c.listingSort()=="");
        check(MarketWorker.current.sent.length==sent); // Owned sorting is local too.
        c.server="north-america";c.chooseTab("My listings");
        check(!c.busy&&c.rows.length==1&&c.rows[0].id=="na-mine"&&MarketWorker.current.sent.length==sent);
        c.server="europe";c.chooseTab("My listings");
        check(!c.busy&&c.rows.length==2&&c.rows[0].id=="mine"&&MarketWorker.current.sent.length==sent);
        c.refresh();check(c.busy&&MarketWorker.current.sent.length==sent+1&&last().path=="/api/v1/marketplace/listings?mine=true&limit=50");
        respond(c,app,last(),[{id:"mine",server:"europe"}],null);

        c.chooseTab("Browse");c.filters["rarity"]="Epic";c.filters["prismatic"]="true";c.page=1;c.refresh();
        check(Std.string(last().path).indexOf("prismatic=true")>=0&&Std.string(last().path).indexOf("rarity=Epic")>=0);
        respond(c,app,last(),[{id:"prism"}],"prism-two");var stale=last();
        c.filters["prismatic"]="";c.refresh();var ordinary=last();
        check(Std.string(ordinary.path).indexOf("prismatic=")<0&&Std.string(ordinary.path).indexOf("cursor=")<0);
        respond(c,app,stale,[{id:"stale"}],null);check(c.busy&&c.rows[0].id=="prism");
        respond(c,app,ordinary,[{id:"epic",item:{name:"Corrupted Gift (+Fervor/-Crit)"}}],null);
        c.selected=c.rows[0];c.filters["category"]="Weapon";c.filters["classes"]="Mage";
        c.chooseTab("Sell");c.chosen=c.inventory[0];c.chosen.name="Corrupted Gift (+Fervor/-Crit)";c.searchSelectedItem();
        check(c.tab=="Browse"&&c.page==1&&Std.string(last().path).indexOf("search=Corrupted%20Gift")>=0
            &&Std.string(last().path).indexOf("category=")<0&&Std.string(last().path).indexOf("rarity=")<0&&Std.string(last().path).indexOf("classes=")<0);
        respond(c,app,last(),[{id:"search"}],"next");var failed=last();
        c.view.dirty=false;respond(c,app,failed,[],null,400);
        check(!c.busy&&c.rows[0].id=="search"&&!c.view.dirty&&last()==failed);
        c.goPage(2);check(c.busy&&last().op=="request"&&Std.string(last().path).indexOf("cursor=next")>=0);
        respond(c,app,last(),[{id:"retry"}],null);

        // Expired listings and sellers whose presence expired are never revived by cache hits.
        c.page=1;c.refresh();respond(c,app,last(),[
            {id:"expired",expiresAt:"2000-01-01T00:00:00.000Z"},
            {id:"offline",seller:{onlineUntil:"2000-01-01T00:00:00.000Z"}},
            {id:"live",expiresAt:"2099-01-01T00:00:00.000Z",seller:{onlineUntil:"2099-01-01T00:00:00.000Z"}}
        ],null);
        check(c.rows.length==1&&c.rows[0].id=="live");
        c.chooseTab("My listings");c.chooseTab("Browse");check(c.rows.length==1&&c.rows[0].id=="live");
        sent=MarketWorker.current.sent.length;
        c.toggleListing(c.rows[0]);check(c.selected!=null&&c.selected.id=="live");
        c.toggleListing({id:"live"});check(c.selected==null); // Same ID from a refreshed snapshot.
        c.chooseTab("My listings");c.chooseTab("Browse");check(c.selected==null&&MarketWorker.current.sent.length==sent);
        c.chooseTab("My listings");c.toggleListing(c.rows[0]);check(c.selected!=null);
        c.toggleListing(c.rows[0]);c.sortByPrice();check(c.selected==null&&MarketWorker.current.sent.length==sent);
        c.refresh();var old=last();c.disconnect();respond(c,app,old,[{id:"old-session"}],null);
        check(c.rows.length==0&&c.selected==null);
        Sys.println("Marketplace cache checks passed: "+checks);
    }
}
