import moresettings.ObviousSkillProcs as Procs;
import moresettings.GameAccess as G;
import moresettings.SettingsData;

class ObviousSkillProcsTest {
    static var checks = 0;
    static var app:Dynamic;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw '$message: expected $expected, got $actual';
    }
    static function node(parent:Dynamic):Dynamic {
        var n:Dynamic = {parent:parent, visible:true, children:[]};
        if (parent != null) (cast parent.children:Array<Dynamic>).push(n);
        return n;
    }
    static function setupHud():Void {
        G.hud = node(app.s2d);
        G.hud.uiScale = 1.0;
        G.hud.allowHeroBar = true;
        G.hud.background = node(G.hud);
        G.hud.interactive = node(G.hud);
        G.hud.bottomBar = node(G.hud);
        G.hud.bottomBar.heroBar = node(G.hud.bottomBar);
        G.hud.bottomBar.heroBarPad = node(G.hud.bottomBar);
        G.hud.floating = node(G.hud);
        G.hud.castingInfo = node(G.hud.floating);
        G.hud.castingInfo.nativeType = "ui.hud.CastingInfo";
        G.hud.castingInfo.castingBar = node(G.hud.castingInfo);
        G.hud.castingInfo.castingBar.bounds = {yMin:880.0, yMax:910.0};
        G.hud.windows = node(G.hud);
        G.hud.modals = node(G.hud);
    }
    static function skill(id:String, proc:Bool):Dynamic return {
        owner:G.hero, removed:false, proc:proc,
        inf:{id:id, nature:0, gfx:{tile:{width:96.0, height:96.0, dx:7.0, dy:9.0, texture:{atlas:true}}}}
    };
    static function button(skill:Dynamic, ?parent:Dynamic):Dynamic {
        var b = node(parent == null ? G.hud.bottomBar.heroBar : parent);
        b.skill = skill; b.locked = false;
        Procs.attach(b);
        return b;
    }
    static function tick():Void Procs.update(app, 0.051);
    static function covered(graphic:Dynamic, x:Float, y:Float):Bool {
        if (graphic.rectangles != null) for (r in (cast graphic.rectangles:Array<Dynamic>))
            if (r.alpha > 0 && x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h) return true;
        if (graphic.polygons != null) for (poly in (cast graphic.polygons:Array<Array<Dynamic>>)) {
            var inside = false;
            var j = poly.length - 1;
            for (i in 0...poly.length) {
                var a = poly[i], b = poly[j];
                if ((a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)
                    inside = !inside;
                j = i;
            }
            if (inside) return true;
        }
        return false;
    }
    static function overlay():Dynamic {
        for (n in G.created) if (n.nativeType == "h2d.Object" && n.parent == G.hud) return n;
        return null;
    }
    static function shown():Array<Dynamic> {
        var root = overlay();
        if (root == null || !root.visible) return [];
        return (cast root.children:Array<Dynamic>).filter(n -> n.visible);
    }
    static function main():Void {
        app = {s2d:{width:1920.0, height:1080.0, visible:true, children:[]}};
        G.hero = {dead:false};
        setupHud();
        var aimed = skill("Bow_Craft_Skill1", true);
        var a = button(aimed);
        Procs.attach(a);
        eq(SettingsData.defaults().obviousSkillProcs, false, "proc alerts default off");
        tick();
        eq(G.created.length, 0, "disabled feature allocates no graphics");
        eq(G.highlightCalls, 0, "disabled feature does not evaluate skills");
        Procs.configure(true); tick();
        eq(shown().length, 1, "native Aimed Shot proc produces one alert");
        eq(G.highlightCalls, 1, "repeated init does not register duplicate checks");
        var first = shown()[0];
        var root = overlay();
        eq(root.layout.isAbsolute, true, "overlay does not reflow the HUD");
        var order:Array<Dynamic> = G.hud.children;
        eq(order.indexOf(root), order.indexOf(G.hud.bottomBar) + 1, "alerts share action-bar draw priority");
        eq(order.indexOf(root) < order.indexOf(G.hud.windows), true, "existing menus render above alerts");
        eq(order.indexOf(root) < order.indexOf(G.hud.modals), true, "modal dialogs render above alerts");
        eq(root.x, 1064.0, "position is right of screen center");
        eq(root.y, 540.0, "position uses screen center vertically");
        var bitmap:Dynamic = (cast first.children[0].children:Array<Dynamic>).filter(n -> n.nativeType == "h2d.Bitmap")[0];
        eq(bitmap.tile.width, 48.0, "proc icon is prominent");
        eq(aimed.inf.gfx.tile.width, 96.0, "native skill tile size is preserved");
        eq(aimed.inf.gfx.tile.dx, 7.0, "native skill tile offset is preserved");
        eq(bitmap.tile.texture, aimed.inf.gfx.tile.texture, "icon shares the native atlas safely");
        var glows = (cast first.children[0].children:Array<Dynamic>).filter(n -> n.filter != null);
        eq(glows.length, 1, "border uses native glow filter");
        eq(glows[0].filter.radius, 2.0, "glow stays close to the slim border");
        eq(glows[0].filter.gain, 0.7, "glow does not become a solid bright band");
        eq(covered(glows[0], 0, 24), false, "gold edge does not extend inward into the icon");
        for (edge in glows) {
            for (i in -19...20) {
                eq(covered(edge, i, -25), true, "top edge is continuous, including its midpoint");
                eq(covered(edge, i, 25), true, "bottom edge is continuous, including its midpoint");
                eq(covered(edge, -25, i), true, "left edge is continuous, including its midpoint");
                eq(covered(edge, 25, i), true, "right edge is continuous, including its midpoint");
            }
            eq(covered(edge, 0, 0), false, "frame does not obscure the skill art");
            eq(covered(edge, 25, 25), false, "sharp corner is cut away");
            eq(covered(edge, 23.5, 23.5), true, "rounded arc joins the edges");
            eq(covered(edge, -23.5, -23.5), true, "opposite rounded corner is continuous");
        }
        var created = G.created.length;
        tick();
        eq(G.created.length, created, "steady procs do not recreate graphics each frame");

        var pyro = skill("Staff_Craft_S1", true);
        var p = button(pyro);
        var duplicate = button(aimed, G.hud.bottomBar.heroBarPad);
        tick();
        eq(shown().length, 2, "simultaneous procs appear once per skill across input layouts");
        eq(Math.abs(shown()[0].y - shown()[1].y), 66.0, "multiple procs have separate positions");
        aimed.proc = false; tick();
        eq(shown().length, 1, "consuming Aimed Shot clears only that proc");
        pyro.proc = false; tick();
        eq(shown().length, 0, "no alerts for ordinary ready skills");
        pyro.proc = true; tick();
        eq(shown().length, 1, "Pyroclasm reset can alert again");
        p.locked = true; tick();
        eq(shown().length, 0, "locked skill is not suggested");
        p.locked = false; pyro.removed = true; tick();
        eq(shown().length, 0, "removed skill is not suggested");
        pyro.removed = false; pyro.owner = {}; tick();
        eq(shown().length, 0, "other players' skills are excluded");
        pyro.owner = G.hero; pyro.inf.nature = 5; tick();
        eq(shown().length, 0, "passives are not suggested as buttons to press");
        pyro.inf.nature = 0; p.visible = false; tick();
        eq(shown().length, 0, "hidden hotbar slot is excluded");
        p.visible = true; G.hud.bottomBar.visible = false; tick();
        eq(shown().length, 0, "hidden hotbar ancestor is respected");
        G.hud.bottomBar.visible = true; tick();
        eq(shown().length, 1, "restoring HUD restores active proc");
        G.hud.visible = false; tick(); eq(shown().length, 0, "Hide UI hides the overlay");
        G.hud.visible = true; G.hud.allowHeroBar = false; tick();
        eq(shown().length, 0, "native overlay restrictions suppress alerts");
        G.hud.allowHeroBar = true; G.hero.dead = true; tick();
        eq(shown().length, 0, "death suppresses alerts");
        G.hero.dead = false; tick(); eq(shown().length, 1, "revival restores current proc state");

        var unrelated = button(skill("Preview", true), G.hud);
        tick(); eq(shown().length, 1, "skill previews outside the actual action bars are excluded");
        var missing = skill("MissingArt", true); missing.inf.gfx = null;
        p.skill = missing; tick(); eq(shown().length, 0, "unknown art does not show a misleading icon");
        G.skillRefs["MissingArt"] = pyro.inf;
        tick(); eq(shown().length, 1, "native referenced skill art is supported");
        var replacement = skill("Replacement", true);
        replacement.inf.gfx.tile.height = 48.0;
        p.skill = replacement; tick();
        eq(shown().length, 1, "weapon skill replacement removes previous proc");
        bitmap = (cast shown()[0].children[0].children:Array<Dynamic>).filter(n -> n.nativeType == "h2d.Bitmap")[0];
        eq(bitmap.tile.height, 24.0, "non-square art preserves aspect ratio");
        G.hud.uiScale = 2.0; G.hud.offsetX = 100.0;
        app.s2d.width = 2560.0; app.s2d.height = 1440.0;
        tick(); eq(overlay().x, 694.0, "resizing and UI scale use native coordinate conversion");
        eq(overlay().y, 360.0, "resized vertical center follows UI scale");
        for (i in 0...50) {
            tick();
            eq(shown()[0].children[0].scaleX >= 1 && shown()[0].children[0].scaleX <= 1.155, true, "pulse scale stays bounded");
        }
        Procs.update(app, Math.NaN);
        eq(Math.isFinite(shown()[0].children[0].scaleX), true, "invalid frame delta cannot corrupt animation");
        Procs.forget(p); tick(); eq(shown().length, 0, "removed widget stops alerting");
        Procs.attach(p); tick();
        var oldRoot = overlay();
        Procs.configure(false);
        eq(oldRoot.parent, null, "disabling detaches overlay immediately");
        Procs.configure(true); tick(); eq(shown().length, 1, "enabling again works without rebuilding HUD");
        oldRoot = overlay(); G.call("h2d.Object", "remove", oldRoot); tick();
        eq(shown().length, 1, "native child rebuild restores overlay on the same HUD");
        eq(overlay() != oldRoot, true, "detached overlay is replaced");
        oldRoot = overlay(); setupHud(); tick();
        eq(oldRoot.parent, null, "HUD replacement detaches old overlay");
        eq(shown().length, 0, "old HUD skills never leak into the new scene");
        button(skill("NewScene", true)); tick(); eq(shown().length, 1, "new HUD registers its own skills");
        eq(G.created.filter(n -> n.nativeType == "h2d.Interactive").length, 0, "alerts cannot intercept mouse input");
        oldRoot = overlay(); Procs.clear();
        eq(oldRoot.parent, null, "game disposal removes the display tree");
        tick(); eq(shown().length, 0, "game disposal clears registrations");
        eq(aimed.inf.gfx.tile.texture.atlas, true, "cleanup preserves shared game textures");
        useFeedback();
        countdownAndLayout();
        combatVisibility();
        trace('Skill proc alerts: $checks checks passed');
    }

    static function combatVisibility():Void {
        Procs.clear(); G.created = []; setupHud();
        G.hero.isInCombat = false;
        var proc = skill("Bow_Craft_Skill1", true); button(proc);
        eq(SettingsData.defaults().hideSkillProcAlertsOutsideCombat, false, "combat-only alerts are opt-in");
        Procs.configure(true); tick();
        eq(shown().length, 1, "default behavior still shows procs outside combat");
        Procs.configure(true, 100, "Right", true); tick();
        eq(shown().length, 0, "combat-only setting hides an already-visible proc");
        var calls = G.highlightCalls, created = G.created.length;
        Procs.onUse(G.hero, proc); tick();
        eq(G.created.length, created, "out-of-combat skill use creates no alert feedback");
        eq(G.highlightCalls, calls, "hidden alerts skip native highlight polling outside combat");
        G.hero.isInCombat = true; tick();
        eq(shown().length, 1, "entering combat immediately shows a currently active proc");
        Procs.onUse(G.hero, proc); tick();
        eq(sparks().length, 12, "in-combat proc use keeps the existing feedback");
        G.hero.isInCombat = false; tick();
        eq(shown().length, 0, "leaving combat hides the whole alert");
        eq(sparks().length, 0, "leaving combat cancels active feedback");
        proc.proc = false; tick(); G.hero.isInCombat = true; tick();
        eq(shown().length, 0, "returning to combat never replays expired procs or feedback");
        G.hero.isInCombat = false; proc.proc = true; tick();
        Procs.configure(true); tick();
        eq(shown().length, 1, "turning off combat-only mode restores a current proc outside combat");
        Procs.clear();
    }

    static function sparks():Array<Dynamic>
        return G.created.filter(n -> n.nativeType == "h2d.Graphics" && n.points != null && n.points.length == 9 && n.visible);

    static function countdownAndLayout():Void {
        Procs.clear(); G.created = []; setupHud();
        app.s2d.width = 1920.0; app.s2d.height = 1080.0;
        var proc = skill("Bow_Craft_Skill1", true);
        proc.script = {Proc:"Bow_Craft_Passive_Status"};
        var buff:Dynamic = {kind:"Bow_Craft_Passive_Status", duration:10.0, remaining:7.2};
        G.hero.statuses = {array:[buff]};
        button(proc);
        Procs.configure(true); tick();
        var timer:Dynamic = G.created.filter(n -> n.nativeType == "h2d.Text")[0];
        eq(timer.text, "8", "enabling midway through a proc uses its actual remaining time");
        eq(timer.visible, true, "timed alert has an in-icon countdown");
        eq(timer.textColor, 0xFFFFFF, "countdown remains white");
        eq(timer.filter.color, 0, "countdown has a black outline");
        eq(timer.y + 16 * timer.scaleX <= 24, true, "timer stays inside the icon");
        buff.remaining = 2.41; tick();
        eq(timer.text, "2.5", "last seconds count down in tenths");
        buff.remaining = 10.0; tick();
        eq(timer.text, "10", "native refresh immediately refreshes the countdown");
        Procs.configure(true, 150, "Left"); tick();
        eq(overlay().scaleX, 1.5, "size slider scales the entire alert");
        eq(overlay().x, 844.0, "left positioning mirrors the offset and allows for size");
        eq(overlay().y, 540.0, "side alerts stay centered vertically");
        var pyro = skill("Staff_Craft_S1", true); button(pyro);
        Procs.configure(true, 100, "Below"); tick();
        eq(overlay().x, 960.0, "below positioning stays centered horizontally");
        eq(overlay().y, 838.0, "below positioning is just above the native cast bar");
        G.hud.castingInfo.castingBar.visible = false; tick();
        eq(overlay().y, 838.0, "alerts retain their cast-bar anchor between casts");
        Procs.configure(true, 200, "Below"); tick();
        eq(overlay().y, 806.0, "larger alerts reserve space above the cast bar");
        G.hud.castingInfo.castingBar.bounds.yMin = 980.0; tick();
        eq(overlay().y, 906.0, "moving the native cast bar moves the below alerts");
        Procs.configure(true, 100, "Below"); tick();
        var order:Array<Dynamic> = G.hud.children;
        var root = overlay(); order.remove(root); order.push(root); tick();
        eq(order.indexOf(root), order.indexOf(G.hud.bottomBar) + 1, "native reordering restores action-bar priority");
        eq(order.indexOf(root) < order.indexOf(G.hud.windows), true, "reordered alerts stay behind open menus");
        eq(shown()[0].y, 0.0, "below row uses horizontal stacking");
        eq(Math.abs(shown()[0].x - shown()[1].x), 66.0, "below row keeps simultaneous alerts separate");
        Procs.onUse(G.hero, proc);
        eq(timer.visible, false, "timer disappears immediately when the proc is used");
        proc.proc = false; tick();
        eq(timer.visible, false, "no stale countdown during the use animation");
        Procs.configure(false); Procs.configure(true); proc.proc = true; buff.duration = -1; tick();
        eq(G.created.filter(n -> n.nativeType == "h2d.Text" && n.parent.parent.visible && n.visible && n.parent.parent.parent.parent != null).length,
            0, "infinite proc has no invented countdown");
        Procs.clear();
    }

    static function useFeedback():Void {
        Procs.clear();
        G.created = [];
        setupHud();
        var proc = skill("UsedProc", true);
        var b = button(proc);
        Procs.configure(true); tick();
        var alert = shown()[0];
        var content = alert.children[0];
        Procs.onUse({}, proc);
        Procs.onUse(G.hero, skill("UsedProc", true));
        eq(sparks().length, 0, "other heroes and unrelated skill instances cannot celebrate this proc");
        proc.proc = false; tick();
        eq(shown().length, 0, "natural expiry stays immediate");
        eq(sparks().length, 0, "natural expiry creates no success effect");

        proc.proc = true; tick();
        Procs.onUse(G.hero, proc);
        var allocated = G.created.length;
        Procs.onUse(G.hero, proc);
        eq(G.created.length, allocated, "duplicate use notification cannot allocate or restart another burst");
        tick(); // Highlight may still be waiting for native/network state to clear.
        eq(shown().length, 1, "used icon stays briefly visible during its exit effect");
        eq(content.alpha, 1.0, "impact holds the icon fully visible");
        eq(content.scaleX, 1.45, "impact snaps directly to its enlarged pose");
        eq(content.filter.nativeType, "h2d.filter.ColorMatrix", "impact gets a temporary high-contrast frame");
        tick(); tick();
        eq(content.filter, null, "impact filter is removed before the normal sparkle fade");
        eq(content.alpha > 0 && content.alpha < 1, true, "used skill art fades instead of disappearing");
        eq(content.scaleX > 1, true, "used icon gives a small pop");
        eq(sparks().length, 12, "accepted highlighted skill emits twelve sparkles");
        eq(sparks().filter(s -> Math.abs(s.x) + Math.abs(s.y) > 15).length, 12,
            "sparkles spread around the alert rather than covering its center");
        proc.proc = false;
        for (i in 0...12) tick();
        eq(shown().length, 0, "spent proc disappears after the short animation");
        eq(sparks().length, 0, "finished sparkle particles are hidden");

        proc.proc = true; tick();
        eq(content.alpha, 1.0, "a later proc restores full icon opacity");
        Procs.onUse(G.hero, proc); proc.proc = false; tick();
        eq(G.created.length, allocated, "repeated use reuses its particle graphics");
        proc.proc = true; tick();
        eq(content.alpha, 1.0, "immediate re-proc remains readable during the earlier sparkle");
        Procs.onUse(G.hero, proc); tick(); tick(); tick();
        eq(content.alpha < 1, true, "immediate re-proc can be used again");
        Procs.update(app, 1.0);
        eq(sparks().length, 0, "a long frame finishes rather than prolonging the effect");
        eq(content.alpha, 1.0, "remaining native highlight/charges return after feedback ends");

        Procs.onUse(G.hero, proc); proc.proc = false; tick();
        G.hud.visible = false; tick();
        eq(sparks().length, 0, "hiding the HUD cancels a running sparkle");
        G.hud.visible = true; tick();
        eq(shown().length, 0, "restoring the HUD does not replay an old use");
        proc.proc = true; tick();
        Procs.onUse(G.hero, proc);
        b.skill = skill("ReplacementWithoutProc", false); tick();
        eq(sparks().length, 0, "unequipping the skill cancels its pending effect");
        eq(shown().length, 0, "removed skill leaves no fading alert behind");

        b.skill = proc; tick();
        Procs.onUse(G.hero, proc); G.hero.dead = true; tick();
        eq(sparks().length, 0, "death cancels success feedback");
        G.hero.dead = false; tick();
        Procs.onUse(G.hero, proc);
        var oldRoot = overlay();
        Procs.configure(false);
        eq(oldRoot.parent, null, "disabling during feedback removes the complete effect tree");
        allocated = G.created.length;
        Procs.onUse(G.hero, proc);
        eq(G.created.length, allocated, "disabled alerts cannot allocate sparkles");
        Procs.clear();
    }
}
