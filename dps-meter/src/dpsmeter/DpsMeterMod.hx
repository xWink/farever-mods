package dpsmeter;

import dpsmeter.MeterConfig.MeterSettings;
import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;
import dpsmeter.GameAccess as G;

@:build(hlx.runtime.Mod.build())
class DpsMeterMod {
    @:hlx.config
    static var config:MeterSettings = MeterConfig.defaults();
    static var collector:Collector;
    static var view:NativeMeterWindow;
    static var recapView:NativeRiftRecapWindow;
    static var kills:KillNotifications;
    static var writer:RunWriter;
    static function main():Void {
        if (ConfigMigration.importLegacy()) reloadConfig();
        else if (!ConfigMigration.hasNative()) MeterConfig.importLegacy(config);
        MeterConfig.normalize(config);
        saveConfig();
        collector = new Collector(config);
        view = new NativeMeterWindow(config);
        recapView = new NativeRiftRecapWindow();
        kills = new KillNotifications(config);
        writer = new RunWriter();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> reloadConfig());
    }
    static function reloadConfig():Void {
        var loaded = ModConfig.load(HlxRuntime.moduleName(), config);
        // The collector and UI share this object; keep their reference live.
        for (key in Reflect.fields(loaded))
            Reflect.setField(config, key, Reflect.field(loaded, key));
        MeterConfig.normalize(config);
    }

    public static function saveConfig():Void {
        try config.save() catch (_:Dynamic) {}
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMeterAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return NativeMeterWindow.constructing || NativeRiftRecapWindow.constructing ? Skip : Continue;
    }
    @:hlx.prefix(ui.notify.NotifyManager.queue)
    static function positionKillPopup(instance:Dynamic, notification:Dynamic):HlxPrefixResult<Void> {
        // These native text components have their own screen placement/lifetime.
        return NativeKillPopups.constructing ? Skip : Continue;
    }
    @:hlx.prefix(st.Player.onUnitKilledIncremented__impl)
    static function replaceCodexKillPopup(instance:Dynamic, unitId:String, completed:Bool):HlxPrefixResult<Void> {
        // Keep the native reward notification; replace only its recurring count.
        return config != null && config.enabled && !completed && G.field(instance, "isMe") == true ? Skip : Continue;
    }
    @:hlx.postfix(st.player.Progress.networkSync)
    static function onProgressSync(instance:Dynamic, context:Dynamic, result:Void):Void {
        if (kills != null) kills.synced(instance);
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
                config.visible = !config.visible; saveConfig();
            }
            if (G.staticCall("hxd.Key", "isPressed", [config.unlockHotkey]) == true) {
                config.unlocked = !config.unlocked; saveConfig();
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
        try kills.update(instance, now) catch (_:Dynamic) {}
    }
}
