package minimap;

import minimap.GameAccess as G;

/** The character's replicated heroic bonus, not a locally calculated rotation. */
class MainMapBonusDungeon {
    public var visible(default, null):Bool = false;
    public var width(default, null):Float = 0;
    var parent:Dynamic;
    var styleParent:Dynamic;
    var root:Dynamic;
    var background:Dynamic;
    var title:Dynamic;
    var nameText:Dynamic;
    var icon:Dynamic;
    var fontSource:Dynamic;
    var font:Dynamic;
    var lastHero:Dynamic;
    var lastId:String;
    var name:String;
    var fontSize:Float = 14;
    var nextSample:Float = 0;
    var layoutKey:String = "";
    var reportedError:Bool = false;

    public function new(parent:Dynamic, styleParent:Dynamic) {
        this.parent = parent;
        this.styleParent = styleParent;
    }

    public function update(hero:Dynamic, mapWidth:Float, mapHeight:Float):Void {
        try {
            var now = haxe.Timer.stamp();
            if (hero != lastHero || now >= nextSample) {
                nextSample = now + 0.5;
                sample(hero);
            }
            if (visible) {
                refreshFont();
                layout(mapWidth, mapHeight);
            }
        } catch (error:Dynamic) {
            hide();
            // Retry optional game data without removing the map or its filters.
            nextSample = haxe.Timer.stamp() + 5;
            lastId = null;
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] Heroic bonus dungeon: " + Std.string(error));
            }
        }
    }

    function sample(hero:Dynamic):Void {
        var specialization = G.field(hero, "specialization");
        if (hero != lastHero) { lastHero = hero; lastId = null; }
        if (specialization == null) { lastId = null; hide(); return; }
        // Same property checked by HeroSpecialization.isBonusHeroicDungeon.
        var id = G.text(G.field(G.field(specialization, "bonusHeroicDungeon"), "activity"));
        if (id != lastId || name == null) {
            var label = "None assigned";
            if (id != "") {
                var inf = G.staticCall("HActivity", "getInf", [id]);
                if (inf == null) { lastId = null; hide(); return; }
                label = G.text(G.staticCall("HText", "activity", [inf, G.current("ETextKind", "Name")]));
                if (label == "") { lastId = null; hide(); return; }
            }
            name = StringTools.replace(StringTools.replace(label, "\n", " "), "\r", "");
            lastId = id;
            ensure();
            G.call("h2d.Text", "set_text", nameText, [name]);
            layoutKey = "";
        }
        refreshIcon();
        visible = true;
        G.call("h2d.Object", "set_visible", root, [true]);
    }

    function ensure():Void {
        if (root != null) return;
        try build() catch (error:Dynamic) {
            dispose();
            throw error;
        }
    }

    function build():Void {
        root = G.create("h2d.Object", [parent]);
        background = G.create("h2d.Graphics", [root]);
        icon = G.create("h2d.Bitmap", [null, root]);
        G.set(icon, "smooth", true);
        // The atlas is neutral: the heroic presentation needs its green tint.
        G.call("h3d.Vector4Impl", "setColor", G.field(icon, "color"), [0xff91ef6b]);
        G.call("h2d.Object", "set_visible", icon, [false]);
        // Use the game's bold font rather than enlarging the fallback bitmap
        // font. Keep the style source alive for delayed CSS/locale changes.
        var style = G.staticCall("domkit.Properties", "createNew",
            ["text", G.field(styleParent, "dom"), [""], {id:"minimapMainBonusFont", "class":"bold-16"}]);
        fontSource = G.field(style, "obj");
        if (fontSource != null) G.call("h2d.Object", "set_visible", fontSource, [false]);
        font = G.field(fontSource, "font");
        if (font == null) font = G.staticCall("hxd.res.DefaultFont", "get", []);
        title = G.create("h2d.Text", [font, root]);
        nameText = G.create("h2d.Text", [font, root]);
        for (text in [title, nameText]) G.set(text, "smooth", true);
        G.call("h2d.Text", "set_text", title, ["Heroic bonus dungeon"]);
        G.call("h2d.Text", "set_textColor", title, [0x89644b]);
        G.call("h2d.Text", "set_textColor", nameText, [0x503a2d]);
        G.call("h2d.Object", "setPosition", title, [48., 8.]);
        G.call("h2d.Object", "setPosition", nameText, [48., 27.]);
        font = null;
        refreshFont();
    }

    function refreshFont():Void {
        var next = G.field(fontSource, "font");
        if (next == null || next == font) return;
        font = next;
        fontSize = Math.max(1, G.number(G.field(font, "size"), 16));
        for (text in [title, nameText]) G.call("h2d.Text", "set_font", text, [font]);
        G.call("h2d.Object", "setScale", title, [14 / fontSize]);
        layoutKey = "";
    }

    function refreshIcon():Void {
        if (G.field(icon, "tile") != null) return;
        // The same atlas definition used by the native heroic difficulty UI.
        var icons = G.field(G.current("Data", "icon"), "byId");
        if (icons == null) return;
        var inf = G.call("haxe.ds.StringMap", "get", icons, ["Dungeon_Heroic"]);
        var gfx = G.field(inf, "gfx");
        if (gfx == null) return;
        var tile = G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
        if (tile == null) return;
        var w = G.number(G.field(tile, "width")), h = G.number(G.field(tile, "height"));
        if (w <= 0 || h <= 0) return;
        var scale = 32 / Math.max(w, h);
        G.call("h2d.Bitmap", "set_tile", icon, [tile]);
        G.call("h2d.Object", "setScale", icon, [scale]);
        G.call("h2d.Object", "setPosition", icon, [26 - w * scale / 2, 28 - h * scale / 2]);
        G.call("h2d.Object", "set_visible", icon, [true]);
    }

    function layout(mapWidth:Float, mapHeight:Float):Void {
        var key = mapWidth + ":" + mapHeight;
        if (layoutKey == key) return;
        layoutKey = key;
        var textWidth = Math.max(1, G.number(G.call("h2d.Text", "get_textWidth", nameText)));
        width = Math.min(Math.max(220, textWidth * 18 / fontSize + 62), Math.max(220, Math.min(340, mapWidth * 0.32)));
        G.call("h2d.Object", "setScale", nameText, [Math.min(18 / fontSize, (width - 62) / textWidth)]);
        G.call("h2d.Graphics", "clear", background);
        for (border in [true, false]) {
            var inset = border ? 0. : 2.;
            G.call("h2d.Graphics", "beginFill", background, [border ? 0x987459 : 0xe9d9bb, 1.]);
            G.call("h2d.Graphics", "drawRoundedRect", background, [inset, inset, width - 2 * inset, 56 - 2 * inset, 8 - inset, 16]);
            G.call("h2d.Graphics", "endFill", background);
        }
        // The card scales down for unusually small map viewports.
        var scale = Math.min(1, Math.max(1, mapWidth - 24) / width);
        G.call("h2d.Object", "setScale", root, [scale]);
        G.call("h2d.Object", "setPosition", root, [12., Math.max(12, mapHeight - 12 - 56 * scale)]);
    }

    function hide():Void {
        visible = false;
        if (root != null) G.call("h2d.Object", "set_visible", root, [false]);
    }

    public function dispose():Void {
        for (object in [root, fontSource]) if (object != null) G.call("h2d.Object", "remove", object);
        root = null; fontSource = null; font = null;
        visible = false;
    }
}
