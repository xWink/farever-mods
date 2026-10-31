package groupfinder;
class GroupFrame {
 public static inline var BODY_COLOR=0xD0BBB2;
 public static var active=0;
 public static var latest:GroupFrame;
 public var ui:Dynamic;public var window:Dynamic={};public var container:Dynamic;public var header:Dynamic;public var title:Dynamic;
 public var x:Null<Float>;public var y:Null<Float>;public var onMoved:Float->Float->Void;
 public function new(ui:Dynamic,title:String,w:Int,h:Int,close:Void->Void){this.ui=ui;container=GameAccess.object();container.height=h-60;header=GameAccess.object();this.title=textAt(header,title,28,17,1000);this.title.textColor=0xEEDDCC;latest=this;active++;}
 public function intact():Bool return true;
 public function layout():Void {
  var live:Array<Dynamic>=[];
  function visit(o:Dynamic):Void {live.push(o);for(child in (cast o.children:Array<Dynamic>))visit(child);}
  visit(container);visit(header);
  // Mirror Flow scroll visibility based on normal-flow content. A Stack
  // parent clamps the scroll height, whereas Vertical measures the grid.
  for(o in live)if(GameAccess.field(o,"scrollBar")!=null&&GameAccess.field(o,"height")!=null) {
   var maxChild=0.0;
   for(child in (cast o.children:Array<Dynamic>))if(child!=o.scrollBar
       &&GameAccess.field(child,"flowProperties")!=null&&child.flowProperties.isAbsolute!=true)
    maxChild=Math.max(maxChild,GameAccess.number(GameAccess.field(child,"height")));
   o.contentHeight=o.layout=="Vertical"?Math.max(maxChild,GameAccess.number(o.height)):GameAccess.number(o.height);
   o.scrollBar.visible=o.contentHeight>o.height;
  }
  GameAccess.nodes=live.filter(o->GameAccess.field(o,"id")!=null);
  GameAccess.labels=live.filter(o->GameAccess.field(o,"testLabel")==true);
  GameAccess.buttons=live.filter(o->GameAccess.field(o,"testButton")==true);
  for(button in GameAccess.buttons)button.text=button.btnText.text;
 }
 public function dispose():Void active--;
 public function button(s:String,x:Int,y:Int,w:Int,action:Void->Void,kind:String):Dynamic {
  var o=GameAccess.object(container);o.text=s;o.testButton=true;o.btnText=GameAccess.object(o);o.btnText.text=s;o.action=action;o.x=x;o.y=y;o.width=w;o.height=36;o.kind=kind;GameAccess.buttons.push(o);return o;
 }
 public static function setClass(o:Dynamic,kind:String):Void {o.kind=kind;}
 public static function textAt(p:Dynamic,s:String,x:Float,y:Float,w:Int,b=false):Dynamic {
  var o=GameAccess.object(p);o.text=s;o.testLabel=true;o.maxWidthText=w;o.x=x;o.y=y;GameAccess.labels.push(o);return o;
 }
 public static function ink(o:Dynamic,color:Int):Void {o.textColor=color;}
 public static function graphic(p:Dynamic):Dynamic return GameAccess.object(p);
 public static function rounded(g:Dynamic,x:Float,y:Float,w:Float,h:Float,r:Float,c:Int,a=1.0):Void {
  if(GameAccess.field(g,"shapes")==null)g.shapes=[];
  (cast g.shapes:Array<Dynamic>).push({x:x,y:y,width:w,height:h,radius:r,color:c,alpha:a});
 }
}
