package trade;
class TradeChat {
    public static var sent:Array<{to:String, text:String}> = [];
    public static var delivered = true;
    public static function isLocalClient(c:Dynamic, p:Dynamic):Bool return true;
    public static function sender(m:Dynamic):String return m.sender;
    public static function send(p:Dynamic, to:String, name:String, text:String, cb:Bool->Void):Void {
        sent.push({to: to, text: text}); cb(delivered);
    }
}
