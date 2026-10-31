import bettermodsettings.NativeDropdown;
import bettermodsettings.DropdownSetting;

private enum PointerKind { EPush; ERelease; EMove; EWheel; }

class NativeDropdownTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function main():Void {
        var control:Dynamic = {items:[], open:true, closes:0, listWindow:{}, selectedIndex:0};
        var saves = 0;
        var refresh = NativeDropdown.configure(control,
            DropdownSetting.parse({label:"Mode", options:["Low", "High"]}), "High", _ -> { saves++; return true; });
        check(control.selectedIndex == 1 && saves == 0, "Initialization preserves the selected value silently");
        HlxRuntime.ui.target = {parent:control.listWindow};
        NativeDropdown.onPointerEvent({kind:EPush});
        check(control.open, "Clicking an option still reaches the native dropdown");
        HlxRuntime.ui.target = {parent:control};
        NativeDropdown.onPointerEvent({kind:EPush});
        check(control.open, "Clicking the dropdown button still toggles normally");
        var wheel:Dynamic = {kind:EWheel, wheelDelta:1., cancel:false, propagate:true};
        var reads = HlxRuntime.topElementReads;
        NativeDropdown.onPointerEvent(wheel);
        check(!control.open && control.closes == 1, "Wheel input immediately closes the dropdown even over its own button");
        check(!wheel.cancel && wheel.propagate && wheel.wheelDelta == 1., "Dismissing the dropdown preserves native scrolling");
        check(saves == 0 && control.selectedIndex == 1, "Scrolling never selects or saves an option");
        check(HlxRuntime.topElementReads == reads, "Wheel dismissal works without hit testing");
        control.open = true; HlxRuntime.ui.target = {};
        NativeDropdown.onPointerEvent({kind:EPush});
        check(!control.open, "Outside-click dismissal remains intact");
        control.open = true;
        NativeDropdown.onPointerEvent({kind:ERelease}); NativeDropdown.onPointerEvent({kind:EMove});
        check(control.open, "Mouse movement and release do not dismiss an option before selection");
        var container:Dynamic = {scrollPosY:20.};
        NativeDropdown.watchScroll(container);
        NativeDropdown.onScroll({}, 50.); NativeDropdown.onScroll(container, 20.);
        check(control.open, "Unrelated scrolling and unchanged positions leave the dropdown alone");
        NativeDropdown.onScroll(container, 50.);
        check(!control.open, "Scrollbar dragging or keyboard scrolling also dismisses the dropdown");
        control.open = true; NativeDropdown.onScroll(container, 50.);
        check(control.open, "Reopening at the current position is stable");
        refresh("Low");
        check(control.selectedIndex == 0 && saves == 0, "External setting refresh remains silent");
        NativeDropdown.closeAll(true);
        control.open = true;
        NativeDropdown.onPointerEvent(wheel); NativeDropdown.onScroll(container, 70.);
        check(control.open, "Closing settings releases old controls and the watched scroll container");
        Sys.println('Native dropdown: $checks checks passed.');
    }
}
