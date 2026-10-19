package trade;
class TradeFrame {
 public static var active=0;
 public var ui:Dynamic;public var window:Dynamic={};public var container:Dynamic;
 public var x:Null<Float>;public var y:Null<Float>;public var onMoved:Float->Float->Void;
 public function new(ui:Dynamic,title:String,w:Int,h:Int,close:Void->Void){this.ui=ui;container=GameAccess.object();active++;}
 public function intact():Bool return true;
 public function layout():Void{}
 public function dispose():Void active--;
 public function button(s:String,x:Int,y:Int,w:Int,action:Void->Void,kind:String):Dynamic {
  var o=GameAccess.object(container);o.text=s;o.action=action;GameAccess.buttons.push(o);return o;
 }
 public static function textAt(p:Dynamic,s:String,x:Float,y:Float,w:Int,b=false):Dynamic {
  var o=GameAccess.object(p);o.text=s;o.maxWidthText=w;GameAccess.labels.push(o);return o;
 }
 public static function graphic(p:Dynamic):Dynamic return GameAccess.object(p);
 public static function rounded(g:Dynamic,x:Float,y:Float,w:Float,h:Float,r:Float,c:Int,a=1.0):Void{}
}
