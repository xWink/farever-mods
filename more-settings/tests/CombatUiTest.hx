import moresettings.MinionHealthBars;
import moresettings.SettingsData;
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

    static function descriptor():Void {
        var config = SettingsData.defaults();
        eq(config.damageNumberLimit,"Medium","Damage number default uses the Medium preset");
        eq(config.hideAlliedMinionHealthBars, false, "minion bar hiding opt-in");
        var descriptor:Dynamic = haxe.Json.parse(sys.io.File.getContent("configFormats.json"));
        var rows:Array<Dynamic> = descriptor.configs;
        var keys = [for (row in rows) Std.string(row.key)];
        eq(keys.indexOf("damageNumberScale"), keys.indexOf("fancyDamageNumbers") + 1,
            "damage number scale follows fancy numbers");
        eq(keys.indexOf("damageNumberOpacity"), keys.indexOf("damageNumberScale") + 1,
            "damage number opacity follows scale");
        eq(keys.indexOf("damageNumberLimit"), keys.indexOf("damageNumberOpacity") + 1,
            "damage number limit follows opacity");
        eq(keys.indexOf("beeVisualLimit"), keys.indexOf("damageNumberLimit") + 1,
            "bee limit follows damage number limit");
        eq(keys.indexOf("bombletVisualLimit"), keys.indexOf("beeVisualLimit") + 1,
            "bomblet limit follows bee limit");
        eq(keys.indexOf("holdSkillRepeat"), keys.indexOf("bombletVisualLimit") + 1,
            "hold skill repeat is available in Combat");
        eq(keys.indexOf("holdSkillRepeatDelay"), keys.indexOf("holdSkillRepeat") + 1,
            "repeat delay appears directly below hold-to-repeat");
        var delay = rows[keys.indexOf("holdSkillRepeatDelay")];
        eq(delay.type, "slider", "repeat delay uses a slider");
        eq(delay.label, "Delay until skill repeats (seconds)", "repeat delay shows units");
        eq(delay.min, 0, "repeat delay allows zero");
        eq(delay.max, 2, "repeat delay allows two seconds");
        eq(delay.step, 0.1, "repeat delay uses tenths of a second");
        eq(config.holdSkillRepeatDelay, 0.7, "repeat delay defaults to 0.7 seconds");
        eq(keys.indexOf("showSkillIconNextToDamageNumber"), keys.indexOf("holdSkillRepeatDelay") + 1,
            "skill icons follow the new Combat controls");
        eq(keys.indexOf("disableDamageNumbers"), -1, "Old damage number disable checkbox was removed");
        for (key in ["damageNumberLimit", "beeVisualLimit", "bombletVisualLimit"]) {
            var row=rows[keys.indexOf(key)];
            eq(row.type,"dropdown",key+" uses a dropdown");
            eq((cast row.options:Array<String>).join(","),"None,Low,Medium,High,Max",
                key+" presents all five presets in order");
            eq(Reflect.hasField(row,"min"),false,key+" has no slider minimum");
            eq(Reflect.hasField(row,"max"),false,key+" has no slider maximum");
        }
        var social = [for (row in rows) Std.string(row.label)].indexOf("Social");
        eq(keys[social - 1], "showEnemyDistance", "enemy distance is last in Combat");
        eq(keys.indexOf("showEnemyDistance"),keys.indexOf("hideAlliedMinionHealthBars")+1,
            "enemy distance follows minion HP display control");
        for (row in rows) {
            if (row.type == "title") eq(["Appearance", "Unfocused Volume", "Fast Travel Music"].indexOf(row.label), -1, "retired sections removed");
            eq(["changeAppearance", "adjustUnfocusedVolume", "backgroundVolume", "adjustFastTravelVolume", "fastTravelVolume"].indexOf(row.key), -1, "retired controls removed");
        }
    }
    static function main():Void {
        minions(); lifetimeBars(); descriptor();
        trace('Combat UI: $checks checks passed.');
    }
}
