package trade;
class TradeChat {
    public static var lastText="";
    public static var lastEcho=false;
    public static var sends=0;
    public static function send(player:Dynamic,to:String,name:String,text:String,reply:Bool->Void,echo=false):Void {
        sends++;lastEcho=echo;lastText=text;reply(true);
    }
    public static function echo(player:Dynamic,to:String,name:String,text:String):Void {lastEcho=true;lastText=text;}
}
