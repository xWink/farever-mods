package bettermodsettings;

/** Uses Farever's options dropdown and its separate, unclipped list window. */
class NativeDropdown {
    static var controls:Array<Dynamic> = [];
    static var arraySlice:hlx.runtime.ResolvedMember;
    static var arrayPush:hlx.runtime.ResolvedMember;
    static var setOptions:hlx.runtime.ResolvedMember;
    static var initIndex:hlx.runtime.ResolvedMember;
    static var isOpen:hlx.runtime.ResolvedMember;
    static var close:hlx.runtime.ResolvedMember;
    static var baseUI:hl.Bytes;
    static var topElement:hlx.runtime.ResolvedMember;
    static var contains:hlx.runtime.ResolvedMember;

    public static function configure(control:Dynamic, setting:DropdownSetting, value:Dynamic, save:String->Bool):Dynamic->Void {
        if (arraySlice == null) arraySlice = member("hl.types.ArrayObj", "slice");
        if (arrayPush == null) arrayPush = member("hl.types.ArrayObj", "pushDyn");
        if (setOptions == null) setOptions = member("ui.comp.Dropdown", "set_options");
        if (initIndex == null) initIndex = member("ui.comp.Dropdown", "initSelectedIndex");
        if (isOpen == null) isOpen = member("ui.comp.Dropdown", "isOpen");
        if (close == null) close = member("ui.comp.Dropdown", "close");
        if (baseUI == null) baseUI = HlxRuntime.resolveType("ui.BaseUI");
        if (topElement == null) topElement = member("ui.BaseUI", "getTopInteractiveElement");
        if (contains == null) contains = member("h2d.Object", "contains");
        // The constructor's items array is native ArrayObj. A local
        // Array<Dynamic> would be ArrayDyn and cannot be passed to set_options.
        var items = HlxRuntime.resolveField(control, "items");
        if (items == null) throw "Native dropdown items are unavailable.";
        var options = HlxRuntime.callResolved(arraySlice, [items, 0, 0]);
        if (options == null) throw "Native dropdown options could not be created.";
        for (index in 0...setting.options.length)
            HlxRuntime.callResolved(arrayPush, [options,
                {name: setting.options[index], value: index, icon: null, group: null}]);
        HlxRuntime.callResolved(setOptions, [control, options]);
        var selected = setting.selectedIndex(value);
        HlxRuntime.callResolved(initIndex, [control, selected]);
        // Initialization is silent. Resolve a selected index back to the local
        // descriptor String, avoiding foreign String internals in saved JSON.
        // onSelectOption also fires when choosing the displayed first option
        // of a missing/invalid config value; onValueChanged would skip that save.
        HlxRuntime.setField(control, "onSelectOption", function(_:Dynamic):Void {
            var index = HlxRuntime.resolveField(control, "selectedIndex");
            var text = setting.valueAt(index);
            if (text != null && save(text)) selected = cast index;
            else HlxRuntime.callResolved(initIndex, [control, selected]);
        });
        controls.push(control);
        return function(value:Dynamic):Void {
            selected = setting.selectedIndex(value);
            HlxRuntime.callResolved(initIndex, [control, selected]);
        };
    }

    /** Run after native hit testing, without consuming or changing the click. */
    public static function onPointerEvent(event:Dynamic):Void {
        if (controls.length == 0
            || Type.enumConstructor(HlxRuntime.resolveField(event, "kind")) != "EPush") return;
        var target:Dynamic = null;
        var targetResolved = false;
        for (control in controls) try {
            if (HlxRuntime.callResolved(isOpen, [control]) != true) continue;
            if (!targetResolved) {
                var ui = HlxRuntime.resolveStaticField(baseUI, "current");
                if (ui == null) return;
                target = HlxRuntime.callResolved(topElement, [ui, null]);
                targetResolved = true;
            }
            var list = HlxRuntime.resolveField(control, "listWindow");
            // The list is a separate window, not a descendant of its button.
            // Native ancestry checks also account for UI scaling and scrolling.
            if (inside(control, target) || inside(list, target)) continue;
            HlxRuntime.callResolved(close, [control, null]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not dismiss dropdown: " + Std.string(error));
        }
    }

    static function inside(root:Dynamic, target:Dynamic):Bool
        return root != null && target != null
            && (root == target || HlxRuntime.callResolved(contains, [root, target]) == true);

    public static function closeAll(clear:Bool = false):Void {
        for (control in controls) try {
            if (HlxRuntime.callResolved(isOpen, [control]) == true)
                HlxRuntime.callResolved(close, [control, null]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not close dropdown: " + Std.string(error));
        }
        if (clear) controls = [];
    }

    static function member(typeName:String, name:String):hlx.runtime.ResolvedMember {
        var type = HlxRuntime.resolveType(typeName);
        var result = type == null ? null : HlxRuntime.resolveMember(type, name);
        if (result == null) throw "Native member unavailable: " + typeName + "." + name;
        return result;
    }
}
