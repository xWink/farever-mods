package itemutilities;

import itemutilities.InspectAccess as G;

/** Native modal input; no extra input hooks or always-on-top controls. */
class NativePresetRename {
    static var generation = 0;
    public static function invalidate():Void generation++;

    public static function open(ui:Dynamic, initial:String, valid:Void->Bool, save:String->Void):Void {
        if (ui == null || !valid()) return;
        var token = ++generation;
        var dialog = G.call("ui.BaseUI", "displayTextInputDialog", ui, [
            "Rename preset", "Maximum 15 characters. Leave empty to restore the default name.", initial,
            (value:Dynamic) -> {
                if (token != generation || !valid()) return;
                generation++;
                save(PresetNames.clean(G.text(value)));
            }, () -> { if (token == generation) generation++; }
        ]);
        var box = G.field(dialog, "input"), input = G.field(box, "input");
        if (input == null) return;
        // InputBox forwards native typing/paste events to this callback.
        // Enforce the limit here as well as at confirmation, without trimming
        // spaces while someone is still typing a multi-word name.
        G.set(box, "onChange", () -> {
            var value = G.text(G.field(input, "text"));
            var limited = PresetNames.limit(value);
            if (limited == value) return;
            G.call("h2d.TextInput", "set_text", input, [limited]);
            for (key in ["cursorIndex", "selectionIndex"])
                if (G.integer(G.field(input, key), -1) > limited.length) G.set(input, key, limited.length);
        });
    }
}
