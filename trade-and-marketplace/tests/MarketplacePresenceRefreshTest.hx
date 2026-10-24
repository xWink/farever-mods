import marketplace.MarketController;
import marketplace.MarketPresenceRefresh;
import marketplace.MarketWorker;
import marketplace.MarketBrowseFeed;
import trade.TradeInventory;
import fareverly.Protocol;

@:access(marketplace.MarketController)
class MarketplacePresenceRefreshTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function row(n:Int,account:String,online=true,until="2026-10-24T00:03:00.000Z",server="europe"):Dynamic return {
        id:"00000000-0000-4000-8000-"+StringTools.lpad(Std.string(n),"0",12),server:server,
        orderType:n%2==0?"buy":"sell",expiresAt:"2099-01-01T00:00:00.000Z",
        seller:{accountId:account,characterName:account,online:online,onlineUntil:until}
    };
    static function last():Dynamic return MarketWorker.current.sent[MarketWorker.current.sent.length-1];
    static function respond(c:MarketController,app:Dynamic,job:Dynamic,data:Dynamic,now:Float,status=200,retry=""):Void {
        MarketWorker.current.incoming.push({generation:job.generation,op:job.op,ticket:job.ticket,
            response:{status:status,error:status==200?"":"HTTP Error",retryAfter:retry,body:haxe.Json.stringify(data)}});
        c.update(app,now);
    }
    public static function run():Void {
        cache(); browsing(); unavailablePages(); cancellation();
        Sys.println('Marketplace presence refresh checks passed: $checks');
    }
    static function cache():Void {
        var p=new MarketPresenceRefresh(),a=row(1,"a"),b=row(2,"a"),wall=Protocol.expiry("2026-10-24T00:00:00Z");
        p.observe({listings:[a]},10);
        check(!p.due(a,69)&&p.due(a,70),"Presence becomes due after a minute, not every frame");
        check(p.deadline(b)==wall+180,"Buy and sell orders share account presence");
        p.observe(row(1,"a",true,"2026-10-24T00:06:00Z"),70);
        check(p.deadline(a)==wall+360&&!p.due(b,71),"Fresh acknowledgement extends all rows for the same account");
        p.observe(row(1,"a",false,"2026-10-24T00:06:00Z"),80);
        check(p.deadline(a)==0,"An explicit offline response overrides an unexpired timestamp");
        p.observe(row(3,"a",true,"2026-10-24T00:07:00Z","north-america"),90);
        check(p.deadline(a)==0&&p.deadline(row(3,"a",true,"","north-america"))==wall+420,
            "Presence on another region cannot make this listing online");
        p.unavailable(a,100);
        check(!p.due(a,150)&&p.due(b,150),"A cancelled listing does not hide another order from that account");
        p.completed(429,"120",100,wall);check(p.next==220,"Presence reads honor Retry-After");
        p.completed(503,"",220,wall);check(p.next==340,"Repeated failures back off");
        p.completed(200,"",340,wall);check(p.next==342,"Successful reads allow a paced fallback");
        check(p.deadline(row(9,"unknown"))==null,"Unknown players are never assumed online");
        var feed=new MarketBrowseFeed("/api/v1/marketplace/listings?limit=24");
        feed.append({listings:[a],nextCursor:"next page"},10);
        feed.append({listings:[b],nextCursor:null},20);
        check(feed.presencePath(a.id,69)==null&&feed.presencePath(a.id,70)==feed.path,"First-page presence respects its own fetch time");
        check(feed.presencePath(b.id,80)==feed.path+"&cursor=next%20page","Later-page presence uses the original cursor");
        feed.checkedPresence(feed.path,80);
        check(feed.presencePath(a.id,81)==null&&feed.next==null&&feed.rows.length==2,"Refreshing presence leaves infinite-scroll data untouched");
    }
    static function setup():{c:MarketController,app:Dynamic,now:Float} {
        trade.TradeMod.savedHideMine=false;trade.TradeMod.savedOnlineOnly=false;
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app:Dynamic={me:player};
        var c=new MarketController();c.player=player;c.inv=new TradeInventory(player);c.server="europe";c.account="self";c.ready=true;
        c.open();return {c:c,app:app,now:haxe.Timer.stamp()};
    }
    static function browsing():Void {
        var s=setup(),c=s.c,app=s.app,t=s.now,wall=Protocol.expiry("2026-10-24T00:00:00Z");
        var a=row(1,"a"),same=row(2,"a"),b=row(3,"b",false),tail=row(4,"tail");
        respond(c,app,last(),{listings:[a,same,b],nextCursor:"tail-cursor"},t);
        c.loadMore();respond(c,app,last(),{listings:[tail],nextCursor:null},t+1);
        a=c.rows[0];same=c.rows[1];b=c.rows[2];tail=c.rows[3];
        c.visibleListings([tail]);c.selected=a;c.listingScrollState().offset=240;
        var originalRows=c.rows,sent=MarketWorker.current.sent.length,originalMessage=c.message;
        c.view.dirty=false;c.update(app,t+30);
        check(MarketWorker.current.sent.length==sent,"No polling burst while fetched presence is fresh");
        c.update(app,t+61);var job=last();
        check(job.op=="presence-read"&&Std.string(job.path).indexOf("cursor=tail-cursor")>=0,
            "Only the visible later page is refreshed first");
        check(!c.busy&&!c.view.dirty&&c.rows==originalRows&&c.selected==a&&c.listingScrollState().offset==240,
            "Background reads do not rebuild the UI or reset selection/scrolling");
        c.update(app,t+62);check(MarketWorker.current.sent.length==sent+1,"Only one background read is in flight");
        respond(c,app,job,{listings:[row(4,"tail",true,"2026-10-24T00:06:00Z")],nextCursor:null},t+62);
        check(c.listingOnline(tail,wall+181),"A visible seller stays online beyond the original snapshot's deadline");
        c.visibleListings([a,same,b]);c.update(app,t+64);job=last();
        check(job.op=="presence-read"&&Std.string(job.path).indexOf("cursor=")<0,"The first page is refreshed as one batch");
        // Newly posted listings can push B out of its original batch.
        respond(c,app,job,{listings:[row(1,"a",true,"2026-10-24T00:06:00Z")],nextCursor:"new-cursor"},t+65);
        check(c.listingOnline(a,wall+181)&&c.listingOnline(same,wall+181),"One response updates both order types for a player");
        check(c.rows==originalRows&&c.rows.length==4&&c.selected==a&&c.message==originalMessage&&!c.view.dirty,
            "Background pagination changes cannot replace or reorder the displayed feed");
        c.update(app,t+67);job=last();
        check(job.path=="/api/v1/marketplace/listings/"+b.id,"A displaced visible listing falls back to its detail endpoint");
        respond(c,app,job,row(3,"b",true,"2026-10-24T00:06:00Z"),t+68);
        check(c.listingOnline(b,wall+181),"An initially offline player can become online without Refresh");
        c.update(app,t+126);job=last();
        respond(c,app,job,{listings:[row(1,"a",false),row(3,"b",true,"2026-10-24T00:07:00Z")],nextCursor:null},t+127);
        check(!c.listingOnline(a,wall+200)&&!c.listingOnline(same,wall+200),"Real offline responses update all of a player's orders");
        c.update(app,t+188);job=last();
        respond(c,app,job,{error:"unavailable"},t+189,503,"120");
        sent=MarketWorker.current.sent.length;c.update(app,t+250);
        check(MarketWorker.current.sent.length==sent&&!c.busy&&c.message==originalMessage,
            "Failures respect backoff without taking over foreground loading/errors");
        check(!c.listingOnline(b,wall+421),"An outage never extends a player's last acknowledged online deadline");
    }
    static function unavailablePages():Void {
        var s=setup(),c=s.c,app=s.app,t=s.now,a=row(1,"peer"),b=row(2,"peer");
        respond(c,app,last(),{listings:[a,b],nextCursor:null},t);a=c.rows[0];b=c.rows[1];c.visibleListings(c.rows);
        c.update(app,t+61);var job=last();
        respond(c,app,job,{error:"invalid_cursor"},t+62,400);
        c.update(app,t+64);job=last();
        check(job.path=="/api/v1/marketplace/listings/"+a.id,"Unavailable page cursors fall back to a visible listing");
        respond(c,app,job,{error:"not_found"},t+65,404);
        c.update(app,t+67);job=last();
        check(job.path=="/api/v1/marketplace/listings/"+b.id,"A cancelled order does not prevent checking another order for that player");
        respond(c,app,job,row(2,"peer",true,"2026-10-24T00:10:00Z"),t+68);
        check(c.listingOnline(b,Protocol.expiry("2026-10-24T00:08:00Z")),"A remaining order supplies fresh player presence");
    }
    static function cancellation():Void {
        var s=setup(),c=s.c,app=s.app,t=s.now,a=row(1,"peer");
        respond(c,app,last(),{listings:[a],nextCursor:null},t);a=c.rows[0];c.visibleListings([a]);
        c.update(app,t+61);var old=last(),sent=MarketWorker.current.sent.length;
        c.view.close();c.update(app,t+62);
        respond(c,app,old,{listings:[row(1,"peer",true,"2026-10-24T00:10:00Z")],nextCursor:null},t+63);
        check(MarketWorker.current.sent.length==sent&&c.presenceRead==null,"Closing Browse cancels pending presence work");
        check(c.peerPresence.deadline(a)==Protocol.expiry(a.seller.onlineUntil),"A cancelled response cannot update the old view");
        c.view.open();c.visibleListings([a]);c.update(app,t+64);old=last();
        c.filters["rarity"]="Epic";c.refresh();var foreground=last();
        check(foreground.op=="request"&&c.busy,"Foreground filter changes remain immediate");
        respond(c,app,old,{listings:[row(1,"peer",false)],nextCursor:null},t+65);
        check(c.busy&&c.peerPresence.deadline(a)>0,"Late background replies cannot replace a new query's status or request state");
        respond(c,app,foreground,{listings:[row(2,"new-peer")],nextCursor:null},t+66);
        check(c.rows.length==1&&c.rows[0].seller.accountId=="new-peer"&&!c.busy,"The requested filter response wins");
        c.visibleListings(c.rows);c.update(app,t+127);old=last();
        c.disconnect();respond(c,{me:null},old,{listings:[row(2,"new-peer",true,"2026-10-24T00:10:00Z")],nextCursor:null},t+128);
        check(c.peerPresence.deadline(row(2,"new-peer"))==null&&c.presenceRead==null,"Session changes discard stale presence acknowledgements");
    }
}
