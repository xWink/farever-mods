package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;

class CharacterLockHooks {
    @:hlx.postfix(ui.win.CharacterSelectScreen.init)
    static function initialized(instance:Dynamic, result:Void):Void {
        try CharacterLocks.attach(instance) catch (error:Dynamic) CharacterLocks.report(error);
    }
    @:hlx.prefix(ui.UIElement.set_enable)
    static function enableButton(instance:Dynamic, value:Bool):HlxPrefixResult<Bool> {
        // The native menu enables Delete again every update, after its general
        // busy-state check. Intercept only our tracked Delete buttons to avoid
        // repeatedly enabling/disabling them and rebuilding hover styles.
        if (value && CharacterLocks.preventEnable(instance)) {
            if (G.field(instance, "enable") != false) G.call("ui.UIElement", "set_enable", instance, [false]);
            return SkipWith(false);
        }
        return Continue;
    }
    @:hlx.prefix(ui.win.CharacterSelectScreen.onDeleteCharacterPressed)
    static function beforeDelete(instance:Dynamic):HlxPrefixResult<Void> {
        return CharacterLocks.blocksDeletion(instance, G.field(instance, "currentSelected")) ? Skip : Continue;
    }
    @:hlx.prefix(ui.win.CharacterSelectScreen.requestCharacterDeletion)
    static function beforeRequest(instance:Dynamic, info:Dynamic):HlxPrefixResult<Void> {
        // Check the dialog's captured character, not a later selection.
        return CharacterLocks.blocksDeletion(instance, info) ? Skip : Continue;
    }
    @:hlx.prefix(ui.win.CharacterMenuScreen.onRemove)
    static function removed(instance:Dynamic):HlxPrefixResult<Void> {
        CharacterLocks.forget(instance);
        return Continue;
    }
}
