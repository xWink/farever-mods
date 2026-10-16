package minimap;

import minimap.GameAccess as G;

/** The character's replicated heroic bonus, not a locally calculated rotation. */
class MainMapBonusDungeon {
    public var visible(default, null):Bool = false;
    public var width(default, null):Float = 0;
    var parent:Dynamic;
    var root:Dynamic;
    var background:Dynamic;
    var title:Dynamic;
    var nameText:Dynamic;
    var icon:Dynamic;
    var lastHero:Dynamic;
    var lastId:String;
    var name:String;
    var fontSize:Float = 14;
    var nextSample:Float = 0;
    var layoutKey:String = "";
    var reportedError:Bool = false;

    public function new(parent:Dynamic) this.parent = parent;

    public function update(hero:Dynamic, mapWidth:Float, mapHeight:Float):Void {
        try {
            var now = haxe.Timer.stamp();
            if (hero != lastHero || now >= nextSample) {
                nextSample = now + 0.5;
                sample(hero);
            }
            if (visible) layout(mapWidth, mapHeight);
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
        visible = true;
        G.call("h2d.Object", "set_visible", root, [true]);
    }

    function ensure():Void {
        if (root != null) return;
        try build() catch (error:Dynamic) {
            if (root != null) G.call("h2d.Object", "remove", root);
            root = null;
            throw error;
        }
    }

    function build():Void {
        root = G.create("h2d.Object", [parent]);
        background = G.create("h2d.Graphics", [root]);
        icon = G.create("h2d.Graphics", [root]);
        LandmarkIcons.draw(icon, "dungeon", 11);
        G.call("h2d.Object", "setPosition", icon, [26., 28.]);
        var font = G.staticCall("hxd.res.DefaultFont", "get", []);
        fontSize = Math.max(1, G.number(G.field(font, "size"), 14));
        title = G.create("h2d.Text", [font, root]);
        nameText = G.create("h2d.Text", [font, root]);
        G.call("h2d.Text", "set_text", title, ["Heroic bonus dungeon"]);
        G.call("h2d.Text", "set_textColor", title, [0x89644b]);
        G.call("h2d.Text", "set_textColor", nameText, [0x503a2d]);
        G.call("h2d.Object", "setScale", title, [13 / fontSize]);
        G.call("h2d.Object", "setPosition", title, [48., 8.]);
        G.call("h2d.Object", "setPosition", nameText, [48., 27.]);
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
}
