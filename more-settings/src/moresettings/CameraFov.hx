package moresettings;

class CameraFov {
    public static function adjust(nativeFov:Float, overrideFov:Float, percent:Int):Float {
        if (overrideFov > 0 || percent == 100 || !Math.isFinite(nativeFov)) return nativeFov;
        return Math.max(1, Math.min(179, nativeFov * Math.max(50, Math.min(150, percent)) / 100));
    }
}
