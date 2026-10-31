package groupfinder;
/** Minimal native DOM/Flow adapter, including normal-flow versus absolute children. */
class GameAccess {
    public static var ui:Dynamic={chat:{messages:{children:[]},chatClient:{}},windows:[]};
    public static var nodes:Array<Dynamic>=[];
    public static var labels:Array<Dynamic>=[];
    public static var buttons:Array<Dynamic>=[];
    public static var cleaned:Array<String>=[];
    public static var notifications:Array<Dynamic>=[];
    public static var textures:Array<Dynamic>=[];
    public static var pngLoads:Array<String>=[];
    static var units:Map<String,Dynamic>=[
        "Warrior"=>{gfx:{id:"WarriorBanner",width:320.0,height:494.0,dx:0.0,dy:0.0}},"Mage"=>{gfx:{id:"MageBanner",width:317.0,height:496.0,dx:-3.0,dy:2.0}},
        "Rogue"=>{gfx:{id:"RogueBanner",width:308.0,height:510.0,dx:0.0,dy:0.0}},"Priest"=>{gfx:{id:"PriestBanner",width:324.0,height:493.0,dx:0.0,dy:0.0}}
    ];
    public static function object(?parent:Dynamic):Dynamic {
        var obj:Dynamic={children:[],parent:parent,x:0.,y:0.,width:0,height:0,scaleX:1.,scaleY:1.};obj.dom={obj:obj,classes:[]};
        if(parent!=null)(cast parent.children:Array<Dynamic>).push(obj);return obj;
    }
    public static function field(obj:Dynamic,name:String):Dynamic return obj==null?null:Reflect.field(obj,name);
    public static function set(obj:Dynamic,name:String,value:Dynamic):Void Reflect.setField(obj,name,value);
    public static function text(value:Dynamic,fallback=""):String return value==null?fallback:Std.string(value);
    public static function number(value:Dynamic,fallback:Float=0):Float return value==null?fallback:value;
    public static function integer(value:Dynamic,fallback=0):Int return value==null?fallback:Std.int(value);
    public static function array(value:Dynamic,proxy=false):Array<Dynamic> return value==null?[]:cast value;
    public static function enumeration(type:String,name:String):Dynamic return name;
    public static function isA(obj:Dynamic,type:String):Bool return obj==ui&&type=="ui.GameUI";
    public static function current(type:String,name:String):Dynamic return type=="ui.BaseUI"?ui:type=="Data"?{byId:units}:type=="Options"?"eu":name;
    public static function create(type:String,args:Array<Dynamic>):Dynamic {
        if(type=="ui.hud.ChatBoxLine")throw "Alerts must use native chat history";
        var parent=type=="h2d.Bitmap"?args[1]:type=="h2d.Graphics"?args[0]:null;
        var obj=object(parent);obj.nativeType=type;
        if(type=="h2d.Bitmap")obj.tile=args[0];
        if(type=="h3d.mat.Texture"){obj.width=args[0];obj.height=args[1];textures.push(obj);}
        if(type=="ui.SimpleTip")obj.text=args[0];
        return obj;
    }
    public static function staticCall(type:String,name:String,args:Array<Dynamic>):Dynamic {
        if(name=="cleanPlayerText"){cleaned.push(args[0]);return StringTools.htmlEscape(StringTools.replace(args[0],"badword","*******"));}
        if(name=="toTile")return args[0];
        if(name=="fromBytes")return {resourceName:args[0]};
        if(name=="fromTexture")return {texture:args[0]};
        if(name!="createNew")throw type+"."+name;
        var obj=object(args[1].obj);obj.id=args[3].id;nodes.push(obj);
        if(args[0]=="text"){obj.text=args[2][0];obj.testLabel=true;labels.push(obj);}
        if(args[0]=="input-box") {obj.input=object(obj);obj.input.text="";obj.inputHint=object(obj);obj.inputHint.text="";}
        if(args[0]=="icon"){obj.icon=args[2][0];obj.bmp=object(obj);}
        return obj.dom;
    }
    public static function call(type:String,name:String,obj:Dynamic,?args:Array<Dynamic>):Dynamic {
        if(args==null)args=[];
        return switch(name) {
            case "get": (cast obj:Map<String,Dynamic>).get(args[0]);
            case "get_chat":obj.chat;
            case "localReceiveMessage":
                if(obj!=ui.chat.chatClient)throw "Not the local chat client";
                var message=args[0];message.localStamp=haxe.Timer.stamp();notifications.push(message);null;
            case "slice": [];
            case "pushDyn": (cast obj:Array<Dynamic>).push(args[0]);
            case "toTexture":
                pngLoads.push(obj.resourceName);
                var pixels=obj.resourceName=="supporter-diamond.png"?1254:176;
                var texture=create("h3d.mat.Texture",[pixels,pixels]);texture.resourceName=obj.resourceName;texture;
            case "scaleToSize":obj.width=args[0];obj.height=args[1];null;
            case "drawTo":args[0].resourceName=obj.tile.texture.resourceName;args[0].sourceTexture=obj.tile.texture;null;
            case "preventAutoDispose":obj.retained=true;null;
            case "dispose":obj.disposed=true;null;
            case "setScale":obj.scaleX=args[0];obj.scaleY=args[0];null;
            case "set_enableInteractive":obj.enableInteractive=args[0];obj.interactive=object(obj);null;
            case "setTip":obj.currentTip={content:args[0],anchor:args[1]};obj.currentTip;
            case "removeTip":obj.currentTip=null;null;
            case "updateScale":obj.scaleX=number(field(obj,"nativeScale"),1);obj.scaleY=obj.scaleX;obj.needUpdateScale=false;null;
            case "getBounds":
                if(field(obj,"inkBounds")!=null)obj.inkBounds;else
                if(field(obj,"nativeType")=="h2d.Bitmap")
                    {xMin:obj.x-number(field(args[0],"x")),yMin:obj.y-number(field(args[0],"y")),xMax:obj.x+obj.tile.width-number(field(args[0],"x")),yMax:obj.y+obj.tile.height-number(field(args[0],"y"))};
                else {xMin:0.,yMin:4.,xMax:Math.min(text(obj.text).length*8.,number(field(obj,"maxWidthText"),1000)),yMax:22.};
            case "getProperties":
                var child=args[0];if(field(child,"flowProperties")==null)child.flowProperties={};child.flowProperties;
            case "initStyle":
                var key=args[0];if(key=="width"||key=="height")set(obj.obj,key,args[1]);null;
            case "addClass":(cast obj.classes:Array<String>).push(args[0]);null;
            case "removeClass":(cast obj.classes:Array<String>).remove(args[0]);null;
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
