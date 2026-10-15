import dpsmeter.ReportMode;

class ReportModeTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function main():Void {
        var mode = new ReportMode();
        var windows = [false, false, false];
        for (index in 0...3) { var i = index; mode.subscribe(value -> windows[i] = value); }
        for (source in 0...3) {
            mode.setHealing(!windows[source]);
            check(windows[0] == windows[1] && windows[1] == windows[2], "A click from any window synchronizes all three");
        }
        mode.toggle();
        check(!mode.healing && windows.indexOf(true) < 0, "Hotkey toggles the shared mode once");
        mode.setHealing(true);
        var reopened = false; mode.subscribe(value -> reopened = value);
        check(reopened, "New or reopened windows immediately inherit the current mode");
        var callbacks = 0; mode.subscribe(_ -> callbacks++);
        mode.setHealing(true);
        check(callbacks == 1, "Setting the current mode does not cause recursive updates");
        mode.toggle();
        check(!reopened && windows.indexOf(true) < 0, "All subscribers follow the next toggle");
        Sys.println('Shared report mode: $checks checks passed.');
    }
}
