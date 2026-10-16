package minimap;

/** Positions the full frame, including its border, within the scaled HUD. */
class MinimapPosition {
    public static inline var MARGIN = 24.0;

    /** Retire the old corner switch without moving an existing minimap. */
    public static function migrateCorner(config:MinimapSettings):Void {
        if (config.leftCorner == true) config.xOffset = 100 - percent(config.xOffset);
        Reflect.deleteField(config, "leftCorner");
    }

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
}
