package trade;
class TradeUi {
    public static function setText(o:Dynamic, s:String):Void o.text = s;
    public static function style(o:Dynamic, k:String, v:Dynamic):Void Reflect.setField(o, "style_" + k, v);
}
