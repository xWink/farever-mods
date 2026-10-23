package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Attaches skill art after native damage/healing number initialization. */
class DamageSkillIcons {
    static inline var ICON_SIZE:Float = 16;
    static var tiles:Map<String, Dynamic> = [];

    public static function apply(display:Dynamic, config:MoreSettingsConfig):Void {
        if (!config.showSkillIconNextToDamageNumber || config.damageNumberLimit == 0) return;
        if (display == null) return;
        var counter = G.field(display, "counter");
        var parent = G.field(counter, "parent");
        var dom = G.field(display, "dom");
        if (parent == null || dom == null) return;

        // Native construction assigns dmg before init, including UI rebuilds.
        var damage = G.field(display, "dmg");
        var skill = gamecompat.HitSkill.read(damage, G.field);
        var inf = G.field(skill, "inf");
        if (inf == null) inf = definition(G.text(G.field(skill, "kind")));
        var bitmap = G.field(display, "iconBmp");
        var nativeTile = G.field(bitmap, "tile");
        var tile = resolve(display, inf, nativeTile, config);
        if (tile == null || tile == nativeTile) return;
        G.set(display, "iconBmp", attach(bitmap, parent, dom, tile));
    }

    /** Self/received heals use a scrolling HUD row instead of HealDisplay. */
    public static function applyHealingFeed(feed:Dynamic, damage:Dynamic, config:MoreSettingsConfig):Void {
        if (!config.showSkillIconNextToDamageNumber || config.damageNumberLimit == 0) return;
        var row = HealingFeed.lastAddedRow(feed, damage);
        if (row == null) return;
        var counter:Dynamic = null;
        var bitmap:Dynamic = null;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", row));
        for (i in 0...count) {
            var child = G.call("h2d.Object", "getChildAt", row, [i]);
            if (G.isA(child, "ui.comp.FmtText")) counter = child;
            if (G.isA(child, "h2d.Bitmap")) bitmap = child;
        }
        if (counter == null) return;
        var skill = gamecompat.HitSkill.read(damage, G.field);
        var inf = G.field(skill, "inf");
        if (inf == null) inf = definition(G.text(G.field(skill, "kind")));
        var tile = sourceTile(skill, inf);
        if (tile == null || tile == G.field(bitmap, "tile")) return;
        bitmap = attach(bitmap, G.field(counter, "parent"), G.field(row, "dom"), tile);
        G.call("domkit.Properties", "initStyle", G.field(bitmap, "dom"), ["margin-right", 4]);
    }

    static function attach(bitmap:Dynamic, parent:Dynamic, dom:Dynamic, tile:Dynamic):Dynamic {
        var iconDom = G.field(bitmap, "dom");
        if (bitmap == null) {
            // Native init omits iconBmp entirely when getDamageIcon yields null.
            // Create the actual DOMKit bitmap after init instead of relying on
            // a tile-return hook. contentRoot is a nested centered container,
            // so use the counter's real parent for the final child order.
            iconDom = G.staticCall("domkit.Properties", "createNew",
                ["bitmap", dom, [], {id:"iconBmp"}]);
            bitmap = G.field(iconDom, "obj");
            if (bitmap == null) throw "Combat number skill icon was not created";
        }
        G.call("h2d.Bitmap", "set_tile", bitmap, [tile]);
        if (iconDom != null) {
            G.call("domkit.Properties", "initStyle", iconDom, ["src", tile]);
            // Native damage styles can hide iconBmp after init, removing it
            // from the flow despite set_visible(true) below. An inline style
            // wins on every DOMKit refresh, like the persistent src override.
            // Only this bitmap is affected; parent/HUD visibility still wins.
            G.call("domkit.Properties", "initStyle", iconDom, ["visible", true]);
        }
        G.call("h2d.Flow", "addChildAt", parent, [bitmap, 0]);
        G.call("h2d.Object", "set_visible", bitmap, [true]);
        return bitmap;
    }

    public static function resolve(display:Dynamic, inf:Dynamic, nativeIcon:Dynamic, config:MoreSettingsConfig):Dynamic {
        if (!config.showSkillIconNextToDamageNumber || config.damageNumberLimit == 0) return nativeIcon;
        var skill = gamecompat.HitSkill.read(G.field(display, "dmg"), G.field);
        var tile = sourceTile(skill, inf);
        return tile == null ? nativeIcon : tile;
    }

    static function sourceTile(skill:Dynamic, inf:Dynamic):Dynamic {
        var tile = skillTile(inf);
        if (tile == null) {
            // Status overrides and summon/child-skill links resolve on the real
            // runtime type. Never infer the cause from the player's last cast.
            var origin = G.callInstance(skill, "getSourceSkill");
            var id = G.text(G.field(origin, "kind"));
            if (id != "" && id != G.text(G.field(inf, "id"))) {
                var sourceInf = G.field(origin, "inf");
                tile = skillTile(sourceInf == null ? definition(id) : sourceInf);
            }
        }
        return tile;
    }

    static function definition(id:String):Dynamic {
        if (id == "") return null;
        var definitions = G.field(G.current("Data", "skill"), "byId");
        return definitions == null ? null : G.call("haxe.ds.StringMap", "get", definitions, [id]);
    }

    static function skillTile(inf:Dynamic):Dynamic {
        var id = G.text(G.field(inf, "id"));
        if (id == "") return null;
        if (tiles.exists(id)) return tiles[id];
        var gfx = G.field(inf, "gfx");
        if (gfx == null) gfx = G.field(G.staticCall("HSkill", "getSkillRef", [id]), "gfx");
        if (gfx == null) return null;
        var original = G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
        var width = G.number(G.field(original, "width"));
        var height = G.number(G.field(original, "height"));
        if (width <= 0 || height <= 0) return null;

        // Skill art can be 96/256 px. Resize only a private tile wrapper, never
        // the shared tile used by hotbars, tooltips, or the combat meter.
        var tile = G.call("h2d.Tile", "clone", original);
        var scale = ICON_SIZE / Math.max(width, height);
        G.call("h2d.Tile", "scaleToSize", tile, [width * scale, height * scale]);
        G.set(tile, "dx", 0.0);
        G.set(tile, "dy", 0.0);
        tiles[id] = tile;
        return tile;
    }

    public static function clear():Void {
        // Textures belong to the game; dropping wrappers must not dispose them.
        tiles = [];
    }
}
