package trade;
class TradeChat {
 public static function isLocalClient(c:Dynamic,p:Dynamic):Bool throw "Preview received protocol";
 public static function sender(m:Dynamic):String throw "Preview parsed sender";
 public static function send(p:Dynamic,to:String,name:String,t:String,cb:Bool->Void):Void throw "Preview sent whisper";
}
