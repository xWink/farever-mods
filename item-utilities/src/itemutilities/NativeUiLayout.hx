package itemutilities;

import haxe.ds.ObjectMap;
import hlx.runtime.ResolvedMember;

/** Refresh native layout every frame; never retain coordinates across a resize. */
class NativeUiLayout {
    static var objectType:hl.Bytes;
    static var syncPosMember:ResolvedMember;
    static var getSceneMember:ResolvedMember;
    static var getBoundsMember:ResolvedMember;
    static var getCameraMember:ResolvedMember;
    static var errorLogged = false;
    static var transforms = new ObjectMap<Dynamic, UiOverlayGeometry>();
    static var projections = new ObjectMap<Dynamic, UiOverlayGeometry>();
    static var scenes = new ObjectMap<Dynamic, Dynamic>();
    static var bounds = new ObjectMap<Dynamic, OverlayRect>();

    public static function beginFrame():Void {
        transforms.clear();
        projections.clear();
        scenes.clear();
        bounds.clear();
    }

    static function resolve():Bool {
        if (objectType == null) objectType = HlxRuntime.resolveType("h2d.Object");
        if (objectType == null) return false;
        if (syncPosMember == null) syncPosMember = HlxRuntime.resolveMember(objectType, "syncPos");
        if (getSceneMember == null) getSceneMember = HlxRuntime.resolveMember(objectType, "getScene");
        if (getBoundsMember == null) getBoundsMember = HlxRuntime.resolveMember(objectType, "getBounds");
        if (getCameraMember == null) {
            var sceneType = HlxRuntime.resolveType("h2d.Scene");
            if (sceneType != null) getCameraMember = HlxRuntime.resolveMember(sceneType, "get_camera");
        }
        return syncPosMember != null && getSceneMember != null
            && getBoundsMember != null && getCameraMember != null;
    }

    static inline function number(object:Dynamic, name:String):Float {
        var value:Dynamic = HlxRuntime.resolveField(object, name);
        return value == null ? Math.NaN : cast value;
    }

    static function matrix(object:Dynamic):UiOverlayGeometry {
        return new UiOverlayGeometry(number(object, "matA"), number(object, "matB"),
            number(object, "matC"), number(object, "matD"),
            number(object, "absX"), number(object, "absY"));
    }

    static function projection(object:Dynamic):UiOverlayGeometry {
        var scene = scenes.get(object);
        if (scene == null) {
            scene = HlxRuntime.callResolved(getSceneMember, [object]);
            if (scene == null) return null;
            scenes.set(object, scene);
        }
        if (projections.exists(scene)) return projections.get(scene);
        var camera = HlxRuntime.callResolved(getCameraMember, [scene]);
        if (camera == null) return null;
        // Match h2d.Camera.cameraX/YToScreen: camera matrix, viewport scale,
        // then the scene's pixel offset (including letterboxing).
        var screen = matrix(camera).then(new UiOverlayGeometry(
            number(scene, "viewportScaleX"), 0, 0, number(scene, "viewportScaleY"),
            number(scene, "offsetX"), number(scene, "offsetY")));
        projections.set(scene, screen);
        return screen;
    }

    static function transform(object:Dynamic):UiOverlayGeometry {
        if (object == null || !resolve()) return null;
        if (transforms.exists(object)) return transforms.get(object);
        // absX/absY and matA..D can be stale after a parent moves or scales.
        HlxRuntime.callResolved(syncPosMember, [object]);
        var screen = projection(object);
        var result = screen == null ? null : matrix(object).then(screen);
        transforms.set(object, result);
        return result;
    }

    public static function rect(object:Dynamic, x:Float, y:Float,
        width:Float, height:Float):OverlayRect {
        try {
            var layout = transform(object);
            return layout == null ? null : layout.rect(x, y, width, height);
        } catch (error:Dynamic) {
            logError(error);
            return null;
        }
    }

    public static function localRect(object:Dynamic, pixels:OverlayRect):OverlayRect {
        if (pixels == null || !pixels.valid()) return null;
        try {
            var screen = transform(object);
            var local = screen == null ? null : screen.inverse();
            return local == null ? null : local.rect(pixels.left, pixels.top, pixels.width, pixels.height);
        } catch (error:Dynamic) {
            logError(error);
            return null;
        }
    }

    public static function objectBounds(object:Dynamic, inset:Float):OverlayRect {
        try {
            if (object == null || !resolve()) return null;
            if (!bounds.exists(object)) {
                // getBounds(null, null) is in scene coordinates, not pixels.
                var native = HlxRuntime.callResolved(getBoundsMember, [object, null, null]);
                bounds.set(object, native == null ? null : new OverlayRect(
                    number(native, "xMin"), number(native, "yMin"),
                    number(native, "xMax"), number(native, "yMax")));
            }
            var native = bounds.get(object);
            if (native == null) return null;
            var screen = projection(object);
            return screen == null ? null : screen.rect(native.left + inset, native.top + inset,
                native.width - 2 * inset, native.height - 2 * inset);
        } catch (error:Dynamic) {
            logError(error);
            return null;
        }
    }

    /** Window occlusion includes blank panel space, not only drawable children. */
    public static function windowBounds(window:Dynamic):OverlayRect {
        if (window == null) return null;
        // Heaps getBounds() asks getBoundsRec(..., false), so a Flow's layout
        // rectangle is not included. Custom windows with absolute children can
        // therefore report only fragments of their visible frame/content.
        // calculatedWidth/Height describe the full panel in its own UI units;
        // rect applies its current transform, camera, and viewport exactly once.
        var width = number(window, "calculatedWidth");
        var height = number(window, "calculatedHeight");
        if (Math.isFinite(width) && Math.isFinite(height) && width > 0 && height > 0) {
            var panel = rect(window, 0, 0, width, height);
            if (panel != null) return panel;
        }
        return objectBounds(window, 0);
    }

    static function logError(error:Dynamic):Void {
        if (errorLogged) return;
        errorLogged = true;
        trace("[Item Utilities] Unable to project UI overlay: " + error);
    }
}
