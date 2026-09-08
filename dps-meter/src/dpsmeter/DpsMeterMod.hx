package dpsmeter;

import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixResult;
import dpsmeter.GameAccess as G;

@:build(hlx.runtime.Mod.build())
class DpsMeterMod {
    static var config:MeterConfig;
    static var collector:Collector;
    static var view:NativeMeterWindow;
    static var recapView:NativeRiftRecapWindow;
    static var writer:RunWriter;
    static function main():Void {
        config = new MeterConfig(); config.load();
        collector = new Collector(config);
        view = new NativeMeterWindow(config);
        recapView = new NativeRiftRecapWindow();
        writer = new RunWriter();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> config.load());
    }
    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMeterAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return NativeMeterWindow.constructing || NativeRiftRecapWindow.constructing ? Skip : Continue;
    }
    @:hlx.prefix(ent.Unit.rpcReceiveDamage__impl)
    static function onDamage(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void> {
        if (collector != null) try collector.damage(instance, damage, haxe.Timer.stamp()) catch (_:Dynamic) {}
        return Continue;
    }
    @:hlx.postfix(ent.Hero.onEnterCombat)
    static function onCombatEnter(instance:Dynamic, result:Void):Void {
        if (collector != null && config.enabled) try collector.model.onCombatEnter(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(ent.Hero.onLeaveCombat)
    static function onCombatExit(instance:Dynamic, result:Void):Void {
        // This callback runs before set_isInCombat stores false. Observe the
        // actual exit event instead of polling that field or another party member.
        if (collector != null && config.enabled) try collector.model.onCombatExit(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        if (collector == null) return;
        var now = haxe.Timer.stamp();
        try {
            if (G.staticCall("hxd.Key", "isPressed", [config.toggleHotkey]) == true) {
                config.visible = !config.visible; config.save();
            }
            if (G.staticCall("hxd.Key", "isPressed", [config.unlockHotkey]) == true) {
                config.unlocked = !config.unlocked; config.save();
            }
            if (config.enabled) collector.update(instance, now);
            while (collector.model.completed.length > 0) {
                var fight = collector.model.completed.shift();
                if (config.sendLogs) writer.enqueue(fight);
            }
            writer.update(now);
        } catch (_:Dynamic) {}
        // A UI failure must never stop the collector or discard a finished report.
        try view.update(collector.model, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
        try recapView.update(collector.model, config.enabled, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
    }
}
