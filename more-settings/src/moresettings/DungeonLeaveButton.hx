package moresettings;

import moresettings.GameAccess as G;

/** Reuse the native instance-leave button for dungeons and rifts. */
class DungeonLeaveButton {
    public static var enabled:Bool = true;
    public static var riftEnabled:Bool = true;
    static var nativeCaption="";
    static var riftCaption=false;
    static var hud:Dynamic;
    static var button:Dynamic;
    static var reportedError:Bool = false;

    public static function attach(instance:Dynamic):Void {
        hud = instance;
        button = G.field(instance, "leaveBtn");
        nativeCaption=G.text(G.field(G.field(button,"btnText"),"text"));
        riftCaption=false;
        // init's native bindUpdate has already run once. Apply to that initial
        // state too; subsequent updates use the game's existing callback.
        if (button != null)
            G.call("ui.UIElement", "set_visible", button, [G.field(button, "visible") == true]);
    }

    public static function visibility(instance:Dynamic, nativeValue:Bool):Bool {
        // This hook also sees other UI elements; reject those without reflection.
        if (button == null || instance != button) return nativeValue;
        if (G.field(hud, "removed") == true) return nativeValue;
        var player = G.call("ui.BaseElement", "get_myPlayer", hud);
        var layer = G.field(player, "layer");
        var activity=G.field(layer,"mainActivity");
        var rift=G.isA(activity,"st.activity.Rift");
        var showRift=rift&&riftEnabled;
        if(showRift!=riftCaption) {
            // Update only the label: Button.setText rebuilds the button and its bindings.
            var label=G.field(button,"btnText");
            if(label!=null)G.call("ui.comp.FmtText","set_text",label,[showRift?"Leave Rift":nativeCaption]);
            riftCaption=showRift;
        }
        if (!showRift && !(enabled&&G.isA(activity,"st.activity.Dungeon"))) return nativeValue;
        // Rifts can also be left while dead, even if the encounter is still active.
        // A missing hero must never expose a stale leave button.
        var hero=G.field(player,"hero");
        return hero!=null && (G.field(hero,"isInCombat")==false
            || (showRift && G.call("ent.GameObject","isDead",hero)==true));
    }

    public static function clear():Void {
        hud = null;
        button = null;
        nativeCaption="";riftCaption=false;
    }

    public static function reportError(error:Dynamic):Void {
        if (reportedError) return;
        reportedError = true;
        trace("[More Settings] Leave instance button: " + Std.string(error));
    }
}
