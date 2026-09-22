package itemutilities;

class AppearancePresetLayout {
    public static function place(button:OverlayRect, panel:OverlayRect, controls:OverlayRect):OverlayRect {
        if (button == null || panel == null || controls == null
            || !button.valid() || !panel.valid() || !controls.valid()) return null;
        var gap = 32 * controls.width / PresetSlots.CONTROLS_WIDTH;
        var room = button.left - panel.left - 2 * gap;
        if (room <= 0) return null;
        var scale = Math.min(1, room / controls.width);
        var width = controls.width * scale;
        var height = controls.height * scale;
        var x = button.left - gap - width;
        var y = (button.top + button.bottom - height) * 0.5;
        return new OverlayRect(x, y, x + width, y + height);
    }
}
