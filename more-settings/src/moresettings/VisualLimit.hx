package moresettings;

/** Dropdown presets. A negative count delegates entirely to the game. */
class VisualLimit {
    public static final damage = new VisualLimit(10, 25, 50, 200, "Medium");
    public static final bees = new VisualLimit(2, 10, 30, 100, "Max");
    public static final bomblets = new VisualLimit(5, 25, 50, 100, "Max");
    static final choices = ["None", "Low", "Medium", "High", "Max"];
    final low:Int;
    final medium:Int;
    final high:Int;
    final legacyMax:Int;
    final fallback:String;

    function new(low:Int, medium:Int, high:Int, legacyMax:Int, fallback:String) {
        this.low=low;this.medium=medium;this.high=high;
        this.legacyMax=legacyMax;this.fallback=fallback;
    }

    public function count(choice:String):Int return switch choice {
        case "None": 0;
        case "Low": low;
        case "Medium": medium;
        case "High": high;
        default: -1;
    };

    public function normalize(value:Dynamic):String {
        if (Std.isOfType(value, String) && choices.indexOf(cast value) >= 0)
            return cast value;
        if (value == null) return fallback;
        // Older versions saved numeric sliders. Keep zero hidden and migrate
        // positive values to the nearest preset, including the old maximum.
        var number=Std.parseFloat(Std.string(value));
        if (!Math.isFinite(number)) return fallback;
        if (number <= 0) return "None";
        var values=[low, medium, high, legacyMax];
        var best=0;
        for (i in 1...values.length)
            if (Math.abs(number-values[i]) <= Math.abs(number-values[best])) best=i;
        return choices[best+1];
    }
}
