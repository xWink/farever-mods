package trade;
class TradeUi {
 public static function node(c:String,p:Dynamic,args:Array<Dynamic>,id:String):Dynamic {
  var o=GameAccess.object(p.obj);o.id=id;o.items=[];o.select=GameAccess.object(o);o.selectText=GameAccess.object(o);
  o.input=GameAccess.object(o);o.inputHint=GameAccess.object(o);return o.dom;
 }
 public static function children(o:Dynamic):Array<Dynamic> return (cast o.children:Array<Dynamic>).copy();
 public static function absolute(p:Dynamic,o:Dynamic):Void{}
 public static function padding(o:Dynamic,v:Int):Void{}
 public static function size(o:Dynamic,w:Int,h:Int):Void{}
 public static function position(o:Dynamic,x:Float,y:Float):Void{}
 public static function style(o:Dynamic,p:String,v:Dynamic):Void{}
 public static function escape(s:String):String return s;
}
