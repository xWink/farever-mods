package moresettings;

import moresettings.GameAccess as G;

private typedef DamageTextEntry = {
    var display:Dynamic;
    var widget:Dynamic;
    var ui:Dynamic;
    var key:String;
    var animate:Float->Void;
    var managed:Bool;
    var idle:Bool;
    var idleAt:Float;
    var restart:Bool;
}

/** Reuse complete native damage displays only with identical native styling. */
class CombatTextPool {
    public static inline var LIMIT = 48;
    public static inline var IDLE_SECONDS = 6.0;
    var entries:Array<DamageTextEntry> = [];
    var owner:Dynamic;
    var clock:Void->Float;
    var nextSweep:Float = 0;

    public function new(?clock:Void->Float) this.clock = clock == null ? haxe.Timer.stamp : clock;

    function key(dmg:Dynamic):String {
        var skill = G.field(dmg, "baseSkill");
        if (skill == null) skill = G.field(dmg, "skill"); // PTR renamed the field.
        return G.text(G.field(dmg, "affinity")) + "\n" + G.text(G.field(skill, "kind"))
            + "\n" + (G.call("st.skill.DamageResult", "get_critical", dmg) == true ? "1" : "0");
    }

    public function capture(display:Dynamic, animate:Float->Void):Float->Void {
        if (entries.length >= LIMIT || animate == null || G.field(display, "dmg") == null) return animate;
        for (entry in entries) if (entry.display == display) return animate;
        var entry:DamageTextEntry = {display: display, widget: null, ui: null,
            key: key(G.field(display, "dmg")), animate: animate, managed: true,
            idle: false, idleAt: 0, restart: false};
        entries.push(entry);
        return function(dt:Float):Void {
            if (!entry.managed) { animate(dt); return; }
            if (entry.idle) return;
            if (entry.restart) { entry.restart = false; dt = 0; }
            var lifetime:Float = G.field(display, "lifetime");
            var maxLifetime:Float = G.field(display, "maxLifetime");
            if (lifetime + dt > maxLifetime) try {
                if (recycle(entry)) return;
            } catch (_:Dynamic) {
                discard(entry);
                return;
            }
            animate(dt);
        };
    }

    function recycle(entry:DamageTextEntry):Bool {
        var widget = G.field(entry.display, "parent");
        var depth = 0;
        while (widget != null && !G.isA(widget, "ui.Widget") && depth++ < 6) widget = G.field(widget, "parent");
        var ui = G.field(widget, "currUI");
        if (widget == null || ui == null || ui != G.current("ui.BaseUI", "current") || G.field(widget, "parent") == null) {
            entry.managed = false; entries.remove(entry); return false;
        }
        entry.widget = widget; entry.ui = ui; entry.idle = true; entry.idleAt = clock();
        // Empty containers are removed by a native WaitEvent. Keep the display
        // attached while idle, but remove its widget from projection work.
        G.call("hl.types.ArrayObj", "remove", G.field(ui, "widgets"), [widget]);
        G.call("h2d.Object", "set_visible", widget, [false]);
        G.set(widget, "active", false);
        G.set(entry.display, "dmg", null); // Do not retain combat state/targets.
        return true;
    }

    public function reuse(dmg:Dynamic, position:Dynamic):Dynamic {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != ui) { clear(); owner = ui; }
        var settings = G.current("Const", "UI");
        if (dmg == null || position == null || G.field(settings, "DamageNumbersEnabled") != true) return null;
        var wanted = key(dmg);
        for (entry in entries) if (entry.idle && entry.key == wanted && entry.ui == ui
                && G.field(entry.widget, "parent") != null && G.field(entry.display, "parent") != null) {
            // These widgets originate exclusively from UnitEffectDisplay's
            // fixed-world-position constructor, so this is their owned vector.
            try {
                var point = G.call("ui.Widget", "getFollowWPos", entry.widget);
                if (point == null) continue;
                G.set(point, "x", G.field(position, "x"));
                G.set(point, "y", G.field(position, "y"));
                G.set(point, "z", G.number(G.field(position, "z")) + G.number(G.field(settings, "DamageNumbersOffsetZ")));
                G.set(entry.display, "dmg", dmg);
                G.set(entry.display, "lifetime", 0.0);
                G.call("ui.comp.DamageDisplay", "updateDamage", entry.display);
                entry.animate(0);
                entry.idle = false; entry.restart = true;
                G.set(entry.widget, "active", true);
                G.call("hl.types.ArrayObj", "push", G.field(ui, "widgets"), [entry.widget]);
                G.call("h2d.Object", "set_visible", entry.widget, [true]);
                G.call("ui.Widget", "update", entry.widget, [0.0]);
                return entry.display;
            } catch (e:Dynamic) {
                // A partially reactivated display must not survive alongside
                // the original display() fallback for the same hit.
                discard(entry);
                throw e;
            }
        }
        return null;
    }

    function discard(entry:DamageTextEntry):Void {
        entry.managed = false; entries.remove(entry);
        try removeIdleWidget(entry) catch (_:Dynamic) {}
    }

    function removeIdleWidget(entry:DamageTextEntry):Void {
        // Empty the container as native expiry would: GameApp's waitUntil
        // closure must observe zero children and release its widget reference.
        G.call("h2d.Object", "remove", entry.display);
        if (entry.widget != null) G.call("h2d.Object", "remove", entry.widget);
    }

    public function sweep():Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != ui) { clear(); owner = ui; }
        var now = clock();
        if (now < nextSweep) return;
        nextSweep = now + 1;
        var i = entries.length;
        while (i-- > 0) {
            var entry = entries[i];
            if (G.field(entry.display, "parent") == null || (entry.idle && now - entry.idleAt >= IDLE_SECONDS)) {
                entry.managed = false;
                entries.splice(i, 1);
                if (entry.idle) removeIdleWidget(entry);
            }
        }
    }

    public function clear():Void {
        var old = entries; entries = [];
        for (entry in old) {
            entry.managed = false;
            // Live numbers complete their existing native animation.
            if (entry.idle) removeIdleWidget(entry);
        }
        owner = null;
    }
}
