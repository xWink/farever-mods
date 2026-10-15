package dpsmeter;
import fareverly.Protocol;
typedef AccountEvent = {generation:Int, active:Bool, manualResult:Bool, message:String, code:String, account:String,
    url:String, credential:Credential, persist:Bool, expectedKey:String};
class FareverlyAccountWorker {
    public static var last:FareverlyAccountWorker;
    public final events:Array<AccountEvent> = [];
    public var cancellations = 0;
    public var generation = 0;
    public function new() last = this;
    public function settings(account:String, key:String):Void {}
    public function start(account:String, rotate:Bool, key:String):Int return ++generation;
    public function cancel():Void cancellations++;
    public function receive():Null<AccountEvent> return events.shift();
}
