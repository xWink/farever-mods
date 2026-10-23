import moresettings.EnemyDistance;
import moresettings.GameAccess as G;

class EnemyDistanceTest {
    static var checks=0;
    static function check(value:Bool,why:String):Void {
        checks++;
        if(!value)throw why;
    }
    static function eq(value:Dynamic,expected:Dynamic,why:String):Void {
        check(value==expected,why+": expected "+Std.string(expected)+", got "+Std.string(value));
    }
    static function main():Void {
        var font:Dynamic={size:20};
        var parent:Dynamic={children:new Array<Dynamic>()};
        var arrow:Dynamic={parent:parent,visible:true,bounds:{
            xMin:98.,xMax:105.,yMin:10.,yMax:22.}};
        var foe:Dynamic={type:"ent.Foe",posx:15.,posy:20.,posz:0.};
        var widget:Dynamic={gameObject:foe,foeName:{font:font,textColor:0xF4F4E8},
            targetIndicator:arrow,active:true,removed:false,
            callbacks:new Array<Float->Void>()};
        G.hero={posx:0.,posy:0.,posz:0.};
        eq(EnemyDistance.distance(G.hero,foe),"25m","3D target distance uses the world positions");
        EnemyDistance.clear();
        EnemyDistance.enabled=false;
        EnemyDistance.attach(widget);
        eq(parent.children.length,0,"Disabled nameplate remains unchanged");
        eq(widget.callbacks.length,1,"Widget gets one native update callback");
        EnemyDistance.enabled=true;
        EnemyDistance.tick(widget,1.0);
        eq(parent.children.length,1,"One label is attached beside native arrow");
        var label:Dynamic=parent.children[0];
        eq(label.font,font,"Distance uses the same native font as foeName");
        eq(label.text,"25m","Label includes meters");
        eq(label.textColor,0xF4F4E8,"Enemy title colour preserved");
        eq(label.scaleX,0.72,"Distance font is smaller than enemy title");
        eq(label.x,108.,"Label is to the right of the down arrow");
        check(label.y>=10.&&label.y<=22.,"Distance label aligns with the arrow");
        EnemyDistance.tick(widget,1.02);
        eq(parent.children.length,1,"Repeated updates do not allocate more labels");
        foe.posx=30.;foe.posy=40.;
        EnemyDistance.tick(widget,1.2);
        eq(label.text,"50m","Distance updates as foe moves");
        G.hero.posx=30.;G.hero.posy=40.;
        EnemyDistance.tick(widget,1.4);
        eq(label.text,"0m","Player motion updates distance too");
        EnemyDistance.enabled=false;
        EnemyDistance.tick(widget,1.6);
        eq(label.visible,false,"Disabling dynamically hides the label");
        EnemyDistance.enabled=true;
        EnemyDistance.tick(widget,1.8);
        eq(label.visible,true,"Re-enabling shows the existing label");
        arrow.visible=false;
        EnemyDistance.tick(widget,2.0);
        eq(label.visible,false,"Hidden native target arrow hides its distance");
        arrow.visible=true;
        widget.active=false;
        EnemyDistance.tick(widget,2.2);
        eq(label.visible,false,"Inactive HUD widgets do not display distance");
        widget.active=true;
        EnemyDistance.tick(widget,2.4);
        eq(label.visible,true,"Returning target gets distance back");
        G.hero.posx=null;
        EnemyDistance.tick(widget,2.6);
        eq(label.visible,false,"Unknown positions fail closed, not at zero meters");
        G.hero.posx=0.;
        widget.gameObject={type:"ent.Hero",posx:3.,posy:4.,posz:0.};
        EnemyDistance.tick(widget,2.8);
        eq(label.visible,false,"Player widgets are not labelled as enemies");
        widget.gameObject=foe;
        EnemyDistance.tick(widget,3);
        eq(label.visible,true,"Enemy widget restores distance");
        EnemyDistance.forget(widget);
        eq(parent.children.length,0,"Native removal releases the decoration");
        EnemyDistance.attach(widget);
        EnemyDistance.enabled=true;
        EnemyDistance.tick(widget,4);
        eq(parent.children.length,1,"Rebuilt widget has only one label");
        EnemyDistance.clear();
        eq(parent.children.length,0,"Scene disposal removes text decorations");
        eq(EnemyDistance.distance(null,foe),"","Missing hero has no distance");
        eq(EnemyDistance.distance(G.hero,{posx:Math.NaN,posy:0.,posz:0.}),"",
            "Invalid native positions never become bogus labels");
        Sys.println("Enemy distance HUD: "+checks+" checks passed");
    }
}
