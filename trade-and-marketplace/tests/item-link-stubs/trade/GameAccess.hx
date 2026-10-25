package trade;

class GameAccess {
    public static var ui:Dynamic;
    public static var created:Array<Dynamic> = [];
    public static function font():Dynamic return {glyphs:new Map<Int,Dynamic>(),tile:{width:256,height:256},lineHeight:20,subFonts:null};
    static function node(kind:String,parent:Dynamic):Dynamic {
        var result:Dynamic={nativeType:kind,parent:parent,children:[],x:0,y:0};
        if(parent!=null) {if(field(parent,"children")==null)parent.children=[];parent.children.push(result);}
        created.push(result);return result;
    }
    static function width(o:Dynamic,text:String):Float {
        var sum=0.0;
        for(i in 0...text.length) {var c=o.font.glyphs.get(text.charCodeAt(i));sum+=c==null?8:number(c.width);}
        return sum;
    }
    public static var alt = false;
    public static var focused = 0;
    public static var nextFrame:Array<Void->Void> = [];
    public static function runNextFrame():Void {
        var pending=nextFrame;nextFrame=[];
        for (callback in pending) callback();
    }
    public static var errors:Array<String> = [];
    public static var definitions:Map<String,Dynamic> = [];
    public static function field(o:Dynamic,k:String):Dynamic return o == null ? null : Reflect.field(o,k);
    public static function set(o:Dynamic,k:String,v:Dynamic):Void { if (o != null) Reflect.setField(o,k,v); }
    public static function text(v:Dynamic,f=""):String return v == null ? f : Std.string(v);
    public static function integer(v:Dynamic,f=0):Int return v == null ? f : Std.int(v);
    public static function number(v:Dynamic,f:Float=0):Float return v == null ? f : v;
    public static function point(x:Float,y:Float):Dynamic return {x:x,y:y};
    public static function isA(o:Dynamic,t:String):Bool {
        var kind=field(o,"nativeType");
        return kind == t || (kind == "st.item.Weapon" && (t == "st.Item" || t == "st.item.Gear"));
    }
    public static function current(t:String,n:String):Dynamic return t == "ui.BaseUI" ? ui
        : t == "Data" ? {byId:{get:(key:String)->definitions.get(n+":"+key)}} : null;
    public static function enumeration(t:String,n:String):Dynamic return n;
    public static function create(t:String,a:Array<Dynamic>):Dynamic return switch(t) {
        case "ui.comp.FmtText":
            var o=node(t,a[1]);o.text="";o.prevUnformatted=null;o.font=font();o.formatText=(v:String)->v;o.textColor=0xffffff;o;
        case "h2d.Mask":var o=node(t,a[2]);o.width=a[0];o.height=a[1];o;
        case "h2d.FontChar":{t:a[0],width:a[1]};
        case "hxbit.EnumFlagsData":{value:0};
        case "hl.types.ArrayDyn":{values:new Array<Dynamic>()};
        case "hxbit.ArrayProxyData":{array:a[0]};
        default:throw "Unexpected allocation "+t;
    };
    public static function staticCall(t:String,n:String,a:Array<Dynamic>):Dynamic return switch(n) {
        case "isDown":alt;
        case "create":{nativeType:"st.item.Weapon",kind:a[0],inf:{id:a[0]}};
        case "fromItem":{realItem:a[1]};
        default:throw "Unexpected static "+t+"."+n;
    };
    public static function call(t:String,n:String,o:Dynamic,?a:Array<Dynamic>):Dynamic return switch(n) {
        case "get":o.get(a[0]);
        case "push":o.values.push(a[0]);null;
        case "makeInf":o.inf={id:o.kind};null;
        case "preventClick":o.mouseDownButton=-1;null;
        case "get_chat":o.chat;
        case "getTextLength":Std.string(o.text).length;
        case "getTextPos", "getCursorPos":Std.int(Math.max(0,Math.min(integer(a[0]),text(o.text).length)));
        case "getInputWidth":o.interactive.width;
        case "get_textWidth":~/<[^>]*>/g.replace(text(o.text),"").length*8.0;
        case "calcTextWidth":width(o,a[0]);
        case "calcAbsPos":null;
        case "clearUndo":o.undo=[];o.redo=[];null;
        case "set_font":o.font=a[0];o.font;
        case "set_textColor", "set_useEllipsis", "set_maxWidthText", "set_textMultiline":set(o,n.substr(4),a[0]);null;
        case "clone":
            if(t=="h2d.Font") {var f=font();var old:Map<Int,Dynamic>=o.glyphs;for(k in old.keys())f.glyphs.set(k,old.get(k));f;}
            else {width:o.width,height:o.height};
        case "set":o.set(a[0],a[1]);null;
        case "remove":if(o.parent!=null)o.parent.children.remove(o);o.parent=null;null;
        case "inputText":
            if(ItemLinkDraft.insert(o,a[0]))null;else {
                var old=text(o.text),start=integer(o.cursorIndex),end=start,selection=field(o,"selectionRange");
                if(selection!=null){start=selection.start;end=start+integer(selection.length);}
                if(field(o,"undo")==null)o.undo=[];o.undo.push(old);
                call("h2d.TextInput","set_text",o,[old.substring(0,start)+a[0]+old.substring(end)]);
                o.cursorIndex=start+text(a[0]).length;o.selectionRange=null;o.changes++;null;
            }
        case "focus":
            if(t=="ui.hud.ChatBox") {
                focused++;
                nextFrame.push(()->{call("h2d.TextInput","focus",o.messageInput.input,[null]);});
            } else {
                o.focused=true;
                if(integer(o.cursorIndex)<0)o.cursorIndex=0;
            }
            null;
        case "waitNextFrame":nextFrame.push(a[0]);null;
        case "chatError":errors.push(a[0]);null;
        case "set_text":
            if(t=="h2d.TextInput") {
                var rewritten=ItemLinkDraft.rewrite(o,a[0]),value=rewritten==null?a[0]:rewritten;
                o.text=value;o.cursorIndex=Std.int(Math.min(integer(field(o,"cursorIndex")),text(value).length));
                ItemLinkDraft.changed(o);value;
            } else {
                if(o.prevUnformatted!=a[0]) {o.prevUnformatted=a[0];o.text=o.formatText(a[0]);}a[0];
            }
        case "setTip":o.currentTip={content:a[0],anchor:a[1]};o.currentTip;
        case "removeTip":o.currentTip=null;null;
        case "getScene":o.scene;
        case "getBounds":
            if(a[0]!=o)throw "Measure tooltip contents in their own unscaled coordinates";
            o.bounds;
        case "globalToLocal":{x:(number(a[0].x)-number(o.x))/number(o.scale,1),y:(number(a[0].y)-number(o.y))/number(o.scale,1)};
        case "setScale":o.scale=a[0];null;
        case "setPosition":o.x=a[0];o.y=a[1];null;
        default:throw "Unexpected call "+t+"."+n;
    };
}
