package minimap;

import minimap.GameAccess as G;
import minimap.MarkerDetails.MarkerMeasurement;

private typedef MeasurementSlot = {
    text:Dynamic, shadow:Dynamic, arrow:Dynamic, arrowShadow:Dynamic,
    direction:String, label:String
};

/** A compact distance row whose arrow glyphs do not depend on native font coverage. */
class HoverMeasurements {
    var root:Dynamic;
    var separator:Dynamic;
    var slots:Array<MeasurementSlot> = [];
    var count:Int = 0;
    var fontScale:Float;
    var width:Float = 0;
    var ink:Int = 0xd0ccc2;
    var shade:Int = 0x171b24;

    public function new(parent:Dynamic, font:Dynamic) {
        root = G.create("h2d.Object", [parent]);
        fontScale = 12 / Math.max(1, G.number(G.field(font, "size"), 12));
        for (_ in 0...2) {
            var shadow = G.create("h2d.Text", [font, root]);
            var text = G.create("h2d.Text", [font, root]);
            var arrowShadow = G.create("h2d.Graphics", [root]);
            var arrow = G.create("h2d.Graphics", [root]);
            G.call("h2d.Text", "set_textColor", shadow, [0x171b24]);
            G.call("h2d.Text", "set_textColor", text, [0xd0ccc2]);
            for (object in [shadow, text]) G.call("h2d.Object", "setScale", object, [fontScale]);
            slots.push({text: text, shadow: shadow, arrow: arrow, arrowShadow: arrowShadow, direction: "", label: ""});
        }
        separator = G.create("h2d.Graphics", [root]);
        for (shadow in [true, false]) {
            var offset = shadow ? 1 : 0;
            G.call("h2d.Graphics", "beginFill", separator, [shadow ? 0x171b24 : 0xd0ccc2, 1.]);
            G.call("h2d.Graphics", "drawCircle", separator, [offset, offset, 1., 8]);
            G.call("h2d.Graphics", "endFill", separator);
        }
        G.call("h2d.Object", "set_visible", root, [false]);
    }

    public function setInk(textColor:Int, shadowColor:Int):Void {
        if (ink == textColor && shade == shadowColor) return;
        ink = textColor;
        shade = shadowColor;
        for (slot in slots) {
            G.call("h2d.Text", "set_textColor", slot.text, [ink]);
            G.call("h2d.Text", "set_textColor", slot.shadow, [shade]);
            slot.direction = "";
        }
        G.call("h2d.Graphics", "clear", separator);
        for (shadow in [true, false]) {
            var offset = shadow ? 1 : 0;
            G.call("h2d.Graphics", "beginFill", separator, [shadow ? shade : ink, 1.]);
            G.call("h2d.Graphics", "drawCircle", separator, [offset, offset, 1., 8]);
            G.call("h2d.Graphics", "endFill", separator);
        }
    }

    public function setValues(values:Array<MarkerMeasurement>):Void {
        count = values.length;
        width = 0;
        var height = 12.;
        for (i in 0...slots.length) {
            var slot = slots[i], visible = i < count;
            for (object in [slot.text, slot.shadow, slot.arrow, slot.arrowShadow])
                G.call("h2d.Object", "set_visible", object, [visible]);
            if (!visible) continue;
            var value = values[i];
            if (slot.direction != value.direction) {
                drawArrow(slot.arrowShadow, value.direction, shade);
                drawArrow(slot.arrow, value.direction, ink);
                slot.direction = value.direction;
            }
            var label = value.metres + " m";
            if (slot.label != label) {
                for (text in [slot.shadow, slot.text]) G.call("h2d.Text", "set_text", text, [label]);
                slot.label = label;
            }
            height = Math.max(height, G.number(G.call("h2d.Text", "get_textHeight", slot.text)) * fontScale);
            if (i > 0) width += 12;
            position(slot.text, width + 16, 0);
            position(slot.shadow, width + 17, 1);
            // Save the arrow's x here; align both arrows vertically after measuring the row.
            position(slot.arrow, width, 0);
            position(slot.arrowShadow, width + 1, 1);
            width += 16 + G.number(G.call("h2d.Text", "get_textWidth", slot.text)) * fontScale;
            if (i == 0) position(separator, width + 6, 0);
        }
        for (i in 0...count) {
            var slot = slots[i], y = (height - 12) / 2;
            position(slot.arrow, G.number(G.field(slot.arrow, "x")), y);
            position(slot.arrowShadow, G.number(G.field(slot.arrowShadow, "x")), y + 1);
        }
        position(separator, G.number(G.field(separator, "x")), height / 2);
        G.call("h2d.Object", "set_visible", separator, [count > 1]);
        G.call("h2d.Object", "set_visible", root, [count > 0]);
    }

    public function place(centerX:Float, y:Float, maxWidth:Float):Void {
        if (count == 0) return;
        var scale = Math.min(1, maxWidth / Math.max(1, width));
        G.call("h2d.Object", "setScale", root, [scale]);
        position(root, centerX - width * scale / 2, y);
    }

    public static function drawArrow(graphics:Dynamic, direction:String, color:Int):Void {
        G.call("h2d.Graphics", "clear", graphics);
        var coords:Array<Float> = switch direction {
            case "horizontal": [0, 6, 4, 2, 4, 5, 8, 5, 8, 2, 12, 6, 8, 10, 8, 7, 4, 7, 4, 10];
            case "vertical": [6, 0, 10, 4, 7, 4, 7, 8, 10, 8, 6, 12, 2, 8, 5, 8, 5, 4, 2, 4];
            default: [6, 0, 10, 4, 7, 4, 7, 12, 5, 12, 5, 4, 2, 4];
        };
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.]);
        for (i in 0...Std.int(coords.length / 2)) {
            var x = coords[i * 2], y = coords[i * 2 + 1];
            if (direction == "down") { x = 12 - x; y = 12 - y; }
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", graphics, [x, y]);
        }
        G.call("h2d.Graphics", "lineTo", graphics,
            [direction == "down" ? 12 - coords[0] : coords[0], direction == "down" ? 12 - coords[1] : coords[1]]);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    static function position(object:Dynamic, x:Float, y:Float):Void
        G.call("h2d.Object", "setPosition", object, [x, y]);
}
