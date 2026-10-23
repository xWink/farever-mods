package moresettings;

import moresettings.GameAccess as G;

/** Suppress redundant Bomblet cosmetics only; preserve native area hits. */
class BombletEffects {
    public static var enabled:Bool = false;
    static var failed = false;
    static var warned = false;
    static var travelWarned = false;
    static var travelRate = new VisualRateLimit(0.01);
    static var explosionRate = new VisualRateLimit(0.01);
    static var amount:Int = 100;
    public static function configure(performance:Bool, value:Int):Void {
        var next=Std.int(Math.max(0,Math.min(100,value)));
        var shouldLimit=performance && next<100;
        if(amount==next && enabled==shouldLimit)return;
        reset();
        amount=next;
        var interval=1.0/Math.max(1,next);
        travelRate=new VisualRateLimit(interval);
        explosionRate=new VisualRateLimit(interval);
        enabled=shouldLimit;
    }
    public static function reset():Void {
        failed=false;warned=false;travelWarned=false;
        travelRate.reset();explosionRate.reset();
    }
    static function isClient(state:Dynamic):Bool
        return G.call("st.BaseState","get_isServer",state) == false;
    public static function suppress(area:Dynamic):Bool {
        if (!enabled || failed || area == null) return false;
        try {
            var skill=G.field(area,"baseSkill");
            var id=G.text(G.field(G.field(skill,"inf"),"id"));
            if (id!="Infusion_Kobold_DPS") return false;
            var step=G.text(G.call("st.skill.SkillArea","get_stepKind",area));
            if (!BombletEffectPolicy.explosion(enabled,id,step,!isClient(area))) return false;
            var skip=amount==0 || !explosionRate.allow(haxe.Timer.stamp());
            if (skip && !warned) {
                warned=true;trace("[More Settings] Bomblet explosion FX limit: "+Std.string(amount)+" new/second; damage retained.");
            }
            return skip;
        } catch(e:Dynamic) {
            failed=true;trace("[More Settings] Bomblet visual protection disabled: "+Std.string(e));
            return false;
        }
    }
    public static function suppressTravel(inf:Dynamic,owner:Dynamic):Bool {
        if (!enabled || failed || inf == null || owner == null) return false;
        try {
            var step=G.text(G.field(inf,"id"));
            if (step!="Bomblet"&&step!="GoldenBomblet") return false;
            var fx=G.text(G.field(G.field(G.field(inf,"visuals"),"bellFx"),"set"));
            if (!BombletEffectPolicy.travel(enabled,step,fx,!isClient(owner))) return false;
            var skip=amount==0 || !travelRate.allow(haxe.Timer.stamp());
            if (skip && !travelWarned) {
                travelWarned=true;trace("[More Settings] Bomblet travel FX capped at "+Std.string(amount)+" starts/sec.");
            }
            return skip;
        } catch(e:Dynamic) {
            failed=true;trace("[More Settings] Bomblet travel FX limit disabled: "+Std.string(e));
            return false;
        }
    }
}
