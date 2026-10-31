import marketplace.MarketTradePresence;
import marketplace.MarketEndpoints;
import fareverly.Protocol;

class MarketTradePresenceTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {checks++;if(!value)throw why;}
    static function response(status:Int,body:String,error="",retryAfter=""):Response
        return {status:status,body:body,error:error,retryAfter:retryAfter};
    public static function run():Void {
        var path=MarketTradePresence.path("Farever:Ab_C-1","north-america");
        check(path=="/api/v1/marketplace/presence?accountId=Farever%3AAb_C-1&server=north-america","Target ID is encoded without changing case");
        check(MarketEndpoints.validUrl(Protocol.ORIGIN+path)&&MarketEndpoints.requiresKey("GET",path),"Presence GET is allowlisted and requires authentication");
        check(!MarketEndpoints.requiresKey("GET","/api/v1/marketplace/listings?server=europe")&&MarketEndpoints.requiresKey("GET","/api/v1/marketplace/listings?mine=true"),"Public listing reads and authenticated own-listing reads retain their policies");
        for(id in [null,"","has space","abc&server=asia","é",StringTools.rpad("x","x",129)])
            check(MarketTradePresence.path(id,"europe")==null,"Invalid account cannot enter the query");
        for(server in ["","any","local"])check(MarketTradePresence.path("peer",server)==null,"A known connected region is mandatory");
        var policy=new MarketTradePresence();
        check(policy.completed(response(200,'{"online":true}'),0,0).online,"Only actual true authorizes a trade");
        check(policy.completed(response(200,'{"online":true,"busy":true}'),0,0).online,"Busy players still count as online for trade presence");
        check(policy.next==0&&policy.unavailable(0)=="","Online results are not cached or rate-limited locally");
        var offline=policy.completed(response(200,'{"online":false}'),0,0);
        check(!offline.online&&offline.message==MarketTradePresence.OFFLINE,"Offline uses the requested explanation");
        for(body in ["broken","{}","null","[]",'{"online":"true"}','{"online":1}','{"online":null}'])
            check(!new MarketTradePresence().completed(response(200,body),0,0).online,"Malformed success cannot authorize a whisper");
        for(status in [0,201,204,400,401,403,429,500,503])
            check(!new MarketTradePresence().completed(response(status,'{"online":true}'),0,0).online,"HTTP status "+status+" cannot authorize a whisper");
        check(!new MarketTradePresence().completed(response(200,'{"online":true}',"read failed"),0,0).online,"Transport failures remain failures despite a partial success body");
        policy.completed(response(429,"", "HTTP 429","37"),100,0);
        check(policy.unavailable(136)!=""&&policy.unavailable(137)=="","Rate-limit cooldown honors Retry-After across recipients");
        policy.completed(response(503,"", "HTTP 503","120"),200,0);
        check(policy.next==320,"Unavailable storage honors its retry delay");
        policy=new MarketTradePresence();policy.completed(response(429,"","","1"),10,0);
        check(policy.next==11,"Concurrency limits can be retried after the supplied one second");
        for(status in [401,403]) {
            policy=new MarketTradePresence();policy.completed(response(status,""),0,0);
            check(policy.blocked&&policy.unavailable(10000)==MarketTradePresence.LOGIN,"Authentication failure blocks retries until verification succeeds");
        }
        Sys.println('Trade presence API policy checks passed: $checks');
    }
}
