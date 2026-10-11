package dpsmeter;

class NativeReadyCheckWindow {
    public static var views:Array<NativeReadyCheckWindow> = [];
    public var visible = false;
    public var send:String->Void;
    var state:ReadyCheck;
    public function new(config:MeterConfig.MeterSettings, state:ReadyCheck, send:String->Void) {
        this.state = state; this.send = send; views.push(this);
    }
    public function update(now:Float, hasHero:Bool):Void visible = hasHero && state.active;
    public function dispose():Void visible = false;
}
