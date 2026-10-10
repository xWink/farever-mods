import moresettings.GameAccess as G;
import moresettings.SocialHooks;
import moresettings.SocialInteract;
import moresettings.SettingsData;
import hlx.runtime.HlxPrefixResult;

class SocialInteractTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function value<T>(result:HlxPrefixResult<T>):T return switch result {
        case SkipWith(value): value;
        default: throw 'Expected native override, got $result';
    };
    static function main():Void {
        var config = SettingsData.defaults();
        eq(config.rebindSocialInteract, false, "Existing controls remain the default");
        eq(config.socialInteractKey, 0, "New hotkey starts unassigned");
        for (invalid in [-1, 27, 512, 999]) {
            config.socialInteractKey = invalid; SettingsData.normalize(config);
            eq(config.socialInteractKey, 0, "Invalid/reserved key becomes unassigned");
        }
        for (valid in [0, 1, 65, 113, 511]) {
            config.socialInteractKey = valid; SettingsData.normalize(config);
            eq(config.socialInteractKey, valid, "Valid single keyboard/mouse key preserved");
        }
        var binding = @:privateAccess SocialHooks.interact;
        eq(@:privateAccess SocialHooks.socialInteract({}), Continue, "Disabled controller hook is native");
        var original:Dynamic = {code:70,mode:2,modifier:1,padCode:null};
        var pad:Dynamic = {code:null,mode:2,modifier:null,padCode:"A"};
        G.defaultBindings = [original, pad];
        G.longPresses.set("Interact", {lastFrame:100});
        G.bufferedPresses.set("Interact", 100.0);
        binding.configure(true, 82);
        var normal = G.defaultBindings.copy();
        eq(@:privateAccess SocialHooks.socialBindingRead("Interact", normal), normal, "Regular Interact binding array untouched");
        eq(normal[0], original, "Regular Interact still uses original binding");
        eq(@:privateAccess SocialHooks.socialBindings("Interact"), Continue, "Regular binding lookup stays native");
        eq(@:privateAccess SocialHooks.socialInput("Interact", null, null), Continue, "Loot/NPC/revive checks stay native");
        eq(@:privateAccess SocialHooks.socialHold("Interact"), Continue, "Other Interact holds stay native");
        var social:Array<Dynamic> = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0].code, 82, "Social hint uses chosen hotkey");
        eq(social[0].modifier, null, "Does not inherit normal Interact's modifier");
        eq(social[0].mode, 2, "Native input mode preserved");
        eq(social[1], pad, "Pad binding preserved");
        eq(original.code, 70, "Saved/default Interact key not mutated");
        eq(original.modifier, 1, "Saved/default Interact modifier not mutated");
        var cached = social[0];
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0], cached, "Repeated hints reuse binding records");
        binding.configure(true, 82);
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0], cached, "Unrelated config changes preserve binding cache");

        var keyboard:Dynamic = (code:Int) -> code == 82;
        var gamepad:Dynamic = (_:Dynamic) -> false;
        var allowed = true;
        G.onInputCheck = (action, keyCheck, padCheck) -> {
            eq(action, "Interact", "Native input flags and cinematic rules come from Interact");
            var bindings:Array<Dynamic> = G.staticCall("lib.Input", "getBindings", [action]);
            eq(bindings[0].code, 82, "Only alias's nested native check sees social binding");
            if (keyCheck != null) {
                eq(keyCheck, keyboard, "Native keyboard callback forwarded unchanged");
                eq(padCheck, gamepad, "Native controller callback forwarded unchanged");
            }
            return allowed;
        };
        eq(value(@:privateAccess SocialHooks.socialInput(SocialInteract.ACTION, keyboard, gamepad)), true, "Eligible native input accepted");
        eq(binding.inBindingCheck, false, "Binding scope ends after poll");
        allowed = false;
        eq(value(@:privateAccess SocialHooks.socialInput(SocialInteract.ACTION, keyboard, gamepad)), false, "Native blocking cannot be bypassed");
        allowed = true;
        G.ui = {textInput:{}};
        eq(value(@:privateAccess SocialHooks.socialInput(SocialInteract.ACTION, keyboard, gamepad)), false, "Typing cannot open player menus");
        G.ui = null;

        G.onHeroCheck = () -> {
            eq(@:privateAccess SocialHooks.socialInteract({}), Continue, "Inner native call executes exactly once");
            var revive = G.defaultBindings.copy();
            eq(@:privateAccess SocialHooks.socialBindingRead("Interact", revive), revive, "Revive press within the same hero method stays native");
            eq(revive[0], original, "Revive uses the original key even inside social scope");
            eq(@:privateAccess SocialHooks.socialHold("Other"), Continue, "Unrelated holds unaffected");
            eq(value(@:privateAccess SocialHooks.socialHold("Interact")), true, "Native social hold gets the replacement input");
        };
        eq(@:privateAccess SocialHooks.socialInteract({}), Skip, "Wrapped native call is not executed twice");
        eq(G.heldAction, SocialInteract.ACTION, "Hold uses a separate native action identity");
        eq(G.bufferedPresses.get("Interact"), 100.0, "Social release cannot create a loot/NPC/revive buffered press");
        eq(G.bufferedPresses.get(SocialInteract.ACTION), 101.0, "Social release buffer is isolated");
        eq(binding.inHeroCheck, false, "Hero scope ends after native call");
        G.padActive = true;
        eq(@:privateAccess SocialHooks.socialInteract({}), Continue, "Controller retains complete native press/hold behavior");
        G.padActive = false;

        G.onInputCheck = (_, _, _) -> throw "native input failed";
        try binding.checkInput(keyboard, gamepad) catch (_:Dynamic) {}
        eq(binding.inBindingCheck, false, "Native exception cannot leak altered bindings into normal Interact");
        G.onHeroCheck = () -> throw "native hero check failed";
        try binding.checkHero({}) catch (_:Dynamic) {}
        eq(binding.inHeroCheck, false, "Native exception cannot leak social scope");

        var hero:Dynamic = {dead:false};
        var widget:Dynamic = {type:"ui.hud.HeroWidget",hero:hero};
        var hint:Dynamic = {parent:widget,input:"Interact",fill:{progress:0.0},rebuilds:0,callbacks:[]};
        binding.attachHint(hint);
        eq(hint.input, SocialInteract.ACTION, "Living player's hint switches to social key");
        eq(hint.rebuilds, 1, "Hint rebuilt only when action changes");
        var update:Float->Void = hint.callbacks[0];
        G.holdProgress = 0.5; update(0);
        eq(hint.fill.progress, 0.5, "Player ring follows social hold progress");
        eq(hint.rebuilds, 1, "Unchanged frames do not rebuild the hint");
        G.holdProgress = 0.05; update(0);
        eq(hint.fill.progress, 0.15, "Native ring minimum retained");
        G.holdProgress = 0; update(0);
        eq(hint.fill.progress, 0.0, "Ring clears after release");
        hero.dead = true; update(0);
        eq(hint.input, "Interact", "Dead ally displays the regular revive key");
        hero.dead = false; update(0);
        eq(hint.input, SocialInteract.ACTION, "Revived player returns to social key");
        G.padActive = true; update(0);
        eq(hint.input, "Interact", "Controller hint remains native");
        G.padActive = false;
        var other:Dynamic = {parent:{type:"ui.hud.InteractibleWidget"},input:"Interact",callbacks:[]};
        binding.attachHint(other);
        eq((cast other.callbacks:Array<Dynamic>).length, 0, "NPC/loot prompts receive no callback");

        config.socialInteractKey = haxe.Json.parse('{"code":82,"modifier":0}');
        SettingsData.normalize(config);
        binding.configure(true, config.socialInteractKey);
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0].code, 82, "modified social hint keeps main key");
        eq(social[0].modifier, 0, "native social hold receives Ctrl modifier");
        eq(social[0].mode, 2, "modified social hold retains native input mode");
        cached = social[0];
        G.longPresses.set(SocialInteract.ACTION, {lastFrame:100});
        binding.configure(true, {code:82,modifier:0});
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0], cached, "equivalent combination reuses social binding cache");
        eq(G.longPresses.exists(SocialInteract.ACTION), true, "unrelated reload does not interrupt a hold");
        binding.configure(true, {code:82,modifier:1});
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0].modifier, 1, "modifier-only social change updates native record");
        eq(G.longPresses.exists(SocialInteract.ACTION), false, "modifier-only change discards previous hold");
        eq(original.modifier, 1, "modified social input leaves saved Interact untouched");
        binding.configure(true, {code:0,modifier:2});
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0].code, 0, "modified social left click stays bound");
        eq(social[0].modifier, 2, "social left click modifier forwarded");
        binding.configure(true, 0);
        social = value(@:privateAccess SocialHooks.socialBindings(SocialInteract.ACTION));
        eq(social[0].code, null, "Unassigned social key disables keyboard inspection");
        eq(social[1], pad, "Unassigned keyboard leaves controller binding intact");
        eq(G.longPresses.exists(SocialInteract.ACTION), false, "Changing binding discards social hold");
        eq(G.bufferedPresses.exists(SocialInteract.ACTION), false, "Changing binding discards social release buffer");
        eq(G.longPresses.exists("Interact"), true, "Changing binding leaves normal hold alone");
        eq(G.bufferedPresses.get("Interact"), 100.0, "Changing binding leaves normal release buffer alone");
        binding.configure(false, 82); update(0);
        eq(hint.input, "Interact", "Disabling restores native hint immediately");
        eq(@:privateAccess SocialHooks.socialInteract({}), Continue, "Disabling restores native player inspection");
        binding.dispose();
        eq((@:privateAccess [for (_ in SocialHooks.reported.keys()) true]).length, 0, "No unexpected hook errors");
        Sys.println('Social interaction: $checks checks passed.');
    }
}
