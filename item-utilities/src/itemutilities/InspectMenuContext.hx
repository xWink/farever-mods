package itemutilities;

typedef InspectTarget = {
    var ui:Dynamic;
    var uid:String;
    var name:String;
}

/** Only the context menu built inside the player's social menu may be extended. */
class InspectMenuContext {
    var pending:InspectTarget;
    public function new() {}
    public function begin(ui:Dynamic, uid:String, name:String, enabled:Bool):Void {
        pending = enabled && ui != null && uid != null && uid != ""
            ? {ui: ui, uid: uid, name: name} : null;
    }
    public function take(ui:Dynamic):InspectTarget {
        if (pending == null || pending.ui != ui) return null;
        var target = pending;
        pending = null;
        return target;
    }
    public function clear():Void pending = null;
    public static function insertionIndex(labels:Array<String>, sendMessage:String):Int {
        // Compare the game's localized label, never an English translation.
        if (sendMessage == null || sendMessage == "") return -1;
        var index = labels.indexOf(sendMessage);
        return index < 0 ? -1 : index + 1;
    }
}
