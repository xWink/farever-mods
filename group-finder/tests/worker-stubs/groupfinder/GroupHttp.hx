package groupfinder;
import fareverly.Protocol;
import haxe.io.Bytes;
import sys.thread.Deque;
import sys.thread.Lock;
/** Exercises the real worker without network access or platform TLS libraries. */
class GroupHttp {
    public static final calls=new Deque<{method:String,url:String,body:String,token:String,headers:Map<String,String>}>();
    public static var holdCreate:Lock;
    public static var scopes=["groups:read","groups:write","marketplace:presence"];
    public static var heartbeatStatus=429;
    public static var createResponse:Response={status:201,body:'{"id":"00000000-0000-4000-8000-000000000001","revision":1,"closed":false}',error:"",retryAfter:""};
    public function new(progress:Void->Void) {}
    public function authenticated(method:String,url:String,body:Bytes,token:String,?headers:Map<String,String>):Response {
        calls.add({method:method,url:url,body:body==null?null:body.toString(),token:token,headers:headers});
        if(StringTools.endsWith(url,"/account"))return {status:200,body:haxe.Json.stringify({account_id:"self",scopes:scopes}),error:"",retryAfter:""};
        if(StringTools.endsWith(url,"/heartbeat"))return {status:heartbeatStatus,body:'{"error":"heartbeat_too_soon"}',error:"",retryAfter:"60"};
        if(method=="POST"&&StringTools.endsWith(url,"/listings")) {
            var hold=holdCreate;holdCreate=null;if(hold!=null&&!hold.wait(5))throw "Test did not release create";return createResponse;
        }
        if(method=="DELETE")return {status:204,body:"",error:"",retryAfter:""};
        return {status:200,body:'{"listings":[],"nextCursor":null}',error:"",retryAfter:""};
    }
}
