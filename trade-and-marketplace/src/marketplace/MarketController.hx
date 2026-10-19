package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;
import fareverly.Protocol;
import fareverly.SessionLease;
import modconfig.CommonSettings;
import hlx.runtime.Bus;
class MarketController {
    public var player:Dynamic;
    public var inv:TradeInventory;
    public var app:Dynamic;
    public var server="";
    public var account="";
    public var message="";
    public var ready=false;
    public var busy=false;
    public var signingIn=false;
    public var view:MarketWindow;
    public var tab="Browse";
    public var rows:Array<Dynamic>=[];
    public var inventory:Array<TradeItem>=[];
    public var selected:Dynamic;
    public var chosen:TradeItem;
    public var page=1;
    public var pages=1;
    public var total=0;
    var cursors:Array<String>=[null];
    public var filters:Map<String,String>=["category"=>"","subcategory"=>"","rarity"=>"","pricing"=>"","classes"=>"","search"=>"","online"=>"false","sort"=>"price-asc"];
    final worker=new MarketWorker();
    var generation=0;
    var key="";
    var pending:(Dynamic->Void);
    var requestAfter=0.0;
    var expectedBody="";
    var requestId="";
    var contactAfter=0.0;
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
                case "request":
                    busy=false;var response=event.response,data:Dynamic=null;
                    try data=haxe.Json.parse(response.body)catch(_:Dynamic){}
                    if(response.status>=200&&response.status<300&&response.error==""&&(data!=null||response.status==204)) {
                        var done=pending;pending=null;if(done!=null)try done(data==null?{}:data)catch(_:Dynamic)message="Unsupported marketplace response. Update the mod and try again.";
                    } else {pending=null;message=error(data==null?"":G.text(G.field(data.error,"code"),G.text(data.error)));
                        if(response.status==401||response.status==403)ready=false;
                        if(response.status==429||response.status>=500)requestAfter=now+Math.max(60,Protocol.retryAfter(response.retryAfter,Date.now().getTime()/1000));}
                    view.dirty=true;
                case "ready":ready=true;message=event.message;view.dirty=true;
                case "error":ready=false;message=event.message;view.dirty=true;
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
                        message="Steam connected. Your API key is shared with other Fareverly mods.";
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
        message=!Protocol.validKey(key)?"Sign in with Steam to list items and show your online status.":"Connecting to Fareverly...";view.dirty=true;
    }
    public function disconnect():Void {
        view.close(); if(player!=null)generation=worker.session("","");
        player=null;inv=null;account="";server="";ready=false;busy=false;signingIn=false;pending=null;
        rows=[];inventory=[];selected=null;chosen=null;expectedBody="";requestId="";
        SessionLease.release(HlxRuntime.moduleName());
    }
    public function fail():Void {
        // A marketplace UI failure must not cancel an unrelated direct trade.
        view.close();message="Could not open the marketplace UI. Please report the game and mod versions.";
        trade.TradeDiagnostics.log(message);
    }
    public function open():Void {
        if(!trade.TradeMod.enabled()||player==null||inv==null)return;
        view.open(); if(tab!="Sell an item")refresh();else loadInventory();
    }
    public function signIn():Void {
        if(player==null)return;
        view.open();
        if(signingIn)return;
        if(!SessionLease.acquire(HlxRuntime.moduleName())){message="A Fareverly sign-in is already running in another mod.";view.dirty=true;return;}
        try {worker.send({generation:generation,op:"auth",entropy:MarketNative.random()});signingIn=true;message="Preparing Steam sign-in...";}
        catch(e:Dynamic){SessionLease.release(HlxRuntime.moduleName());message=Std.string(e);}
        view.dirty=true;
    }
    public function cancelSignIn():Void {reconnect();message="Sign-in cancelled.";view.dirty=true;}
    public function chooseTab(value:String):Void {if(busy)return;tab=value;page=1;selected=null;chosen=null;if(tab=="Sell an item")loadInventory();else refresh();view.dirty=true;}
    public function loadInventory():Void {
        inventory=[];chosen=null;
        if(inv!=null)for(s in inv.stacks())if(inv.canDrop(s,1))try inventory.push(TradeInventory.describe(s.item,s.count))catch(_:Dynamic){}
        total=inventory.length;pages=Std.int(Math.max(1,Math.ceil(total/12)));page=Std.int(Math.max(1,Math.min(page,pages)));view.dirty=true;
    }
    public function refresh():Void {
        if(tab=="Sell an item"){loadInventory();return;}
        var path="/api/v1/marketplace/listings";
        if(page==1)cursors=[null];
        var params=["limit=12"];
        if(tab=="My listings")params.push("mine=true");
        if(page>1&&cursors[page-1]!=null)params.push("cursor="+StringTools.urlEncode(cursors[page-1]));
        if(tab=="Browse") {
            if(server==""){message="Reconnect to identify your game server before browsing.";view.dirty=true;return;}
            params.push("server="+server);
            for(k=>v in filters)if(v!="")params.push(k+"="+StringTools.urlEncode(v));
        }
        request("GET",path+"?"+params.join("&"),null,null,data->{
            if(!Std.isOfType(data.listings,Array)||(cast data.listings:Array<Dynamic>).length>12)throw "Invalid listings";
            rows=data.listings;total=rows.length;pages=page+(data.nextCursor==null?0:1);
            cursors[page]=data.nextCursor;selected=null;message=total==0?"No matching listings.":"Listings updated.";
        });
    }
    public function request(method:String,path:String,body:Dynamic,headers:Map<String,String>,done:Dynamic->Void):Void {
        if(busy)return;
        if(haxe.Timer.stamp()<requestAfter){message="Please wait before retrying the marketplace.";view.dirty=true;return;}
        if((method!="GET"||path.indexOf("mine=true")>=0)&&!ready){message="Sign in with Steam before managing listings.";view.dirty=true;return;}
        busy=true;pending=done;message="Loading...";view.dirty=true;
        worker.send({generation:generation,op:"request",method:method,path:path,body:body==null?null:haxe.Json.stringify(body),headers:headers});
    }
    public function list(quantity:Int,trays:Int,offers:Bool):Void {
        if(chosen==null||busy)return;
        try {
            var value=MarketExport.snapshot(inv,chosen,quantity,trays,offers,server,app),body=haxe.Json.stringify(value);
            // A timed-out submission reuses its UUID and exact body; a second click cannot duplicate it.
            if(body!=expectedBody){requestId=MarketExport.uuid();expectedBody=body;}
            request("POST","/api/v1/marketplace/listings",value,["Idempotency-Key"=>requestId],data->{expectedBody="";requestId="";chosen=null;tab="My listings";page=1;refresh();});
        } catch(e:Dynamic){message=Std.string(e);view.dirty=true;}
    }
    public function changePrice(trays:Int,offers:Bool):Void {
        if(selected==null||busy)return;
        if(!offers&&(trays<1||trays>200000)){message="Choose a total price of 1 to 200,000 Silver Trays.";view.dirty=true;return;}
        var row=selected;
        // Price-only updates preserve the original item/character snapshot and expiry.
        var value:Dynamic=haxe.Json.parse(haxe.Json.stringify(Reflect.field(row,"export")));
        if(value==null){message="Refresh My listings before editing.";view.dirty=true;return;}
        value.price=offers?{mode:"offers"}:{mode:"fixed",silverTrays:trays};
        request("PUT","/api/v1/marketplace/listings/"+row.id,value,["If-Match"=>'"'+row.revision+'"'],data->refresh());
    }
    public function remove(sold:Bool):Void {
        if(selected==null||busy)return;
        var row=selected;
        request("DELETE","/api/v1/marketplace/listings/"+row.id,null,["If-Match"=>'"'+row.revision+'"'],data->refresh());
    }
    public function contact():Void {
        if(selected==null||haxe.Timer.stamp()<contactAfter)return;
        var row=selected;if(row.seller.accountId==account){message="This is your listing.";view.dirty=true;return;}
        if(row.server!=server){message="This listing is on another server.";view.dirty=true;return;}
        contactAfter=haxe.Timer.stamp()+5;
        // Recheck availability before sending one explicit, human-readable whisper.
        request("GET","/api/v1/marketplace/listings/"+row.id,null,null,current->{
            trade.TradeChat.send(player,current.seller.accountId,current.seller.characterName,
                "Hi! I'm interested in your marketplace listing: "+TradeInventory.itemName(current.item.baseId)+" x"+current.item.quantity+
                (current.price.mode=="offers"?" (open to offers).":" for "+current.price.silverTrays+" Silver Trays."),ok->{message=ok?"Whisper sent to "+current.seller.characterName+". Arrange a party and meet nearby to trade.":"Could not send the whisper. The seller may be unavailable.";view.dirty=true;});
            message="Sending whisper...";
        });
    }
    public static function error(code:String):String return switch(code){
        case "duplicate_item":"You already have an active listing for this item.";
        case "listing_limit":"You can have up to 10 active listings. Remove or complete a listing first.";
        case "listing_unavailable","listing_not_found":"This listing expired or was removed. Refresh the marketplace.";
        case "stale_revision":"This listing changed. Refresh before editing it.";
        case "unauthorized","insufficient_scope","sign_in_required":"Sign in with Steam to manage your listings.";
        case "invalid_export","update_mod_required":"The server could not accept this item's data. Update the mod and try again.";
        case "rate_limited","write_busy","write_in_progress":"Too many requests. Wait a minute before trying again.";
        default:"The marketplace request failed. Please retry shortly.";
    };
}
