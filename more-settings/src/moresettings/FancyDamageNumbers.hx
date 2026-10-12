package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Styles native damage/healing counters; rendering objects stay in the game module. */
class FancyDamageNumbers {
    static var ramp:Dynamic;
    static var rampPixels:Dynamic;
    static var halfMask:Dynamic;
    static var halfPixels:Dynamic;
    static var gradientOwners = new haxe.ds.ObjectMap<Dynamic, {counter:Dynamic, shader:Dynamic}>();

    public static function apply(display:Dynamic, config:MoreSettingsConfig):Void {
        if (!config.fancyDamageNumbers) return;
        var healing = G.isA(display, "ui.comp.HealDisplay");
        var counter = G.field(display, "counter");
        var dom = G.field(counter, "dom");
        if (dom == null) return;

        var nativeColor:Dynamic = G.field(G.field(display, "affinity"), "damageColor");
        if (nativeColor == null) nativeColor = G.field(counter, "textColor");
        var baseColor:Int = nativeColor == null ? 0xFFFFFF : cast nativeColor;
        style(counter, G.field(display, "dmg"), G.field(display, "isCrit") == true, healing, baseColor);
    }

    /** Received/self healing uses EffectsFeed, not HealDisplay. */
    public static function applyHealingFeed(feed:Dynamic, damage:Dynamic, config:MoreSettingsConfig):Void {
        // HLX runs postfixes even when the hiding prefix skipped the native row.
        // Do not restyle the previous heal when no new row was added.
        if (config.disableDamageNumbers || !config.fancyDamageNumbers || damage == null) return;
        var element = HealingFeed.lastAddedRow(feed, damage);
        if (element == null) return;
        var children = G.integer(G.call("h2d.Object", "get_numChildren", element));
        for (i in 0...children) {
            var counter = G.call("h2d.Object", "getChildAt", element, [i]);
            if (!G.isA(counter, "ui.comp.FmtText")) continue;
            style(counter, damage, G.call("st.skill.DamageResult", "get_critical", damage) == true, true, 0xFFFFFF);
        }
    }

    static function style(counter:Dynamic, damage:Dynamic, critical:Bool, healing:Bool, baseColor:Int):Void {
        var dom = G.field(counter, "dom");
        if (dom == null) return;

        // Inline styles survive subsequent native affinity/crit CSS refreshes.
        // DamageDisplay.init creates a fresh counter, so toggling affects new hits.
        G.call("domkit.Properties", "initStyle", dom, ["color", 0xFFFFFF]);
        G.call("h2d.Text", "set_textColor", counter, [0xFFFFFF]);

        var raw = !healing && G.field(damage, "affinity") == "Raw";
        var filter:Dynamic = G.field(counter, "filter");
        if (raw || healing) {
            // Raw and healing start from an unshadowed white fill so their
            // gradients are not tinted by the game's native affinity filter.
            filter = null;
            G.call("domkit.Properties", "initStyle", dom, ["text-shadow", null]);
            G.set(counter, "dropShadow", null);
        }

        // Use the actual hit's affinity, including for skills with mixed damage.
        var magic = false;
        if (!raw && !healing && damage != null)
            magic = G.call("st.skill.DamageResult", "get_isMagic", damage) == true;

        var top = healing ? (critical ? 0xFFD966 : 0xB8FF92)
            : raw ? (critical ? 0xF5E149 : 0xFFFFFF)
            : critical ? (magic ? 0xEF8DE8 : 0xFFCB6D)
            : magic ? 0xBCC2FF : damage != null ? 0xFFCB6D : baseColor;
        var bottom = healing ? 0x238C45
            : raw ? (critical ? 0xEBEBEB : 0xB8B8B8)
            : critical ? (magic ? 0x5963C4 : 0xFF0000)
            : magic ? 0x5963C4 : damage != null ? 0xF04424 : shade(baseColor);
        if (critical) {
            var middle = healing ? 0xB8FF92 : raw ? 0xFFFFFF
                : magic ? 0xC08DEF : 0xF04424;
            // Encode the original white/black intensity in R and height in G.
            // A second native matrix pass selects a linear segment at half height.
            // This supports arbitrary stops (including black) without dividing by
            // a colour channel, tinting shadows, or allocating textures per hit.
            filter = append(filter, gradient(0xFF00FF, 0xFFFFFF));
            filter = append(filter, matrixGradient(segment(top, middle, false), segment(middle, bottom, true), getHalfMask()));
        } else filter = append(filter, gradient(top, bottom));
        applyBorder(counter, dom, filter);
    }

    static function applyBorder(counter:Dynamic, dom:Dynamic, filter:Dynamic):Void {
        // A single 1 px black outline after tinting keeps the border uncoloured.
        filter = append(filter, outline());
        G.call("domkit.Properties", "initStyle", dom, ["filter", filter]);
        G.call("h2d.Object", "set_filter", counter, [filter]);
    }

    static function outline():Dynamic {
        var filter = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", filter, [1.0]);
        G.call("h2d.filter.Outline", "set_quality", filter, [0.5]);
        G.call("h2d.filter.Outline", "set_color", filter, [0x000000]);
        // Keep native opaque, premultiplied-alpha rendering.
        return filter;
    }

    static function append(existing:Dynamic, next:Dynamic):Dynamic {
        if (existing == null) return next;
        var group = G.create("h2d.filter.Group", [null]);
        G.call("h2d.filter.Group", "add", group, [existing]);
        G.call("h2d.filter.Group", "add", group, [next]);
        return group;
    }

    static function shade(color:Int):Int {
        return (Math.round(((color >> 16) & 255) * 0.55) << 16)
            | (Math.round(((color >> 8) & 255) * 0.55) << 8)
            | Math.round((color & 255) * 0.55);
    }

    static function gradient(top:Int, bottom:Int):Dynamic {
        return matrixGradient(tint(top), tint(bottom), getRamp());
    }

    /** Transform intensity * [1, height, 1] into either half of the RGB gradient. */
    static function segment(start:Int, end:Int, lower:Bool):Dynamic {
        var matrix = tint(0);
        for (column in 1...4) {
            var shift = (3 - column) * 8;
            var a = ((start >> shift) & 255) / 255.0;
            var b = ((end >> shift) & 255) / 255.0;
            G.set(matrix, "_1" + column, lower ? 2 * a - b : a);
            G.set(matrix, "_2" + column, 2 * (b - a));
        }
        return matrix;
    }

    static function matrixGradient(first:Dynamic, second:Dynamic, mask:Dynamic):Dynamic {
        // Reuse the game's masked two-matrix screen shader. UVs cover the whole
        // rendered counter, not the unrelated positions of digits in the font atlas.
        var shader = G.create("h3d.pass.ColorMatrixShader", []);
        for (name in ["useAlpha", "useMask", "hasSecondMatrix"])
            G.call("h3d.pass.ColorMatrixShader", "set_" + name, shader, [true]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskInvert", shader, [false]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix", shader, [first]);
        G.call("h3d.pass.ColorMatrixShader", "set_matrix2", shader, [second]);
        G.call("h3d.pass.ColorMatrixShader", "set_mask", shader, [mask]);
        G.call("h3d.pass.ColorMatrixShader", "set_maskPower", shader, [1.0]);
        vector(G.field(shader, "maskMatA__"), 1, 0, 0);
        vector(G.field(shader, "maskMatB__"), 0, 1, 0);
        var channel = G.field(shader, "maskChannel__");
        vector(channel, 1, 0, 0);
        G.set(channel, "w", 0.0);
        return G.create("h2d.filter.Shader", [shader, "texture"]);
    }

    public static function bindGradient(filter:Dynamic, counter:Dynamic):Void {
        if (ramp == null) return;
        var shader = G.field(G.field(filter, "pass"), "shader");
        if (shader != null && (G.field(shader, "mask__") == ramp || (halfMask != null && G.field(shader, "mask__") == halfMask)))
            gradientOwners.set(filter, {counter: counter, shader: shader});
    }

    public static function unbindGradient(filter:Dynamic):Void {
        gradientOwners.remove(filter);
    }

    /** Map the render tile to glyph geometry, excluding line height and borders. */
    public static function syncGradient(filter:Dynamic, context:Dynamic, input:Dynamic):Void {
        var owner = gradientOwners.get(filter);
        if (owner == null) return;
        // Text and font styles are finalized after DamageDisplay.init. FmtText
        // inherits HtmlText, whose calcHeight is the full line box, not the ink.
        // TileLayerContent records the placed glyph quads, including their font
        // offsets. Read those live so resizing/rebuilding text stays aligned.
        G.call("h2d.Text", "updateSize", owner.counter);
        var content = G.field(G.field(owner.counter, "glyphs"), "content");
        var yMin = number(content, "yMin", Math.POSITIVE_INFINITY);
        var yMax = number(content, "yMax", Math.NEGATIVE_INFINITY);
        if (!Math.isFinite(yMin) || !Math.isFinite(yMax) || yMax <= yMin) {
            yMin = Math.POSITIVE_INFINITY;
            yMax = Math.NEGATIVE_INFINITY;
        }
        // HtmlText can place a differently styled run in another TileGroup.
        // Its glyph coordinates are also in the text's local space. Ignore
        // images and interactive boxes, which do not have glyph content bounds.
        var elements = G.field(owner.counter, "elements");
        if (number(elements, "length", 0) > 0) for (element in G.array(elements)) {
            if (G.field(element, "visible") == false) continue;
            var run = G.field(element, "content");
            var runMin = number(run, "yMin", Math.NaN);
            var runMax = number(run, "yMax", Math.NaN);
            if (!Math.isFinite(runMin) || !Math.isFinite(runMax) || runMax <= runMin) continue;
            yMin = Math.min(yMin, runMin);
            yMax = Math.max(yMax, runMax);
        }
        var height = yMax - yMin;
        // Keep a safe mapping while an empty counter has no built glyphs yet.
        if (!Math.isFinite(height) || height <= 0) {
            yMin = number(owner.counter, "calcYMin", 0);
            height = number(owner.counter, "calcHeight", 0);
        }
        var root = G.field(owner.counter, "filter");
        var scale = number(root, "resolutionScale", 1);
        if (G.field(root, "useScreenResolution") == true)
            scale *= number(G.field(context, "scene"), "viewportScaleY", 1);
        var tileHeight = number(input, "height", 0);
        var tileY = number(input, "dy", 0);
        if (!Math.isFinite(height) || height <= 0 || !Math.isFinite(yMin)
            || !Math.isFinite(scale) || scale <= 0 || tileHeight <= 0) return;
        // Sample texel centers in the 64-row ramp for an even linear blend.
        var span = 63.0 / 64.0;
        vector(G.field(owner.shader, "maskMatB__"), 0,
            span * tileHeight / (scale * height),
            0.5 / 64.0 + span * (tileY - yMin) / height);
    }

    static function number(object:Dynamic, field:String, fallback:Float):Float {
        var value:Dynamic = G.field(object, field);
        return value == null ? fallback : cast value;
    }

    static function vector(value:Dynamic, x:Float, y:Float, z:Float):Void {
        G.set(value, "x", x); G.set(value, "y", y); G.set(value, "z", z);
    }

    static function tint(color:Int):Dynamic {
        var matrix = G.create("h3d.MatrixImpl", []);
        G.call("h3d.MatrixImpl", "zero", matrix);
        // Multiply existing RGB instead of replacing it: native black shadows
        // stay black, transparent pixels stay transparent, and fades retain alpha.
        G.set(matrix, "_11", ((color >> 16) & 255) / 255.0);
        G.set(matrix, "_22", ((color >> 8) & 255) / 255.0);
        G.set(matrix, "_33", (color & 255) / 255.0);
        G.set(matrix, "_44", 1.0);
        return matrix;
    }

    static function getRamp():Dynamic {
        if (ramp != null && G.call("h3d.mat.Texture", "isDisposed", ramp) != true) return ramp;
        dispose();
        var format = G.enumeration("hxd.PixelFormat", "RGBA");
        rampPixels = G.staticCall("hxd.Pixels", "alloc", [1, 64, format]);
        for (y in 0...64) {
            var gray = Math.round(y * 255 / 63);
            G.call("hxd.Pixels", "setPixel", rampPixels, [0, y, 0xFF000000 | (gray << 16) | (gray << 8) | gray]);
        }
        ramp = G.staticCall("h3d.mat.Texture", "fromPixels", [rampPixels, format]);
        G.call("h3d.mat.Texture", "set_filter", ramp, [G.enumeration("h3d.mat.Filter", "Linear")]);
        G.call("h3d.mat.Texture", "set_wrap", ramp, [G.enumeration("h3d.mat.Wrap", "Clamp")]);
        G.call("h3d.mat.Texture", "preventAutoDispose", ramp);
        var texture = ramp, pixels = rampPixels;
        G.set(texture, "realloc", function():Void {
            G.call("h3d.mat.Texture", "uploadPixels", texture, [pixels, null, null]);
        });
        return ramp;
    }

    static function getHalfMask():Dynamic {
        if (halfMask != null && G.call("h3d.mat.Texture", "isDisposed", halfMask) != true) return halfMask;
        if (halfMask != null) G.set(halfMask, "realloc", null);
        if (halfPixels != null) G.call("hxd.Pixels", "dispose", halfPixels);
        // Same texel-center mapping as the linear ramp, with an exact split at
        // 50%. Nearest avoids blending the two line equations near the middle.
        var format = G.enumeration("hxd.PixelFormat", "RGBA");
        halfPixels = G.staticCall("hxd.Pixels", "alloc", [1, 64, format]);
        for (y in 0...64)
            G.call("hxd.Pixels", "setPixel", halfPixels, [0, y, y < 32 ? 0xFF000000 : 0xFFFFFFFF]);
        halfMask = G.staticCall("h3d.mat.Texture", "fromPixels", [halfPixels, format]);
        G.call("h3d.mat.Texture", "set_filter", halfMask, [G.enumeration("h3d.mat.Filter", "Nearest")]);
        G.call("h3d.mat.Texture", "set_wrap", halfMask, [G.enumeration("h3d.mat.Wrap", "Clamp")]);
        G.call("h3d.mat.Texture", "preventAutoDispose", halfMask);
        var texture = halfMask, pixels = halfPixels;
        G.set(texture, "realloc", function():Void {
            G.call("h3d.mat.Texture", "uploadPixels", texture, [pixels, null, null]);
        });
        return halfMask;
    }

    public static function dispose():Void {
        gradientOwners.clear();
        if (halfMask != null) {
            G.set(halfMask, "realloc", null);
            G.call("h3d.mat.Texture", "dispose", halfMask);
            halfMask = null;
        }
        if (halfPixels != null) {
            G.call("hxd.Pixels", "dispose", halfPixels);
            halfPixels = null;
        }
        if (ramp != null) {
            G.set(ramp, "realloc", null);
            G.call("h3d.mat.Texture", "dispose", ramp);
            ramp = null;
        }
        if (rampPixels != null) {
            G.call("hxd.Pixels", "dispose", rampPixels);
            rampPixels = null;
        }
    }
}
