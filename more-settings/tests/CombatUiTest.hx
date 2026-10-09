import moresettings.MinionHealthBars;
import moresettings.BarbershopButton;
import moresettings.SettingsData;
import moresettings.AppearanceEditor;
import moresettings.GameAccess as G;

class CombatUiTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ": expected " + expected + ", got " + actual;
    }
    static function bar(unit:Dynamic, parentType = "ui.hud.FoeWidget", visible = true):Dynamic
        return {unit:unit, visible:visible, removed:false, parent:{type:parentType, parent:null, callbacks:new Array<Float->Void>()}};
    static function unit(layer:Dynamic, owner:Dynamic, enemy = false):Dynamic
        return {type:"ent.Foe", summonOwner:owner, enemy:enemy, layer:layer, removed:false};
    static function attributeBar(unit:Dynamic, atbId = "Lifetime", parentType = "ui.hud.FoeWidget", visible = true):Dynamic {
        var result = bar(unit, parentType, visible);
        result.atbId = atbId;
        return result;
    }

    static function minions():Void {
        MinionHealthBars.clear(); MinionHealthBars.configure(false);
        var layer:Dynamic = {};
        G.hero = {layer:layer};
        var own = bar(unit(layer, G.hero));
        var ally = bar(unit(layer, {}));
        var enemy = bar(unit(layer, {}, true));
        var ordinary = bar(unit(layer, null));
        var otherZone = bar(unit({}, G.hero));
        var player = bar({type:"ent.Hero", layer:layer}, "ui.hud.HeroWidget");
        var boss = bar(unit(layer, {}), "ui.hud.BossInfo");
        var initiallyHidden = bar(unit(layer, {}), "ui.hud.FoeWidget", false);
        for (b in [own, ally, enemy, ordinary, otherZone, player, boss, initiallyHidden]) MinionHealthBars.attach(b);
        eq(own.visible, true, "disabled keeps own summon bar");
        eq(own.parent.callbacks.length, 1, "updates live on the widget, not the hidden child");
        MinionHealthBars.configure(true);
        eq(own.visible, true, "own minion health stays visible");
        eq(ally.visible, false, "hides allied minion health");
        for (b in [enemy, ordinary, otherZone, player, boss]) eq(b.visible, true, "unrelated health bars stay native");
        eq(player.parent.callbacks.length, 0, "no callback on player bars");
        eq(boss.parent.callbacks.length, 0, "no callback on boss HUD");
        G.call("ui.UIElement", "set_visible", own, [true]);
        eq(own.visible, true, "native visibility refresh keeps own bar visible");
        G.call("ui.UIElement", "set_visible", ally, [true]);
        eq(ally.visible, false, "native visibility refresh cannot reveal an allied filtered bar");
        G.call("ui.UIElement", "set_visible", ally, [false]);
        MinionHealthBars.configure(false);
        eq(own.visible, true, "disabling restores native visible bar");
        eq(ally.visible, false, "disabling respects a later native hide");
        eq(initiallyHidden.visible, false, "disabling never reveals an originally hidden bar");
        G.call("ui.UIElement", "set_visible", ally, [true]);
        MinionHealthBars.configure(true);
        ally.unit.enemy = true;
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, true, "hostility change restores the enemy bar");
        ally.unit.enemy = false;
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, false, "friendly again hides allied bar");
        ally.unit.summonOwner = G.hero;
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, true, "becoming locally owned restores bar immediately");
        ally.unit.summonOwner = null;
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, true, "no-longer-summoned unit restores its bar");
        ally.unit.summonOwner = {};
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, false, "other owner hides allied bar again");
        MinionHealthBars.clear();
        eq(ally.visible, true, "session cleanup restores tracked visibility");
        eq(own.visible, true, "own minion bar remains visible through all changes");
        MinionHealthBars.configure(false);
    }

    static function lifetimeBars():Void {
        MinionHealthBars.clear(); MinionHealthBars.configure(true);
        var layer:Dynamic = {};
        G.hero = {layer:layer};
        var own = attributeBar(unit(layer, G.hero));
        var allyUnit = unit(layer, {}); allyUnit.kind = "Summon_Imp";
        var ally = attributeBar(allyUnit);
        var health = bar(allyUnit);
        var enemy = attributeBar(unit(layer, {}, true));
        var unknownOwner = attributeBar(unit(layer, null));
        var otherAttribute = attributeBar(allyUnit, "SpecialEnergy");
        var boss = attributeBar(allyUnit, "Lifetime", "ui.hud.BossInfo");
        var player = attributeBar({type:"ent.Hero", layer:layer}, "Lifetime", "ui.hud.HeroWidget");
        var initiallyHidden = attributeBar(allyUnit, "Lifetime", "ui.hud.FoeWidget", false);
        for (b in [own, ally, enemy, unknownOwner, otherAttribute, boss, player, initiallyHidden])
            MinionHealthBars.attachLifetime(b);
        MinionHealthBars.attach(health);
        eq(ally.visible, false, "Almaz imp lifetime bar hides without a HealthBar component");
        eq(health.visible, false, "summons with both health and lifetime hide both bars");
        for (b in [own, enemy, unknownOwner, otherAttribute, boss, player])
            eq(b.visible, true, "own, unrelated and unresolved lifetime bars stay visible");
        eq(otherAttribute.parent.callbacks.length, 0, "other attribute bars are not tracked");
        G.call("ui.UIElement", "set_visible", ally, [true]);
        eq(ally.visible, false, "native refresh cannot reveal filtered lifetime bar");
        unknownOwner.unit.summonOwner = {};
        @:privateAccess MinionHealthBars.refresh(unknownOwner, true);
        eq(unknownOwner.visible, false, "late ownership hides allied lifetime bar");
        unknownOwner.unit.summonOwner = G.hero;
        @:privateAccess MinionHealthBars.refresh(unknownOwner, true);
        eq(unknownOwner.visible, true, "local ownership restores lifetime bar");
        MinionHealthBars.configure(false);
        eq(ally.visible, true, "disabling restores allied lifetime bar");
        eq(health.visible, true, "disabling restores allied health bar");
        eq(initiallyHidden.visible, false, "disabling preserves a natively hidden lifetime bar");
        MinionHealthBars.clear();
    }

    static function barber():Void {
        BarbershopButton.clear(); AppearanceEditor.requests = 0;
        var panel:Dynamic = {children:new Array<Dynamic>(), calculatedWidth:620.0}; panel.dom = {obj:panel};
        var helmet:Dynamic = {slot:"Slot_Head", parent:{}, bounds:{xMin:55.0,xMax:115.0,yMin:150.0,yMax:210.0}};
        var gloves:Dynamic = {slot:"Slot_Hands", parent:{}, bounds:{xMin:510.0,xMax:570.0,yMin:150.0,yMax:210.0}};
        var page:Dynamic = {unit:G.hero, scene:{parent:panel}, buttons:{items:[helmet, gloves]}, removed:false,
            callbacks:new Array<Float->Void>()};
        BarbershopButton.attach(page);
        var children:Array<Dynamic> = panel.children;
        eq(children.length, 1, "one native button added");
        var button = children[0];
        eq(button.text, "Barbershop", "requested label");
        eq(button.props.isAbsolute, true, "button does not move the model or appearance slots");
        eq(button.minWidth, 140, "button width fits the whitespace");
        eq(button.x, 465.0, "right margin matches the top margin");
        eq(button.y, 15.0, "top margin mirrors the native Character button bottom offset");
        eq(G.relativeTo == panel, true, "native panel coordinates used for UI scaling");
        var click:Void->Void = button.onClick; click();
        eq(AppearanceEditor.requests, 1, "click requests the existing editor");
        gloves.bounds.xMin = 530; gloves.bounds.xMax = 590; gloves.bounds.yMin = 200;
        panel.calculatedWidth = 640;
        var callbacks:Array<Float->Void> = page.callbacks;
        for (callback in callbacks) callback(0.016);
        eq(button.x, 485.0, "native panel resize preserves the right margin");
        eq(button.y, 15.0, "top margin stays fixed when the slots move vertically");
        page.unit = {};
        for (callback in callbacks) callback(0.016);
        click();
        eq(button.visible, false, "not offered for another player's appearance");
        eq(AppearanceEditor.requests, 1, "stale button cannot edit another character");
        page.unit = G.hero; page.callbacks = [];
        BarbershopButton.attach(page);
        eq(children.length, 1, "rebuild replaces rather than duplicates the button");
        click();
        eq(AppearanceEditor.requests, 1, "replaced button action is inert");
        BarbershopButton.forget(page);
        var nextClick:Void->Void = children[0].onClick; nextClick();
        eq(AppearanceEditor.requests, 1, "removed page action is inert");
        BarbershopButton.clear();
    }

    static function descriptor():Void {
        var config = SettingsData.defaults();
        eq(config.disableDamageNumbers, false, "damage hiding opt-in");
        eq(config.hideAlliedMinionHealthBars, false, "minion bar hiding opt-in");
        var descriptor:Dynamic = haxe.Json.parse(sys.io.File.getContent("configFormats.json"));
        var rows:Array<Dynamic> = descriptor.configs;
        var keys = [for (row in rows) Std.string(row.key)];
        eq(keys.indexOf("disableDamageNumbers"), keys.indexOf("fancyDamageNumbers") + 1, "damage toggle follows fancy numbers");
        var combatEnd = -1;
        var inCombat = false;
        for (i in 0...rows.length) if (rows[i].type == "title") {
            if (inCombat) { combatEnd = i; break; }
            if (rows[i].label == "Combat") inCombat = true;
        }
        eq(combatEnd > 0, true, "Combat has a following settings section");
        eq(keys[combatEnd - 1], "hideAlliedMinionHealthBars", "minion bars last in Combat");
        for (row in rows) {
            if (row.type == "title") eq(["Appearance", "Unfocused Volume", "Fast Travel Music"].indexOf(row.label), -1, "retired sections removed");
            eq(["changeAppearance", "adjustUnfocusedVolume", "backgroundVolume", "adjustFastTravelVolume", "fastTravelVolume"].indexOf(row.key), -1, "retired controls removed");
        }
    }
    static function main():Void {
        minions(); lifetimeBars(); barber(); descriptor();
        trace('Combat UI: $checks checks passed.');
    }
}
