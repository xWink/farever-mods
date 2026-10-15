package dpsmeter;

/** Analyzer navigation never inspects, submits, or retries a ranked log. */
class FareverlyOpen {
    public static inline var URL = "https://fareverly.com/analyze";
    public var message(default, null):String = "";
    public var opening(default, null):Bool = false;
    var selected = false;
    var openingUntil:Float = 0;
    public function new() {}
    public function select(id:String):Void { selected = id != ""; message = ""; }
    public function busy(now:Float):Bool return opening || now < openingUntil;
    public function begin(now:Float):String {
        if (!selected || busy(now)) return "";
        opening = true; message = ""; return URL;
    }
    public function opened(now:Float):Void { if (opening) { opening = false; openingUntil = now + 2; } }
    public function fail(message:String):Void {
        opening = false; openingUntil = 0; this.message = message;
    }
}
