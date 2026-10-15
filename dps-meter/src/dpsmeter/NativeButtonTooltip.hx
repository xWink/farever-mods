package dpsmeter;

import dpsmeter.GameAccess as G;

/** Native title-only tips that fit their text and refresh while still hovered. */
class NativeButtonTooltip {
    static inline var MAX_TEXT_WIDTH = 360;

    public static function set(button:Dynamic, text:String):Void {
        G.set(button, "textTip", text);
        G.call("ui.UIElement", "set_getTip", button, [function():Dynamic {
            var tip = G.create("ui.SimpleTip", [LiteralText.escape(text), null, null]);
            // Measure again after native CSS has supplied the final font and padding.
            var previousReflow = G.field(tip, "onAfterReflow");
            var measuredAfterStyles = false;
            G.set(tip, "onAfterReflow", function():Void {
                // Flow calls this method unconditionally on every reflow.
                // Keep it callable, including after our one-time measurement.
                if (previousReflow != null) Reflect.callMethod(tip, previousReflow, []);
                if (!measuredAfterStyles) {
                    measuredAfterStyles = true;
                    fit(tip, text);
                }
            });
            fit(tip, text);
            return tip;
        }]);

        var visible = G.field(G.current("ui.BaseUI", "current"), "currentTip");
        if (visible == null || G.field(visible, "anchor") != button) return;
        var content = G.field(visible, "tipContent");
        var title = G.field(content, "title");
        if (title == null) return;
        // Changing getTip only affects the next hover. Update the existing tip
        // in place as well, preserving its anchor and appearance animation.
        G.set(content, "titleText", LiteralText.escape(text));
        NativeUi.setText(title, text);
        fit(content, text);
    }

    static function fit(tip:Dynamic, text:String):Void {
        var title = G.field(tip, "title");
        if (title == null) return;
        G.call("ui.comp.FmtText", "set_textMultiline", title, [true]);
        G.call("h2d.Text", "set_lineBreak", title, [true]);
        G.call("ui.comp.FmtText", "set_useEllipsis", title, [false]);
        G.call("ui.comp.FmtText", "set_maxWidthText", title, [null]);
        var scale = Math.max(.01, G.number(G.field(title, "scaleX"), 1));
        var wrapWidth = MAX_TEXT_WIDTH / scale;
        G.call("h2d.Text", "set_maxWidth", title, [wrapWidth]);
        // A detached Text has no stale parent width constraint from the previous tip.
        var measure = G.create("h2d.Text", [G.field(title, "font"), null]);
        G.call("h2d.Text", "set_letterSpacing", measure, [G.number(G.field(title, "letterSpacing"))]);
        G.call("h2d.Text", "set_lineBreak", measure, [true]);
        G.call("h2d.Text", "set_maxWidth", measure, [wrapWidth]);
        G.call("h2d.Text", "set_text", measure, [text]);
        // FmtText's bold glyph overhang and the native header inset are not
        // included in Text.textWidth. Leave breathing room at the right edge.
        var width = Math.ceil(G.number(G.call("h2d.Text", "get_textWidth", measure)) * scale) + 28;
        // SimpleTip's header has nested flows. Remove their fixed minimums too,
        // retaining each flow's own padding and the game's background/border.
        var flow = G.field(title, "parent");
        while (flow != null) {
            width += G.integer(G.field(flow, "paddingLeft")) + G.integer(G.field(flow, "paddingRight"));
            if (G.field(flow, "fillWidth") == true) {
                G.call("h2d.Flow", "set_fillWidth", flow, [false]);
                NativeUi.style(flow, "fill-width", false);
            }
            if (G.integer(G.field(flow, "minWidth"), -1) != width
                || G.integer(G.field(flow, "maxWidth"), -1) != width)
                NativeUi.size(flow, width);
            if (flow == tip) break;
            flow = G.field(flow, "parent");
        }
    }
}
