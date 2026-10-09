package minimap;

import minimap.GameAccess as G;
import minimap.MinimapButtonLayout.ButtonSpot;
import minimap.MinimapMenu.MenuShortcut;
import minimap.MinimapMod.MinimapSettings;

private typedef Chip = {
    var id:String;
    var x:Float;
    var y:Float;
    var width:Float;
    var height:Float;
    var background:Dynamic;
    var icon:Dynamic;
    var hit:Dynamic;
}

private typedef MenuRow = {
    var key:String;
    var box:Dynamic;
}

/** Category buttons to the right of the minimap. Right-click opens that category only. */
class MinimapControls {
    public var root:Dynamic;
    var shield:Dynamic;
    var bar:Dynamic;
    var menu:Dynamic;
    var chips:Array<Chip> = [];
    var rows:Array<MenuRow> = [];
    var size:Int = 0;
    var circular:Bool = false;
    var config:MinimapSettings;
    var hovered:String = "";
    var openId:String = "";
    var fontSource:Void->Dynamic;
    var drawIcon:Dynamic->String->Void;
    var originX:Float = 0;
    var originY:Float = 0;
    var screenWidth:Float = 0;
    var screenHeight:Float = 0;
    /** Width past the card's right edge, including the gap before the buttons. */
    public static function columnExtra(mapSize:Int, circular:Bool = false):Float
        return MinimapButtonLayout.extra(mapSize, circular);

    public function new() {
        root = G.create("h2d.Object", [null]);
        shield = G.create("h2d.Interactive", [1.0, 1.0, root, null]);
        G.call("h2d.Object", "set_visible", shield, [false]);
        G.set(shield, "width", 0);
        G.set(shield, "height", 0);
        G.set(shield, "enableRightButton", true);
        G.set(shield, "onPush", (event:Dynamic) -> {
            G.set(event, "propagate", false);
            close();
        });
        bar = G.create("h2d.Object", [root]);
        menu = G.create("h2d.Object", [root]);
        G.call("h2d.Object", "set_visible", menu, [false]);
    }

    public function bindFont(source:Void->Dynamic):Void {
        fontSource = source;
    }

    public function bindIcons(draw:Dynamic->String->Void):Void {
        drawIcon = draw;
    }

    var dockKey:String = "";

    /** A fixed column inside the expanded dialog, not stretched across the big map. */
    public function layoutDock(x:Float, y:Float, height:Float):Void {
        var shortcuts = MinimapMenu.shortcuts();
        var count = shortcuts.length;
        if (count == 0) return;
        var gap = 4.0;
        var button = 36.0;
        var stack = button * count + gap * (count - 1);
        if (height > 0 && stack > height) {
            var fit = height / stack;
            button *= fit;
            gap *= fit;
        }
        var key = Std.int(x) + ":" + Std.int(y) + ":" + Std.int(button * 10) + ":" + count;
        if (key == dockKey && chips.length == count) return;
        dockKey = key;
        var spots:Array<ButtonSpot> = [];
        for (index in 0...count) spots.push({x: x, y: y + index * (button + gap), size: button});
        build(spots, -1, false);
    }

    public function layout(nextSize:Int, round:Bool):Void {
        if (nextSize == size && round == circular && chips.length > 0 && dockKey == "") return;
        dockKey = "";
        build(MinimapButtonLayout.spots(nextSize, round), nextSize, round);
    }

    function build(spots:Array<ButtonSpot>, nextSize:Int, round:Bool):Void {
        size = nextSize;
        circular = round;
        close();
        clear(bar);
        chips = [];
        var shortcuts = MinimapMenu.shortcuts();
        if (shortcuts.length == 0 || spots.length == 0) return;
        for (index in 0...spots.length) {
            var shortcut = shortcuts[index];
            var spot = spots[index];
            var chip = G.create("h2d.Object", [bar]);
            G.call("h2d.Object", "setPosition", chip, [spot.x, spot.y]);
            var background = G.create("h2d.Graphics", [chip]);
            var icon = G.create("h2d.Graphics", [chip]);
            var hit = G.create("h2d.Interactive", [spot.size, spot.size, chip, null]);
            G.set(hit, "isEllipse", circular);
            var cursor = G.current("hxd.Cursor", "Default");
            if (cursor != null) G.call("h2d.Interactive", "set_cursor", hit, [cursor]);
            G.set(hit, "enableRightButton", true);
            var id = shortcut.id;
            G.set(hit, "onOver", (_:Dynamic) -> hovered = id);
            G.set(hit, "onOut", (_:Dynamic) -> if (hovered == id) hovered = "");
            G.set(hit, "onPush", (event:Dynamic) -> {
                if (button(event) != 1) return;
                G.set(event, "propagate", false);
                if (openId == id) close();
                else open(id);
            });
            G.set(hit, "onClick", (event:Dynamic) -> {
                if (button(event) != 0) return;
                G.set(event, "propagate", false);
                var current = MinimapMenu.find(id);
                if (current == null || config == null) return;
                MinimapMod.setToggles(MinimapMenu.masterValues(config, current.masters));
                close();
                paint();
            });
            chips.push({id: id, x: spot.x, y: spot.y, width: spot.size, height: spot.size,
                background: background, icon: icon, hit: hit});
        }
        drawIcons();
        paint();
    }

    public function redrawIcons():Void {
        drawIcons();
        paint();
    }

    public function sync(config:MinimapSettings):Void {
        this.config = config;
        paint();
    }

    public function place(x:Float, y:Float, screenWidth:Float, screenHeight:Float):Void {
        originX = x;
        originY = y;
        this.screenWidth = screenWidth;
        this.screenHeight = screenHeight;
        G.call("h2d.Object", "setPosition", root, [x, y]);
        if (openId != "") {
            G.call("h2d.Object", "setPosition", shield, [-originX, -originY]);
            G.set(shield, "width", screenWidth);
            G.set(shield, "height", screenHeight);
        }
    }

    public function show(visible:Bool):Void {
        G.call("h2d.Object", "set_visible", root, [visible]);
        if (!visible) close();
    }

    public function caption():String {
        if (hovered == "" || config == null) return "";
        var shortcut = MinimapMenu.find(hovered);
        if (shortcut == null) return "";
        return shortcut.label + (MinimapMenu.lit(config, shortcut.masters) ? ": On" : ": Off");
    }

    public function dispose():Void {
        close();
        if (root != null) G.call("h2d.Object", "remove", root);
        root = null;
        chips = [];
        rows = [];
    }

    function open(id:String):Void {
        var shortcut = MinimapMenu.find(id);
        var chip = chipById(id);
        if (shortcut == null || chip == null || config == null) return;
        openId = id;
        G.call("h2d.Object", "set_visible", shield, [true]);
        place(originX, originY, screenWidth, screenHeight);
        buildMenu(shortcut, chip);
    }

    function close():Void {
        openId = "";
        rows = [];
        clear(menu);
        if (shield != null) {
            G.call("h2d.Object", "set_visible", shield, [false]);
            G.set(shield, "width", 0);
            G.set(shield, "height", 0);
        }
        if (menu != null) G.call("h2d.Object", "set_visible", menu, [false]);
    }

    function buildMenu(shortcut:MenuShortcut, chip:Chip):Void {
        clear(menu);
        rows = [];
        var background = G.create("h2d.Graphics", [menu]);
        var font = font();
        if (font == null) { close(); return; }
        var scale = 13 / Math.max(1, G.number(G.field(font, "size"), 13));
        var width = 180.0;
        var labels:Array<Dynamic> = [];
        var title = text(font, scale, 0xfff3d6, shortcut.label);
        labels.push(title);
        width = Math.max(width, measured(title, scale) + 16);
        for (entry in shortcut.items) {
            var label = text(font, scale, 0xe6e0d6, entry.label);
            labels.push(label);
            width = Math.max(width, measured(label, scale) + 36);
        }
        var rowHeight = 22.0;
        var height = rowHeight * (shortcut.items.length + 1) + 8;
        // Open toward the map so the list stays on screen beside the right-hand column.
        var x = chip.x - width - 2;
        var y = chip.y;
        if (originX + x < 4) x = chip.x + chip.width + 2;
        if (originY + y + height > screenHeight - 4) y = screenHeight - 4 - height - originY;
        if (originY + y < 4) y = 4 - originY;
        G.call("h2d.Object", "setPosition", menu, [x, y]);
        fillRect(background, 0, 0, width, height, 0x1c1814, 0.98);
        fillRect(background, 0, 0, width, 1, 0xb39888, 1);
        fillRect(background, 0, height - 1, width, 1, 0xb39888, 1);
        fillRect(background, 0, 0, 1, height, 0xb39888, 1);
        fillRect(background, width - 1, 0, 1, height, 0xb39888, 1);
        var blocker = G.create("h2d.Interactive", [width, height, menu, null]);
        G.set(blocker, "enableRightButton", true);
        G.set(blocker, "onPush", (event:Dynamic) -> G.set(event, "propagate", false));
        G.set(blocker, "onClick", (event:Dynamic) -> G.set(event, "propagate", false));
        placeText(title, 8, 4);
        for (index in 0...shortcut.items.length) {
            var entry = shortcut.items[index];
            var top = 4 + rowHeight * (index + 1);
            var box = G.create("h2d.Graphics", [menu]);
            G.call("h2d.Object", "setPosition", box, [8, top + 4]);
            paintBox(box, MinimapMenu.checked(config, entry.key));
            placeText(labels[index + 1], 26, top + 3);
            var hit = G.create("h2d.Interactive", [width, rowHeight, menu, null]);
            G.call("h2d.Object", "setPosition", hit, [0, top - 1]);
            var key = entry.key;
            G.set(hit, "onClick", (event:Dynamic) -> {
                if (button(event) != 0) return;
                G.set(event, "propagate", false);
                if (config == null) return;
                var values:Map<String, Bool> = [];
                values.set(key, !MinimapMenu.checked(config, key));
                MinimapMod.setToggles(values);
                paint();
            });
            rows.push({key: key, box: box});
        }
        G.call("h2d.Object", "set_visible", menu, [true]);
    }

    function paint():Void {
        if (config == null) return;
        for (chip in chips) {
            var shortcut = MinimapMenu.find(chip.id);
            if (shortcut == null) continue;
            var on = MinimapMenu.lit(config, shortcut.masters);
            G.call("h2d.Graphics", "clear", chip.background);
            if (circular) {
                var radius = chip.width / 2;
                fillCircle(chip.background, radius, radius, radius, on ? 0xe7d7b1 : 0x4a4338, 1);
                fillCircle(chip.background, radius, radius, Math.max(1, radius - 1.25), 0x17202b, 0.94);
            } else {
                fillRect(chip.background, 0, 0, chip.width, chip.height, 0x17202b, 0.94);
                fillRect(chip.background, 0, 0, chip.width, 1, on ? 0xe7d7b1 : 0x4a4338, 1);
                fillRect(chip.background, 0, chip.height - 1, chip.width, 1, on ? 0xe7d7b1 : 0x4a4338, 1);
                fillRect(chip.background, 0, 0, 1, chip.height, on ? 0xe7d7b1 : 0x4a4338, 1);
                fillRect(chip.background, chip.width - 1, 0, 1, chip.height, on ? 0xe7d7b1 : 0x4a4338, 1);
            }
            G.set(chip.icon, "alpha", on ? 1 : 0.35);
        }
        for (row in rows) paintBox(row.box, MinimapMenu.checked(config, row.key));
    }

    function drawIcons():Void {
        if (drawIcon == null) return;
        for (chip in chips) {
            G.call("h2d.Graphics", "clear", chip.icon);
            drawIcon(chip.icon, chip.id);
            var fit = switch (chip.id) {
                case "resources": 0.72;
                case "enemies", "npcs": 1.45;
                case "landmarks", "orbs": 0.9;
                default: 1;
            };
            var scale = Math.min(chip.width, chip.height) / 22 * fit;
            G.call("h2d.Object", "setScale", chip.icon, [scale]);
            G.call("h2d.Object", "setPosition", chip.icon, [chip.width / 2, chip.height / 2]);
        }
    }

    function paintBox(box:Dynamic, on:Bool):Void {
        G.call("h2d.Graphics", "clear", box);
        fillRect(box, 0, 0, 12, 12, 0x2a241f, 1);
        fillRect(box, 0, 0, 12, 1, 0xb39888, 1);
        fillRect(box, 0, 11, 12, 1, 0xb39888, 1);
        fillRect(box, 0, 0, 1, 12, 0xb39888, 1);
        fillRect(box, 11, 0, 1, 12, 0xb39888, 1);
        if (on) fillRect(box, 3, 3, 6, 6, 0xffc14a, 1);
    }

    function text(font:Dynamic, scale:Float, color:Int, value:String):Dynamic {
        var label = G.create("h2d.Text", [font, menu]);
        G.call("h2d.Text", "set_text", label, [value]);
        G.call("h2d.Text", "set_textColor", label, [color]);
        G.call("h2d.Object", "setScale", label, [scale]);
        return label;
    }

    function placeText(label:Dynamic, x:Float, y:Float):Void {
        G.call("h2d.Object", "setPosition", label, [x, y]);
    }

    function measured(label:Dynamic, scale:Float):Float {
        return G.number(G.call("h2d.Text", "get_textWidth", label)) * scale;
    }

    function font():Dynamic {
        var face = null;
        if (fontSource != null) try face = fontSource() catch (_:Dynamic) face = null;
        if (face == null) try face = G.staticCall("hxd.res.DefaultFont", "get", []) catch (_:Dynamic) face = null;
        return face;
    }

    function chipById(id:String):Chip {
        for (chip in chips) if (chip.id == id) return chip;
        return null;
    }

    static function button(event:Dynamic):Int
        return G.integer(G.field(event, "button"));

    static function fillCircle(graphics:Dynamic, x:Float, y:Float, radius:Float, color:Int, alpha:Float):Void {
        G.call("h2d.Graphics", "beginFill", graphics, [color, alpha]);
        G.call("h2d.Graphics", "drawCircle", graphics, [x, y, radius, 32]);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    static function fillRect(graphics:Dynamic, x:Float, y:Float, width:Float, height:Float, color:Int, alpha:Float):Void {
        G.call("h2d.Graphics", "beginFill", graphics, [color, alpha]);
        G.call("h2d.Graphics", "drawRect", graphics, [x, y, width, height]);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    static function clear(object:Dynamic):Void {
        if (object == null) return;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        while (count > 0) {
            G.call("h2d.Object", "remove", G.call("h2d.Object", "getChildAt", object, [0]));
            count--;
        }
    }
}
