package trade;

class GameAccess {
    public static var ui:Dynamic;
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
        case "inputText":
            if(o.selectionRange!=null)throw "Existing draft selection would be overwritten";
            if(o.cursorIndex!=Std.string(o.text).length)throw "Link must append at the end";
            o.text=Std.string(o.text)+a[0];o.cursorIndex=Std.string(o.text).length;o.changes++;null;
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
            if(o.prevUnformatted!=a[0]) {o.prevUnformatted=a[0];o.text=o.formatText(a[0]);}a[0];
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
