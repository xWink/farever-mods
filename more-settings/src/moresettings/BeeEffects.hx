package moresettings;

import moresettings.GameAccess as G;

private typedef BeeVisual = { var obj:Dynamic; var visible:Bool; }

/** Client-only performance budget. Bees and attacks still simulate normally. */
class BeeEffects {
    public static var enabled:Bool = false;
    static var quota = new VisualQuota(2);
    static var rate = new VisualRateLimit();
    static var hidden = new haxe.ds.ObjectMap<Dynamic, BeeVisual>();
    static var failed = false;
    static var warned = false;
    static var auraWarned = false;

    static function isClient(state:Dynamic):Bool
        return G.call("st.BaseState", "get_isServer", state) == false;
    static function show(object:Dynamic, visible:Bool):Void
        G.call("h3d.scene.Object", "set_visible", object, [visible]);

    public static function reset():Void {
        // Disabling the option restores exactly the pre-existing visibility.
        for (entry in hidden) try show(entry.obj, entry.visible) catch (_:Dynamic) {}
        hidden = new haxe.ds.ObjectMap(); quota.reset(); rate.reset();
        failed = false; warned = false; auraWarned = false;
    }
    static function error(e:Dynamic):Void {
        reset(); failed = true;
        trace("[More Settings] Bee visual protection disabled; visuals restored: " + Std.string(e));
    }
    public static function release(unit:Dynamic):Void {
        if (unit == null) return;
        var entry = hidden.get(unit);
        if (entry != null) {
            try show(entry.obj, entry.visible) catch (_:Dynamic) {}
            hidden.remove(unit);
        }
        quota.release(unit);
    }
    public static function update(unit:Dynamic):Void {
        if (!enabled || failed || unit == null) return;
        try {
            var kind=G.text(G.field(unit, "kind"));
            if (kind != "Summon_Bee" || !BeeEffectPolicy.unit(enabled, kind, !isClient(unit))) return;
            var obj=G.field(unit,"obj");
            if (obj == null) { release(unit); return; }
            var entry=hidden.get(unit);
            if (entry != null && entry.obj != obj) { release(unit); entry = null; }
            if (quota.admit(unit)) {
                if (entry != null) { show(entry.obj, entry.visible); hidden.remove(unit); }
                return;
            }
            if (entry == null) {
                var visible=G.call("h3d.scene.Object","get_visible",obj) == true;
                entry={obj:obj,visible:visible};hidden.set(unit,entry);
            }
            show(obj,false);
            if (!warned) {
                warned = true;
                trace("[More Settings] Bee visual budget active (2 displayed bee models).");
            }
        } catch(e:Dynamic) error(e);
    }
    public static function suppressAura(entity:Dynamic, fx:Dynamic, skill:Dynamic):Bool {
        if (!enabled || failed || entity == null || fx == null || skill == null) return false;
        try {
            var name=G.text(G.field(fx,"set"));
            if (name!="Honey_Aura") return false;
            var id=G.text(G.field(G.field(skill,"inf"),"id"));
            if (!BeeEffectPolicy.aura(enabled,id,name,!isClient(skill))) return false;
            if (!auraWarned) {
                auraWarned=true;
                trace("[More Settings] Bee Honey_Aura visual/audio suppressed; buff retained.");
            }
            return true;
        } catch(e:Dynamic) { error(e); return false; }
    }
    public static function suppressSkillFx(source:Dynamic):Bool {
        if (!enabled || failed || source == null) return false;
        try {
            var skill=G.field(source,"baseSkill");
            var id=G.text(G.field(G.field(skill,"inf"),"id"));
            return id=="SummonBee_HoneyBolt" && BeeEffectPolicy.projectile(enabled,id,!isClient(skill));
        } catch(e:Dynamic) { error(e); return false; }
    }
    public static function suppressProjectile(projectile:Dynamic):Bool {
        if (!enabled || failed || projectile == null) return false;
        try {
            var skill=G.field(projectile,"baseSkill");
            var id=G.text(G.field(G.field(skill,"inf"),"id"));
            return id=="SummonBee_HoneyBolt"
                && BeeEffectPolicy.projectile(enabled,id,!isClient(projectile))
                && !rate.allow(haxe.Timer.stamp());
        } catch(e:Dynamic) { error(e); return false; }
    }
}
