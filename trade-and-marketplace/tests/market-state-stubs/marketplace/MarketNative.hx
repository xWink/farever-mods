package marketplace;
class MarketNative {
    public static var writes=0;
    public static function random():haxe.io.Bytes return haxe.io.Bytes.alloc(32);
    public static function write(path:String,contents:String):Void {writes++;sys.io.File.saveContent(path,contents);}
}
