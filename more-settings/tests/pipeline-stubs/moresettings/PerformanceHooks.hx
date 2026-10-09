package moresettings;

/** Unrelated driver lifecycle callbacks are not exercised by this test. */
class PerformanceHooks {
    public static function beginResourceFrame(driver:Dynamic):Void {}
    public static function endResourceFrame(driver:Dynamic):Void {}
    public static function recycleResources(allocator:Dynamic):Void {}
}
