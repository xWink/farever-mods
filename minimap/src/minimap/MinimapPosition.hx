package minimap;

/** Positions the full frame, including its border, within the scaled HUD. */
class MinimapPosition {
    public static inline var MARGIN = 24.0;

    public static function percent(value:Float):Int {
        return Math.isFinite(value) ? Math.round(Math.max(0, Math.min(100, value))) : 0;
    }

    public static function axis(viewport:Float, extent:Float, offset:Float, reverse:Bool = false):Float {
        var available = Math.max(0, viewport - extent);
        // On unusually small windows, reduce both margins equally to stay visible.
        var margin = Math.min(MARGIN, available / 2);
        var travel = available - margin * 2;
        var fraction = percent(offset) / 100;
        return margin + travel * (reverse ? 1 - fraction : fraction);
    }

    /** Outer frame covering 80% of the screen, centered on both axes. */
    public static function overview(screenWidth:Float, screenHeight:Float):{x:Float, y:Float, width:Float, height:Float} {
        var width = Math.max(1, screenWidth * 0.8);
        var height = Math.max(1, screenHeight * 0.8);
        return {x: (screenWidth - width) / 2, y: (screenHeight - height) / 2, width: width, height: height};
    }
}
