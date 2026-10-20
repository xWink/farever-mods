package trade;
class TradeChat {
    public static var lastText="";
    public static var lastEcho=false;
    public static function send(player:Dynamic,to:String,name:String,text:String,reply:Bool->Void,echo=false):Void {lastEcho=echo;lastText=text;reply(true);}
}
