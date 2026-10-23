package minimap;

/** Independent map switches, preserving an existing disabled preference. */
class MapVisibility {
    public static function migrate(config:MinimapSettings):Void {
        var previous = config.enabled != false;
        if (config.mainMapEnabled == null) config.mainMapEnabled = previous;
        if (config.minimapEnabled == null) config.minimapEnabled = previous;
        Reflect.deleteField(config, "enabled");
    }
}
