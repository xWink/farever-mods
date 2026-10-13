package itemutilities;

class InspectUi {
    public static function escape(text:String):String
        return StringTools.replace(StringTools.replace(StringTools.htmlEscape(text), "[", "&#91;"), "$", "&#36;");
    public static function node(kind:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var object = InspectAccess.object(kind,parent.obj);
        object.id=id;
        // The game sizes this child independently of the dropdown wrapper.
        if (kind == "dropdown") {
            object.select=InspectAccess.object("element",object);
            object.select.width=300; object.select.height=42;
            object.select.background={shader:{backgroundColor:{value:0xFFF5E4DC}},color:{value:0xFFFFFFFF}};
            for (child in ["selected-icon", "selected-text", "dropdown-arrow"])
                InspectAccess.object(child,object.select);
            object.selectText=object.select.children[1];
        }
        // Native buttons use a shader color; the tile alone does not color it.
        if (kind == "button") object.background={shader:{backgroundColor:{value:0xFFB2988C}},color:{value:0xFFFFFFFF}};
        return object.dom;
    }
    public static function absolute(parent:Dynamic, object:Dynamic):Void object.absolute=true;
    public static function position(object:Dynamic, x:Float, y:Float):Void { object.x=x; object.y=y; }
    public static function padding(object:Dynamic, value:Int):Void object.padding=value;
    public static function style(object:Dynamic, property:String, value:Dynamic):Void {
        if (object.styles == null) object.styles={};
        Reflect.setField(object.styles,property,value);
    }
    public static function size(object:Dynamic, w:Int, h:Int):Void { object.width=w; object.height=h; }
}
