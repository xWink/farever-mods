package minimap;

/** Normalize layout choices before saving, preserving the old shape checkbox. */
class MinimapLayout {
    public static function migrate(config:MinimapSettings):Void {
        if (config.minimapShape != "Circular" && config.minimapShape != "Square")
            config.minimapShape = config.circular == false ? "Square" : "Circular";
        if (config.filterButtonPosition != "Right") config.filterButtonPosition = "Left";
        Reflect.deleteField(config, "circular");
    }
}
