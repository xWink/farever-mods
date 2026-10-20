package trade;
class GameAccess {
 public static var buttons:Array<Dynamic>=[];
 public static var labels:Array<Dynamic>=[];
 public static var nodes:Array<Dynamic>=[];
 public static var dialogs=0;
 public static var textures:Array<Dynamic>=[];
 public static var removed:Array<Dynamic>=[];
 public static var maskWhitened=false;
 public static var failNextTooltip=false;
 public static var ui:Dynamic={root:{}};
 public static function object(?parent:Dynamic):Dynamic {
  var o:Dynamic={children:[],parent:parent,color:{x:1.,y:1.,z:1.}};o.dom={obj:o};
  if(parent!=null)(cast parent.children:Array<Dynamic>).push(o);return o;
 }
 public static function field(o:Dynamic,k:String):Dynamic return o==null?null:Reflect.field(o,k);
 public static function array(o:Dynamic,proxy=false):Array<Dynamic> return o==null?[]:cast o;
 public static function text(v:Dynamic,f=""):String return v==null?f:Std.string(v);
 public static function number(v:Dynamic,f:Float=0):Float return v==null?f:cast v;
 public static function integer(v:Dynamic,f=0):Int return v==null?f:Std.int(v);
 public static function set(o:Dynamic,k:String,v:Dynamic):Void {if(o!=null){if(k=="onAfterReflow"&&field(o,"text")!=null)throw "Text is not a Flow";Reflect.setField(o,k,v);}}
 public static function enumeration(t:String,n:String):Dynamic return n;
 public static function isA(o:Dynamic,t:String):Bool return field(o,"nativeType")==t;
 public static function current(t:String,n:String):Dynamic return t=="ui.BaseUI"?ui:n;
 public static function create(t:String,a:Array<Dynamic>):Dynamic {var parent=t=="h2d.Bitmap"?a[1]:t=="h2d.Object"||t=="h2d.Graphics"?a[0]:null;var o=object(parent);o.nativeType=t;if(t=="h3d.mat.Texture"){o.width=a[0];o.height=a[1];textures.push(o);}if(t=="h2d.Bitmap")o.tile=a[0];return o;}
 public static function staticCall(t:String,n:String,a:Array<Dynamic>):Dynamic return n=="isPressed"?false:n=="getVersion"?"test":n=="getGfx"?a[0]:{id:"Epic"};
 public static function call(t:String,n:String,o:Dynamic,?a:Array<Dynamic>):Dynamic {
  if(n=="set_getTip"&&failNextTooltip){failNextTooltip=false;throw "Injected native tooltip failure";}
  return switch(n){
   case "getProperties":
    var child=a[0];if(field(child,"flowProperties")==null)child.flowProperties={};child.flowProperties;
   case "calcTextWidth": Std.string(a[0]).length*8.0;
   case "getSize":
    if(field(o,"bounds")!=null)o.bounds;else {xMin:0.0,yMin:field(o,"text")==null?0.0:4.0,xMax:field(o,"text")==null?number(field(o,"width"),22):Std.string(o.text).length*8.0,yMax:field(o,"text")==null?number(field(o,"height"),22):22.0};
   case "clear": if(t=="h3d.mat.Texture")o.clearAlpha=a[1];else if(t=="h2d.Graphics")o.shapes=[];null;
   case "dispose": o.disposed=true;null;
   case "toTexture": var texture=create("h3d.mat.Texture",[512,512]);texture.sourcePng=true;texture.clearAlpha=0.0;texture;
   case "set_colorAdd": maskWhitened=true;null;
   case "getBounds": field(o,"inkBounds")==null?call(t,"getSize",o,[null]):o.inkBounds;
   case "addChild": var child=a[0];if(child.parent!=null)(cast child.parent.children:Array<Dynamic>).remove(child);child.parent=o;(cast o.children:Array<Dynamic>).push(child);null;
   case "addChildAt": var child=a[0];if(child.parent!=null)(cast child.parent.children:Array<Dynamic>).remove(child);child.parent=o;(cast o.children:Array<Dynamic>).insert(a[1],child);null;
   case "setScale": o.scaleX=a[0];o.scaleY=a[0];null;
   case "set_enableInteractive": o.enableInteractive=a[0];null;
   case "set_getTip":
    o.getTip=a[0];
    // Mirror native UIElement.makeInteractive's early return. A base Flow interactive
    // already enabled here never receives the UIElement hover handlers.
    if(field(o,"enableInteractive")!=true) {
     o.enableInteractive=true;o.interactive={};
     o.interactive.onOver=()->{if(o.showTipOnOver)o.displayedTip=o.getTip();};
    }
    null;
   case "displayDialog": dialogs++;null;
   case "setItem": o.item=a[0];null;
   case "set_scrollPosY", "set_overflow", "set_minHeight", "set_maxHeight", "set_verticalSpacing": Reflect.setField(o,n.substr(4),a[0]);null;
   case "set_options": o.options=a[0];null;
   case "initSelectedIndex": o.selectText.text=o.options[a[0]].name;null;
   case "set_text": o.text=a[0];null;
   case "set_textColor": o.textColor=a[0];null;
   case "set_verticalAlign", "set_horizontalAlign", "set_isAbsolute", "set_selected", "set_enable", "set_textAlign", "set_maxWidthText", "set_maxWidth", "set_textMultiline", "set_lineBreak", "set_useEllipsis", "set_width", "set_height", "set_visible": Reflect.setField(o,n.substr(4),a[0]);null;
   case "moveTo", "lineTo": if(field(o,"points")==null)o.points=[]; (cast o.points:Array<Dynamic>).push(a);null;
   case "get_textWidth": Std.string(o.text).length*8.0;
   case "get_textHeight": 18.0;
   case "get_numChildren": (cast o.children:Array<Dynamic>).length;
   case "slice": [];
   case "pushDyn": (cast o:Array<Dynamic>).push(a[0]);
   case "remove": removed.push(o);if(o.parent!=null)(cast o.parent.children:Array<Dynamic>).remove(o);null;
   case "isOpen": field(o,"open")==true;
   case "close": o.open=false;o.listWindow=null;null;
   case "toggle":
    if(field(o,"open")==true){o.open=false;o.listWindow=null;}
    else {
     o.open=true;if(field(ui.root,"children")==null)ui.root.children=[];
     o.listWindow=object(ui.root);o.listWindow.content=object(o.listWindow);
     o.items=[for(_ in (cast o.options:Array<Dynamic>))object(o.listWindow.content)];
    }null;
   case "set_onClick": o.action=a[0];null;
   case "getName": "Tester";
   case "getRequiredLevel": 15;
   case "getILevel": 35;
   default: null;
  };
 }
}
