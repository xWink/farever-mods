package itemutilities;

class SkillPresetLayout {
    public static function place(footer:OverlayRect, text:OverlayRect, controls:OverlayRect):OverlayRect {
        if (footer == null || text == null || controls == null
            || !footer.valid() || !text.valid() || !controls.valid()) return null;
        var padding = 16 * controls.width / PresetSlots.CONTROLS_WIDTH;
        var gap = footer.right - text.right - 2 * padding;
        if (gap <= 0) return null;
        var scale = Math.min(1, Math.min(gap / controls.width, footer.height / controls.height));
        var width = controls.width * scale;
        var height = controls.height * scale;
        var x = footer.right - padding - width;
        var y = (footer.top + footer.bottom - height) * 0.5;
        return new OverlayRect(x, y, x + width, y + height);
    }
}
