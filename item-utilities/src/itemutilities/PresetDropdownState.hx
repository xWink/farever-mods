package itemutilities;

/** An open menu belongs to one preset bar and expires when that bar disappears. */
class PresetDropdownState {
    var kind = -1;
    var drawn = false;
    var bounds:OverlayRect;
    public function new() {}

    public function beginFrame():Void drawn = false;
    public function endFrame():Void { if (!drawn) clear(); }
    public function clear():Void { kind = -1; bounds = null; }
    public function isOpen():Bool return kind >= 0;

    public function inputBounds():OverlayRect {
        return isOpen() && bounds != null && bounds.valid() ? bounds : null;
    }
    public function update(category:Int, open:Bool, ?area:OverlayRect):Void {
        if (open) { kind = category; bounds = area; drawn = true; }
        else if (kind == category) clear();
    }

    public function covered(category:Int, tooltip:Bool, window:Bool):Bool
        return window || (tooltip && kind != category);

    public function blocksTooltip(x:Float, y:Float):Bool
        return kind >= 0 && bounds != null && bounds.valid()
            && x >= bounds.left && x < bounds.right && y >= bounds.top && y < bounds.bottom;
}
