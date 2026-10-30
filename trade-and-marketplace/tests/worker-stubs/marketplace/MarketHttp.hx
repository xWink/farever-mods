package marketplace;
import fareverly.Protocol;
import haxe.io.Bytes;
import sys.thread.Deque;
import sys.thread.Lock;

/** In-memory transport; the production worker and its auth/heartbeat scheduling run unchanged. */
class MarketHttp {
    public static final calls=new Deque<{method:String,url:String,body:String,token:String}>();
    public static var response:Response={status:200,body:'{"online":true}',error:"",retryAfter:""};
    public static var holdPresence:Lock;
    final progress:Void->Void;
    public function new(progress:Void->Void)this.progress=progress;
    public function authenticated(method:String,url:String,body:Bytes,token:String,?headers:Map<String,String>):Response {
        progress();
        calls.add({method:method,url:url,body:body==null?null:body.toString(),token:token});
        if(url==Protocol.ORIGIN+"/api/v1/account")return {status:200,error:"",retryAfter:"",body:'{"account_id":"sender","scopes":["marketplace:write","marketplace:presence"]}'};
        if(url==Protocol.ORIGIN+"/api/v1/marketplace/heartbeat")return {status:200,error:"",retryAfter:"",body:'{"server":"europe","onlineUntil":"2099-01-01T00:00:00.000Z"}'};
        if(url.indexOf("/api/v1/marketplace/presence?")>=0) {
            var hold=holdPresence;holdPresence=null;
            if(hold!=null&&!hold.wait(5))throw "Test did not release the presence request";
            return response;
        }
        throw "Unexpected test HTTP endpoint";
    }
}
