package dpsmeter;
import fareverly.Protocol;
typedef AccountEvent = {generation:Int, active:Bool, manualResult:Bool, message:String, code:String, account:String,
    url:String, credential:Credential, persist:Bool, expectedKey:String};
class FareverlyAccountWorker {
    public static var last:FareverlyAccountWorker;
    public final events:Array<AccountEvent> = [];
    public final settingsCalls:Array<{account:String, key:String, notifySuccess:Bool}> = [];
    public var cancellations = 0;
    public var generation = 0;
    public function new() last = this;
    public function settings(account:String, key:String, notifySuccess:Bool = false):Void
        settingsCalls.push({account:account, key:key, notifySuccess:notifySuccess});
    public function start(account:String, rotate:Bool, key:String):Int return ++generation;
    public function cancel():Void cancellations++;
    public function receive():Null<AccountEvent> return events.shift();
}
