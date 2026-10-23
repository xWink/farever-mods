package moresettings;

import moresettings.GameAccess as G;

private typedef EnemyDistanceView = {
    var arrow:Dynamic;
    var label:Dynamic;
    var lastText:String;
    var nextUpdate:Float;
    var broken:Bool;
}

/** Adds a small label beside the native FoeWidget target chevron.

    We reuse FoeWidget.foeName.font and targetIndicator's actual bounds,
    rather than cloning its name or changing native DOMKit layout. The only
    game objects created here are detached client-side text decorations. */
class EnemyDistance {
    public static var enabled:Bool = false;
    static var views=new haxe.ds.ObjectMap<Dynamic,EnemyDistanceView>();
    static var warned=false;
    static inline var FONT_SCALE:Float=0.72;
    static inline var UPDATE_SECONDS:Float=0.15;

    public static function distance(hero:Dynamic, foe:Dynamic):String {
        if(hero==null||foe==null)return "";
        for(axis in ["posx","posy","posz"])
            if(G.field(hero,axis)==null||G.field(foe,axis)==null)return "";
        var dx=G.number(G.field(hero,"posx"),Math.NaN)-G.number(G.field(foe,"posx"),Math.NaN);
        var dy=G.number(G.field(hero,"posy"),Math.NaN)-G.number(G.field(foe,"posy"),Math.NaN);
        var dz=G.number(G.field(hero,"posz"),Math.NaN)-G.number(G.field(foe,"posz"),Math.NaN);
        var meters=Math.sqrt(dx*dx+dy*dy+dz*dz);
        return Math.isFinite(meters)?Std.string(Std.int(Math.round(Math.max(0,meters))))+"m":"";
    }

    public static function attach(widget:Dynamic):Void {
        if(widget==null)return;
        var old=views.get(widget);
        if(old!=null)drop(old);
        var entry:EnemyDistanceView={arrow:null,label:null,lastText:"",nextUpdate:-1,broken:false};
        views.set(widget,entry);
        // This native callback runs with the existing FoeWidget HUD lifecycle.
        // Binding even while disabled allows toggling the setting live.
        G.call("ui.UIElement","bindUpdate",widget,[(_:Float)->{
            if(views.get(widget)==entry && !entry.broken)
                try tick(widget,haxe.Timer.stamp()) catch(e:Dynamic) {
                    entry.broken=true;drop(entry);report(e);
                }
        }]);
    }
    public static function tick(widget:Dynamic,now:Float):Void {
        var view=views.get(widget);
        if(view==null||view.broken)return;
        if(!enabled||G.field(widget,"removed")==true||G.field(widget,"active")==false) {
            hide(view);return;
        }
        var foe=G.field(widget,"gameObject");
        var hero=G.staticCall("GameApp","getMyHero",[]);
        var arrow=G.field(widget,"targetIndicator");
        var foeName=G.field(widget,"foeName");
        if(!G.isA(foe,"ent.Foe")||hero==null||hero==foe
            ||arrow==null||G.field(arrow,"visible")==false||foeName==null) {
            hide(view);return;
        }
        var parent=G.field(arrow,"parent"),font=G.field(foeName,"font");
        if(parent==null||font==null){hide(view);return;}
        if(view.label==null||view.arrow!=arrow||G.field(view.label,"parent")!=parent) {
            drop(view);
            var label=G.create("h2d.Text",[font,parent]);
            if(label==null)return;
            G.call("h2d.Text","set_lineBreak",label,[false]);
            G.call("h2d.Text","set_textColor",label,
                [G.integer(G.field(foeName,"textColor"),0xFFFFFF)]);
            G.call("h2d.Object","setScale",label,[FONT_SCALE]);
            view.arrow=arrow;view.label=label;view.lastText="";view.nextUpdate=-1;
        }
        if(!Math.isFinite(now))return;
        if(view.nextUpdate>=0&&now<view.nextUpdate&&now>=view.nextUpdate-UPDATE_SECONDS)
            return;
        view.nextUpdate=now+UPDATE_SECONDS;
        var value=distance(hero,foe);
        if(value==""){hide(view);return;}
        if(value!=view.lastText) {
            G.call("h2d.Text","set_text",view.label,[value]);
            view.lastText=value;
        }
        // Position in the chevron's parent coordinates, following native HUD
        // scaling and the target indicator's actual animated location.
        var bounds=G.call("h2d.Object","getBounds",arrow,[parent,null]);
        var x=G.number(G.field(bounds,"xMax"),Math.NaN);
        var top=G.number(G.field(bounds,"yMin"),Math.NaN);
        var bottom=G.number(G.field(bounds,"yMax"),Math.NaN);
        if(!Math.isFinite(x)||!Math.isFinite(top)||!Math.isFinite(bottom)){hide(view);return;}
        var textHeight=G.number(G.call("h2d.Text","get_textHeight",view.label),0)*FONT_SCALE;
        G.call("h2d.Object","setPosition",view.label,[x+3.0,(top+bottom-textHeight)/2]);
        if(G.field(view.label,"visible")!=true)
            G.call("h2d.Object","set_visible",view.label,[true]);
    }
    static function hide(entry:EnemyDistanceView):Void {
        if(entry.label!=null&&G.field(entry.label,"visible")==true)
            G.call("h2d.Object","set_visible",entry.label,[false]);
    }
    static function drop(entry:EnemyDistanceView):Void {
        if(entry.label!=null)try G.call("h2d.Object","remove",entry.label)catch(_:Dynamic){}
        entry.label=null;entry.arrow=null;entry.lastText="";entry.nextUpdate=-1;
    }
    public static function forget(widget:Dynamic):Void {
        if(widget==null)return;
        var entry=views.get(widget);
        if(entry==null)return;
        drop(entry);views.remove(widget);
    }
    public static function clear():Void {
        for(entry in views)drop(entry);
        views=new haxe.ds.ObjectMap();warned=false;
    }
    public static function report(error:Dynamic):Void {
        if(!warned){
            warned=true;
            trace("[More Settings] Enemy distance label unavailable: "+Std.string(error));
        }
    }
}
