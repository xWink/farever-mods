package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;
import fareverly.Protocol;
import fareverly.SessionLease;
import modconfig.CommonSettings;
import hlx.runtime.Bus;
class MarketController {
    public static inline var PAGE_SIZE = 8;
    public static inline var LISTING_LIMIT = 20;
    public var filtersExpanded=false;
    public var hideMine=false;
    var browseRows:Array<Dynamic>=[];
    public function pageSize():Int return tab=="Browse"?PAGE_SIZE:9;
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
    var ownedKnown=false;
    var ownedListingCount=0;
    public function listingLimitReached():Bool return ownedListingCount>=LISTING_LIMIT;
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
    var listingCaches:Map<String,MarketPages>=[];
    var activePages:MarketPages;
    var filledBrowse:MarketBrowseFeed;
    var prefetch:Null<{cache:MarketPages,page:Int,ticket:Int,waiting:Bool}>;
    var nextTicket=0;
    var mineSort="";
    public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","prismatic"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"false","sort"=>""];
    final worker=new MarketWorker();
    var generation=0;
    var key="";
    var pending:(Dynamic->Void);
    var pendingFailure:Void->Void;
    var pendingMethod="";
    var pendingPath="";
    // Requests and writes must finish, but navigation and filter changes should
    // take effect immediately. Replay only the latest desired view afterwards.
    var navigationPending=false;
    var navigationForce=false;
    final cooldown=new MarketCooldown();
    var retryOnOpen=false;
    var expectedBody="";
    var requestId="";
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
                case "prefetch":receivePrefetch(event,now);
                case "request":
                    busy=false;var response=event.response,data:Dynamic=null,method=pendingMethod,path=pendingPath,failed=pendingFailure;pendingFailure=null;
                    try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
                    if(response.status>=200&&response.status<300&&response.error==""&&(data!=null||response.status==204)) {
                        if(ready)connectionIssue=false;
                        if(method=="GET")retryOnOpen=false;
                        var done=pending;pending=null;if(done!=null)try done(data==null?{}:data)catch(e:Dynamic) {
                            MarketApiLog.unexpected(method,path,response.status,"Could not process response: "+Std.string(e),key);
                            message="Unsupported marketplace response. Update the mod and try again.";
                            if(method=="GET")retryOnOpen=true;
                        }
                    } else {pending=null;if(failed!=null)failed();
                        var code=data==null?"":G.text(G.field(data.error,"code"),G.text(data.error));
                        if(code=="listing_limit")ownedListingCount=LISTING_LIMIT;
                        if(method=="PUT"&&code=="stale_revision"){ownedKnown=false;editingListingId="";}
                        cooldown.record(method,path,response.status,response.retryAfter,haxe.Timer.stamp(),Date.now().getTime()/1000);
                        message=response.status==0||response.status>=500?MarketText.TEMPORARY_ERROR:
                            response.status==429?cooldown.message(method,path,haxe.Timer.stamp()):
                            method=="PUT"&&code=="stale_revision"?"This listing changed. Refresh before editing it again.":error(code);
                        if(method=="GET")retryOnOpen=true;
                        if(response.status>=200&&response.status<300&&response.error=="")
                            MarketApiLog.unexpected(method,path,response.status,"Expected a JSON response",key);
                        if((method!="GET"||path.indexOf("mine=true")>=0)&&(response.status==401||response.status==403)){ready=false;connectionIssue=true;}
                    }
                    view.dirty=true;
                case "presence":ownOnlineUntil=event.onlineUntil;ownOnlineServer=event.server;
                case "ready":ready=true;connectionIssue=false;message=event.message;view.dirty=true;
                    if(opened&&(tab=="Sell"||tab=="My listings")&&!ownedKnown&&!busy)refreshSell();
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
    }
    static function readKey(values:Dynamic):String {var v=Reflect.field(values,"fareverlyApiKey");return Std.isOfType(v,String)?v:"";}
    function reconnect():Void {
        ownOnlineUntil=0;ownOnlineServer="";
        key="";try key=readKey(CommonSettings.read())catch(_:Dynamic){}
        generation=worker.session(server==""?"":account,key,server);busy=false;ready=false;pending=null;pendingFailure=null;navigationPending=false;navigationForce=false;cooldown.clear();retryOnOpen=false;
        signingIn=false;SessionLease.release(HlxRuntime.moduleName());
        invalidateListings();ownedItems=[];ownedKinds=[];
        if(tab=="Sell"){availableInventory=[];inventory=[];inventorySlots=[];chosen=null;total=0;}
        connectionIssue=!Protocol.validKey(key);message="";view.dirty=true;
    }
    public function disconnect():Void {
        contactingSeller="";editingListingId="";
        view.close(); if(player!=null)generation=worker.session("","");
        ownOnlineUntil=0;ownOnlineServer="";
        player=null;inv=null;account="";server="";ready=false;busy=false;signingIn=false;connectionIssue=false;pending=null;pendingFailure=null;navigationPending=false;navigationForce=false;
        cooldown.clear();retryOnOpen=false;
        rows=[];browseRows=[];inventory=[];availableInventory=[];locations=[];selected=null;chosen=null;expectedBody="";requestId="";
        inventorySlots=[];inventoryIndexes=[];inventorySource=null;bankNames=[];bankTab=0;
        opened=false;page=pages=1;total=0;invalidateListings();ownedItems=[];ownedKinds=[];
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
        // Closing a window is not navigation: retain the page, selection and sell draft.
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
        if(tab=="My listings"){minePage=page;mineSelectedId=G.text(G.field(selected,"id"));}
        else if(tab=="Browse"&&hideMine&&filledBrowse!=null) {
            filledBrowse.current=page;filledBrowse.selectedId=G.text(G.field(selected,"id"));
        } else if(activePages!=null&&tab=="Browse") {
            activePages.current=page;activePages.selectedId=G.text(G.field(selected,"id"));
        }
    }
    function cancelPrefetch():Void {
        // Waiting for a speculative page blocks the UI without an active
        // foreground request. Cancel that wait when navigation supersedes it.
        if(prefetch!=null&&prefetch.waiting)busy=false;
        prefetch=null;worker.cancelPrefetch();
    }
    function invalidateListings():Void {
        cancelPrefetch();listingCaches=[];activePages=null;filledBrowse=null;ownedKnown=false;ownedListingCount=0;ownedExpiry=[];ownedRows=[];minePage=1;mineSelectedId="";
    }
    public function chooseTab(value:String):Void {
        editingListingId="";rememberTab();cancelPrefetch();opened=true;
        tab=value;rows=[];browseRows=[];selected=null;total=0;page=pages=1;
        // Show the destination immediately; an unfinished request remains owned
        // by its original operation until the response is processed.
        navigationPending=busy;navigationForce=false;
        if(tab=="Sell") {
            activePages=null;
            if(ownedKnown){loadInventory();message="";}
            else if(busy)loadInventory();
            else refreshSell();
        } else if(tab=="My listings") {
            activePages=null;page=minePage;
            if(ownedKnown)displayOwned();
            else if(!busy)refreshSell();
        } else {
            activePages=cacheForTab();
            page=hideMine&&filledBrowse!=null&&filledBrowse.path==activePages.path
                ?filledBrowse.current:activePages.current;
            if(!canBrowse()) {
                rows=[];browseRows=[];selected=null;page=pages=1;total=0;
                message=MarketText.SIGN_IN_TO_BROWSE;
            } else if(busy) {
                if(hideMine&&filledBrowse!=null&&filledBrowse.path==activePages.path)
                    displayFilledBrowse(filledBrowse);
                else if(!hideMine) {
                    var cached=activePages.get(page,haxe.Timer.stamp());
                    if(cached!=null)displayPage(activePages,page,cached);
                }
                message="Loading...";
            } else showListings(false);
        }
        view.dirty=true;
    }
    function resumeNavigation():Void {
        if(!navigationPending||busy)return;
        var force=navigationForce;navigationPending=false;navigationForce=false;
        if(tab=="Browse")showListings(force);
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
    public function toggleFilters():Void {
        // Layout only: keep the query, pagination, selection and prefetched rows.
        filtersExpanded=!filtersExpanded;view.dirty=true;
    }
    public function setHideMine(value:Bool):Void {
        if(hideMine==value)return;
        hideMine=value;saveFilterPreferences();
        if(tab=="Browse") {
            cancelPrefetch();
            page=pages=1;selected=null;rows=[];browseRows=[];total=0;
            // The saved raw pages can still be used when Hide mine is disabled.
            // Enabling it switches to a stream that continues loading cursor
            // pages until each displayed page contains eight visible rows.
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
            return (expiry==""||Protocol.expiry(expiry)>now)
                &&(filters["online"]!="true"||seller==null||listingOnline(row,now))
                &&(!hideMine||account==""||G.text(G.field(seller,"accountId"))!=account);
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
        if(tab=="My listings")mineSort=value;else filters["sort"]=value;
        page=1;
        if(tab=="My listings"&&ownedKnown)displayOwned();else refresh();
    }
    public function searchSelectedItem():Void {
        if(busy||tab!="Sell")return;
        var name=chosen==null?"":chosen.name;
        if(name=="")return;
        // The shortcut searches the item, not the old category/rarity/class restrictions.
        for(k in filters.keys())if(k!="online"&&k!="sort")filters[k]="";
        filters["search"]=name.substr(0,100);
        listingCaches.remove("Browse");
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
            var path="/api/v1/marketplace/listings?mine=true&limit=50"+(cursor==null?"":"&cursor="+StringTools.urlEncode(cursor));
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
        ownedListingCount=ownedRows.filter(row->{
            var expires=G.text(G.field(row,"expiresAt"));
            return G.text(G.field(row,"server"))==server&&(expires==""||Protocol.expiry(expires)>now);
        }).length;
        var items:Map<String,Bool>=[],kinds:Map<String,Bool>=[],expiry:Map<String,Float>=[];
        for(row in ownedRows) {
            var item=G.field(G.field(row,"export"),"item");if(item==null)item=G.field(row,"item");
            if(item==null)continue;
            var id=MarketItemIdentity.key(item),expires=G.text(G.field(row,"expiresAt"));
            items[id]=true;kinds[G.text(G.field(item,"baseId"))]=true;
            if(expires!="")expiry[id]=Protocol.expiry(expires);
        }
        ownedItems=items;ownedKinds=kinds;ownedExpiry=expiry;
    }
    public function listingOnline(row:Dynamic,?at:Float):Bool {
        var now=at==null?Date.now().getTime()/1000:at;
        var seller=G.field(row,"seller"),deadline=Protocol.expiry(G.text(G.field(seller,"onlineUntil")));
        if(G.field(seller,"online")==false)deadline=0;
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
        pages=Std.int(Math.max(1,Math.ceil(available.length/pageSize())));
        page=Std.int(Math.max(1,Math.min(page,pages)));minePage=page;
        rows=available.slice((page-1)*pageSize(),page*pageSize());total=rows.length;
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
    function cacheForTab():MarketPages {
        var limit=pageSize(),params=["limit="+limit,"server="+StringTools.urlEncode(server)];
        var keys=[for(k in filters.keys())k];keys.sort(Reflect.compare);
        for(k in keys)if(filters[k]!="")params.push(k+"="+StringTools.urlEncode(filters[k]));
        var path="/api/v1/marketplace/listings?"+params.join("&"),cache=listingCaches[tab];
        if(cache==null||cache.path!=path) {cache=new MarketPages(path,limit);listingCaches[tab]=cache;}
        return cache;
    }
    public function refresh():Void {
        if(busy) {
            // Preserve the latest query/desired tab; do not drop the click
            // while the current request or listing write is still in progress.
            navigationPending=true;navigationForce=true;view.dirty=true;return;
        }
        if(tab=="Sell"||tab=="My listings"){refreshSell();return;}
        showListings(true);
    }
    public function goPage(value:Int):Void {
        if(value<1||value>pages||value==page)return;
        rememberTab();page=value;
        if(tab=="My listings"&&ownedKnown)displayOwned();
        else if(busy) {
            navigationPending=true;navigationForce=false;
            rows=[];browseRows=[];selected=null;total=0;
            message="Loading...";view.dirty=true;
        } else if(tab=="My listings")refreshSell();
        else showListings(false);
    }
    function showListings(force:Bool):Void {
        if(!canBrowse()) {
            rows=[];browseRows=[];selected=null;total=0;pages=page=1;
            message=MarketText.SIGN_IN_TO_BROWSE;view.dirty=true;return;
        }
        if(server==""){message="Reconnect to identify your game server before browsing.";view.dirty=true;return;}
        if(hideMine){showFilledBrowse(force);return;}
        var cache=cacheForTab();activePages=cache;
        if(page>1&&cache.cursors[page-1]==null)page=1;
        cache.current=page;cache.trim();
        var target=page,cached=force?null:cache.get(target,haxe.Timer.stamp());
        if(cached!=null){displayPage(cache,target,cached);prefetchNext();return;}
        if(!force){rows=[];browseRows=[];selected=null;total=0;}
        if(!force&&prefetch!=null&&prefetch.cache==cache&&prefetch.page==target) {
            prefetch.waiting=true;busy=true;message="Loading...";view.dirty=true;return;
        }
        cancelPrefetch();
        if(force)cache.forget(target);
        request("GET",cache.url(target),null,null,data->{
            var result=cache.put(target,data,haxe.Timer.stamp());
            // A response for the page/query we left still fills its cache,
            // but cannot replace the new tab's rows or selected listing.
            if(tab=="Browse"&&!navigationPending&&activePages==cache
                &&page==target&&cacheForTab()==cache) {
                displayPage(cache,target,result);prefetchNext();
            }
        });
    }
    // Hide mine is a local filter, so the server can return an entire page
    // owned by this player. Consume additional cursor pages rather than leave
    // sparse display pages. Keep already-seen visible rows for later pages.
    function showFilledBrowse(force:Bool):Void {
        var cache=cacheForTab();
        if(filledBrowse==null||filledBrowse.path!=cache.path||force
            ||filledBrowse.stale(haxe.Timer.stamp()))
            filledBrowse=new MarketBrowseFeed(cache.path);
        var stream=filledBrowse;
        activePages=cache;
        displayFilledBrowse(stream);
        var visibleCount=visibleBrowseRows(stream.rows).length;
        if(stream.complete||visibleCount>=page*PAGE_SIZE)return;
        if(busy){navigationPending=true;return;}
        var requested=stream.url();
        request("GET",requested,null,null,data->{
            stream.append(data,haxe.Timer.stamp());
            if(tab=="Browse"&&hideMine&&filledBrowse==stream&&!navigationPending)
                showFilledBrowse(false);
        });
    }
    function displayFilledBrowse(stream:MarketBrowseFeed):Void {
        var visible=visibleBrowseRows(stream.rows);
        var start=(page-1)*PAGE_SIZE,end=page*PAGE_SIZE;
        var id=G.text(G.field(selected,"id"),stream.selectedId);
        browseRows=stream.rows;
        rows=visible.slice(start,end);total=rows.length;
        pages=page+(visible.length>end||!stream.complete?1:0);
        selected=null;
        for(row in rows)if(G.text(G.field(row,"id"))==id){selected=row;break;}
        stream.current=page;stream.selectedId=G.text(G.field(selected,"id"));
        message=rows.length==0&&stream.complete?"No matching listings.":"Listings updated.";
        view.dirty=true;
    }
    function displayPage(cache:MarketPages,target:Int,result:MarketPages.MarketPage):Void {
        var selectedId=G.text(G.field(selected,"id"),cache.selectedId);
        browseRows=result.rows;
        rows=visibleBrowseRows();
        page=target;cache.current=target;cache.trim();total=rows.length;pages=page+(result.next==null?0:1);
        selected=null;
        for(row in rows)if(G.text(G.field(row,"id"))==selectedId){selected=row;break;}
        cache.selectedId=G.text(G.field(selected,"id"));
        message=total==0?"No matching listings.":"Listings updated.";view.dirty=true;
    }
    function prefetchNext():Void {
        if(!canBrowse()||hideMine)return;
        var cache=activePages,now=haxe.Timer.stamp();
        if(busy||prefetch!=null||cache==null||tab=="Sell"||cooldown.remaining("GET",cache.path,now)>0
            ||(tab=="My listings"&&!ready))return;
        var next=page+1;
        if(cache.cursors[next-1]==null||cache.get(next,now)!=null)next=page-1;
        if(next<1||(next>1&&cache.cursors[next-1]==null)||cache.get(next,now)!=null)return;
        prefetch={cache:cache,page:next,ticket:++nextTicket,waiting:false};
        worker.send({generation:generation,op:"prefetch",ticket:prefetch.ticket,method:"GET",path:cache.url(next)});
    }
    function receivePrefetch(event:MarketWorker.MarketEvent,now:Float):Void {
        if(prefetch==null||event.ticket!=prefetch.ticket)return;
        var work=prefetch;prefetch=null;
        if(work.waiting)busy=false;
        var response=event.response,data:Dynamic=null,ok=false;
        try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
        if(response.status==200&&response.error==""&&data==null)
            MarketApiLog.unexpected("GET",work.cache.url(work.page),200,"Expected a JSON response",key);
        if(response.status==200&&response.error==""&&data!=null)try {
            var result=work.cache.put(work.page,data,haxe.Timer.stamp());ok=true;
            if(work.waiting&&activePages==work.cache)displayPage(work.cache,work.page,result);
        }catch(e:Dynamic)MarketApiLog.unexpected("GET",work.cache.url(work.page),response.status,"Could not process response: "+Std.string(e),key);
        if(!ok) {
            cooldown.record("GET",work.cache.url(work.page),response.status,response.retryAfter,haxe.Timer.stamp(),Date.now().getTime()/1000);
            if(work.waiting){retryOnOpen=true;message=response.status==429?cooldown.message("GET",work.cache.url(work.page),haxe.Timer.stamp()):"Could not load this page. Press Refresh to retry.";view.dirty=true;}
        } else if(!busy&&activePages==work.cache&&work.page<page&&work.cache.get(page,haxe.Timer.stamp())==null) {
            // A refreshed previous page can move its boundary. Reload from the new
            // cursor rather than pair stale current rows with a different next page.
            showListings(false);
        } else prefetchNext();
    }
    public function request(method:String,path:String,body:Dynamic,headers:Map<String,String>,done:Dynamic->Void,?failed:Void->Void):Bool {
        if(busy)return false;
        if(cooldown.remaining(method,path,haxe.Timer.stamp())>0){message=cooldown.message(method,path,haxe.Timer.stamp());view.dirty=true;return false;}
        if((method!="GET"||path.indexOf("mine=true")>=0)&&!ready){message=connectionIssue?MarketText.CONNECTION_ERROR:"Connecting to Fareverly. Please try again shortly.";view.dirty=true;return false;}
        busy=true;pending=done;pendingFailure=failed;pendingMethod=method;pendingPath=path;message="Loading...";view.dirty=true;
        try worker.send({generation:generation,op:"request",method:method,path:path,body:body==null?null:haxe.Json.stringify(body),headers:headers})catch(e:Dynamic) {
            busy=false;pending=null;pendingFailure=null;
            MarketApiLog.unexpected(method,path,0,"Could not queue request: "+Std.string(e),key);
            message=MarketText.TEMPORARY_ERROR;if(method=="GET")retryOnOpen=true;view.dirty=true;
            return false;
        }
        return true;
    }
    public function list(quantity:Int,trays:Int,offers:Bool):Void {
        if(chosen==null||busy||listingLimitReached())return;
        if(isBound(chosen)){message="This item is bound and cannot be traded.";view.dirty=true;return;}
        if(isLocked(chosen)){message="This item is locked.";view.dirty=true;return;}
        if(!ownedKnown){refreshSell();return;}
        try {
            var submittedUid=chosen.uid,submittedCount=ownedListingCount;
            var value=MarketExport.snapshot(inv,chosen,quantity,trays,offers,server,app,bankOnly),body=haxe.Json.stringify(value);
            if(ownedItems.exists(MarketItemIdentity.key(value.item)))throw "You already have an active listing for this item.";
            // A timed-out submission reuses its UUID and exact body; a second click cannot duplicate it.
            if(body!=expectedBody){requestId=MarketExport.uuid();expectedBody=body;}
            request("POST","/api/v1/marketplace/listings",value,["Idempotency-Key"=>requestId],data->{
                invalidateListings();ownedListingCount=submittedCount+1;
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
    /** Quantity changes retain the original item identity and character snapshot. */
    function editAvailable(row:Dynamic):Int return MarketInventory.available(inv,G.field(G.field(row,"export"),"item"));
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
                editingListingId="";indexOwned();cancelPrefetch();listingCaches=[];activePages=null;
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
            indexOwned();cancelPrefetch();listingCaches=[];activePages=null;message="";
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
            message="Please wait "+(contactingSeller==sellerId?10:Math.ceil(deadline-haxe.Timer.stamp()))+" seconds before whispering this seller again.";
            view.dirty=true;trade.TradeMod.chatError(message);return;
        }
        if(busy)return;
        contactingSeller=sellerId;
        // Recheck availability before sending one explicit, human-readable whisper.
        var queued=request("GET","/api/v1/marketplace/listings/"+row.id,null,null,current->{
            try {
                var seller=G.text(current.seller.characterName),to=G.text(current.seller.accountId);
                if(G.field(current,"id")==null)Reflect.setField(current,"id",G.field(row,"id"));
                var packet=MarketWhisperWire.packet(current,to),parts=MarketWhisperWire.encode(packet);
                var display=MarketWhisperWire.display(packet,TradeInventory.itemName);
                var pendingParts=parts.length,allDelivered=true;
                message="Sending whisper...";view.dirty=true;
                for(part in parts)trade.TradeChat.send(player,to,seller,part,ok->{
                    if(!ok)allDelivered=false;
                    pendingParts--;
                    if(pendingParts!=0)return;
                    contactingSeller="";
                    if(allDelivered) {
                        sellerWhisperAfter.set(sellerId,haxe.Timer.stamp()+10);
                        // Echo the original human-readable line once, never the
                        // transport fragments. The recipient decodes independently.
                        try trade.TradeChat.echo(player,to,seller,display)
                        catch(error:Dynamic)trade.TradeDiagnostics.log("Marketplace whisper echo: "+Std.string(error));
                    } else sellerWhisperAfter.remove(sellerId);
                    message=allDelivered?"Whisper sent to "+seller+". Arrange a party and meet nearby to trade."
                        :"Could not send the whisper. The seller may be unavailable.";
                    view.dirty=true;
                });
            }catch(error:Dynamic){
                contactingSeller="";
                message="Could not send the marketplace whisper: "+Std.string(error);
                view.dirty=true;
            }
        },()->{contactingSeller="";});
        if(!queued)contactingSeller="";
    }
    public static function error(code:String):String return switch(code){
        case "duplicate_item":"You already have an active listing for this item.";
        case "listing_limit":"You can have up to 20 active listings per region. Remove a listing first.";
        case "listing_unavailable","listing_not_found":"This listing expired or was removed. Refresh the marketplace.";
        case "stale_revision":"This listing changed. Refresh before removing it.";
        case "unauthorized","insufficient_scope","sign_in_required":"Sign in with Steam to manage your listings.";
        case "invalid_export","update_mod_required":"The server could not accept this item's data. Update the mod and try again.";
        case "rate_limited","write_busy","write_in_progress":"Too many requests. Please wait before trying again.";
        default:"The marketplace request failed. Please retry shortly.";
    };
}
