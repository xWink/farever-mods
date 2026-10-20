package trade;
class TradeChat {
    public static var lastText="";
    public static function send(player:Dynamic,to:String,name:String,text:String,reply:Bool->Void):Void {lastText=text;reply(true);}
}
