package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;
import fareverly.Protocol;
import fareverly.SessionLease;
import modconfig.CommonSettings;
import hlx.runtime.Bus;
class MarketController {
    public static inline var PAGE_SIZE = 6;
    public var filtersExpanded=false;
    public function pageSize():Int return tab=="Browse"?(filtersExpanded?PAGE_SIZE:8):9;
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
    var locations:Map<String,String>=[];
    var ownedKnown=false;
    var ownedItems:Map<String,Bool>=[];
    var ownedKinds:Map<String,Bool>=[];
    public var selected:Dynamic;
    public var chosen:TradeItem;
    public var page=1;
    public var pages=1;
    public var total=0;
    var listingCaches:Map<String,MarketPages>=[];
    var activePages:MarketPages;
    var prefetch:Null<{cache:MarketPages,page:Int,ticket:Int,waiting:Bool}>;
    var nextTicket=0;
    var ownedFetched=0.0;
    var mineSort="price-asc";
    public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","prismatic"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"true","sort"=>"price-asc"];
    final worker=new MarketWorker();
    var generation=0;
    var key="";
    var pending:(Dynamic->Void);
    var pendingMethod="";
    var pendingPath="";
    var requestAfter=0.0;
    var expectedBody="";
    var requestId="";
    var contactAfter=0.0;
    var opened=false;
    public function new() {
        view=new MarketWindow(this);
        Bus.subscribe(CommonSettings.CHANGED_TOPIC,(_:Dynamic)->{if(player!=null)try {if(readKey(CommonSettings.read())!=key)reconnect();}catch(_:Dynamic){}});
        var action="better-mod-settings/action/"+HlxRuntime.moduleName()+"/";
        Bus.subscribe(action+"openMarketplace",(_:Dynamic)->open());
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
        var event=worker.receive();
        while(event!=null){
            if(event.generation==generation) switch(event.op){
                case "prefetch":receivePrefetch(event,now);
                case "request":
                    busy=false;var response=event.response,data:Dynamic=null,method=pendingMethod,path=pendingPath;
                    try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
                    if(response.status>=200&&response.status<300&&response.error==""&&(data!=null||response.status==204)) {
                        if(ready)connectionIssue=false;
                        var done=pending;pending=null;if(done!=null)try done(data==null?{}:data)catch(e:Dynamic) {
                            MarketApiLog.unexpected(method,path,response.status,"Could not process response: "+Std.string(e),key);
                            message="Unsupported marketplace response. Update the mod and try again.";
                        }
                    } else {pending=null;message=error(data==null?"":G.text(G.field(data.error,"code"),G.text(data.error)));
                        if(response.status>=200&&response.status<300&&response.error=="")
                            MarketApiLog.unexpected(method,path,response.status,"Expected a JSON response",key);
                        if(response.status==401||response.status==403){ready=false;connectionIssue=true;}
                        if(response.status==0||response.status>=500)connectionIssue=true;
                        if(response.status==429||response.status>=500)requestAfter=now+Math.max(60,Protocol.retryAfter(response.retryAfter,Date.now().getTime()/1000));}
                    view.dirty=true;
                case "ready":ready=true;connectionIssue=false;message=event.message;view.dirty=true;
                    if(opened&&tab=="Sell"&&!ownedKnown&&!busy)refreshSell();
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
        view.update();
    }
    static function readKey(values:Dynamic):String {var v=Reflect.field(values,"fareverlyApiKey");return Std.isOfType(v,String)?v:"";}
    function reconnect():Void {
        key="";try key=readKey(CommonSettings.read())catch(_:Dynamic){}
        generation=worker.session(server==""?"":account,key);busy=false;ready=false;pending=null;requestAfter=0;
        signingIn=false;SessionLease.release(HlxRuntime.moduleName());
        invalidateListings();ownedItems=[];ownedKinds=[];
        if(tab=="Sell"){availableInventory=[];inventory=[];inventorySlots=[];chosen=null;total=0;}
        connectionIssue=!Protocol.validKey(key);message="";view.dirty=true;
    }
    public function disconnect():Void {
        view.close(); if(player!=null)generation=worker.session("","");
        player=null;inv=null;account="";server="";ready=false;busy=false;signingIn=false;connectionIssue=false;pending=null;
        rows=[];inventory=[];availableInventory=[];locations=[];selected=null;chosen=null;expectedBody="";requestId="";
        inventorySlots=[];inventoryIndexes=[];inventorySource=null;bankNames=[];bankTab=0;
        opened=false;page=pages=1;total=0;invalidateListings();ownedItems=[];ownedKinds=[];
        SessionLease.release(HlxRuntime.moduleName());
    }
    public function fail(error:Dynamic):Void {
        // A marketplace UI failure must not cancel an unrelated direct trade.
        view.recover(error);
    }
    public function open():Void {
        if(!trade.TradeMod.enabled()||player==null||inv==null)return;
        view.open();
        // Closing a window is not navigation: retain the page, selection and sell draft.
        // Mutations still validate fresh inventory/listing data before acting.
        if(!opened){opened=true;refresh();}
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
        if(activePages!=null&&tab!="Sell") {
            activePages.current=page;activePages.selectedId=G.text(G.field(selected,"id"));
        }
    }
    function cancelPrefetch():Void {prefetch=null;worker.cancelPrefetch();}
    function invalidateListings():Void {
        cancelPrefetch();listingCaches=[];activePages=null;ownedKnown=false;ownedFetched=0;
    }
    public function chooseTab(value:String):Void {
        if(busy)return;
        rememberTab();cancelPrefetch();opened=true;tab=value;rows=[];selected=null;total=0;page=pages=1;
        if(tab=="Sell") {
            activePages=null;
            if(ownedKnown&&haxe.Timer.stamp()-ownedFetched<MarketPages.MAX_AGE){loadInventory();message="";}
            else refreshSell();
        } else {
            activePages=cacheForTab();page=activePages.current;
            showListings(false);
        }
        view.dirty=true;
    }
    public function toggleFilters():Void {
        if(busy)return;
        filtersExpanded=!filtersExpanded;page=pages=1;refresh();view.dirty=true;
    }
    public function levelSort():String return tab=="My listings"?mineSort:filters["sort"];
    public function sortByLevel():Void {
        if(busy||tab=="Sell")return;
        var value=levelSort()=="required-level-asc"?"required-level-desc":"required-level-asc";
        if(tab=="My listings")mineSort=value;else filters["sort"]=value;
        page=1;refresh();
    }
    public function searchSelectedItem():Void {
        if(busy)return;
        var name=tab=="Sell"?(chosen==null?"":chosen.name):G.text(G.field(G.field(selected,"item"),"name"));
        if(name=="")return;
        // The shortcut searches the item, not the old category/rarity/class restrictions.
        for(k in filters.keys())if(k!="online"&&k!="sort")filters[k]="";
        filters["search"]=name.substr(0,100);
        listingCaches.remove("Browse");
        chooseTab("Browse");
    }
    function refreshSell():Void {
        if(busy)return;
        ownedKnown=false;availableInventory=[];inventory=[];inventorySlots=[];chosen=null;total=0;view.dirty=true;
        // No server/character/online filter: duplicate rules are account-wide.
        // Fifty is the API maximum and exceeds the account's ten-listing cap.
        request("GET","/api/v1/marketplace/listings?mine=true&limit=50",null,null,data->{
            if(!Std.isOfType(data.listings,Array)||(cast data.listings:Array<Dynamic>).length>50||data.nextCursor!=null)
                throw "Incomplete owned listings";
            var items:Map<String,Bool>=[],kinds:Map<String,Bool>=[];
            for(row in (cast data.listings:Array<Dynamic>)) {
                var item=G.field(G.field(row,"export"),"item");if(item==null)item=G.field(row,"item");
                items[MarketItemIdentity.key(item)]=true;kinds[G.text(G.field(item,"baseId"))]=true;
            }
            ownedItems=items;ownedKinds=kinds;ownedKnown=true;ownedFetched=haxe.Timer.stamp();loadInventory();message="";
        });
    }
    public function loadInventory():Void {
        var chosenId=chosen==null?"":chosen.uid;
        availableInventory=[];listedInventory=[];chosen=null;locations=[];inventoryIndexes=[];inventorySlots=[];
        var sources=MarketInventory.sources(inv,bankOnly);
        bankNames=MarketInventory.bankNames(inv);
        bankTab=Std.int(Math.max(0,Math.min(bankTab,bankNames.length-1)));
        inventorySource=sources.length==0?null:sources[bankOnly?bankTab:0];
        if(!ownedKnown){applyInventorySearch();return;}
        var source=inventorySource;
        if(source!=null)for(s in source.stacks())if(source.canDrop(s,1))try {
            var item=TradeInventory.describe(s.item,s.count);
            item.name=MarketText.itemName(item.kind,item.name);
            if(!locations.exists(item.uid)) {
                if(ownedKinds.exists(item.kind)&&ownedItems.exists(MarketItemIdentity.key(MarketExport.itemData(s.item,item,s.count))))listedInventory[item.uid]=true;
                availableInventory.push(item);locations[item.uid]=bankOnly?bankNames[bankTab]:"In backpack";
                inventoryIndexes[item.uid]=s.index;
                if(item.uid==chosenId)chosen=item;
            }
        }catch(_:Dynamic){}
        applyInventorySearch();
    }
    public function searchInventory():Void {if(busy)return;page=1;applyInventorySearch();}
    function applyInventorySearch():Void {
        inventory=MarketInventory.filter(availableInventory,sellSearch);
        inventorySlots=[for(_ in 0...MarketInventory.slotCount(inventorySource)) null];
        for(item in inventory)if(inventoryIndexes.exists(item.uid))inventorySlots[inventoryIndexes[item.uid]]=item;
        if(chosen!=null&&inventory.indexOf(chosen)<0)chosen=null;
        total=inventory.length;pages=page=1;view.dirty=true;
    }
    public function setBankOnly(value:Bool):Void {
        if(busy)return;
        bankOnly=value;page=1;loadInventory();
    }
    public function setBankTab(value:Int):Void {
        if(busy||value<0||value>=bankNames.length||value==bankTab)return;
        bankTab=value;chosen=null;loadInventory();
    }
    public function inventoryStack(item:TradeItem):Dynamic {
        if(inventorySource==null||!inventoryIndexes.exists(item.uid))return null;
        var stack=G.call("st.Inventory","getStack",inventorySource.inventory,[inventoryIndexes[item.uid]]);
        return G.uid(G.field(stack,"item"))==item.uid?stack:null;
    }
    public function isListed(item:TradeItem):Bool return item!=null&&listedInventory.exists(item.uid);
    public function inventoryLocation(item:TradeItem):String return locations.exists(item.uid)?locations[item.uid]:"In backpack";
    function cacheForTab():MarketPages {
        var limit=pageSize(),params=["limit="+limit];
        if(tab=="My listings")params.push("mine=true&sort="+mineSort);
        else {
            params.push("server="+server);
            var keys=[for(k in filters.keys())k];keys.sort(Reflect.compare);
            for(k in keys)if(filters[k]!="")params.push(k+"="+StringTools.urlEncode(filters[k]));
        }
        var path="/api/v1/marketplace/listings?"+params.join("&"),cache=listingCaches[tab];
        if(cache==null||cache.path!=path) {cache=new MarketPages(path,limit);listingCaches[tab]=cache;}
        return cache;
    }
    public function refresh():Void {
        if(busy)return;
        if(tab=="Sell"){refreshSell();return;}
        showListings(true);
    }
    public function goPage(value:Int):Void {
        if(busy||value<1||value>pages||value==page)return;
        rememberTab();page=value;showListings(false);
    }
    function showListings(force:Bool):Void {
        if(tab=="Browse"&&server==""){message="Reconnect to identify your game server before browsing.";view.dirty=true;return;}
        var cache=cacheForTab();activePages=cache;
        if(page>1&&cache.cursors[page-1]==null)page=1;
        cache.current=page;cache.trim();
        var target=page,cached=force?null:cache.get(target,haxe.Timer.stamp());
        if(cached!=null){displayPage(cache,target,cached);prefetchNext();return;}
        if(!force){rows=[];selected=null;total=0;}
        if(!force&&prefetch!=null&&prefetch.cache==cache&&prefetch.page==target) {
            prefetch.waiting=true;busy=true;message="Loading...";view.dirty=true;return;
        }
        cancelPrefetch();
        if(force)cache.forget(target);
        request("GET",cache.url(target),null,null,data->{
            var result=cache.put(target,data,haxe.Timer.stamp());
            displayPage(cache,target,result);prefetchNext();
        });
    }
    function displayPage(cache:MarketPages,target:Int,result:MarketPages.MarketPage):Void {
        var selectedId=G.text(G.field(selected,"id"),cache.selectedId),now=Date.now().getTime()/1000;
        rows=result.rows.filter(row->{
            var expiry=G.text(G.field(row,"expiresAt")),seller=G.field(row,"seller");
            return (expiry==""||Protocol.expiry(expiry)>now)
                &&(tab!="Browse"||filters["online"]!="true"||seller==null||Protocol.expiry(G.text(G.field(seller,"onlineUntil")))>now);
        });
        page=target;cache.current=target;cache.trim();total=rows.length;pages=page+(result.next==null?0:1);
        selected=null;
        for(row in rows)if(G.text(G.field(row,"id"))==selectedId){selected=row;break;}
        cache.selectedId=G.text(G.field(selected,"id"));
        message=total==0?"No matching listings.":"Listings updated.";view.dirty=true;
    }
    function prefetchNext():Void {
        var cache=activePages,now=haxe.Timer.stamp();
        if(busy||prefetch!=null||cache==null||tab=="Sell"||now<requestAfter
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
            if(response.status==401||response.status==403){ready=false;connectionIssue=true;}
            if(response.status==429||response.status>=500)requestAfter=now+Math.max(60,Protocol.retryAfter(response.retryAfter,Date.now().getTime()/1000));
            if(work.waiting){message="Could not load this page. Press Refresh to retry.";view.dirty=true;}
        } else if(!busy&&activePages==work.cache&&work.page<page&&work.cache.get(page,haxe.Timer.stamp())==null) {
            // A refreshed previous page can move its boundary. Reload from the new
            // cursor rather than pair stale current rows with a different next page.
            showListings(false);
        } else prefetchNext();
    }
    public function request(method:String,path:String,body:Dynamic,headers:Map<String,String>,done:Dynamic->Void):Void {
        if(busy)return;
        if(haxe.Timer.stamp()<requestAfter){message="Please wait before retrying the marketplace.";view.dirty=true;return;}
        if((method!="GET"||path.indexOf("mine=true")>=0)&&!ready){connectionIssue=true;message=MarketText.CONNECTION_ERROR;view.dirty=true;return;}
        busy=true;pending=done;pendingMethod=method;pendingPath=path;message="Loading...";view.dirty=true;
        worker.send({generation:generation,op:"request",method:method,path:path,body:body==null?null:haxe.Json.stringify(body),headers:headers});
    }
    public function list(quantity:Int,trays:Int,offers:Bool):Void {
        if(chosen==null||busy||!ownedKnown)return;
        try {
            var value=MarketExport.snapshot(inv,chosen,quantity,trays,offers,server,app,bankOnly),body=haxe.Json.stringify(value);
            if(ownedItems.exists(MarketItemIdentity.key(value.item)))throw "You already have an active listing for this item.";
            // A timed-out submission reuses its UUID and exact body; a second click cannot duplicate it.
            if(body!=expectedBody){requestId=MarketExport.uuid();expectedBody=body;}
            request("POST","/api/v1/marketplace/listings",value,["Idempotency-Key"=>requestId],data->{invalidateListings();expectedBody="";requestId="";chosen=null;tab="My listings";page=1;refresh();});
        } catch(e:Dynamic){message=Std.string(e);view.dirty=true;}
    }
    public function remove():Void {
        if(selected==null||busy)return;
        var id=G.text(G.field(selected,"id")),revision=G.integer(G.field(selected,"revision"));
        if(id==""||revision<1){message="This listing changed. Refresh before removing it.";view.dirty=true;return;}
        // Explicit conversion is required for numeric API fields on HashLink.
        request("DELETE","/api/v1/marketplace/listings/"+id,null,["If-Match"=>'"'+Std.string(revision)+'"'],data->{
            invalidateListings();selected=null;page=1;refresh();
        });
    }
    public function contact():Void {
        if(selected==null||haxe.Timer.stamp()<contactAfter)return;
        var row=selected;if(row.seller.accountId==account){message="This is your listing.";view.dirty=true;return;}
        if(row.server!=server){message="This listing is on another server.";view.dirty=true;return;}
        contactAfter=haxe.Timer.stamp()+5;
        // Recheck availability before sending one explicit, human-readable whisper.
        request("GET","/api/v1/marketplace/listings/"+row.id,null,null,current->{
            var seller=G.text(current.seller.characterName);
            message="Sending whisper...";
            trade.TradeChat.send(player,G.text(current.seller.accountId),seller,
                "Hi! I'm interested in your marketplace listing: "+TradeInventory.itemName(G.text(current.item.baseId))+" x"+MarketText.number(current.item.quantity)+
                (current.price.mode=="offers"?" (open to offers).":" for "+MarketText.price(current.price)+"."),ok->{message=ok?"Whisper sent to "+seller+". Arrange a party and meet nearby to trade.":"Could not send the whisper. The seller may be unavailable.";view.dirty=true;},true);
        });
    }
    public static function error(code:String):String return switch(code){
        case "duplicate_item":"You already have an active listing for this item.";
        case "listing_limit":"You can have up to 10 active listings. Remove a listing first.";
        case "listing_unavailable","listing_not_found":"This listing expired or was removed. Refresh the marketplace.";
        case "stale_revision":"This listing changed. Refresh before removing it.";
        case "unauthorized","insufficient_scope","sign_in_required":"Sign in with Steam to manage your listings.";
        case "invalid_export","update_mod_required":"The server could not accept this item's data. Update the mod and try again.";
        case "rate_limited","write_busy","write_in_progress":"Too many requests. Wait a minute before trying again.";
        default:"The marketplace request failed. Please retry shortly.";
    };
}
