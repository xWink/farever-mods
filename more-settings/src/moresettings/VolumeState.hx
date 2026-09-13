package moresettings;

import moresettings.SettingsData.MoreSettingsConfig;

/** One saved master volume, shared by overlapping temporary volume limits. */
class VolumeState {
    public var active(default, null):Bool = false;
    public var saved(default, null):Float = 1;

    public function new() {}

    public static function target(config:MoreSettingsConfig, focused:Bool, traveling:Bool):Null<Float> {
        var result:Null<Float> = null;
        if (!focused && config.adjustUnfocusedVolume) result = SettingsData.percent(config.backgroundVolume) / 100;
        if (traveling && config.adjustFastTravelVolume) {
            var travel = SettingsData.percent(config.fastTravelVolume) / 100;
            result = result == null ? travel : Math.min(result, travel);
        }
        return result;
    }

    public function apply(current:Float, target:Null<Float>):Float {
        if (target == null) {
            if (!active) return current;
            active = false;
            return saved;
        }
        if (!active) { saved = current; active = true; }
        // Temporary limits never make a quieter master setting louder.
        return Math.min(saved, target);
    }

    public function masterChanged(current:Float):Void {
        if (active) saved = current;
    }
}
