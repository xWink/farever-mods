package minimap;

/** The HUD layout regression does not load HLX or dispatch gameplay input. */
class MinimapMod {
    public static function adjustZoom(delta:Float):Void throw "Unexpected zoom input";
}
