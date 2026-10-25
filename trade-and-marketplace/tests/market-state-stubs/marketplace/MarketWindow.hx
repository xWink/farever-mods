package marketplace;
class MarketWindow {
    public var dirty=true;
    public var shown=false;
    public var notices:Array<String>=[];
    public var noticePending=false;
    public function new(controller:MarketController) {}
    public function isOpen():Bool return shown;
    public function open():Void shown=true;
    public function close():Void shown=false;
    public function recover(error:Dynamic):Void {}
    public function update():Void {}
    public function showFareverlyNotice(message:String,pending=false):Void {notices.push(message);noticePending=pending;}
    public function closeFareverlyNotice():Void noticePending=false;
}
