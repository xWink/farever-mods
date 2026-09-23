package itemutilities;

typedef InspectTipBounds = {xMin:Float, yMin:Float, xMax:Float, yMax:Float};

/** Fit the entire rendered tip, including comparisons left of its origin. */
class InspectTooltipPlacement {
    public static function fit(x:Float, y:Float, bounds:InspectTipBounds, viewport:InspectTipBounds):{x:Float, y:Float, scale:Float} {
        var width = bounds.xMax - bounds.xMin, height = bounds.yMax - bounds.yMin;
        var availableWidth = viewport.xMax - viewport.xMin, availableHeight = viewport.yMax - viewport.yMin;
        if (width <= 0 || height <= 0 || availableWidth <= 0 || availableHeight <= 0)
            return {x: x, y: y, scale: 1};
        var scale = Math.min(1, Math.min(availableWidth / width, availableHeight / height));
        return {
            x: Math.max(viewport.xMin - bounds.xMin * scale, Math.min(x, viewport.xMax - bounds.xMax * scale)),
            y: Math.max(viewport.yMin - bounds.yMin * scale, Math.min(y, viewport.yMax - bounds.yMax * scale)),
            scale: scale
        };
    }
}
