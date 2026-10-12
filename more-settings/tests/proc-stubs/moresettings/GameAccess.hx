package moresettings;

/** Strict fake of the native display tree and audited APIs used by proc alerts. */
class GameAccess {
    public static var hud:Dynamic;
    public static var hero:Dynamic;
    public static var created:Array<Dynamic> = [];
    public static var tileLoads = 0;
    public static var highlightCalls = 0;
    public static var skillRefs:Map<String, Dynamic> = [];
    public static function field(o:Dynamic, key:String):Dynamic return o == null ? null : Reflect.field(o, key);
    public static function set(o:Dynamic, key:String, value:Dynamic):Void Reflect.setField(o, key, value);
    public static function text(o:Dynamic):String return o == null ? "" : Std.string(o);
    public static function number(o:Dynamic):Float return o == null ? 0 : o;
    public static function integer(o:Dynamic):Int return Std.int(number(o));
    public static function isA(o:Dynamic, type:String):Bool return o != null && o.nativeType == type;
    public static function array(o:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) o = field(o, "array");
        return o == null ? [] : o;
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "h3d.MatrixImpl") return {};
        if (type == "h2d.filter.ColorMatrix") return {nativeType:type, matrix:args[0]};
        if (type == "h2d.col.PointImpl") return {x:args[0], y:args[1]};
        if (type == "h2d.filter.Glow") return {nativeType:type};
        if (type == "h2d.filter.Outline") return {nativeType:type};
        if (type == "h2d.filter.Group") return {nativeType:type, filters:[]};
        if (["h2d.Object", "h2d.Bitmap", "h2d.Graphics", "h2d.Text"].indexOf(type) < 0) throw 'Unexpected create $type';
        var parent:Dynamic = args[type == "h2d.Bitmap" || type == "h2d.Text" ? 1 : 0];
        var node:Dynamic = {nativeType:type, parent:parent, children:[], visible:true, x:0.0, y:0.0, scaleX:1.0, alpha:1.0};
        if (type == "h2d.Bitmap") node.tile = args[0];
        if (type == "h2d.Text") { node.font = args[0]; node.text = ""; }
        if (parent != null) (cast parent.children:Array<Dynamic>).push(node);
        created.push(node);
        return node;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        return switch (type + "." + name) {
            case "ui.GameUI.getHud": hud;
            case "GameApp.getMyHero": hero;
            case "HSkill.getSkillRef": skillRefs[args[0]];
            case "ui.BaseUI.getTile": tileLoads++; args[0].tile;
            case "hxd.res.DefaultFont.get": {size:16.0};
            default: throw 'Unexpected static call $type.$name';
        }
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        switch (type + "." + name) {
            case "h3d.MatrixImpl.identity":
            case "h3d.MatrixImpl.colorSaturate": object.saturation = args[0];
            case "h3d.MatrixImpl.colorContrast": object.contrast = args[0];
            case "ent.GameObject.isDead": return object.dead == true;
            case "ui.Hud.canShowHeroBar": return object.allowHeroBar == true;
            case "st.skill.Skill.shouldHighlight":
                highlightCalls++;
                if (object.fail == true) throw "unavailable skill script";
                return object.proc == true;
            case "st.State.get_time": return object.time;
            case "st.skill.Status.canElapsedStop": return object.duration > 0 && object.persistent != true;
            case "st.skill.BaseSkill.getDurationLeft": return object.remaining;
            case "script.SkillScript.getInflictedStatuses": return object.marks;
            case "h2d.Flow.getProperties":
                if (args[0].parent != object) throw "Flow child is not attached";
                args[0].layout = {};
                return args[0].layout;
            case "h2d.Object.getChildIndex": return (cast object.children:Array<Dynamic>).indexOf(args[0]);
            case "h2d.Object.getChildAt": return object.children[args[0]];
            case "h2d.Object.get_numChildren": return object.children.length;
            case "h2d.Object.getBounds": return object.bounds;
            case "h2d.Flow.addChildAt":
                var child = args[0];
                if (child.parent != null) (cast child.parent.children:Array<Dynamic>).remove(child);
                var decorations = (object.background == null ? 0 : 1) + (object.interactive == null ? 0 : 1);
                (cast object.children:Array<Dynamic>).insert(args[1] + decorations, child);
                child.parent = object;
            case "h2d.Object.globalToLocal":
                return {x:(args[0].x - number(object.offsetX)) / object.uiScale,
                    y:(args[0].y - number(object.offsetY)) / object.uiScale};
            case "h2d.Object.setPosition": object.x = args[0]; object.y = args[1];
            case "h2d.Object.setScale": object.scaleX = args[0]; object.scaleY = args[0];
            case "h2d.Object.set_visible": object.visible = args[0];
            case "h2d.Object.set_filter":
                object.filter = args[0];
                BuffStackOutlines.afterFilter(object);
            case "h2d.Object.remove":
                if (object.parent != null) (cast object.parent.children:Array<Dynamic>).remove(object);
                object.parent = null;
            case "h2d.Tile.clone": return Reflect.copy(object);
            case "h2d.Tile.scaleToSize": object.width = args[0]; object.height = args[1];
            case "h2d.filter.Blur.set_radius": object.radius = args[0];
            case "h2d.filter.Blur.set_gain": object.gain = args[0];
            case "h2d.filter.Outline.set_size": object.size = args[0];
            case "h2d.filter.Outline.set_quality": object.quality = args[0];
            case "h2d.filter.Outline.set_color": object.color = args[0];
            case "h2d.filter.Group.add": (cast object.filters:Array<Dynamic>).push(args[0]);
            case "h2d.Text.set_textColor": object.textColor = args[0];
            case "h2d.Text.set_lineBreak": object.lineBreak = args[0];
            case "h2d.Text.set_text": object.text = args[0];
            case "h2d.Text.get_textWidth": return object.text.length * 8.0;
            case "h2d.Text.get_textHeight": return 16.0;
            case "h2d.Graphics.beginFill": object.fill = args[0]; object.fillAlpha = args[1]; object.path = [];
            case "h2d.Graphics.drawRect":
                if (object.fill == null) throw "Border rectangle has no fill";
                if (object.rectangles == null) object.rectangles = [];
                (cast object.rectangles:Array<Dynamic>).push({x:args[0], y:args[1], w:args[2], h:args[3], color:object.fill, alpha:object.fillAlpha});
            case "h2d.Graphics.moveTo", "h2d.Graphics.lineTo":
                if (object.points == null) object.points = [];
                (cast object.points:Array<Dynamic>).push({x:args[0], y:args[1]});
                (cast object.path:Array<Dynamic>).push({x:args[0], y:args[1]});
            case "h2d.Graphics.endFill":
                if (object.polygons == null) object.polygons = [];
                if (object.path.length > 0) (cast object.polygons:Array<Dynamic>).push(object.path);
            case "h2d.Graphics.drawRoundedRect":
            default: throw 'Unexpected call $type.$name';
        }
        return null;
    }
}
