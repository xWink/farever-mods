package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;
import fareverly.Protocol;
import fareverly.SessionLease;
import modconfig.CommonSettings;
import hlx.runtime.Bus;
class MarketController {
    public static inline var LISTING_LIMIT = 20;
    public var filtersExpanded=false;
    public var hideMine=false;
    var browseRows:Array<Dynamic>=[];
    public var player:Dynamic;
    public var inv:TradeInventory;
    public var app:Dynamic;
    public var server="";
    public var account="";
    public var message="";
    public var ready=false;
    public var connectionIssue=false;
    public var busy=false;
    public var signingIn=false;
    public var view:MarketWindow;
    public var tab="Browse";
    public var buy=new MarketBuy();
    public var rows:Array<Dynamic>=[];
    public var inventory:Array<TradeItem>=[];
    public var bankOnly=false;
    public var sellSearch="";
    public var bankTab=0;
    public var bankNames:Array<String>=[];
    public var inventorySlots:Array<TradeItem>=[];
    var inventoryIndexes:Map<String,Int>=[];
    var inventorySource:TradeInventory;
    var availableInventory:Array<TradeItem>=[];
    var listedInventory:Map<String,Bool>=[];
    var lockedInventory:Map<String,Bool>=[];
    var boundInventory:Map<String,Bool>=[];
    var locations:Map<String,String>=[];
    var ownOnlineUntil=0.0;
    var ownOnlineServer="";
    var peerPresence=new MarketPresenceRefresh();
    var visiblePresenceRows:Array<Dynamic>=[];
    var presencePollAt=0.0;
    var presenceRead:Null<{ticket:Int,path:String,feed:MarketBrowseFeed,row:Dynamic,batch:Bool}>;
    var ownedKnown=false;
    var ownedSellCount=0;
    var ownedBuyCount=0;
    var ownedBuyItems:Map<String,Float>=[];
    public function listingLimitReached(orderType:String):Bool return (orderType=="buy"?ownedBuyCount:ownedSellCount)>=LISTING_LIMIT;
    var ownedItems:Map<String,Bool>=[];
    var ownedKinds:Map<String,Bool>=[];
    var ownedExpiry:Map<String,Float>=[];
    var ownedRows:Array<Dynamic>=[];
    var minePage=1;
    var mineSelectedId="";
    public var selected:Dynamic;
    public var editingListingId="";
    public var editQuantityLimit=1;
    public var chosen:TradeItem;
    public var page=1;
    public var pages=1;
    public var total=0;
    var listingCaches:Map<String,MarketBrowseFeed>=[];
    var mineScroll={offset:0.0};
    var filledBrowse:MarketBrowseFeed;
    var prefetch:Null<{feed:MarketBrowseFeed,path:String,ticket:Int}>;
    var nextTicket=0;
    var mineSort="";
    public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","prismatic"=>"","orderType"=>"any","classes"=>"","search"=>"","online"=>"false","sort"=>""];
    final worker=new MarketWorker();
    var generation=0;
    var key="";
    var pending:(Dynamic->Void);
    var pendingFailure:Void->Void;
    var pendingMethod="";
    var pendingPath="";
    var pendingOrderType="";
    var pendingBuyItemKey="";
    // Requests and writes must finish, but navigation and filter changes should
    // take effect immediately. Replay only the latest desired view afterwards.
    var navigationPending=false;
    var navigationForce=false;
    final cooldown=new MarketCooldown();
    var retryOnOpen=false;
    var expectedBody="";
    var requestId="";
    var buyExpectedBody="";
    var buyRequestId="";
    var sellerWhisperAfter:Map<String,Float>=[];
    var contactingSeller="";
    var opened=false;
    public function new() {
        var saved=trade.TradeMod.marketplaceFilters();
        hideMine=saved.hideMine;filters["online"]=saved.onlineOnly?"true":"false";
        view=new MarketWindow(this);
        Bus.subscribe(CommonSettings.CHANGED_TOPIC,(_:Dynamic)->{if(player!=null)try {if(readKey(CommonSettings.read())!=key)reconnect();}catch(_:Dynamic){}});
        var action="better-mod-settings/action/"+HlxRuntime.moduleName()+"/";
        Bus.subscribe(action+"fareverlySignIn",(_:Dynamic)->signIn());
    }
    public function update(app:Dynamic,now:Float):Void {
        this.app=app;
        // The native player changes during a layer/character transition. Invalidate queued work first.
        var me=trade.TradeMod.enabled()?G.field(app,"me"):null;
        if(G.field(me,"isMe")!=true||G.field(me,"hero")==null||G.field(G.field(me,"hero"),"removed")==true)me=null;
        if(player!=me) {
            disconnect();player=me;
            if(me!=null) {
                inv=new TradeInventory(me);account=G.text(G.field(me,"uid"));
                if(G.current("lib.Network","OFFLINE_MODE")!=true && G.current("lib.Network","realmId")!=null)
                    server=MarketExport.server(G.text(G.current("Options","serverRegion")));
                reconnect();
            }
        }
        if(me!=null&&G.current("lib.Network","OFFLINE_MODE")!=true&&G.current("lib.Network","realmId")!=null) {
            var connectedServer=MarketExport.server(G.text(G.current("Options","serverRegion")));
            if(connectedServer!=server){server=connectedServer;reconnect();}
        }
        var event=worker.receive();
        while(event!=null){
            if(event.generation==generation) switch(event.op){
                case "presence-read":receivePresenceRead(event,now);
                case "prefetch":receivePrefetch(event,now);
                case "request":
                    busy=false;var response=event.response,data:Dynamic=null,method=pendingMethod,path=pendingPath,orderType=pendingOrderType,buyItemKey=pendingBuyItemKey,failed=pendingFailure;pendingFailure=null;
                    try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
                    if(response.status>=200&&response.status<300&&response.error==""&&(data!=null||response.status==204)) {
                        peerPresence.observe(data,now);
                        if(ready)connectionIssue=false;
                        if(method=="GET")retryOnOpen=false;
                        var done=pending;pending=null;if(done!=null)try done(data==null?{}:data)catch(e:Dynamic) {
                            MarketApiLog.unexpected(method,path,response.status,"Could not process response: "+Std.string(e),key);
                            message="Unsupported marketplace response. Update the mod and try again.";
                            if(method=="GET")retryOnOpen=true;
                        }
                    } else {pending=null;if(failed!=null)failed();
                        var code=data==null?"":G.text(G.field(data.error,"code"),G.text(data.error));
                        if(code=="listing_limit") {
                            if(orderType=="buy")ownedBuyCount=LISTING_LIMIT;
                            else if(orderType=="sell")ownedSellCount=LISTING_LIMIT;
                        }
                        if(code=="duplicate_item"&&buyItemKey!="")ownedBuyItems[buyItemKey]=0;
                        if(method=="PUT"&&code=="stale_revision"){ownedKnown=false;editingListingId="";}
                        cooldown.record(method,path,response.status,response.retryAfter,haxe.Timer.stamp(),Date.now().getTime()/1000);
                        message=response.status==0||response.status>=500?MarketText.TEMPORARY_ERROR:
                            response.status==429?cooldown.message(method,path,haxe.Timer.stamp()):
                            method=="PUT"&&code=="stale_revision"?"This listing changed. Refresh before editing it again.":error(code,orderType);
                        if(method=="GET")retryOnOpen=true;
                        if(response.status>=200&&response.status<300&&response.error=="")
                            MarketApiLog.unexpected(method,path,response.status,"Expected a JSON response",key);
                        if((method!="GET"||path.indexOf("mine=true")>=0)&&(response.status==401||response.status==403)){ready=false;connectionIssue=true;}
                    }
                    view.dirty=true;
                case "presence":ownOnlineUntil=event.onlineUntil;ownOnlineServer=event.server;
                case "ready":ready=true;connectionIssue=false;message=event.message;view.dirty=true;
                    if(opened&&(tab=="Sell"||tab=="Buy"||tab=="My listings")&&!ownedKnown&&!busy)refreshSell();
                case "connection-error":message=event.message;view.dirty=true;
                case "error":ready=false;connectionIssue=true;message=event.message;view.dirty=true;
                case "auth","auth-end":
                    signingIn=event.op=="auth";message=(event.code==null||event.code==""?"":"Code: "+event.code+"\n")+event.message;
                    if(!signingIn)SessionLease.release(HlxRuntime.moduleName());view.dirty=true;
                case "credential":
                    signingIn=false;SessionLease.release(HlxRuntime.moduleName());
                    try {
                        var values=CommonSettings.read();
                        if(readKey(values)!=event.expectedKey)throw "The API key changed during sign-in. Your current key was kept.";
                        Reflect.setField(values,"fareverlyApiKey",event.credential.accessToken);
                        sys.FileSystem.createDirectory(haxe.io.Path.directory(CommonSettings.PATH));
                        MarketNative.write(sys.FileSystem.fullPath(CommonSettings.PATH),haxe.Json.stringify(values,null,"  "));
                        Bus.publish(CommonSettings.CHANGED_TOPIC,{key:"fareverlyApiKey"});
                        message="Fareverly connected. Your API key is shared with other Fareverly mods.";
                    } catch(e:Dynamic)message=Std.string(e);
                    view.dirty=true;
                default:
            }
            event=worker.receive();
        }
        if(navigationPending&&!busy)resumeNavigation();
        view.update();
        refreshPeerPresence(now);
    }
    static function readKey(values:Dynamic):String {var v=Reflect.field(values,"fareverlyApiKey");return Std.isOfType(v,String)?v:"";}
    function reconnect():Void {
        cancelPresenceRead();peerPresence=new MarketPresenceRefresh();
        ownOnlineUntil=0;ownOnlineServer="";
        key="";try key=readKey(CommonSettings.read())catch(_:Dynamic){}
        generation=worker.session(server==""?"":account,key,server);busy=false;ready=false;pending=null;pendingFailure=null;navigationPending=false;navigationForce=false;cooldown.clear();retryOnOpen=false;
        signingIn=false;SessionLease.release(HlxRuntime.moduleName());
        invalidateListings();ownedItems=[];ownedKinds=[];
        if(tab=="Sell"){availableInventory=[];inventory=[];inventorySlots=[];chosen=null;total=0;}
        connectionIssue=!Protocol.validKey(key);message="";view.dirty=true;
    }
    public function disconnect():Void {
        cancelPresenceRead();peerPresence=new MarketPresenceRefresh();
        contactingSeller="";editingListingId="";
        view.close(); if(player!=null)generation=worker.session("","");
        ownOnlineUntil=0;ownOnlineServer="";
        player=null;inv=null;account="";server="";ready=false;busy=false;signingIn=false;connectionIssue=false;pending=null;pendingFailure=null;navigationPending=false;navigationForce=false;
        cooldown.clear();retryOnOpen=false;
        rows=[];browseRows=[];inventory=[];availableInventory=[];locations=[];selected=null;chosen=null;expectedBody="";requestId="";
        buyExpectedBody="";buyRequestId="";
        inventorySlots=[];inventoryIndexes=[];inventorySource=null;bankNames=[];bankTab=0;
        buy=new MarketBuy();opened=false;page=pages=1;total=0;invalidateListings();ownedItems=[];ownedKinds=[];
        SessionLease.release(HlxRuntime.moduleName());
    }
    public function fail(error:Dynamic):Void {
        // A marketplace UI failure must not cancel an unrelated direct trade.
        view.recover(error);
    }
    public function toggle():Void {
        if(view.isOpen())view.close();else open();
    }
    public function open():Void {
        if(!trade.TradeMod.enabled()||player==null||inv==null)return;
        view.open();
        // Closing a window is not navigation: retain scrolling, selection and the sell draft.
        // Mutations still validate fresh inventory/listing data before acting.
        if(!opened||retryOnOpen&&!busy){opened=true;refresh();}
    }
    public function signIn():Void {
        if(player==null)return;
        view.open();
        if(server==""){message="Reconnect to a game server before signing in.";view.dirty=true;return;}
        if(signingIn)return;
        if(!SessionLease.acquire(HlxRuntime.moduleName())){message="A Fareverly sign-in is already running in another mod.";view.dirty=true;return;}
        try {worker.send({generation:generation,op:"auth",entropy:MarketNative.random()});signingIn=true;message="Preparing Steam sign-in...";}
        catch(e:Dynamic){SessionLease.release(HlxRuntime.moduleName());message=Std.string(e);}
        view.dirty=true;
    }
    public function cancelSignIn():Void {reconnect();message="Sign-in cancelled.";view.dirty=true;}
    function rememberTab():Void {
        if(tab=="My listings")mineSelectedId=G.text(G.field(selected,"id"));
        else if(tab=="Browse"&&filledBrowse!=null)
            filledBrowse.selectedId=G.text(G.field(selected,"id"));
    }
    function cancelPrefetch():Void {prefetch=null;worker.cancelPrefetch();}
    function cancelPresenceRead():Void {
        presenceRead=null;visiblePresenceRows=[];presencePollAt=0;
        worker.cancelPresenceRead();
    }
    /** The virtualized list reports just the rows on screen, including its small overscan. */
    public function visibleListings(value:Array<Dynamic>):Void {
        visiblePresenceRows=value;presencePollAt=0;
    }
    function refreshPeerPresence(now:Float):Void {
        if(!view.isOpen()||tab!="Browse"||!canBrowse()) {
            if(presenceRead!=null)cancelPresenceRead();
            return;
        }
        if(busy||navigationPending||prefetch!=null||presenceRead!=null||now<peerPresence.next||now<presencePollAt)return;
        presencePollAt=now+1;
        if(filledBrowse==null||!filledBrowse.loaded)return;
        var candidates=visiblePresenceRows.copy();if(selected!=null)candidates.push(selected);
        for(row in candidates) {
            var id=G.text(G.field(row,"id"));
            if(G.text(G.field(G.field(row,"seller"),"accountId"))==account||!peerPresence.due(row,now)
                ||!~/^[a-f0-9-]{36}$/.match(id))continue;
            // Usually one existing list-page request refreshes every visible
            // player. If a row moved out of that page, resolve its detail next.
            var path=filledBrowse.presencePath(id,now),batch=path!=null;
            if(!batch)path="/api/v1/marketplace/listings/"+id;
            if(cooldown.remaining("GET",path,now)>0)return;
            presenceRead={ticket:++nextTicket,path:path,feed:filledBrowse,row:row,batch:batch};
            try worker.send({generation:generation,op:"presence-read",ticket:presenceRead.ticket,method:"GET",path:path})
            catch(_:Dynamic){presenceRead=null;peerPresence.completed(0,"",now,Date.now().getTime()/1000);}
            return;
        }
    }
    function receivePresenceRead(event:MarketWorker.MarketEvent,now:Float):Void {
        if(presenceRead==null||event.ticket!=presenceRead.ticket)return;
        var work=presenceRead;presenceRead=null;
        var response=event.response,status=response.status,data:Dynamic=null;
        if(status==200&&response.error=="")try {
            data=haxe.Json.parse(response.body);
            if(work.batch) {
                if(data==null||!Std.isOfType(data.listings,Array)||(cast data.listings:Array<Dynamic>).length>MarketBrowseFeed.LIMIT)
                    throw "Invalid presence page";
                work.feed.checkedPresence(work.path,now);
            } else if(data==null||G.text(G.field(data,"id"))!=G.text(G.field(work.row,"id"))
                ||G.text(G.field(data,"server"))!=G.text(G.field(work.row,"server"))
                ||!Std.isOfType(G.field(G.field(data,"seller"),"online"),Bool))throw "Invalid presence detail";
            peerPresence.observe(data,now);
        }catch(_:Dynamic)status=0;
        else if(work.batch&&(status==400||status==404)) {
            // A cursor may stop resolving while its rows are still on screen.
            // Use bounded detail reads instead of retrying that page forever.
            work.feed.checkedPresence(work.path,now);status=404;
        }
        else if(status==404)peerPresence.unavailable(work.row,now);
        else if(status==200)status=0;
        peerPresence.completed(status,response.retryAfter,now,Date.now().getTime()/1000);
        cooldown.record("GET",work.path,status,response.retryAfter,now,Date.now().getTime()/1000);
        // Only live status changes. Keep rows, cursor, selected details, scroll,
        // filters and the foreground loading/error state exactly as they were.
    }
    function invalidateListings(resetCounts=true):Void {
        cancelPresenceRead();
        cancelPrefetch();listingCaches=[];filledBrowse=null;mineScroll={offset:0.0};
        if(resetCounts){ownedSellCount=0;ownedBuyCount=0;ownedBuyItems=[];}
        ownedKnown=false;ownedExpiry=[];ownedRows=[];minePage=1;mineSelectedId="";
    }
    public function listingScrollState():{offset:Float} return tab=="Browse"&&filledBrowse!=null?filledBrowse.scroll:mineScroll;
    public function loadingMore():Bool return tab=="Browse"&&prefetch!=null&&prefetch.feed==filledBrowse;
    public function loadMoreFailed():Bool return tab=="Browse"&&filledBrowse!=null&&filledBrowse.failed;
    public function chooseTab(value:String):Void {
        editingListingId="";rememberTab();cancelPrefetch();cancelPresenceRead();opened=true;
        tab=value;rows=[];browseRows=[];selected=null;total=0;page=pages=1;
        // Show the destination immediately; an unfinished request remains owned
        // by its original operation until the response is processed.
        navigationPending=busy;navigationForce=false;
        if(tab=="Buy") {
            buy.load();message="";
            if(ownedKnown)navigationPending=false;
            else if(!busy&&ready)refreshSell();
        } else if(tab=="Sell") {
            if(ownedKnown){loadInventory();message="";}
            else if(busy)loadInventory();
            else refreshSell();
        } else if(tab=="My listings") {
            if(ownedKnown)displayOwned();
            else if(!busy)refreshSell();
        } else {
            filledBrowse=cacheForTab();
            if(!canBrowse())message=MarketText.SIGN_IN_TO_BROWSE;
            else if(busy) {displayFilledBrowse(filledBrowse);message="Loading...";}
            else showListings(false);
        }
        view.dirty=true;
    }
    function resumeNavigation():Void {
        if(!navigationPending||busy)return;
        var force=navigationForce;navigationPending=false;navigationForce=false;
        if(tab=="Browse")showListings(force);
        else if(tab=="Buy") {
            if(ready&&(force||!ownedKnown))refreshSell();
        }
        else if(tab=="Sell") {
            if(force||!ownedKnown)refreshSell();
            else {loadInventory();message="";}
        } else if(tab=="My listings") {
            if(force||!ownedKnown)refreshSell();
            else displayOwned();
        }
    }
    public function toggleListing(row:Dynamic):Void {
        if(busy)return;
        editingListingId="";
        selected=selected!=null&&G.text(G.field(selected,"id"))==G.text(G.field(row,"id"))?null:row;
        rememberTab();view.dirty=true;
    }
    public function toggleFilters():Void {filtersExpanded=!filtersExpanded;view.dirty=true;}
    public function setHideMine(value:Bool):Void {
        if(hideMine==value)return;
        hideMine=value;saveFilterPreferences();
        if(tab=="Browse") {
            rememberTab();cancelPrefetch();filledBrowse=null;
            page=pages=1;selected=null;rows=[];browseRows=[];total=0;
            // The unfiltered cache remains available when Hide mine is off.
            // When enabled, the server excludes this account from each batch.
            if(busy){navigationPending=true;navigationForce=false;}
            else showListings(false);
        }
        view.dirty=true;
    }
    function visibleBrowseRows(?source:Array<Dynamic>):Array<Dynamic> {
        var now=Date.now().getTime()/1000;
        var raw=source==null?browseRows:source;
        return raw.filter(row->{
            var expiry=G.text(G.field(row,"expiresAt")),seller=G.field(row,"seller");
            // Hide mine is handled on the server with excludeAccountId.
            // Never discard own listings here and refill from extra pages.
            return (expiry==""||Protocol.expiry(expiry)>now)
                &&(filters["online"]!="true"||seller==null||listingOnline(row,now));
        });
    }
    public function canBrowse():Bool return ready||Protocol.validKey(key);
    public function saveFilterPreferences():Void
        trade.TradeMod.saveMarketplaceFilters(hideMine,filters["online"]=="true");
    public function listingSort():String return tab=="My listings"?mineSort:filters["sort"];
    public function sortByLevel():Void cycleSort("required-level");
    public function sortByPrice():Void cycleSort("price");
    function cycleSort(column:String):Void {
        if(tab=="Sell")return;
        var current=listingSort();
        var value=current==column+"-asc"?column+"-desc":current==column+"-desc"?"":column+"-asc";
        if(tab=="My listings"){mineSort=value;mineScroll={offset:0.0};}else filters["sort"]=value;
        page=1;
        if(tab=="My listings"&&ownedKnown)displayOwned();else refresh();
    }
    public function searchSelectedItem():Void {
        if(busy||tab!="Sell")return;
        var name=chosen==null?"":chosen.name;
        if(name=="")return;
        // The shortcut searches the item, not the old category/rarity/class restrictions.
        for(k in filters.keys())if(k!="online"&&k!="sort")filters[k]="";
        filters["orderType"]="any";
        filters["search"]=name.substr(0,100);
        listingCaches=[];
        chooseTab("Browse");
    }
    function refreshSell():Void {
        if(busy){navigationPending=true;navigationForce=true;view.dirty=true;return;}
        ownedKnown=false;
        if(tab=="Sell")loadInventory();
        view.dirty=true;
        // Duplicate-item checks span regions, so collect all pages before replacing the snapshot.
        var collected:Array<Dynamic>=[],seen:Map<String,Bool>=[],cursors:Map<String,Bool>=[];
        function fetchPage(cursor:Null<String>):Void {
            var path="/api/v1/marketplace/listings?mine=true&orderType=any&limit=50"+(cursor==null?"":"&cursor="+StringTools.urlEncode(cursor));
            request("GET",path,null,null,data->{
                if(!Std.isOfType(data.listings,Array)||(cast data.listings:Array<Dynamic>).length>50
                    ||(data.nextCursor!=null&&!Std.isOfType(data.nextCursor,String)))throw "Incomplete owned listings";
                for(row in (cast data.listings:Array<Dynamic>)) {
                    var id=G.text(G.field(row,"id"));
                    if(id!=""&&seen.exists(id))continue;
                    if(id!="")seen[id]=true;
                    collected.push(row);
                }
                if(data.nextCursor!=null) {
                    var next:String=data.nextCursor;
                    if(next==""||cursors.exists(next)||[for(k in cursors.keys())k].length>=4)throw "Invalid owned listings pagination";
                    cursors[next]=true;fetchPage(next);return;
                }
                ownedRows=collected;indexOwned();ownedKnown=true;
                // A late owned-listings response updates account state, not an
                // unrelated Browse page that was selected during the request.
                if(tab=="My listings")displayOwned();
                else if(tab=="Sell")loadInventory();
                if(tab!="Browse")message="";
            });
        }
        fetchPage(null);
    }
    function indexOwned():Void {
        var now=Date.now().getTime()/1000;
        ownedSellCount=0;ownedBuyCount=0;
        for(row in ownedRows) {
            var expires=G.text(G.field(row,"expiresAt"));
            if(G.text(G.field(row,"server"))!=server||(expires!=""&&Protocol.expiry(expires)<=now))continue;
            if(MarketOrder.isBuy(row))ownedBuyCount++;else ownedSellCount++;
        }
        var items:Map<String,Bool>=[],kinds:Map<String,Bool>=[],expiry:Map<String,Float>=[],buys:Map<String,Float>=[];
        for(row in ownedRows) {
            var item=G.field(G.field(row,"export"),"item");if(item==null)item=G.field(row,"item");
            if(item==null)continue;
            var id=MarketItemIdentity.key(item),expires=G.text(G.field(row,"expiresAt"));
            // Identical buy orders conflict across all regions, independently of sell orders.
            if(MarketOrder.isBuy(row)) {
                var deadline=expires==""?0:Protocol.expiry(expires);
                if(expires==""||deadline>now)buys[id]=deadline;
                continue;
            }
            items[id]=true;kinds[G.text(G.field(item,"baseId"))]=true;
            if(expires!="")expiry[id]=Protocol.expiry(expires);
        }
        ownedItems=items;ownedKinds=kinds;ownedExpiry=expiry;ownedBuyItems=buys;
    }
    public function buyAlreadyListed():Bool {
        try {
            var key=MarketItemIdentity.key(MarketExport.buyItem(buy));
            if(!ownedBuyItems.exists(key))return false;
            var deadline=ownedBuyItems[key];
            return deadline==0||deadline>Date.now().getTime()/1000;
        }catch(_:Dynamic)return false;
    }
    public function listingOnline(row:Dynamic,?at:Float):Bool {
        var now=at==null?Date.now().getTime()/1000:at;
        var seller=G.field(row,"seller"),deadline=Protocol.expiry(G.text(G.field(seller,"onlineUntil")));
        if(G.field(seller,"online")==false)deadline=0;
        var fresh=peerPresence.deadline(row);if(fresh!=null)deadline=fresh;
        if(account!=""&&G.text(G.field(seller,"accountId"))==account&&ownOnlineServer!=""
            &&G.text(G.field(row,"server"))==ownOnlineServer)deadline=Math.max(deadline,ownOnlineUntil);
        return deadline>now;
    }
    function displayOwned():Void {
        var now=Date.now().getTime()/1000,id=G.text(G.field(selected,"id"),mineSelectedId);
        var available=ownedRows.filter(row->{
            var region=G.text(G.field(row,"server")),expiry=G.text(G.field(row,"expiresAt"));
            return region==server&&(expiry==""||Protocol.expiry(expiry)>now);
        });
        if(mineSort!="")available.sort((a,b)->{
            var price=StringTools.startsWith(mineSort,"price-");
            var av:Dynamic=price?G.field(G.field(a,"price"),"silverTrays"):G.field(G.field(a,"item"),"requiredLevel");
            var bv:Dynamic=price?G.field(G.field(b,"price"),"silverTrays"):G.field(G.field(b,"item"),"requiredLevel");
            if(av==null||bv==null)return av==bv?0:av==null?1:-1;
            return Reflect.compare(G.integer(av),G.integer(bv))*(StringTools.endsWith(mineSort,"-desc")?-1:1);
        });
        page=pages=minePage=1;
        rows=available;total=rows.length;
        selected=null;
        for(row in rows)if(G.text(G.field(row,"id"))==id){selected=row;break;}
        mineSelectedId=G.text(G.field(selected,"id"));view.dirty=true;message="";
    }
    public function loadInventory():Void {
        var now=Date.now().getTime()/1000;
        for(id in [for(id in ownedExpiry.keys())id])if(ownedExpiry[id]<=now){ownedExpiry.remove(id);ownedItems.remove(id);}
        var chosenId=chosen==null?"":chosen.uid;
        availableInventory=[];listedInventory=[];lockedInventory=[];boundInventory=[];chosen=null;locations=[];inventoryIndexes=[];inventorySlots=[];
        var sources=MarketInventory.sources(inv,bankOnly);
        bankNames=MarketInventory.bankNames(inv);
        bankTab=Std.int(Math.max(0,Math.min(bankTab,bankNames.length-1)));
        inventorySource=sources.length==0?null:sources[bankOnly?bankTab:0];
        var source=inventorySource;
        if(source!=null)for(s in source.stacks())try {
            var allowed=source.canDrop(s,1),locked=!allowed&&MarketInventory.locked(source,s);
            var item=TradeInventory.describe(s.item,s.count);
            item.name=MarketText.itemName(item.kind,item.name,TradeInventory.itemName);
            if(!locations.exists(item.uid)) {
                if(locked)lockedInventory[item.uid]=true;
                else if(!allowed)boundInventory[item.uid]=true;
                if(ownedKinds.exists(item.kind)&&ownedItems.exists(MarketItemIdentity.key(MarketExport.itemData(s.item,item,s.count))))listedInventory[item.uid]=true;
                availableInventory.push(item);locations[item.uid]=bankOnly?bankNames[bankTab]:"In backpack";
                inventoryIndexes[item.uid]=s.index;
                if(item.uid==chosenId)chosen=item;
            }
        }catch(_:Dynamic){}
        applyInventorySearch();
    }
    public function searchInventory():Void {page=1;applyInventorySearch();}
    function applyInventorySearch():Void {
        inventory=MarketInventory.filter(availableInventory,sellSearch);
        inventorySlots=[for(_ in 0...MarketInventory.slotCount(inventorySource)) null];
        for(item in inventory)if(inventoryIndexes.exists(item.uid))inventorySlots[inventoryIndexes[item.uid]]=item;
        if(chosen!=null&&inventory.indexOf(chosen)<0)chosen=null;
        total=inventory.length;pages=page=1;view.dirty=true;
    }
    public function setBankOnly(value:Bool):Void {
        if(tab!="Sell")return;
        bankOnly=value;page=1;loadInventory();
    }
    public function setBankTab(value:Int):Void {
        if(tab!="Sell"||value<0||value>=bankNames.length||value==bankTab)return;
        bankTab=value;chosen=null;loadInventory();
    }
    public function inventoryStack(item:TradeItem):Dynamic {
        if(inventorySource==null||!inventoryIndexes.exists(item.uid))return null;
        var stack=G.call("st.Inventory","getStack",inventorySource.inventory,[inventoryIndexes[item.uid]]);
        return G.uid(G.field(stack,"item"))==item.uid?stack:null;
    }
    public function isListed(item:TradeItem):Bool return item!=null&&listedInventory.exists(item.uid);
    public function isBound(item:TradeItem):Bool return item!=null&&boundInventory.exists(item.uid);
    public function isLocked(item:TradeItem):Bool return item!=null&&lockedInventory.exists(item.uid);
    public function inventoryLocation(item:TradeItem):String return locations.exists(item.uid)?locations[item.uid]:"In backpack";
    function cacheForTab():MarketBrowseFeed {
        var order=filters["orderType"];
        if(order==null||order=="")order="any";
        var params=["server="+StringTools.urlEncode(server),"orderType="+StringTools.urlEncode(order)];
        if(hideMine)params.push("excludeAccountId="+StringTools.urlEncode(account));
        params.push("limit="+MarketBrowseFeed.LIMIT);
        var keys=[for(k in filters.keys())k];keys.sort(Reflect.compare);
        for(k in keys)if(k!="orderType"&&filters[k]!="")params.push(k+"="+StringTools.urlEncode(filters[k]));
        var path="/api/v1/marketplace/listings?"+params.join("&"),slot=hideMine?"hidden":"all",cache=listingCaches[slot];
        if(cache==null||cache.path!=path){cache=new MarketBrowseFeed(path);listingCaches[slot]=cache;}
        return cache;
    }
    public function refresh():Void {
        if(tab=="Buy") {
            buy.load(true);
            if(busy){navigationPending=true;navigationForce=true;}
            else if(ready)refreshSell();
            view.dirty=true;return;
        }
        if(busy) {
            // Preserve the latest query/desired tab; do not drop the click
            // while the current request or listing write is still in progress.
            navigationPending=true;navigationForce=true;view.dirty=true;return;
        }
        if(tab=="Sell"||tab=="My listings"){mineScroll={offset:0.0};refreshSell();return;}
        showListings(true);
    }
    function showListings(force:Bool):Void {
        if(!canBrowse()) {
            rows=[];browseRows=[];selected=null;total=0;pages=page=1;
            message=MarketText.SIGN_IN_TO_BROWSE;view.dirty=true;return;
        }
        if(server==""){message="Reconnect to identify your game server before browsing.";view.dirty=true;return;}
        if(hideMine&&!Protocol.validAccount(account)) {
            // Never fall back to unfiltered results when the account cannot be
            // identified: that would silently defeat the user's Hide mine choice.
            rows=[];browseRows=[];selected=null;total=0;pages=page=1;
            message="Your Farever account could not be identified. Reconnect before browsing with Hide mine.";
            view.dirty=true;return;
        }
        var stream=cacheForTab();
        if(force||stream.stale(haxe.Timer.stamp())) {
            var replacement=new MarketBrowseFeed(stream.path);
            replacement.selectedId=G.text(G.field(selected,"id"),stream.selectedId);
            stream=replacement;listingCaches[hideMine?"hidden":"all"]=stream;
        }
        cancelPrefetch();cancelPresenceRead();filledBrowse=stream;
        if(stream.loaded){displayFilledBrowse(stream);return;}
        // Keep the previous snapshot visible during an explicit refresh. The
        // new feed owns a fresh scroll position and only replaces rows on success.
        if(!force)displayFilledBrowse(stream);
        request("GET",stream.url(),null,null,data->{
            stream.append(data,haxe.Timer.stamp());
            if(tab=="Browse"&&!navigationPending&&filledBrowse==stream&&cacheForTab()==stream)
                displayFilledBrowse(stream);
        });
    }
    function displayFilledBrowse(stream:MarketBrowseFeed):Void {
        var id=G.text(G.field(selected,"id"),stream.selectedId);
        browseRows=stream.rows;rows=visibleBrowseRows(stream.rows);total=rows.length;page=pages=1;
        selected=null;
        for(row in rows)if(G.text(G.field(row,"id"))==id){selected=row;break;}
        stream.selectedId=G.text(G.field(selected,"id"));
        message=rows.length==0&&stream.complete?"No matching listings.":"Listings updated.";
        view.dirty=true;
    }
    /** Called near the bottom of the viewport; a failure requires an explicit retry. */
    public function loadMore(retry=false):Void {
        var stream=filledBrowse,now=haxe.Timer.stamp();
        if(tab!="Browse"||!canBrowse()||busy||navigationPending||prefetch!=null||stream==null
            ||!stream.loaded||stream.complete||stream.failed&&!retry||cacheForTab()!=stream)return;
        var path=stream.url();
        if(cooldown.remaining("GET",path,now)>0) {
            if(retry){message=cooldown.message("GET",path,now);view.dirty=true;}
            return;
        }
        stream.failed=false;
        prefetch={feed:stream,path:path,ticket:++nextTicket};
        try worker.send({generation:generation,op:"prefetch",ticket:prefetch.ticket,method:"GET",path:path})
        catch(e:Dynamic) {
            prefetch=null;stream.failed=true;
            MarketApiLog.unexpected("GET",path,0,"Could not queue request: "+Std.string(e),key);
        }
        view.dirty=true;
    }
    function receivePrefetch(event:MarketWorker.MarketEvent,now:Float):Void {
        if(prefetch==null||event.ticket!=prefetch.ticket)return;
        var work=prefetch;prefetch=null;
        var response=event.response,data:Dynamic=null,ok=false;
        try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
        if(response.status==200&&response.error==""&&data==null)
            MarketApiLog.unexpected("GET",work.path,200,"Expected a JSON response",key);
        if(response.status==200&&response.error==""&&data!=null)try {
            work.feed.append(data,haxe.Timer.stamp());ok=true;
            peerPresence.observe(data,now);
        }catch(e:Dynamic)MarketApiLog.unexpected("GET",work.path,response.status,"Could not process response: "+Std.string(e),key);
        if(!ok) {
            work.feed.failed=true;
            cooldown.record("GET",work.path,response.status,response.retryAfter,haxe.Timer.stamp(),Date.now().getTime()/1000);
        }
        if(tab=="Browse"&&filledBrowse==work.feed&&!navigationPending&&cacheForTab()==work.feed) {
            if(ok)displayFilledBrowse(work.feed);
            else if(response.status==429)message=cooldown.message("GET",work.path,haxe.Timer.stamp());
            view.dirty=true;
        }
    }
    public function request(method:String,path:String,body:Dynamic,headers:Map<String,String>,done:Dynamic->Void,?failed:Void->Void):Bool {
        if(busy)return false;
        if(cooldown.remaining(method,path,haxe.Timer.stamp())>0){message=cooldown.message(method,path,haxe.Timer.stamp());view.dirty=true;return false;}
        if((method!="GET"||path.indexOf("mine=true")>=0)&&!ready){message=connectionIssue?MarketText.CONNECTION_ERROR:"Connecting to Fareverly. Please try again shortly.";view.dirty=true;return false;}
        busy=true;pending=done;pendingFailure=failed;pendingMethod=method;pendingPath=path;message="Loading...";view.dirty=true;
        // A response belongs to the submitted order, even after navigating to another tab.
        pendingOrderType=method=="POST"&&path=="/api/v1/marketplace/listings"?(MarketOrder.isBuy(body)?"buy":"sell"):"";
        pendingBuyItemKey="";
        if(pendingOrderType=="buy")try pendingBuyItemKey=MarketItemIdentity.key(G.field(body,"item"))catch(_:Dynamic){}
        try worker.send({generation:generation,op:"request",method:method,path:path,body:body==null?null:haxe.Json.stringify(body),headers:headers})catch(e:Dynamic) {
            busy=false;pending=null;pendingFailure=null;
            MarketApiLog.unexpected(method,path,0,"Could not queue request: "+Std.string(e),key);
            message=MarketText.TEMPORARY_ERROR;if(method=="GET")retryOnOpen=true;view.dirty=true;
            return false;
        }
        return true;
    }
    public function list(quantity:Int,trays:Int,offers:Bool):Void {
        if(chosen==null||busy)return;
        if(listingLimitReached("sell")){message=error("listing_limit","sell");view.dirty=true;return;}
        if(isBound(chosen)){message="This item is bound and cannot be traded.";view.dirty=true;return;}
        if(isLocked(chosen)){message="This item is locked.";view.dirty=true;return;}
        if(!ownedKnown){refreshSell();return;}
        try {
            var submittedUid=chosen.uid;
            var value=MarketExport.snapshot(inv,chosen,quantity,trays,offers,server,app,bankOnly),body=haxe.Json.stringify(value);
            if(ownedItems.exists(MarketItemIdentity.key(value.item)))throw "You already have an active listing for this item.";
            // A timed-out submission reuses its UUID and exact body; a second click cannot duplicate it.
            if(body!=expectedBody){requestId=MarketExport.uuid();expectedBody=body;}
            request("POST","/api/v1/marketplace/listings",value,["Idempotency-Key"=>requestId],data->{
                invalidateListings(false);ownedSellCount++;
                // Keep known markers while reconciling, including the item just accepted by the server.
                ownedItems[MarketItemIdentity.key(value.item)]=true;
                ownedKinds[G.text(G.field(value.item,"baseId"))]=true;
                expectedBody="";requestId="";
                if(chosen!=null&&chosen.uid==submittedUid)chosen=null;
                // Do not re-open Sell or overwrite a new Browse query after
                // the user navigates away during an in-flight POST.
                if(!navigationPending&&tab=="Sell"){page=1;refresh();}
            });
        } catch(e:Dynamic){message=Std.string(e);view.dirty=true;}
    }
    public function availableToList(item:TradeItem):Int {
        try return MarketExport.available(inv,item,bankOnly)catch(_:Dynamic)return 0;
    }
    public function submitBuy():Void {
        if(tab!="Buy"||busy||buy.selected==null)return;
        if(!ready){message=connectionIssue?MarketText.CONNECTION_ERROR:"Connecting to Fareverly. Please try again shortly.";view.dirty=true;return;}
        if(listingLimitReached("buy")){message=error("listing_limit","buy");view.dirty=true;return;}
        try {
            var submittedBuy=buy,draft=buy.draftKey();
            var value=MarketExport.buySnapshot(buy,server,app,player),body=haxe.Json.stringify(value);
            if(buyAlreadyListed()){message=error("duplicate_item","buy");view.dirty=true;return;}
            // Keep a separate retry token so using Sell after a timeout cannot
            // change this draft's idempotency key. The server checks duplicates.
            if(body!=buyExpectedBody){buyRequestId=MarketExport.uuid();buyExpectedBody=body;}
            request("POST","/api/v1/marketplace/listings",haxe.Json.parse(buyExpectedBody),["Idempotency-Key"=>buyRequestId],data->{
                if(G.text(data.id)==""||G.integer(data.revision)!=1||!MarketOrder.isBuy(data)||G.text(data.server)!=G.text(value.server))
                    throw "Invalid buy order receipt";
                invalidateListings(false);ownedBuyCount++;
                ownedBuyItems[MarketItemIdentity.key(value.item)]=Date.now().getTime()/1000+72*60*60;
                buyExpectedBody="";buyRequestId="";
                if(buy==submittedBuy&&buy.draftKey()==draft)buy.clearSelection();
                message="Buy order posted.";
                // Navigation queued during submission resumes after this callback.
                // The catalog remains open if the player stayed on Buy.
            });
        }catch(e:Dynamic){message=Std.string(e);view.dirty=true;}
    }
    /** Quantity changes retain the original item identity and character snapshot. */
    function editAvailable(row:Dynamic):Int return MarketOrder.isBuy(row)?10000:MarketInventory.available(inv,G.field(G.field(row,"export"),"item"));
    public function beginEdit():Bool {
        if(busy||selected==null||tab!="My listings")return false;
        if(!ownedKnown){refreshSell();return false;}
        var original=G.field(selected,"export");
        if(original==null||G.text(original.server)!=server) {
            message="Refresh My listings to load this listing for editing.";view.dirty=true;return false;
        }
        try {
            editQuantityLimit=Std.int(Math.min(10000,Math.max(G.integer(original.item.quantity),editAvailable(selected))));
            editingListingId=G.text(selected.id);view.dirty=true;return true;
        }catch(e:Dynamic){message=Std.string(e);view.dirty=true;return false;}
    }
    public function cancelEdit():Void {if(!busy){editingListingId="";view.dirty=true;}}
    public function edit(quantity:Int,trays:Int,offers:Bool):Void {
        if(busy||selected==null||editingListingId==""||G.text(selected.id)!=editingListingId||tab!="My listings")return;
        var row=selected,id=editingListingId,revision=G.integer(row.revision),original=G.field(row,"export");
        try {
            if(original==null||revision<1||G.text(original.server)!=server)throw "Refresh My listings before editing this listing.";
            if(quantity<1||quantity>10000||(!offers&&(trays<1||trays>200000)))throw "Choose a valid quantity and a total price of 1 to 200,000 Silver Trays.";
            if(quantity>G.integer(original.item.quantity)&&quantity>editAvailable(row))throw "Not enough of this item available to increase the listing quantity.";
            var value:Dynamic=haxe.Json.parse(haxe.Json.stringify(original));
            value.item.quantity=quantity;value.price=offers?{mode:"offers"}:{mode:"fixed",silverTrays:trays};
            request("PUT","/api/v1/marketplace/listings/"+id,value,["If-Match"=>'"'+Std.string(revision)+'"'],data->{
                if(G.text(data.id)!=id||G.integer(data.revision)<=revision)throw "Invalid listing edit receipt";
                var updated:Dynamic=haxe.Json.parse(haxe.Json.stringify(row));
                updated.revision=data.revision;updated.export=value;updated.item.quantity=quantity;updated.price=value.price;
                ownedRows=[for(existing in ownedRows)G.text(existing.id)==id?updated:existing];
                editingListingId="";indexOwned();cancelPrefetch();listingCaches=[];filledBrowse=null;
                mineSelectedId=id;
                if(tab=="My listings"){selected=updated;displayOwned();}
                message="Listing updated.";
            });
        }catch(e:Dynamic){message=Std.string(e);view.dirty=true;}
    }
    public function remove():Void {
        if(selected==null||busy)return;
        var id=G.text(G.field(selected,"id")),revision=G.integer(G.field(selected,"revision"));
        if(id==""||revision<1){message="This listing changed. Refresh before removing it.";view.dirty=true;return;}
        var previousRows=ownedRows,previousPage=page,previousSelection=selected;
        // Update the local snapshot immediately, but retain it for a rejected DELETE.
        var sent=request("DELETE","/api/v1/marketplace/listings/"+id,null,["If-Match"=>'"'+Std.string(revision)+'"'],data->{
            indexOwned();cancelPrefetch();listingCaches=[];filledBrowse=null;message="";
        },()->{
            ownedRows=previousRows;indexOwned();minePage=previousPage;mineSelectedId=id;
            if(tab=="My listings"){page=previousPage;selected=previousSelection;displayOwned();}
        });
        if(!sent)return;
        ownedRows=ownedRows.filter(row->G.text(G.field(row,"id"))!=id);
        selected=null;mineSelectedId="";displayOwned();
    }

    public function contact():Void {
        if(selected==null)return;
        var row=selected;if(row.seller.accountId==account){message="This is your listing.";view.dirty=true;return;}
        if(row.server!=server){message="This listing is on another server.";view.dirty=true;return;}
        var sellerId=G.text(row.seller.accountId);
        var deadline=sellerWhisperAfter.get(sellerId);
        if(contactingSeller==sellerId||(deadline!=null&&haxe.Timer.stamp()<deadline)) {
            message="Please wait "+(contactingSeller==sellerId?10:Math.ceil(deadline-haxe.Timer.stamp()))+" seconds before whispering this "+MarketOrder.ownerLabel(row).toLowerCase()+" again.";
            view.dirty=true;trade.TradeMod.chatError(message);return;
        }
        if(busy)return;
        contactingSeller=sellerId;
        // Recheck availability before sending one explicit, human-readable whisper.
        var queued=request("GET","/api/v1/marketplace/listings/"+row.id,null,null,current->{
            try {
                var seller=G.text(current.seller.characterName),to=G.text(current.seller.accountId);
                var text=MarketWhisperMessage.message(current);
                // Send one ordinary, readable whisper with the stable item ID.
                // Both the buyer's native echo and the recipient's chat localize it.
                message="Sending whisper...";view.dirty=true;
                trade.TradeChat.send(player,to,seller,text,ok->{
                    contactingSeller="";
                    if(ok)sellerWhisperAfter.set(sellerId,haxe.Timer.stamp()+10);
                    else sellerWhisperAfter.remove(sellerId);
                    message=ok?"Whisper sent to "+seller+". Arrange a party and meet nearby to trade."
                        :"Could not send the whisper. The "+MarketOrder.ownerLabel(current).toLowerCase()+" may be unavailable.";
                    view.dirty=true;
                },true);
            }catch(error:Dynamic){
                contactingSeller="";
                message="Could not send the marketplace whisper: "+Std.string(error);
                view.dirty=true;
            }
        },()->{contactingSeller="";});
        if(!queued)contactingSeller="";
    }
    public static function error(code:String,orderType=""):String return switch(code){
        case "duplicate_item":orderType=="buy"?"You already have a buy order for this item. Edit it in My listings.":"You already have an active listing for this item.";
        case "listing_limit":orderType=="buy"||orderType=="sell"
            ?"You can have up to 20 active "+orderType+" orders per region. Remove a "+orderType+" order first."
            :"You can have up to 20 buy orders and 20 sell orders per region. Remove an order of the same type first.";
        case "listing_unavailable","listing_not_found":"This listing expired or was removed. Refresh the marketplace.";
        case "stale_revision":"This listing changed. Refresh before removing it.";
        case "unauthorized","insufficient_scope","sign_in_required":"Sign in with Steam to manage your listings.";
        case "invalid_export","update_mod_required":"The server could not accept this item's data. Update the mod and try again.";
        case "rate_limited","write_busy","write_in_progress":"Too many requests. Please wait before trying again.";
        default:"The marketplace request failed. Please retry shortly.";
    };
}
