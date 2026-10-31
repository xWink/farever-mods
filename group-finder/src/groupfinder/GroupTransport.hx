package groupfinder;
import fareverly.Protocol;
typedef GroupJob={generation:Int,op:String,?ticket:Int,?account:String,?server:String,?key:String,?method:String,?path:String,?body:String,?headers:Map<String,String>,?entropy:haxe.io.Bytes};
typedef GroupEvent={generation:Int,op:String,?ticket:Int,?response:Response,?message:String,?code:String,?credential:Credential,?expectedKey:String};
interface GroupTransport {
    public function session(account:String,key:String,server:String):Int;
    public function send(job:GroupJob):Void;
    public function receive():Null<GroupEvent>;
}
