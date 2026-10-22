package marketplace;
class MarketWindow {
    public var dirty=true;
    public var shown=false;
    public function new(controller:MarketController) {}
    public function isOpen():Bool return shown;
    public function open():Void shown=true;
    public function close():Void shown=false;
    public function recover(error:Dynamic):Void {}
    public function update():Void {}
}
