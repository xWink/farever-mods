package trade;
import trade.GameAccess as G;
import trade.TradeUi.*;
/** Shared native Options frame, with explicitly owned layout and drag lifetime. */
class TradeFrame {
    public static var constructing = false;
    public var ui:Dynamic;
    public var window:Dynamic;
    public var root:Dynamic;
    public var body:Dynamic;
    public var container:Dynamic;
    public var header:Dynamic;
    public var title:Dynamic;
    public var closeButton:Dynamic;
    public var width:Int;
    public var height:Int;
    public var x:Null<Float>;
    public var y:Null<Float>;
    public var onMoved:Float->Float->Void;
    var dragSurface:Dynamic;
    var dragging = false;
    var startX = 0.0;
    var startY = 0.0;
    var mouseX = 0.0;
    var mouseY = 0.0;
    var nextId = 0;
    public function new(ui:Dynamic,titleText:String,width:Int,height:Int,close:Void->Void,blockInputs = true) {
        this.ui = ui; this.width = width; this.height = height;
        constructing = true;
        try window = G.create("ui.win.TitleWindow",["Options",null]) catch(e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        var flags = 0, names = ["PreventCloseOther","FreeCursor","AutoRegisterLayer","NeedLayer"];
        if (blockInputs) names = names.concat(["BlockInputs","BlockSkills"]);
        for (name in names) flags |= 1 << Type.enumIndex(G.enumeration("ui.win.WindowFlags",name));
        G.call("ui.win.BaseWindow","set_windowFlags",window,[flags]); G.call("ui.win.BaseWindow","rebuild",window);
        root = G.field(ui,"root");
        G.call("h2d.Flow","addChildAt",root,[window,G.call("h2d.Object","get_numChildren",root)]);
        G.call("ui.BaseUI","displayWindow",ui,[window,null]); absolute(root,window); padding(window,0); size(window,width,height);
        for (child in children(window)) if (G.field(child,"bgMask") != null) {
            absolute(window,child); padding(child,0); size(child,width,height); position(child,0,0);
        }
        var dom = G.field(window,"dom");
        G.set(dom,"component",G.staticCall("domkit.Component","get",["options-window",null]));
        var content = G.field(dom,"contentRoot");
        header = G.field(window,"header"); padding(header,0); absolute(window,header); size(header,width-2,52); position(header,0,0);
        title = G.field(header,"headerTitle"); setText(title,titleText); absolute(header,title); position(title,28,17);
        G.call("ui.comp.FmtText","set_maxWidthText",title,[width-98]);
        G.call("h2d.Text","set_textAlign",title,[G.enumeration("h2d.Align","Left")]);
        closeButton = G.field(header,"closeBtn"); show(closeButton,true); absolute(header,closeButton); size(closeButton,34,34); position(closeButton,width-48,11);
        G.call("ui.UIElement","set_onClick",closeButton,[close]);
        dragSurface = G.create("h2d.Interactive",[(width-65)*1.0,52.0,header,null]); absolute(header,dragSurface);
        G.set(dragSurface,"onPush",beginDrag); G.set(dragSurface,"cursor",G.enumeration("hxd.Cursor","Move"));
        var inset = graphic(window); rounded(inset,4,52,width-8,height-58,0,13679538);
        G.call("h2d.Flow","addChildAt",window,[content,G.call("h2d.Object","get_numChildren",window)]);
        padding(content,0); absolute(window,content); size(content,width-16,height-60); position(content,8,52);
        body = node("options-content",dom,[0],"tradeBody"); container = prepareBody(body);
        var object = G.field(body,"obj"), options = G.field(object,"optionsList");
        for (o in [object,options,container]) {
            padding(o,0); size(o,width-16,height-60);
            var limit = G.enumeration("h2d.FlowOverflow","Limit"); G.call("h2d.Flow","set_overflow",o,[limit]); style(o,"overflow",limit);
        }
        absolute(content,object); position(object,0,0); absolute(object,options); position(options,0,0); absolute(options,container); position(container,0,0);
        installStyles();
    }
    function installStyles():Void {
        var sheet = "";
        for (s in [{name:"accept",bg:"#527F40",fg:"#FFFFFF"},{name:"unaccept",bg:"#E8BB4D",fg:"#433523"},{name:"cancel",bg:"#B8443A",fg:"#FFFFFF"}]) {
            var selector = "button.trade-"+s.name;
            sheet += selector+" > #background { background: "+s.bg+"; }"+selector+":hover > #background { background: darken("+s.bg+", 8%); }"
                +selector+":active > #background { background: darken("+s.bg+", 15%); }"+selector+" > #btnText { color: "+s.fg+"; }";
        }
        var style = G.field(ui,"style");
        G.call("domkit.CssStyle","add",style,[G.call("domkit.CssParser","parseSheet",G.field(style,"cssParser"),[sheet,"trade-actions"])]);
    }
    public function button(text:String,x:Int,y:Int,w:Int,action:Void->Void,kind:String):Dynamic {
        var obj = G.field(node("button",G.field(container,"dom"),[text],"tradeButton"+(nextId++)),"obj");
        absolute(container,obj); padding(obj,0); size(obj,w,36); position(obj,x,y); G.call("ui.UIElement","set_onClick",obj,[action]);
        G.call("h2d.Text","set_lineBreak",G.field(obj,"btnText"),[false]); style(G.field(obj,"btnText"),"line-break",false);
        setClass(obj,kind); return obj;
    }
    public static function setClass(obj:Dynamic,kind:String):Void {
        var dom = G.field(obj,"dom");
        for (name in ["accept","unaccept","cancel"]) G.call("domkit.Properties",name == kind ? "addClass" : "removeClass",dom,["trade-"+name]);
    }
    public static function textAt(parent:Dynamic,text:String,x:Float,y:Float,w:Int,bold = false):Dynamic {
        var obj = label(G.field(parent,"dom"),text); absolute(parent,obj); position(obj,x,y);
        G.call("ui.comp.FmtText","set_maxWidthText",obj,[w]);
        if (bold) G.call("domkit.Properties","addClass",G.field(obj,"dom"),["bold-14"]);
        return obj;
    }
    public static function ink(text:Dynamic,color:Int):Void { G.call("h2d.Text","set_textColor",text,[color]); style(text,"color",color); }
    public static function graphic(parent:Dynamic):Dynamic { var g = G.create("h2d.Graphics",[parent]); absolute(parent,g); return g; }
    public static function rounded(g:Dynamic,x:Float,y:Float,w:Float,h:Float,r:Float,color:Int,alpha = 1.0):Void {
        var c:hl.Ref<Int> = color, a:hl.Ref<Float> = alpha;
        G.call("h2d.Graphics","beginFill",g,[c,a]);
        if (r > 0) G.call("h2d.Graphics","drawRoundedRect",g,[x,y,w,h,r,null]); else G.call("h2d.Graphics","drawRect",g,[x,y,w,h]);
        G.call("h2d.Graphics","endFill",g);
    }
    public function intact():Bool return window != null && G.field(window,"parent") != null && G.field(window,"removed") != true && bodyIntact(body,container);
    public function point(x:Float,y:Float,?relative:Dynamic):{x:Float,y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl")); G.set(p,"x",x); G.set(p,"y",y);
        var q = G.call("h2d.Object","globalToLocal",relative == null ? root : relative,[p]);
        return {x:G.number(G.field(q,"x")),y:G.number(G.field(q,"y"))};
    }
    public function mouse(?relative:Dynamic):{x:Float,y:Float} {
        var scene = G.field(ui,"s2d");
        return point(G.number(G.call("h2d.Scene","get_mouseX",scene)),G.number(G.call("h2d.Scene","get_mouseY",scene)),relative);
    }
    public function layout(?avoid:Dynamic):Void {
        var scene = G.field(ui,"s2d"), top = point(0,0), bottom = point(G.number(G.field(scene,"width")),G.number(G.field(scene,"height")));
        var left = top.x+16, right = bottom.x-16;
        if (avoid != null) {
            var b = G.call("h2d.Object","getBounds",avoid,[root,null]), min = G.number(G.field(b,"xMin")), max = G.number(G.field(b,"xMax"));
            if (min < max) { if (min-left >= right-max) right = Math.max(left+1,min-16); else left = Math.min(right-1,max+16); }
        }
        var scale = Math.max(0.1,Math.min(1,Math.min((right-left)/width,(bottom.y-top.y-32)/height)));
        G.call("h2d.Object","setScale",window,[scale]);
        if (dragging) {
            if (G.staticCall("hxd.Key","isDown",[0]) != true) finishDrag();
            else { var m = mouse(); x = startX+m.x-mouseX; y = startY+m.y-mouseY; }
        }
        var px = x == null ? left+(right-left-width*scale)/2 : x, py = y == null ? top.y+(bottom.y-top.y-height*scale)/2 : y;
        position(window,Math.max(top.x,Math.min(px,bottom.x-width*scale)),Math.max(top.y,Math.min(py,bottom.y-height*scale)));
    }
    function beginDrag(event:Dynamic):Void {
        if (G.integer(G.field(event,"button")) != 0) return;
        G.set(event,"propagate",false); var p = mouse(); mouseX = p.x; mouseY = p.y;
        startX = G.number(G.field(window,"x")); startY = G.number(G.field(window,"y")); dragging = true;
        G.call("h2d.Interactive","startDrag",dragSurface,[(e:Dynamic)->{
            G.set(e,"propagate",false); var kind = G.enumName(G.field(e,"kind")); if (kind == "ERelease" || kind == "EReleaseOutside") finishDrag();
        },finishDrag]);
    }
    function finishDrag():Void {
        if (!dragging) return; dragging = false; x = G.number(G.field(window,"x")); y = G.number(G.field(window,"y"));
        G.call("h2d.Interactive","stopDrag",dragSurface); if (onMoved != null) onMoved(x,y);
    }
    public function dispose():Void {
        finishDrag(); var old = window; window = null;
        if (old != null) G.call("ui.BaseUI","removeWindow",ui,[old]);
        root = body = container = header = title = closeButton = dragSurface = null;
    }
}
