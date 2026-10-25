package moresettings;

import moresettings.GameAccess as G;

private typedef ProcIcon = {
    var id:String;
    var skill:Dynamic;
    var node:Dynamic;
    var content:Dynamic;
    var glow:Dynamic;
    var timer:Dynamic;
    var timerLabel:String;
    var active:Bool;
    var age:Float;
    var useAge:Float;
    var used:Bool;
    var impact:Dynamic;
    var impactPending:Bool;
    var flash:Dynamic;
    var ring:Dynamic;
    var sparks:Array<ProcSpark>;
}

private typedef ProcSpark = {
    var node:Dynamic;
    var dx:Float;
    var dy:Float;
}

/** Mirrors equipped skills' native special-state highlight, without changing casts. */
class ObviousSkillProcs {
    static inline var SIZE:Float = 48;
    static inline var SPACING:Float = 66;
    static inline var IMPACT_DURATION:Float = 0.06;
    static inline var BURST_DURATION:Float = 0.55;
    static var enabled = false;
    static var hideOutsideCombat = false;
    static var alertScale:Float = 1.0;
    static var alertPosition = "Right";
    static var buttons:Array<Dynamic> = [];
    static var icons:Array<ProcIcon> = [];
    static var hud:Dynamic;
    static var root:Dynamic;
    static var point:Dynamic;
    static var castingInfo:Dynamic;
    static var castBounds:Dynamic;
    static var untilCheck:Float = 0;
    static var reported = false;

    public static function configure(value:Bool, size:Int = 100, position:String = "Right", combatOnly:Bool = false):Void {
        enabled = value;
        hideOutsideCombat = combatOnly;
        alertScale = Math.max(50, Math.min(200, size)) / 100;
        alertPosition = ["Left", "Right", "Below"].indexOf(position) < 0 ? "Right" : position;
        untilCheck = 0;
        if (!enabled) clearIcons();
    }

    public static function attach(button:Dynamic):Void {
        // Observe even while disabled, so enabling in settings works immediately.
        if (buttons.indexOf(button) < 0) buttons.push(button);
        untilCheck = 0;
    }

    public static function forget(element:Dynamic):Void {
        if (buttons.remove(element)) untilCheck = 0;
        if (element == hud) {
            clearIcons();
            hud = null;
        }
    }

    /** Hero.onSkillUse runs after native skill.start, not for queued key presses. */
    public static function onUse(hero:Dynamic, skill:Dynamic):Void {
        if (!enabled || root == null || hero == null || skill == null
            || (hideOutsideCombat && G.field(hero, "isInCombat") != true)
            || hero != G.staticCall("GameApp", "getMyHero", [])
            || G.field(skill, "owner") != hero || hud != G.staticCall("ui.GameUI", "getHud", [])
            || !under(root, hud, true) || G.call("ent.GameObject", "isDead", hero) == true
            || G.call("ui.Hud", "canShowHeroBar", hud) != true) return;
        for (icon in icons) {
            if (!icon.active || icon.skill != skill || icon.used) continue;
            icon.active = false;
            icon.used = true;
            icon.useAge = 0;
            icon.impactPending = true;
            if (icon.timer != null) G.call("h2d.Object", "set_visible", icon.timer, [false]);
            if (icon.sparks.length == 0) createUseEffect(icon);
            G.call("h2d.Object", "set_visible", icon.flash, [true]);
            G.call("h2d.Object", "set_visible", icon.ring, [true]);
            for (spark in icon.sparks) G.call("h2d.Object", "set_visible", spark.node, [true]);
            untilCheck = 0;
            return;
        }
    }

    public static function update(app:Dynamic, dt:Float):Void {
        if (!enabled) return;
        var nextHud = G.staticCall("ui.GameUI", "getHud", []);
        if (nextHud != hud) {
            var oldHud = hud;
            clearIcons();
            if (oldHud != null) buttons = buttons.filter(b -> !under(b, oldHud));
            hud = nextHud;
            untilCheck = 0;
        }
        // Keep the alerts beside the action bar in the native display tree,
        // below windows and overlays, including after an in-place HUD rebuild.
        var barParent = G.field(G.field(hud, "bottomBar"), "parent");
        if (root != null && G.field(root, "parent") != barParent) {
            clearIcons();
            untilCheck = 0;
        }
        var scene = G.field(app, "s2d");
        var hero = G.staticCall("GameApp", "getMyHero", []);
        if (hud == null || scene == null || hero == null || barParent == null || !under(barParent, hud, true)
            || (hideOutsideCombat && G.field(hero, "isInCombat") != true)
            || !under(hud, scene, true)
            || G.call("ent.GameObject", "isDead", hero) == true
            || G.call("ui.Hud", "canShowHeroBar", hud) != true) {
            hide();
            return;
        }
        var seconds = Math.isFinite(dt) && dt > 0 ? dt : 0;
        var elapsed = Math.min(seconds, 0.1);
        for (icon in icons) if (icon.useAge >= 0) {
            // Show the snap pose once even if the cast begins on a long frame.
            if (icon.impactPending) icon.impactPending = false;
            else icon.useAge += seconds;
            if (icon.useAge >= IMPACT_DURATION + BURST_DURATION) {
                cancelUse(icon);
                untilCheck = 0; // Remaining charges may still deserve an alert.
            }
        }
        untilCheck -= elapsed;
        if (untilCheck <= 0) {
            refresh(hero);
            untilCheck = 0.05; // The native predicates need no per-hit hooks.
        }
        var active = [for (icon in icons) if (icon.active || icon.useAge >= 0) icon];
        if (root == null) return;
        G.call("h2d.Object", "set_visible", root, [active.length > 0]);
        if (active.length == 0) return;

        // Work in the action bar's parent coordinates, not the topmost HUD
        // layer. Absolute Flow placement leaves the action bar layout intact.
        G.set(point, "x", G.number(G.field(scene, "width")) * 0.5);
        G.set(point, "y", G.number(G.field(scene, "height")) * 0.5);
        var parent = G.field(root, "parent");
        var center = G.call("h2d.Object", "globalToLocal", parent, [point]);
        var below = alertPosition == "Below";
        var offset = 104 + (alertScale - 1) * SIZE * 0.5;
        var x = G.number(G.field(center, "x"));
        var y = G.number(G.field(center, "y"));
        if (below) y = aboveCastBar(parent, y + offset);
        else x += alertPosition == "Left" ? -offset : offset;
        G.call("h2d.Object", "setScale", root, [alertScale]);
        G.call("h2d.Object", "setPosition", root, [x, y]);
        for (i in 0...active.length) {
            var icon = active[i];
            icon.age += elapsed;
            var pulse = 0.5 + 0.5 * Math.cos(icon.age * Math.PI * 2 / 0.9);
            var entrance = Math.max(0, 1 - icon.age / 0.18);
            var along = (i - (active.length - 1) * 0.5) * SPACING;
            G.call("h2d.Object", "setPosition", icon.node, [below ? along : 0.0, below ? 0.0 : along]);
            var playingUse = icon.useAge >= 0 && !icon.active;
            var impact = playingUse && icon.useAge < IMPACT_DURATION;
            var burstAge = Math.max(0, icon.useAge - IMPACT_DURATION);
            var progress = burstAge / BURST_DURATION;
            var useScale = 1 + 0.45 * Math.exp(-burstAge / 0.065);
            var fade = Math.min(1, burstAge / 0.28);
            var filter = impact ? icon.impact : null;
            if (G.field(icon.content, "filter") != filter)
                G.call("h2d.Object", "set_filter", icon.content, [filter]);
            G.call("h2d.Object", "setScale", icon.content,
                [playingUse ? useScale : 1 + 0.035 * pulse + 0.12 * entrance]);
            G.set(icon.content, "alpha", playingUse ? (1 - fade) * (1 - fade) : 1.0);
            G.set(icon.glow, "alpha", impact ? 1.0 : 0.4 + 0.4 * pulse);
            if (icon.useAge >= 0) {
                var spread = 1 - (1 - progress) * (1 - progress);
                G.call("h2d.Object", "setScale", icon.flash, [useScale]);
                G.set(icon.flash, "alpha", impact || icon.active ? 0.0 : 0.75 * Math.max(0, 1 - burstAge / 0.14));
                G.call("h2d.Object", "setScale", icon.ring, [1 + spread]);
                G.set(icon.ring, "alpha", impact ? 0.0 : 0.95 * Math.max(0, 1 - progress / 0.65));
                for (spark in icon.sparks) {
                    G.call("h2d.Object", "setPosition", spark.node,
                        [spark.dx * (20 + 40 * spread), spark.dy * (20 + 40 * spread) - 10 * spread]);
                    G.call("h2d.Object", "setScale", spark.node, [0.8 + 0.6 * Math.sin(progress * Math.PI)]);
                    G.set(spark.node, "alpha", impact ? 0.0 : Math.min(1, (1 - progress) * 1.6));
                }
            }
        }
    }

    static function refresh(hero:Dynamic):Void {
        var bar = G.field(hud, "bottomBar");
        var keyboard = G.field(bar, "heroBar");
        var controller = G.field(bar, "heroBarPad");
        var equipped:Map<String, Dynamic> = [];
        var desired:Map<String, Dynamic> = [];
        // Keep registration order for a stable stack when several procs coexist.
        var order:Array<String> = [];
        buttons = buttons.filter(b -> G.field(b, "parent") != null);
        for (button in buttons) {
            if ((!under(button, keyboard, true) && !under(button, controller, true))
                || !under(button, hud, true) || G.field(button, "locked") == true) continue;
            var skill = G.field(button, "skill");
            var inf = G.field(skill, "inf");
            var id = G.text(G.field(inf, "id"));
            if (skill == null || G.field(skill, "removed") == true || G.field(skill, "owner") != hero
                || G.integer(G.field(inf, "nature")) == 5 || id == "" || equipped.exists(id)) continue;
            equipped[id] = skill;
            if (G.call("st.skill.Skill", "shouldHighlight", skill) != true) continue;
            desired[id] = skill;
            order.push(id);
        }
        for (icon in icons) {
            if (equipped[icon.id] != icon.skill) cancelUse(icon);
            var highlighted = desired.exists(icon.id);
            if (!highlighted) icon.used = false;
            var wasActive = icon.active;
            icon.active = highlighted && !icon.used;
            if (icon.active) icon.skill = desired[icon.id];
            if (!icon.active || !wasActive) icon.age = 0;
            G.call("h2d.Object", "set_visible", icon.node, [icon.active || icon.useAge >= 0]);
        }
        for (id in order) {
            var found = false;
            for (icon in icons) if (icon.id == id) { found = true; break; }
            if (!found) {
                var icon = createIcon(id, desired[id]);
                if (icon != null) icons.push(icon);
            }
        }
        for (icon in icons) updateTimer(icon);
        if (root != null) placeOnActionBarLayer();
    }

    static function placeOnActionBarLayer():Void {
        var bar = G.field(hud, "bottomBar");
        var parent = G.field(bar, "parent");
        var barIndex = G.integer(G.call("h2d.Object", "getChildIndex", parent, [bar]));
        var index = G.integer(G.call("h2d.Object", "getChildIndex", parent, [root]));
        if (index == barIndex + 1) return;
        // Remove before indexing again: moving from before the bar otherwise
        // shifts its index and can put the alerts above a window container.
        G.call("h2d.Object", "remove", root);
        barIndex = G.integer(G.call("h2d.Object", "getChildIndex", parent, [bar]));
        // Flow.addChildAt takes a content index and adds these decoration slots
        // itself; Object.getChildIndex returns the raw display-list index.
        var decorations = (G.field(parent, "background") == null ? 0 : 1)
            + (G.field(parent, "interactive") == null ? 0 : 1);
        G.call("h2d.Flow", "addChildAt", parent, [root, barIndex + 1 - decorations]);
        G.set(G.call("h2d.Flow", "getProperties", parent, [root]), "isAbsolute", true);
    }

    static function aboveCastBar(parent:Dynamic, fallback:Float):Float {
        if (!under(castingInfo, hud)) castingInfo = findCastingInfo(hud, 5);
        var bar = G.field(castingInfo, "castingBar");
        if (bar == null) return fallback;
        // getBounds uses the native, laid-out bar even between casts. Reuse the
        // bounds object and reserve room for the idle pulse plus a small gap.
        castBounds = G.call("h2d.Object", "getBounds", bar, [parent, castBounds]);
        var top = G.field(castBounds, "yMin");
        return top == null ? fallback : G.number(top) - 32 * alertScale - 10;
    }

    static function findCastingInfo(node:Dynamic, depth:Int):Dynamic {
        if (node == null || depth < 0 || node == root) return null;
        if (G.isA(node, "ui.hud.CastingInfo")) return node;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", node));
        for (i in 0...count) {
            var found = findCastingInfo(G.call("h2d.Object", "getChildAt", node, [i]), depth - 1);
            if (found != null) return found;
        }
        return null;
    }

    static function updateTimer(icon:ProcIcon):Void {
        var label = icon.active ? ProcTiming.label(ProcTiming.remaining(icon.skill)) : "";
        if (label == "") {
            if (icon.timer != null) G.call("h2d.Object", "set_visible", icon.timer, [false]);
            return;
        }
        if (icon.timer == null) {
            var font:Dynamic = null;
            for (button in buttons) if (G.field(button, "skill") == icon.skill) {
                font = G.field(G.field(button, "chargesText"), "font");
                if (font != null) break;
            }
            if (font == null) font = G.staticCall("hxd.res.DefaultFont", "get", []);
            icon.timer = G.create("h2d.Text", [font, icon.content]);
            G.call("h2d.Text", "set_textColor", icon.timer, [0xFFFFFF]);
            G.call("h2d.Text", "set_lineBreak", icon.timer, [false]);
            G.call("h2d.Object", "set_filter", icon.timer, [BuffStackOutlines.makeOutline(1.5)]);
        }
        if (label != icon.timerLabel) {
            icon.timerLabel = label;
            G.call("h2d.Text", "set_text", icon.timer, [label]);
            var width = G.number(G.call("h2d.Text", "get_textWidth", icon.timer));
            var height = G.number(G.call("h2d.Text", "get_textHeight", icon.timer));
            var size = G.number(G.field(G.field(icon.timer, "font"), "size"));
            var scale = Math.min(16 / Math.max(1, size), 42 / Math.max(1, width));
            G.call("h2d.Object", "setScale", icon.timer, [scale]);
            G.call("h2d.Object", "setPosition", icon.timer, [-width * scale * 0.5, 21 - height * scale]);
        }
        G.call("h2d.Object", "set_visible", icon.timer, [true]);
    }

    static function createIcon(id:String, skill:Dynamic):Null<ProcIcon> {
        var inf = G.field(skill, "inf");
        var gfx = G.field(inf, "gfx");
        if (gfx == null) gfx = G.field(G.staticCall("HSkill", "getSkillRef", [id]), "gfx");
        if (gfx == null) return null;
        var original = G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
        var width = G.number(G.field(original, "width"));
        var height = G.number(G.field(original, "height"));
        if (width <= 0 || height <= 0) return null;
        if (root == null) {
            root = G.create("h2d.Object", [null]);
            placeOnActionBarLayer();
            point = G.create("h2d.col.PointImpl", [0.0, 0.0]);
        }
        var node = G.create("h2d.Object", [root]);
        var content = G.create("h2d.Object", [node]);
        var back = G.create("h2d.Graphics", [content]);
        G.call("h2d.Graphics", "beginFill", back, [0x10141F, 0.92]);
        G.call("h2d.Graphics", "drawRoundedRect", back, [-27.0, -27.0, 54.0, 54.0, 5.0, null]);
        G.call("h2d.Graphics", "endFill", back);

        // Never resize or dispose the game's shared hotbar tile/texture.
        var tile = G.call("h2d.Tile", "clone", original);
        var scale = SIZE / Math.max(width, height);
        G.call("h2d.Tile", "scaleToSize", tile, [width * scale, height * scale]);
        G.set(tile, "dx", -width * scale * 0.5);
        G.set(tile, "dy", -height * scale * 0.5);
        G.create("h2d.Bitmap", [tile, content]);
        var glow = border(content, 1.0, 0xFFD25B);
        var filter = G.create("h2d.filter.Glow", [null, null, null, null, null, null]);
        G.set(filter, "color", 0xFFC342);
        G.set(filter, "alpha", 0.7);
        G.call("h2d.filter.Blur", "set_radius", filter, [2.0]);
        G.call("h2d.filter.Blur", "set_gain", filter, [0.7]);
        G.call("h2d.Object", "set_filter", glow, [filter]);
        return {id:id, skill:skill, node:node, content:content, glow:glow, timer:null, timerLabel:"",
            active:true, age:0, useAge:-1, used:false, impact:null, impactPending:false,
            flash:null, ring:null, sparks:[]};
    }

    static function createUseEffect(icon:ProcIcon):Void {
        var matrix = G.create("h3d.MatrixImpl", []);
        G.call("h3d.MatrixImpl", "identity", matrix);
        G.call("h3d.MatrixImpl", "colorSaturate", matrix, [-1.0]);
        G.call("h3d.MatrixImpl", "colorContrast", matrix, [2.2]);
        icon.impact = G.create("h2d.filter.ColorMatrix", [matrix]);
        // Reuse the flash, expanding gold frame and stars. No per-frame drawing.
        icon.flash = G.create("h2d.Graphics", [icon.node]);
        G.call("h2d.Graphics", "beginFill", icon.flash, [0xFFE8A3, 1.0]);
        G.call("h2d.Graphics", "drawRoundedRect", icon.flash, [-24.0, -24.0, 48.0, 48.0, 4.0, null]);
        G.call("h2d.Graphics", "endFill", icon.flash);
        icon.ring = border(icon.node, 1.75, 0xFFD25B);
        for (i in 0...12) {
            var star = G.create("h2d.Graphics", [icon.node]);
            var radius = i % 2 == 0 ? 6.0 : 4.0;
            G.call("h2d.Graphics", "beginFill", star, [i % 2 == 0 ? 0xFFE8A3 : 0xFFD25B, 1.0]);
            G.call("h2d.Graphics", "moveTo", star, [0.0, -radius]);
            G.call("h2d.Graphics", "lineTo", star, [1.0, -1.0]);
            G.call("h2d.Graphics", "lineTo", star, [radius, 0.0]);
            G.call("h2d.Graphics", "lineTo", star, [1.0, 1.0]);
            G.call("h2d.Graphics", "lineTo", star, [0.0, radius]);
            G.call("h2d.Graphics", "lineTo", star, [-1.0, 1.0]);
            G.call("h2d.Graphics", "lineTo", star, [-radius, 0.0]);
            G.call("h2d.Graphics", "lineTo", star, [-1.0, -1.0]);
            G.call("h2d.Graphics", "lineTo", star, [0.0, -radius]);
            G.call("h2d.Graphics", "endFill", star);
            var angle = (i + 0.25) * Math.PI / 6;
            var reach = i % 2 == 0 ? 1.0 : 0.75;
            icon.sparks.push({node:star, dx:Math.cos(angle) * reach, dy:Math.sin(angle) * reach});
        }
    }

    static function cancelUse(icon:ProcIcon):Void {
        icon.useAge = -1;
        icon.used = false;
        icon.impactPending = false;
        if (icon.impact != null && G.field(icon.content, "filter") == icon.impact)
            G.call("h2d.Object", "set_filter", icon.content, [null]);
        if (icon.flash != null) G.call("h2d.Object", "set_visible", icon.flash, [false]);
        if (icon.ring != null) G.call("h2d.Object", "set_visible", icon.ring, [false]);
        for (spark in icon.sparks) G.call("h2d.Object", "set_visible", spark.node, [false]);
    }

    static function border(parent:Dynamic, thickness:Float, color:Int):Dynamic {
        var graphics = G.create("h2d.Graphics", [parent]);
        // Fill four straight segments and concentric arc quads. The native
        // rounded-stroke path previously dropped the straight sides in-game.
        var outer = 25 + thickness * 0.5;
        var inner = 25 - thickness * 0.5;
        var corner = 20.0;
        var outerRadius = outer - corner;
        var innerRadius = inner - corner;
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
        G.call("h2d.Graphics", "drawRect", graphics, [-corner, -outer, corner * 2, thickness]);
        G.call("h2d.Graphics", "drawRect", graphics, [-corner, inner, corner * 2, thickness]);
        G.call("h2d.Graphics", "drawRect", graphics, [-outer, -corner, thickness, corner * 2]);
        G.call("h2d.Graphics", "drawRect", graphics, [inner, -corner, thickness, corner * 2]);
        G.call("h2d.Graphics", "endFill", graphics);
        for (quarter in 0...4) {
            var cx = quarter == 0 || quarter == 3 ? corner : -corner;
            var cy = quarter < 2 ? corner : -corner;
            for (i in 0...10) {
                var a = (quarter + i / 10) * Math.PI * 0.5;
                var b = (quarter + (i + 1) / 10) * Math.PI * 0.5;
                G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
                G.call("h2d.Graphics", "moveTo", graphics,
                    [cx + Math.cos(a) * outerRadius, cy + Math.sin(a) * outerRadius]);
                G.call("h2d.Graphics", "lineTo", graphics,
                    [cx + Math.cos(b) * outerRadius, cy + Math.sin(b) * outerRadius]);
                G.call("h2d.Graphics", "lineTo", graphics,
                    [cx + Math.cos(b) * innerRadius, cy + Math.sin(b) * innerRadius]);
                G.call("h2d.Graphics", "lineTo", graphics,
                    [cx + Math.cos(a) * innerRadius, cy + Math.sin(a) * innerRadius]);
                G.call("h2d.Graphics", "endFill", graphics);
            }
        }
        return graphics;
    }

    static function under(node:Dynamic, ancestor:Dynamic, visible = false):Bool {
        if (ancestor == null) return false;
        while (node != null) {
            if (visible && G.field(node, "visible") == false) return false;
            if (node == ancestor) return true;
            node = G.field(node, "parent");
        }
        return false;
    }

    static function hide():Void {
        if (root != null) G.call("h2d.Object", "set_visible", root, [false]);
        for (icon in icons) { icon.active = false; icon.age = 0; cancelUse(icon); }
        untilCheck = 0;
    }

    static function clearIcons():Void {
        if (root != null) G.call("h2d.Object", "remove", root);
        root = null;
        point = null;
        castingInfo = null;
        castBounds = null;
        // Native filters use the engine's render-target pool. Only our display
        // objects/wrappers are released; skill atlas textures remain game-owned.
        icons = [];
    }

    public static function clear():Void {
        clearIcons();
        buttons = [];
        hud = null;
        untilCheck = 0;
    }

    public static function report(error:Dynamic):Void {
        if (!reported) trace("[More Settings] Skill proc alerts: " + Std.string(error));
        reported = true;
        // Fail closed instead of leaving a stale proc on screen or retrying an
        // unsupported game API every frame. Toggling the setting retries it.
        enabled = false;
        clearIcons();
    }
}
