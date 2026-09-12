package itemutilities;

// Keep synthetic presses confined to one controller's native tryInteract call.
// This class has no game/runtime dependencies so its scope can be regression-tested.
class QuickLootState {
    var inputController:Dynamic;
    var repeatController:Dynamic;
    var targetController:Dynamic;

    public function new() {}

    public function prepare(controller:Dynamic, enabled:Bool):Void {
        inputController = enabled ? controller : null;
        repeatController = null;
        targetController = null;
    }

    public function takeInput(key:String):Dynamic {
        if (key != "Interact") return null;
        var controller = inputController;
        inputController = null;
        return controller;
    }

    public function repeat(controller:Dynamic):Void {
        repeatController = controller;
    }

    public function beginInteraction(controller:Dynamic):Void {
        targetController = controller != null && repeatController == controller
            ? controller : null;
        repeatController = null;
    }

    public function filtersTarget(controller:Dynamic):Bool {
        return controller != null && targetController == controller;
    }

    public function endInteraction(controller:Dynamic):Void {
        if (targetController == controller) targetController = null;
    }

    public function finish(controller:Dynamic):Void {
        if (inputController == controller) inputController = null;
        if (repeatController == controller) repeatController = null;
        endInteraction(controller);
    }
}
