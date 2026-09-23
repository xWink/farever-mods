import dpsmeter.MeterControllerFocus;
import dpsmeter.GameAccess as G;

class ControllerFocusTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function element(?parent:Dynamic, layer:Bool = false):Dynamic {
        var node:Dynamic = {parent:parent, children:[], allocated:false, visible:true,
            isBindLayer:layer, padFocusable:true, padDefaultFocus:true, padAlwaysFocusable:true,
            padClick:"UIAccept", padHover:"UIInspect", enableInteractive:true,
            dom:{styles:new Map<String, Dynamic>()}};
        if (parent != null) parent.children.push(node);
        return node;
    }
    static function assertPassive(node:Dynamic):Void {
        eq(node.isBindLayer, false, "not a controller input layer");
        eq(node.padFocusable, false, "not a controller focus target");
        eq(node.padDefaultFocus, false, "does not claim default focus");
        eq(node.padAlwaysFocusable, false, "no forced controller focus");
        eq(node.padClick, null, "no inherited controller click binding");
        eq(node.padHover, null, "no inherited controller inspection binding");
        eq(G.bindings.indexOf(node), -1, "native bindings removed");
    }
    static function main():Void {
        var game = element(null, true), meter = element(null, true);
        var wrapper:Dynamic = {parent:meter, children:[]}; meter.children.push(wrapper);
        var book = element(wrapper), nested = element(meter, true), row = element(nested);
        var clicks = 0, drags = 0;
        book.onClick = function() clicks++;
        var mouse:Dynamic = {parent:meter, children:[], onPush:function() drags++, cursor:"Move"};
        meter.children.push(mouse);
        G.attach(game); G.attach(meter);
        meter.windowFlags = 8192; // Existing construction leaves the native layer registered.
        eq(G.layers[G.layers.length - 1], nested, "reproduce meter taking controller focus");

        MeterControllerFocus.track(meter);
        assertPassive(meter); assertPassive(book); assertPassive(nested); assertPassive(row);
        eq(G.layers.length, 1, "only gameplay layer remains");
        eq(G.layers[0], game, "menu path can use default gameplay layer");
        eq(G.focused, null, "release focus from the meter's child");
        eq(book.enableInteractive, true, "mouse interaction stays enabled");
        book.onClick(); mouse.onPush();
        eq(clicks, 1, "history mouse click still runs"); eq(drags, 1, "drag callback still runs");
        eq(mouse.cursor, "Move", "drag cursor remains unchanged");

        // New player/skill rows can be added after the meter has been shown.
        var later = element(wrapper, true); G.attach(later);
        MeterControllerFocus.configureNode(later);
        assertPassive(later); eq(G.layers.length, 1, "new nodes release their own layer");
        for (node in [meter, book, later]) G.applyControllerStyles(node);
        eq(G.layers.length, 1, "hover/controller styles cannot re-register meter layers");
        eq(G.focused, null, "styles cannot restore automatic focus");
        meter.visible = false; meter.visible = true; G.attach(meter);
        eq(G.layers.length, 1, "hide/show/reattach keeps meter passive");

        var history = element(null, true); G.attach(history);
        MeterControllerFocus.configureNode(history);
        eq(history.isBindLayer, true, "separate history window is unaffected");
        eq(history.padFocusable, true, "other windows retain controller focus");
        eq(G.focused, history, "other window keeps its active focus");

        MeterControllerFocus.forget(meter);
        var detached = element(meter, true);
        MeterControllerFocus.configureNode(detached);
        eq(detached.isBindLayer, true, "disposed meter is no longer tracked");
        var rebuilt = element(null, true); G.attach(rebuilt);
        MeterControllerFocus.track(rebuilt); assertPassive(rebuilt);
        eq(G.layers[G.layers.length - 1], history, "rebuild preserves another window's layer");
        var rebuildRow = element(rebuilt); G.attach(rebuildRow);
        MeterControllerFocus.forget(meter); // An old owner cannot clear the new guard.
        MeterControllerFocus.configureNode(rebuildRow); assertPassive(rebuildRow);
        MeterControllerFocus.forget(rebuilt);
        Sys.println('Meter controller focus: $checks checks passed');
    }
}
