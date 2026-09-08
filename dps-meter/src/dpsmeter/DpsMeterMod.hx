package dpsmeter;

import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixResult;
import dpsmeter.GameAccess as G;

@:build(hlx.runtime.Mod.build())
class DpsMeterMod {
    static var config:MeterConfig;
    static var collector:Collector;
    static var view:NativeMeterWindow;
    static var writer:RunWriter;
    static var lastError:Float = -100;
    static var lastErrorMessage:String = "";
    static function main():Void {
        config = new MeterConfig(); config.load();
        collector = new Collector(config);
        view = new NativeMeterWindow(config);
        writer = new RunWriter();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> config.load());
        trace("[DpsMeter] Initialized; uploader deferred until the first game update");
    }
    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMeterAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return NativeMeterWindow.constructing ? Skip : Continue;
    }
    @:hlx.prefix(ent.Unit.rpcReceiveDamage__impl)
    static function onDamage(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void> {
        if (collector != null) try collector.damage(instance, damage, haxe.Timer.stamp()) catch (e:Dynamic) logError("damage collection", e);
        return Continue;
    }
    @:hlx.postfix(ent.Hero.onEnterCombat)
    static function onCombatEnter(instance:Dynamic, result:Void):Void {
        if (collector != null && config.enabled) try collector.model.onCombatEnter(G.uid(instance), haxe.Timer.stamp())
        catch (e:Dynamic) logError("combat entry", e);
    }
    @:hlx.postfix(ent.Hero.onLeaveCombat)
    static function onCombatExit(instance:Dynamic, result:Void):Void {
        // This callback runs before set_isInCombat stores false. Observe the
        // actual exit event instead of polling that field or another party member.
        if (collector != null && config.enabled) try collector.model.onCombatExit(G.uid(instance), haxe.Timer.stamp())
        catch (e:Dynamic) logError("combat exit", e);
    }
    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        if (collector == null) return;
        var now = haxe.Timer.stamp();
        var operation = "hotkeys";
        try {
            if (G.staticCall("hxd.Key", "isPressed", [config.toggleHotkey]) == true) {
                config.visible = !config.visible; config.save();
            }
            if (G.staticCall("hxd.Key", "isPressed", [config.unlockHotkey]) == true) {
                config.unlocked = !config.unlocked; config.save();
            }
            operation = "party/profile update";
            if (config.enabled) collector.update(instance, now);
            operation = "report export";
            while (collector.model.completed.length > 0) {
                var fight = collector.model.completed.shift();
                if (config.sendLogs) writer.enqueue(fight);
            }
            operation = "uploader update";
            writer.update(now);
        } catch (e:Dynamic) logError(operation, e);
        // A UI failure must never stop the collector or discard a finished report.
        try view.update(collector.model, G.field(instance, "hero") != null, now) catch (e:Dynamic) logError("window update", e);
    }
    static function logError(operation:String, error:Dynamic):Void {
        var now = haxe.Timer.stamp();
        if (now - lastError <= 5) return;
        lastError = now;
        var message = operation + ": " + error;
        trace("[DpsMeter] " + message);
        // Include the failing call site once per distinct error, not a full
        // repeated stack every five seconds. This logger's line isn't its cause.
        if (message != lastErrorMessage) {
            lastErrorMessage = message;
            try {
                var stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack(true).slice(0, 8));
                if (stack != "") trace("[DpsMeter] " + stack);
            } catch (_:Dynamic) {}
        }
    }
}
