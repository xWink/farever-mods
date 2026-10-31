package groupfinder;
/** Minimal native DOM/Flow adapter, including normal-flow versus absolute children. */
class GameAccess {
    public static var ui:Dynamic={};
    public static var nodes:Array<Dynamic>=[];
    public static var labels:Array<Dynamic>=[];
    public static var buttons:Array<Dynamic>=[];
    public static var cleaned:Array<String>=[];
    public static function object(?parent:Dynamic):Dynamic {
        var obj:Dynamic={children:[],parent:parent,x:0.,y:0.,width:0,height:0};obj.dom={obj:obj};
        if(parent!=null)(cast parent.children:Array<Dynamic>).push(obj);return obj;
    }
    public static function field(obj:Dynamic,name:String):Dynamic return obj==null?null:Reflect.field(obj,name);
    public static function set(obj:Dynamic,name:String,value:Dynamic):Void Reflect.setField(obj,name,value);
    public static function text(value:Dynamic,fallback=""):String return value==null?fallback:Std.string(value);
    public static function number(value:Dynamic,fallback:Float=0):Float return value==null?fallback:value;
    public static function integer(value:Dynamic,fallback=0):Int return value==null?fallback:Std.int(value);
    public static function array(value:Dynamic,proxy=false):Array<Dynamic> return value==null?[]:cast value;
    public static function enumeration(type:String,name:String):Dynamic return name;
    public static function current(type:String,name:String):Dynamic return type=="ui.BaseUI"?ui:"eu";
    public static function create(type:String,args:Array<Dynamic>):Dynamic return object(args[0]);
    public static function staticCall(type:String,name:String,args:Array<Dynamic>):Dynamic {
        if(name=="cleanPlayerText"){cleaned.push(args[0]);return StringTools.htmlEscape(StringTools.replace(args[0],"badword","*******"));}
        if(name!="createNew")throw type+"."+name;
        var obj=object(args[1].obj);obj.id=args[3].id;nodes.push(obj);
        if(args[0]=="text"){obj.text=args[2][0];obj.testLabel=true;labels.push(obj);}
        if(args[0]=="input-box") {obj.input=object(obj);obj.input.text="";obj.inputHint=object(obj);obj.inputHint.text="";}
        return obj.dom;
    }
    public static function call(type:String,name:String,obj:Dynamic,?args:Array<Dynamic>):Dynamic {
        if(args==null)args=[];
        return switch(name) {
            case "getProperties":
                var child=args[0];if(field(child,"flowProperties")==null)child.flowProperties={};child.flowProperties;
            case "initStyle":
                var key=args[0];if(key=="width"||key=="height")set(obj.obj,key,args[1]);null;
            case "addClass","removeClass": null;
            case "get_numChildren": (cast obj.children:Array<Dynamic>).length;
            case "getChildAt": (cast obj.children:Array<Dynamic>)[args[0]];
            case "remove": if(obj.parent!=null)(cast obj.parent.children:Array<Dynamic>).remove(obj);obj.parent=null;null;
            case "addChild":
                var child=args[0];if(child.parent!=null)(cast child.parent.children:Array<Dynamic>).remove(child);
                child.parent=obj;(cast obj.children:Array<Dynamic>).push(child);null;
            case "setPosition": obj.x=args[0];obj.y=args[1];null;
            case "get_outerHeight": obj.height;
            case "get_outerWidth": obj.width;
            case "get_leader": (cast obj.players:Array<Dynamic>)[0];
            case "get_level": obj.level;
            case "set_overflow":
                obj.overflow=args[0];
                if(args[0]=="Scroll"){obj.scrollBar=object(obj);obj.scrollBarCursor=object(obj.scrollBar);}
                null;
            case "getSize": {xMin:0.,yMin:4.,xMax:160.,yMax:22.};
            case "clear":obj.shapes=[];null;
            default:
                if(StringTools.startsWith(name,"set_")){set(obj,name.substr(4),args[0]);null;}
                else throw type+"."+name;
        };
    }
}
