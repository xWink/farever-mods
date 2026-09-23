package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectUi.*;

/** A separate native UnitScene, never the player's world model or editable sheet. */
class InspectPreview {
    var object:Dynamic;
    var hero:Dynamic;
    var appliedSignature:String;
    public static inline var WIDTH = 328;
    public static inline var HEIGHT = 556;

    public function new(parent:Dynamic, hero:Dynamic) {
        this.hero = hero;
        object = G.field(node("unit-scene", parent, [hero, null], "itemUtilitiesInspectPreview"), "obj");
        padding(object, 0); size(object, WIDTH, HEIGHT);
        absolute(G.field(parent, "obj"), object);
        G.set(object, "autoFit", true); style(object, "auto-fit", true);
        // Native auto-fit adds padding in world units, not as a scale factor.
        // Keep a small margin so its first fit does not zoom the hero far out.
        G.set(object, "viewPadding", 0.12); style(object, "view-padding", 0.12);
        var scene = G.field(object, "unitScene");
        padding(scene, 0); size(scene, WIDTH, HEIGHT);
        absolute(object, scene); position(scene, 0, 0);
        G.set(object, "needFit", 4);
    }

    public function isFor(hero:Dynamic):Bool return this.hero == hero;

    public function update(signature:String, x:Int, y:Int):Void {
        position(object, x, y);
        var view = G.field(object, "unitView");
        if (signature == appliedSignature || view == null || G.call("client.UnitView", "isReady", view) != true) return;
        // This view belongs only to our render-to-texture scene. Native visuals
        // read the inspected hero's equipment, appearance, and body settings.
        G.set(view, "forcedWeaponHolster", false);
        G.call("client.UnitView", "updateDynamicVisuals", view, [null]);
        G.call("ui.comp.UnitScene", "setAnim", object, ["Idle"]);
        G.set(object, "needFit", 4);
        appliedSignature = signature;
    }

    public function dispose():Void {
        // Scene.onRemove disposes its private scene and render texture.
        if (object != null) G.call("h2d.Object", "remove", object);
        object = null; hero = null;
    }
}
