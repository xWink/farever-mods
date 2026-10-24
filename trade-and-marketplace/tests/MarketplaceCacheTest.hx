import marketplace.MarketController;
import marketplace.MarketBrowseFeed;
import marketplace.MarketText;
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
        var feed=new MarketBrowseFeed("/listings?limit=24");
        feed.append({listings:[{id:"1"}],nextCursor:"two / +"},10);
        check(!feed.stale(69)&&feed.stale(70));
        check(feed.url()=="/listings?limit=24&cursor=two%20%2F%20%2B");
        var invalid=false;
        try feed.append({listings:[{id:"partial"}],nextCursor:"two / +"},11)catch(_:Dynamic)invalid=true;
        check(invalid&&feed.rows.length==1&&feed.next=="two / +"&&feed.fetchedAt==10);
        invalid=false;try feed.append({listings:[{id:"partial"},{}],nextCursor:null},11)catch(_:Dynamic)invalid=true;
        check(invalid&&feed.rows.length==1);
        feed.append({listings:[{id:"1"},{id:"2"}],nextCursor:null},11);
        check(feed.rows.length==2&&feed.complete);
        var longFeed=new MarketBrowseFeed("/listings");
        for(i in 0...60)longFeed.append({listings:[{id:Std.string(i)}],nextCursor:Std.string(i)},i);
        check(longFeed.rows.length==60&&!longFeed.complete); // No arbitrary page cap.

        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.ready=true;
        c.open();respond(c,app,last(),[{id:"1"}],"two");
        check(last().op=="request"&&MarketWorker.current.sent.length==1&&!c.busy);
        c.loadMore();var batch=last();
        check(batch.op=="prefetch"&&Std.string(batch.path).indexOf("cursor=two")>=0&&!c.busy&&c.rows[0].id=="1");
        c.toggleListing(c.rows[0]);c.listingScrollState().offset=240;
        var sent=MarketWorker.current.sent.length;c.loadMore();check(MarketWorker.current.sent.length==sent);
        respond(c,app,batch,[{id:"1"},{id:"2"}],"three");
        check(c.rows.length==2&&c.rows[1].id=="2"&&c.selected.id=="1"&&c.listingScrollState().offset==240);
        c.loadMore();respond(c,app,last(),[{id:"3"}],null);
        check(c.rows.length==3&&!c.busy&&!c.loadingMore());
        sent=MarketWorker.current.sent.length;c.loadMore();check(MarketWorker.current.sent.length==sent);

        // Fresh tab caches restore all accumulated rows, selection and scrolling.
        c.selected=c.rows[0];c.chooseTab("Sell");
        check(c.busy&&c.inventory.length>0); // Local stacks render before the API reply.
        respond(c,app,last(),[
            {id:"mine",server:"europe",item:{baseId:"a",requiredLevel:20},price:{silverTrays:5}},
            {id:"higher",server:"europe",item:{baseId:"b",requiredLevel:30},price:{silverTrays:2}},
            {id:"expired-mine",server:"europe",expiresAt:"2000-01-01T00:00:00.000Z"},
            {id:"na-mine",server:"north-america"}
        ],null);
        c.chosen=c.inventory[0];var chosen=c.chosen;
        c.chooseTab("Browse");check(c.selected!=null&&c.selected.id=="1"&&!c.busy&&c.rows.length==3&&c.listingScrollState().offset==240);
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
        c.refresh();check(c.busy&&MarketWorker.current.sent.length==sent+1&&last().path=="/api/v1/marketplace/listings?mine=true&orderType=any&limit=50");
        respond(c,app,last(),[{id:"mine",server:"europe"}],null);

        c.chooseTab("Browse");c.filters["rarity"]="Epic";c.filters["prismatic"]="true";c.page=1;c.refresh();
        check(Std.string(last().path).indexOf("prismatic=true")>=0&&Std.string(last().path).indexOf("rarity=Epic")>=0);
        respond(c,app,last(),[{id:"prism"}],"prism-two");c.loadMore();var stale=last();
        c.filters["prismatic"]="";c.refresh();var ordinary=last();
        check(Std.string(ordinary.path).indexOf("prismatic=")<0&&Std.string(ordinary.path).indexOf("cursor=")<0);
        respond(c,app,stale,[{id:"stale"}],null);check(c.busy&&c.rows[0].id=="prism");
        respond(c,app,ordinary,[{id:"epic",item:{name:"Corrupted Gift (+Fervor/-Crit)"}}],null);
        c.selected=c.rows[0];c.filters["category"]="Weapon";c.filters["classes"]="Mage";
        c.chooseTab("Sell");c.chosen=c.inventory[0];c.chosen.name="Corrupted Gift (+Fervor/-Crit)";c.searchSelectedItem();
        check(c.tab=="Browse"&&c.page==1&&Std.string(last().path).indexOf("search=Corrupted%20Gift")>=0
            &&Std.string(last().path).indexOf("category=")<0&&Std.string(last().path).indexOf("rarity=")<0&&Std.string(last().path).indexOf("classes=")<0);
        respond(c,app,last(),[{id:"search"}],"next");c.loadMore();var failed=last();
        respond(c,app,failed,[],null,500);
        check(!c.busy&&c.rows[0].id=="search"&&c.loadMoreFailed()&&!c.loadingMore());
        sent=MarketWorker.current.sent.length;c.loadMore();c.loadMore();check(MarketWorker.current.sent.length==sent);
        c.loadMore(true);check(MarketWorker.current.sent.length==sent&&c.loadMoreFailed()&&c.message.indexOf("Please wait")>=0);
        @:privateAccess c.cooldown.clear();
        c.loadMore(true);check(!c.busy&&c.loadingMore()&&last().op=="prefetch"&&Std.string(last().path).indexOf("cursor=next")>=0);
        respond(c,app,last(),[{id:"retry"}],null);
        check(c.rows.length==2&&c.rows[0].id=="search"&&c.rows[1].id=="retry"&&!c.loadMoreFailed());

        // Expired listings and sellers whose presence expired are never revived by cache hits.
        c.page=1;c.filters["online"]="true";c.refresh();respond(c,app,last(),[
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
        ownListingFilter();
        keyAndPreferencePersistence();
        Sys.println("Marketplace cache checks passed: "+checks);
    }

    static function ownListingFilter():Void {
        var player:Dynamic={isMe:true,uid:"self",hero:{loadout:{banks:[]}}},app={me:player};
        var c=new MarketController();
        c.player=player;c.inv=new TradeInventory(player);c.account="self";c.server="north-america";c.ready=true;
        c.filters["online"]="false";
        var own:Dynamic={id:"mine",server:"north-america",seller:{accountId:"self",characterName:"Another character"}},
            other:Dynamic={id:"other",server:"north-america",seller:{accountId:"other",characterName:"My name"}};
        c.open();
        var first=last();
        check(Std.string(first.path).indexOf("excludeAccountId=")<0);
        check(Std.string(first.path).indexOf("limit=24")>=0);
        respond(c,app,first,[own,other],null);
        check(!c.hideMine&&c.rows.length==2&&c.rows[0].id=="mine");
        var sent=MarketWorker.current.sent.length;

        c.setHideMine(true);
        var request=last(),path=Std.string(request.path);
        check(c.hideMine&&c.busy&&MarketWorker.current.sent.length==sent+1);
        check(StringTools.startsWith(path,"/api/v1/marketplace/listings?server=north-america&orderType=any&excludeAccountId=self&limit=24"));
        check(path.indexOf("cursor=")<0&&path.indexOf("hideMine")<0);

        // Both Browse modes append server-filtered batches without local pagination.
        var listings:Array<Dynamic>=[for(i in 0...24){id:"public-"+i,seller:{accountId:"other"}}];
        respond(c,app,request,listings,"next-batch");
        check(!c.busy&&c.rows.length==24&&c.rows[0].id=="public-0");
        c.loadMore();
        check(!c.busy&&c.loadingMore()&&Std.string(last().path).indexOf("excludeAccountId=self&limit=24")>=0
            &&Std.string(last().path).indexOf("cursor=next-batch")>=0);
        respond(c,app,last(),[for(i in 0...3){id:"tail-"+i,seller:{accountId:"other"}}],null);
        check(!c.busy&&c.rows.length==27&&c.rows[24].id=="tail-0");
        var buffered=MarketWorker.current.sent.length;
        c.toggleFilters();check(c.filtersExpanded&&!c.busy&&c.rows.length==27&&MarketWorker.current.sent.length==buffered);
        c.toggleFilters();check(!c.filtersExpanded&&c.rows.length==27&&MarketWorker.current.sent.length==buffered);
        c.listingScrollState().offset=800;
        c.setHideMine(false);
        check(!c.hideMine&&!c.busy&&c.rows.length==2&&c.rows[0].id=="mine"&&MarketWorker.current.sent.length==buffered);
        c.setHideMine(true);
        check(c.rows.length==27&&!c.busy&&MarketWorker.current.sent.length==buffered&&c.listingScrollState().offset==800);
        c.chooseTab("My listings");respond(c,app,last(),[own],null);
        check(c.hideMine&&c.rows.length==1&&c.rows[0].id=="mine");
        c.chooseTab("Browse");
        check(!c.busy&&c.rows.length==27&&c.rows[0].id=="public-0");

        // Search/filter changes make new API requests with server exclusion.
        c.filters["rarity"]="Epic";c.refresh();request=last();path=Std.string(request.path);
        check(c.busy&&path.indexOf("excludeAccountId=self&limit=24")>=0
            &&path.indexOf("rarity=Epic")>=0&&path.indexOf("cursor=")<0);
        respond(c,app,request,[other],null);
        check(!c.busy&&c.rows.length==1&&c.rows[0].id=="other");

        // Never issue a request without a valid account ID when exclusion is on.
        c.account="";sent=MarketWorker.current.sent.length;c.refresh();
        check(!c.busy&&c.rows.length==0&&MarketWorker.current.sent.length==sent);
        check(c.message.indexOf("account could not be identified")>=0);
        // URL-encode the authenticated account identity before sending it.
        c.account="farever:account_123";c.refresh();request=last();
        check(c.busy&&Std.string(request.path).indexOf("excludeAccountId=farever%3Aaccount_123")>=0);
        respond(c,app,request,[],null);check(!c.busy&&c.rows.length==0);
        c.setHideMine(false);

        // API batch size is 24, not eight. Preserve opaque cursors and reject
        // responses that exceed the documented page limit.
        var feed=new MarketBrowseFeed("/api/v1/marketplace/listings?limit=24");
        feed.append({listings:[for(i in 0...24){id:"row-"+i}],nextCursor:"next"},10);
        check(feed.rows.length==24&&feed.url().indexOf("cursor=next")>=0);
        var invalid=false;
        try feed.append({listings:[for(i in 0...25){id:"too-many-"+i}],nextCursor:null},11)
        catch(_:Dynamic)invalid=true;
        check(invalid&&feed.rows.length==24);
    }

    static function keyAndPreferencePersistence():Void {
        trade.TradeMod.savedHideMine=false;trade.TradeMod.savedOnlineOnly=false;
        var initial=new MarketController();
        check(!initial.hideMine&&initial.filters["online"]=="false");
        initial.setHideMine(true);
        initial.filters["online"]="true";initial.saveFilterPreferences();
        var reopened=new MarketController(); // Simulate a new game session.
        check(reopened.hideMine&&reopened.filters["online"]=="true");
        reopened.setHideMine(false);
        reopened.filters["online"]="false";reopened.saveFilterPreferences();
        var defaults=new MarketController();
        check(!defaults.hideMine&&defaults.filters["online"]=="false");
        check(!trade.TradeMod.savedHideMine&&!trade.TradeMod.savedOnlineOnly);

        var player:Dynamic={isMe:true,uid:"unsigned",hero:{loadout:{banks:[]}}};
        var app:Dynamic={me:player};
        var noKey=new MarketController();
        noKey.player=player;noKey.inv=new TradeInventory(player);noKey.server="europe";
        noKey.ready=false; // Server has not validated any credential.
        var sent=MarketWorker.current.sent.length;
        noKey.open();
        check(noKey.tab=="Browse"&&!noKey.busy&&MarketWorker.current.sent.length==sent);
        check(noKey.message==MarketText.SIGN_IN_TO_BROWSE);
        noKey.chooseTab("Sell");noKey.chooseTab("Browse");
        check(!noKey.busy&&MarketWorker.current.sent.length==sent);
        // A valid key allows Browse while account verification is pending.
        @:privateAccess noKey.key="fv1_"+StringTools.rpad("z","z",43);
        noKey.refresh();
        check(noKey.busy&&MarketWorker.current.sent.length==sent+1);
        respond(noKey,app,last(),[{id:"verified"}],null);
        check(!noKey.busy&&noKey.rows.length==1&&noKey.rows[0].id=="verified");
    }
}
