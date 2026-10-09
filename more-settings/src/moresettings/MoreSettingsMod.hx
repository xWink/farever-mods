package moresettings;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;
import modconfig.ConfigMigration;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

@:build(hlx.runtime.Mod.build())
class MoreSettingsMod {
    @:hlx.config
    static var config:MoreSettingsConfig = SettingsData.defaults();
    static var hideUi = new HideUiBinding();
    static var reportedInputError:Bool = false;
    static var reportedDamageNumberError:Bool = false;

    static function main():Void {
        var imported = ConfigMigration.importLegacy("more-audio-settings");
        if (!imported) imported = ConfigMigration.importLegacy("mute-unfocused");
        if (!imported) imported = ConfigMigration.importLegacy();
        if (imported) config = ModConfig.load(HlxRuntime.moduleName(), config);
        var previous = ModConfig.load(HlxRuntime.moduleName(), {
            disableProfanityFilter: (null:Null<Bool>)
        });
        if (previous.disableProfanityFilter == null) {
            // Preserve the standalone mod's preference when combining installs.
            config.disableProfanityFilter = previousProfanityPreference();
        }
        SettingsData.normalize(config);
        BossHealth.enabled = config.showBossHealth;
        PerformanceHooks.enabled = config.performanceOptimization;
        StallMetrics.configure(config.performanceDiagnostics);
        DungeonPartyGuard.enabled = config.waitForParty;
        NameplateColors.enabled = config.classColoredNames;
        NameplateWeapons.enabled = config.showNameplateWeapons;
        DungeonLeaveButton.enabled = config.leaveDungeonButton;
        CrabgantuaWarnings.configure(config.crabgantuaRockfallWarnings);
        MinionHealthBars.configure(config.hideAlliedMinionHealthBars);
        SocialHooks.configure(config, false);
        hideUi.configure(config.hideUiKey);
        config.save();
        AllyEffects.configure(config);
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            SettingsData.normalize(config);
            BossHealth.enabled = config.showBossHealth;
            PerformanceHooks.enabled = config.performanceOptimization;
            StallMetrics.configure(config.performanceDiagnostics);
            DungeonPartyGuard.enabled = config.waitForParty;
            NameplateColors.enabled = config.classColoredNames;
            NameplateWeapons.enabled = config.showNameplateWeapons;
            DungeonLeaveButton.enabled = config.leaveDungeonButton;
            CrabgantuaWarnings.configure(config.crabgantuaRockfallWarnings);
            MinionHealthBars.configure(config.hideAlliedMinionHealthBars);
            SocialHooks.configure(config);
            hideUi.configure(config.hideUiKey);
            AllyEffects.configure(config);
        });
    }

    @:hlx.prefix(HText.cleanPlayerText)
    static function cleanPlayerText(text:String):HlxPrefixResult<String> {
        return config.disableProfanityFilter ? SkipWith(StringTools.htmlEscape(text)) : Continue;
    }

    @:hlx.postfix(ui.hud.HeroWidget.initActive)
    static function afterHeroNameplate(instance:Dynamic, result:Void):Void {
        try NameplateColors.attach(instance) catch (e:Dynamic) NameplateColors.reportError(e);
        try NameplateWeapons.attach(instance) catch (e:Dynamic) NameplateWeapons.reportError(e);
    }

    @:hlx.postfix(ui.comp.HealthBar.init)
    static function afterHealthBarInit(instance:Dynamic, result:Void):Void {
        try BossHealth.attach(instance) catch (e:Dynamic) BossHealth.reportError(e);
        try MinionHealthBars.attach(instance) catch (e:Dynamic) MinionHealthBars.report(e);
    }

    @:hlx.postfix(ui.comp.AttributeBar.init)
    static function afterAttributeBarInit(instance:Dynamic, result:Void):Void {
        try MinionHealthBars.attachLifetime(instance) catch (e:Dynamic) MinionHealthBars.report(e);
    }

    @:hlx.prefix(ui.comp.DamageDisplay.display)
    static function beforeDamageNumber(damage:Dynamic, position:Dynamic):HlxPrefixResult<Dynamic>
        return config.disableDamageNumbers ? SkipWith(null) : Continue;

    @:hlx.prefix(ui.comp.HealDisplay.display)
    static function beforeHealingNumber(damage:Dynamic, position:Dynamic):HlxPrefixResult<Dynamic>
        return config.disableDamageNumbers ? SkipWith(null) : Continue;

    @:hlx.prefix(ui.hud.EffectsFeed.displayDamage)
    static function beforeIncomingDamageNumber(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void>
        return config.disableDamageNumbers ? Skip : Continue;

    @:hlx.prefix(ui.hud.EffectsFeed.displayHeal)
    static function beforeIncomingHealingNumber(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void>
        return config.disableDamageNumbers ? Skip : Continue;

    @:hlx.postfix(ui.win.GearAppearance.init)
    static function afterGearAppearanceInit(instance:Dynamic, result:Void):Void {
        try BarbershopButton.attach(instance) catch (error:Dynamic) AppearanceEditor.report(error);
    }

    @:hlx.postfix(ui.BaseElement.onRemove)
    static function afterElementRemoved(instance:Dynamic, result:Void):Void {
        MinionHealthBars.forget(instance);
        BarbershopButton.forget(instance);
    }

    @:hlx.postfix(ui.comp.DamageDisplay.init)
    static function afterDamageDisplayInit(instance:Dynamic, result:Void):Void {
        // HealDisplay calls this base initializer, then changes its component.
        // Style healing once, after the complete subclass initialization.
        if (G.isA(instance, "ui.comp.HealDisplay")) return;
        try FancyDamageNumbers.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(ui.comp.HealDisplay.init)
    static function afterHealDisplayInit(instance:Dynamic, result:Void):Void {
        try FancyDamageNumbers.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(ui.hud.EffectsFeed.displayHeal)
    static function afterReceivedHeal(instance:Dynamic, damage:Dynamic, result:Void):Void {
        try FancyDamageNumbers.applyHealingFeed(instance, damage, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(h2d.filter.Filter.bind)
    static function afterDamageFilterBind(instance:Dynamic, s:Dynamic, result:Void):Void {
        try FancyDamageNumbers.bindGradient(instance, s) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(h2d.filter.Filter.unbind)
    static function afterDamageFilterUnbind(instance:Dynamic, s:Dynamic, result:Void):Void {
        FancyDamageNumbers.unbindGradient(instance);
    }

    @:hlx.prefix(h2d.filter.Shader.draw)
    static function beforeDamageGradientDraw(instance:Dynamic, ctx:Dynamic, input:Dynamic):HlxPrefixResult<Dynamic> {
        try FancyDamageNumbers.syncGradient(instance, ctx, input) catch (error:Dynamic) damageNumberError(error);
        return Continue;
    }

    static function damageNumberError(error:Dynamic):Void {
        if (!reportedDamageNumberError) {
            reportedDamageNumberError = true;
            trace("[More Settings] Fancy damage numbers: " + Std.string(error));
        }
    }

    @:hlx.postfix(lib.Input.getBindings)
    static function hideUiBindings(key:String, result:Dynamic):Dynamic {
        try return hideUi.bindings(key, result) catch (e:Dynamic) inputError(e);
        return result;
    }

    @:hlx.postfix(ui.win.element.InstanceSelectScreen.init)
    static function afterInstanceSelectInit(instance:Dynamic, result:Void):Void {
        try DungeonPartyGuard.update(instance) catch (e:Dynamic) DungeonPartyGuard.reportError(e);
    }

    @:hlx.postfix(ui.hud.ActivitiesInfo.init)
    static function afterActivitiesInfoInit(instance:Dynamic, result:Void):Void {
        try DungeonLeaveButton.attach(instance) catch (e:Dynamic) DungeonLeaveButton.reportError(e);
    }

    @:hlx.prefix(ui.UIElement.set_visible)
    static function beforeUiVisibility(instance:Dynamic, value:Bool):HlxPrefixResult<Bool> {
        try {
            if (MinionHealthBars.intercept(instance, value)) return SkipWith(false);
        } catch (error:Dynamic) MinionHealthBars.report(error);
        try {
            var visible = DungeonLeaveButton.visibility(instance, value);
            if (visible != value) {
                // Re-enter with the final value: this prefix then continues to
                // the native setter. Unchanged frames never hide then reshow
                // the button, avoiding repeated layout invalidation.
                if (G.field(instance, "visible") != visible)
                    G.call("ui.UIElement", "set_visible", instance, [visible]);
                return SkipWith(visible);
            }
        } catch (e:Dynamic) DungeonLeaveButton.reportError(e);
        return Continue;
    }

    @:hlx.postfix(ui.win.element.InstanceSelectScreen.update)
    static function afterInstanceSelectUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        try DungeonPartyGuard.update(instance) catch (e:Dynamic) DungeonPartyGuard.reportError(e);
    }

    @:hlx.prefix(ui.win.element.InstanceSelectScreen.startAction)
    static function beforeInstanceStart(instance:Dynamic):HlxPrefixResult<Void> {
        // Check again at activation, including keyboard/controller actions and
        // party changes since the last UI update. Ready and Cancel stay native.
        if (DungeonPartyGuard.waiting(instance)) return Skip;
        return Continue;
    }

    @:hlx.postfix(lib.Input.isPressed)
    static function hideUiPressed(key:String, result:Bool):Bool {
        try return hideUi.pressed(key, result) catch (e:Dynamic) inputError(e);
        return result;
    }

    @:hlx.prefix(GameApp.update)
    static function beforeUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        DiagnosticHooks.update(instance, config.performanceOptimization);
        PerformanceHooks.update(instance, dt);
        AppearanceEditor.update(instance);
        AllyEffects.update(instance);
        return Continue;
    }

    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.suspend();
        PerformanceHooks.dispose();
        DungeonLeaveButton.clear();
        try FancyDamageNumbers.dispose() catch (error:Dynamic) damageNumberError(error);
        AppearanceEditor.close();
        BarbershopButton.clear();
        MinionHealthBars.clear();
        AllyEffects.dispose();
        CrabgantuaWarnings.dispose();
        SocialHooks.dispose();
        return Continue;
    }

    static function previousProfanityPreference():Bool {
        for (path in ["hlx/config/disable-profanity-filter/config.json", "hlx/mods/disable-profanity-filter/config.json"]) {
            if (!sys.FileSystem.exists(path)) continue;
            try {
                var old:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
                var value = Reflect.field(old, "disableProfanityFilter");
                if (Std.isOfType(value, Bool)) return value;
            } catch (_:Dynamic) {}
        }
        return true;
    }

    static function inputError(error:Dynamic):Void {
        if (!reportedInputError) {
            reportedInputError = true;
            trace("[More Settings] Hide UI binding: " + Std.string(error));
        }
    }
}
