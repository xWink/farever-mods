package trade;
class TradeUi {
 public static function node(c:String,p:Dynamic,args:Array<Dynamic>,id:String):Dynamic {
  var o=GameAccess.object(p.obj);o.id=id;o.items=[];o.select=GameAccess.object(o);o.selectText=GameAccess.object(o);
  o.fmtText=GameAccess.object(o);o.fmtText.text=args.length>0?Std.string(args[0]):"";
  o.arrow=GameAccess.object(o.select);o.arrow.defaultIcon="ArrowDown";o.arrow.nativeType="ui.comp.Icon";
  GameAccess.nodes.push(o);
  o.input=GameAccess.object(o);o.inputHint=GameAccess.object(o);o.iconBmp=GameAccess.object(o);return o.dom;
 }
 public static function children(o:Dynamic):Array<Dynamic> return (cast o.children:Array<Dynamic>).copy();
 public static function absolute(p:Dynamic,o:Dynamic):Void{}
 public static function padding(o:Dynamic,v:Int):Void{}
 public static function size(o:Dynamic,w:Int,h:Int):Void {o.width=w;o.height=h;}
 public static function position(o:Dynamic,x:Float,y:Float):Void {o.x=x;o.y=y;}
 public static function style(o:Dynamic,p:String,v:Dynamic):Void{}
 public static function setText(o:Dynamic,s:String):Void {o.text=s;}
 public static function escape(s:String):String return s;
}
