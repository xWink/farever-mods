package dpsmeter;
class FareverlyBrowser {
    public static final opened:Array<String> = [];
    public function new() {}
    public function open(url:String):Void opened.push(url);
    public function poll():Bool return true;
}
