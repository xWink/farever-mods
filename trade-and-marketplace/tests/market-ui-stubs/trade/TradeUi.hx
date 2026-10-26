package trade;
class TradeUi {
 public static function node(c:String,p:Dynamic,args:Array<Dynamic>,id:String,?layout:String):Dynamic {
  var o=GameAccess.object(p.obj);o.id=id;o.component=c;o.items=[];
  if(layout!=null)o.layout=layout=="vertical"?"Vertical":layout;o.select=GameAccess.object(o);o.selectText=GameAccess.object(o.select);
  o.selectText.bounds={xMin:0.,yMin:0.,xMax:100.,yMax:24.};
  o.selectText.inkBounds={xMin:1.,yMin:8.,xMax:101.,yMax:22.};
  o.fmtText=GameAccess.object(o);o.fmtText.text=args.length>0?Std.string(args[0]):"";
  o.arrow=GameAccess.object(o.select);o.arrow.defaultIcon="ArrowDown";o.arrow.nativeType="ui.comp.Icon";
  if(c=="item-button"){o.stack=args[0];o.item=args[0].item;}
  if(c=="item-slot") {
   o.stack=args[0];o.inf=args[1];o.innerSlot=GameAccess.object(o);
   o.innerSlot.nativeRarity=args[1]==null?null:GameAccess.staticCall("HItem","getRarity",[args[1]]).id;
   o.item=o.stack==null?null:o.stack.item;
   if(o.item!=null){var mask=GameAccess.object(o.innerSlot);o.button=GameAccess.object(mask);o.button.item=o.item;
    o.button.countTxt=GameAccess.object(o.button);o.button.countTxt.text=Std.string(o.stack.count);
   }
  }
  GameAccess.nodes.push(o);
  o.input=GameAccess.object(o);o.inputHint=GameAccess.object(o);o.iconBmp=GameAccess.object(o);return o.dom;
 }
 public static function children(o:Dynamic):Array<Dynamic> return (cast o.children:Array<Dynamic>).copy();
 public static function absolute(p:Dynamic,o:Dynamic):Void {
  if(GameAccess.field(o,"flowProperties")==null)o.flowProperties={};o.flowProperties.isAbsolute=true;
 }
 public static function padding(o:Dynamic,v:Int):Void{}
 public static function size(o:Dynamic,w:Int,h:Int=-1):Void {o.width=w;if(h>=0)o.height=h;}
 public static function position(o:Dynamic,x:Float,y:Float):Void {o.x=x;o.y=y;}
 public static function style(o:Dynamic,p:String,v:Dynamic):Void{}
 public static function setText(o:Dynamic,s:String):Void {o.text=s;}
 public static function escape(s:String):String
  return s==null?"":StringTools.replace(StringTools.replace(StringTools.htmlEscape(s),"[","&#91;"),"$","&#36;");
}
