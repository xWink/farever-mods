package moresettings;

import moresettings.GameAccess as G;
import modinput.Hotkey;

/** Separate the player-menu hold from Interact's revive/loot/NPC press. */
class SocialInteract {
    public static inline var ACTION = "MoreSettingsSocialInteract";
    public var enabled(default, null) = false;
    public var inHeroCheck(default, null) = false;
    public var inBindingCheck(default, null) = false;
    var keyCode = -1;
    var modifier:Null<Int> = null;
    var cached:Array<{source:Dynamic, mode:Dynamic, replacement:Dynamic}> = [];

    public function new() {}

    public function configure(enabled:Bool, binding:Dynamic, refreshExisting:Bool = true):Void {
        binding = Hotkey.normalize(binding);
        var keyCode = Hotkey.isBound(binding) ? Hotkey.code(binding) : -1;
        var modifier = Hotkey.modifier(binding);
        if (this.enabled == enabled && this.keyCode == keyCode && this.modifier == modifier) return;
        this.enabled = enabled;
        this.keyCode = keyCode;
        this.modifier = modifier;
        cached = [];
        if (refreshExisting) clearPresses();
    }

    public function usesHotkey():Bool
        return enabled && G.staticCall("gamepad.Pad", "get_active", []) != true;

    public function checkHero(controller:Dynamic):Void {
        // Re-enter just this native method, with exception-safe scope cleanup.
        // The hook lets the inner call through, retaining all native eligibility,
        // distance, combat, resurrection, and menu-position checks.
        inHeroCheck = true;
        try G.call("client.PlayerController", "tryInteractHero", controller)
        catch (error:Dynamic) { inHeroCheck = false; throw error; }
        inHeroCheck = false;
    }

    public function longPressed():Bool {
        // The alias owns its native hold/buffer records. Using "Interact" here
        // would make a short social tap turn into a loot/NPC press on release.
        return G.staticCall("lib.Input", "isLongPressed", [ACTION]) == true;
    }

    public function checkInput(keyboard:Dynamic, pad:Dynamic):Bool {
        if (!enabled) return false;
        var ui = G.current("ui.BaseUI", "current");
        if (ui != null && G.call("ui.BaseUI", "getFocusedTextInput", ui) != null) return false;
        // Delegate mode/modifier/cinematic/console checks to Interact. Only its
        // temporary binding list changes during this call; no Data/input edits.
        var previous = inBindingCheck;
        inBindingCheck = true;
        var result:Bool;
        try result = G.staticCall("lib.Input", "checkInput", ["Interact", keyboard, pad]) == true
        catch (error:Dynamic) { inBindingCheck = previous; throw error; }
        inBindingCheck = previous;
        return result;
    }

    public function bindings(result:Dynamic):Dynamic {
        if (!enabled || result == null) return result;
        var length = G.integer(G.field(result, "length"));
        for (i in 0...length) {
            var source = G.call("hl.types.ArrayObj", "getDyn", result, [i]);
            if (source == null || G.field(source, "padCode") != null) continue;
            var mode = G.field(source, "mode");
            var replacement:Dynamic = null;
            for (entry in cached) if (entry.source == source && entry.mode == mode) {
                replacement = entry.replacement;
                break;
            }
            if (replacement == null) {
                replacement = {
                    code: (keyCode < 0 ? null : keyCode : Null<Int>),
                    mode: (mode == null ? null : G.integer(mode) : Null<Int>),
                    modifier: modifier,
                    padCode: null
                };
                if (cached.length >= 8) cached = [];
                cached.push({source: source, mode: mode, replacement: replacement});
            }
            // getBindings returns a reusable native scratch array. Never mutate
            // the default/user binding records or save over the game's controls.
            G.call("hl.types.ArrayObj", "setDyn", result, [i, replacement]);
        }
        return result;
    }

    public function getBindings():Dynamic
        return bindings(G.staticCall("lib.Input", "getBindings", ["Interact"]));

    static function heroWidget(input:Dynamic):Dynamic {
        var parent = G.field(input, "parent");
        while (parent != null) {
            if (G.isA(parent, "ui.hud.HeroWidget")) return parent;
            parent = G.field(parent, "parent");
        }
        return null;
    }

    public function attachHint(input:Dynamic):Void {
        var action = G.field(input, "input");
        if (action != "Interact" && action != ACTION) return;
        var widget = heroWidget(input);
        if (widget == null) return;
        // Native init clears old callbacks. This callback follows the native
        // progress callback (which unfortunately hardcodes "Interact").
        G.call("ui.UIElement", "bindUpdate", input, [(_:Float) -> {
            try updateHint(input, widget) catch (error:Dynamic) SocialHooks.report(error);
        }]);
    }

    public function updateHint(input:Dynamic, widget:Dynamic):Void {
        var hero = G.field(widget, "hero");
        var social = usesHotkey() && hero != null && G.call("ent.GameObject", "isDead", hero) != true;
        var action = social ? ACTION : "Interact";
        if (G.field(input, "input") != action) {
            G.set(input, "input", action);
            G.call("ui.UIElement", "rebuild", input);
            return;
        }
        if (!social) return;
        var progress = G.number(G.staticCall("lib.Input", "getLongPressProgress", [ACTION]));
        var offset = G.number(G.current("ui.comp.LongInputKey", "OFFSET"));
        G.call("ui.comp.RadialFillImage", "set_progress", G.field(input, "fill"),
            [progress == 0 ? 0.0 : Math.max(offset, progress)]);
    }

    function clearPresses():Void {
        for (name in ["longPresses", "bufferedPresses"]) {
            var map = G.current("lib.Input", name);
            if (map != null) G.call("haxe.ds.StringMap", "remove", map, [ACTION]);
        }
    }

    public function dispose():Void {
        inHeroCheck = false;
        inBindingCheck = false;
        cached = [];
        clearPresses();
    }
}
