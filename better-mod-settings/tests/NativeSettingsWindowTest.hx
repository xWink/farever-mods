import bettermodsettings.NativeSettingsWindow;

class NativeSettingsWindowTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function main():Void {
        var menu:Dynamic = {windowFlags:32, dom:{}};
        for (inWorld in [false, true]) {
            HlxRuntime.liveWorld = inWorld;
            var window = NativeSettingsWindow.create(menu);
            check(window.dom != null && window.allocated, "Native DOM initializes at character select and in game");
            check(window.windowFlags == menu.windowFlags && window.setFlagsOnce,
                "Menu lifetime flags are set through the native setter before rebuild");
            check(!NativeSettingsWindow.creating, "Constructor scope ends after success");
        }
        var unrelated:Dynamic = {windowFlags:1 | 65536};
        NativeSettingsWindow.beforeRebuild(unrelated);
        check(unrelated.windowFlags == (1 | 65536), "Other native windows keep their normal world requirements");
        HlxRuntime.failWindowConstruction = true;
        var failed = false;
        try NativeSettingsWindow.create(menu) catch (_:Dynamic) failed = true;
        check(failed && !NativeSettingsWindow.creating, "Constructor failure clears the temporary scope");
        NativeSettingsWindow.beforeRebuild(unrelated);
        check(unrelated.windowFlags == (1 | 65536), "A failed construction cannot change later native windows");
        HlxRuntime.failWindowConstruction = false;
        check(NativeSettingsWindow.create(menu).dom != null, "Opening can be retried after failure");
        check(menu.windowFlags == 32 && menu.dom != null, "Opening preserves the Game Menu");
        Sys.println('Native settings window: $checks checks passed.');
    }
}
