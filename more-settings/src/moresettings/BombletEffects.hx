package moresettings;

import moresettings.GameAccess as G;

/** Suppress redundant Bomblet cosmetics only; preserve native area hits. */
class BombletEffects {
    public static var enabled:Bool = false;
    static var failed = false;
    static var travelRate = new VisualRateLimit(0.01);
    static var explosionRate = new VisualRateLimit(0.01);
    // A single explosion can hit several enemies before playAreaFx runs.
    // Share its decision with every hit splash instead of spending one slot per hit.
    static var explosions = new haxe.ds.ObjectMap<Dynamic, Bool>();
    static var amount:Int = -1;
    public static function configure(value:Int):Void {
        var next=value < 0 ? -1 : value;
        var shouldLimit=next >= 0;
        if(amount==next && enabled==shouldLimit)return;
        reset();
        amount=next;
        var interval=1.0/Math.max(1,next);
        travelRate=new VisualRateLimit(interval);
        explosionRate=new VisualRateLimit(interval);
        enabled=shouldLimit;
    }
    public static function reset():Void {
        failed=false;
        travelRate.reset();explosionRate.reset();
        explosions = new haxe.ds.ObjectMap();
    }
    public static function release(area:Dynamic):Void {
        if (area != null) explosions.remove(area);
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
            var cached=explosions.get(area);
            if (cached != null) return cached;
            var hidden=amount==0 || !explosionRate.allow(haxe.Timer.stamp());
            explosions.set(area,hidden);
            return hidden;
        } catch(e:Dynamic) {
            failed=true;trace("[More Settings] Bomblet visual protection disabled: "+Std.string(e));
            return false;
        }
    }
    public static function suppressHit(hitData:Dynamic):Bool {
        if (!enabled || failed || hitData == null) return false;
        var skill=gamecompat.HitSkill.read(hitData,G.field);
        if (G.text(G.field(G.field(skill,"inf"),"id")) != "Infusion_Kobold_DPS") return false;
        return suppress(G.field(hitData,"area"));
    }
    public static function suppressTravel(inf:Dynamic,owner:Dynamic):Bool {
        if (!enabled || failed || inf == null || owner == null) return false;
        try {
            var step=G.text(G.field(inf,"id"));
            if (step!="Bomblet"&&step!="GoldenBomblet") return false;
            var fx=G.text(G.field(G.field(G.field(inf,"visuals"),"bellFx"),"set"));
            if (!BombletEffectPolicy.travel(enabled,step,fx,!isClient(owner))) return false;
            return amount==0 || !travelRate.allow(haxe.Timer.stamp());
        } catch(e:Dynamic) {
            failed=true;trace("[More Settings] Bomblet travel FX limit disabled: "+Std.string(e));
            return false;
        }
    }
}
