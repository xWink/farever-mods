package trade;
class GameAccess {
 public static var buttons:Array<Dynamic>=[];
 public static var labels:Array<Dynamic>=[];
 public static var failNextTooltip=false;
 public static var ui:Dynamic={root:{}};
 public static function object(?parent:Dynamic):Dynamic {
  var o:Dynamic={children:[],parent:parent,color:{x:1.,y:1.,z:1.}};o.dom={obj:o};
  if(parent!=null)(cast parent.children:Array<Dynamic>).push(o);return o;
 }
 public static function field(o:Dynamic,k:String):Dynamic return o==null?null:Reflect.field(o,k);
 public static function array(o:Dynamic):Array<Dynamic> return o==null?[]:cast o;
 public static function text(v:Dynamic,f=""):String return v==null?f:Std.string(v);
 public static function integer(v:Dynamic,f=0):Int return v==null?f:Std.int(v);
 public static function set(o:Dynamic,k:String,v:Dynamic):Void {if(o!=null)Reflect.setField(o,k,v);}
 public static function current(t:String,n:String):Dynamic return ui;
 public static function create(t:String,a:Array<Dynamic>):Dynamic return object(a.length>1?a[1]:null);
 public static function staticCall(t:String,n:String,a:Array<Dynamic>):Dynamic return n=="isPressed"?false:n=="getVersion"?"test":{id:"Epic"};
 public static function call(t:String,n:String,o:Dynamic,?a:Array<Dynamic>):Dynamic {
  if(n=="set_getTip"&&failNextTooltip){failNextTooltip=false;throw "Injected native tooltip failure";}
  return switch(n){
   case "set_maxWidthText", "set_maxWidth", "set_textMultiline", "set_lineBreak", "set_useEllipsis": Reflect.setField(o,n.substr(4),a[0]);null;
   case "slice": [];
   case "pushDyn": (cast o:Array<Dynamic>).push(a[0]);
   case "remove": if(o.parent!=null)(cast o.parent.children:Array<Dynamic>).remove(o);null;
   case "isOpen": false;
   case "set_onClick": o.action=a[0];null;
   case "getName": "Tester";
   case "getRequiredLevel": 15;
   case "getILevel": 35;
   default: null;
  };
 }
}
