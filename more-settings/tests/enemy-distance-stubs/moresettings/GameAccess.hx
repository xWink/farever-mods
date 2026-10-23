package moresettings;

/** Small native-display harness for enemy nameplate distance positioning. */
class GameAccess {
    public static var hero:Dynamic;
    public static function field(o:Dynamic,k:String):Dynamic
        return o==null?null:Reflect.field(o,k);
    public static function number(v:Dynamic,fallback:Float=0):Float {
        if(v==null)return fallback;
        var f=Std.parseFloat(Std.string(v));
        return Math.isFinite(f)?f:fallback;
    }
    public static function integer(v:Dynamic,fallback:Int=0):Int
        return Std.int(number(v,fallback));
    public static function isA(o:Dynamic,t:String):Bool
        return o!=null&&field(o,"type")==t;
    public static function staticCall(t:String,n:String,a:Array<Dynamic>):Dynamic
        return t=="GameApp"&&n=="getMyHero"?hero:null;
    public static function create(t:String,args:Array<Dynamic>):Dynamic {
        if(t!="h2d.Text")throw "Unexpected native constructor "+t;
        var parent:Dynamic=args[1];
        var label:Dynamic={font:args[0],parent:parent,visible:true,
            text:"",scaleX:1.,scaleY:1.,x:0.,y:0.,type:"h2d.Text"};
        var children:Array<Dynamic>=parent.children;
        children.push(label);
        return label;
    }
    public static function call(t:String,n:String,o:Dynamic,?args:Array<Dynamic>):Dynamic {
        if(args==null)args=[];
        return switch(n) {
            case "bindUpdate":
                var cb:Float->Void=args[0];
                var callbacks:Array<Float->Void>=o.callbacks;
                callbacks.push(cb);cb(0);null;
            case "set_text":o.text=args[0];null;
            case "set_textColor":o.textColor=args[0];null;
            case "set_lineBreak":o.lineBreak=args[0];null;
            case "setScale":o.scaleX=args[0];o.scaleY=args[0];null;
            case "setPosition":o.x=args[0];o.y=args[1];null;
            case "set_visible":o.visible=args[0];null;
            case "getBounds":o.bounds;
            case "get_textHeight":o.font.size*1.0;
            case "remove":
                var parent=field(o,"parent");
                if(parent!=null) {
                    var children:Array<Dynamic>=parent.children;
                    children.remove(o);
                    o.parent=null;
                }
                null;
            default:throw "Unexpected native method "+t+"."+n;
        }
    }
}
