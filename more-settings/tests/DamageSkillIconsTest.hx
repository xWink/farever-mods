import moresettings.DamageSkillIcons;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class DamageSkillIconsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        var config = SettingsData.defaults();
        var texture:Dynamic = {};
        var original:Dynamic = {width:256.0, height:128.0, dx:12.0, dy:8.0, texture:texture};
        var inf:Dynamic = {id:"Proc", gfx:{tile:original}};
        var hit:Dynamic = {dmg:{skill:{kind:"Proc"}}};
        var native:Dynamic = {status:"poison"};
        eq(DamageSkillIcons.resolve(hit, inf, native, config), native, "Disabled icons preserve native status indicators");
        eq(G.tileLoads, 0, "Disabled option performs no tile lookups");

        config.showSkillIconNextToDamageNumber = true;
        var tile = DamageSkillIcons.resolve(hit, inf, native, config);
        eq(config.fancyDamageNumbers, false, "Skill icons work independently of Fancy damage numbers");
        eq(tile != original, true, "Uses a private tile wrapper");
        eq(tile.width, 16.0, "Large skill art fits the native damage indicator");
        eq(tile.height, 8.0, "Non-square art preserves its aspect ratio");
        eq(tile.dx, 0.0, "Atlas offsets do not shift the icon into the number");
        eq(original.width, 256.0, "Hotbar/tooltip tile width stays intact");
        eq(original.height, 128.0, "Hotbar/tooltip tile height stays intact");
        eq(original.dx, 12.0, "Shared tile offset stays intact");
        eq(tile.texture, texture, "Reuses the game's texture");
        eq(DamageSkillIcons.resolve(hit, inf, native, config), tile, "Repeated hits reuse their tile wrapper");
        eq(G.tileLoads, 1, "Repeated hits do not reload art");

        var status:Dynamic = {id:"Dot"};
        G.skillRefs["Dot"] = inf;
        eq(DamageSkillIcons.resolve({dmg:{skill:{kind:"Dot"}}}, status, native, config).width, 16.0,
            "Internal status damage uses the game's referenced skill art");
        var definitions:Map<String, Dynamic> = ["Proc" => inf];
        G.data = {skill:{byId:definitions}};
        var summon:Dynamic = {dmg:{skill:{kind:"SummonAttack", sourceSkill:{kind:"Proc"}}}};
        eq(DamageSkillIcons.resolve(summon, {id:"SummonAttack"}, native, config), tile,
            "Summon attacks without art resolve the actual originating skill");
        eq(DamageSkillIcons.resolve(hit, {id:"Unknown"}, native, config), tile,
            "Missing definition may still resolve a known hit source");
        eq(DamageSkillIcons.resolve({dmg:{skill:{kind:"Unknown"}}}, {id:"Unknown"}, native, config), native,
            "Unknown damage retains its existing status icon");
        eq(DamageSkillIcons.resolve({dmg:null}, null, null, config), null,
            "Missing metadata does not invent an unrelated icon");

        hit.nativeType = "ui.comp.HealDisplay";
        eq(DamageSkillIcons.resolve(hit, inf, native, config), tile, "Healing resolves its responsible skill art");
        hit.nativeType = "ui.comp.DamageDisplay";
        config.disableDamageNumbers = true;
        eq(DamageSkillIcons.resolve(hit, inf, native, config), native, "Hidden numbers do not get custom icons");
        config.disableDamageNumbers = false;
        config.showSkillIconNextToDamageNumber = false;
        eq(DamageSkillIcons.resolve(hit, inf, native, config), native, "Disabling restores native selection despite cached art");
        config.showSkillIconNextToDamageNumber = true;
        DamageSkillIcons.clear();
        eq(DamageSkillIcons.resolve(hit, inf, native, config) != tile, true, "New scenes obtain fresh tile wrappers");
        eq(original.texture, texture, "Clearing wrappers preserves game-owned textures");
        attachment();
        healingFeed();
        trace('Damage skill icons: $checks checks passed');
    }

    /** Reproduce native init: iconBmp may not exist, counter is in contentRoot. */
    static function display(skill:Dynamic, ?nativeTile:Dynamic):Dynamic {
        var display:Dynamic = {dmg:{skill:skill}, children:[], iconBmp:null};
        var centered:Dynamic = {parent:display, children:[]};
        var contentDom:Dynamic = {obj:centered};
        display.children.push(centered);
        display.dom = {obj:display, contentRoot:contentDom};
        var counter:Dynamic = {parent:centered, text:"1,234", filter:{gradient:true}, dropShadow:{color:0}, nativeType:"ui.comp.FmtText"};
        display.counter = counter;
        if (nativeTile != null) {
            var bitmap:Dynamic = {parent:centered, tile:nativeTile, visible:true, nativeType:"h2d.Bitmap"};
            bitmap.dom = {obj:bitmap, styles:{src:nativeTile}};
            display.iconBmp = bitmap;
            centered.children.push(bitmap);
        }
        centered.children.push(counter);
        return display;
    }

    static function attachment():Void {
        DamageSkillIcons.clear();
        var config = SettingsData.defaults();
        var inf:Dynamic = {id:"DirectHit", gfx:{tile:{width:96.0, height:96.0, texture:{}}}};
        var source:Dynamic = {kind:"DirectHit", inf:inf};
        var hit = display(source);
        DamageSkillIcons.apply(hit, config);
        eq(hit.iconBmp, null, "disabled option leaves native number-only display unchanged");
        config.showSkillIconNextToDamageNumber = true;
        var before = G.bitmapCreates;
        var filter = hit.counter.filter;
        var shadow = hit.counter.dropShadow;
        DamageSkillIcons.apply(hit, config);
        eq(G.bitmapCreates, before + 1, "creates the missing bitmap without any tile-return hook");
        eq(hit.iconBmp != null, true, "native iconBmp field is populated");
        eq(hit.iconBmp.parent, hit.counter.parent, "icon uses number's nested animated container");
        eq(hit.iconBmp.parent != hit, true, "does not mistakenly attach to the outer damage display");
        eq(hit.counter.parent.children[0], hit.iconBmp, "icon precedes text in native flow");
        eq(hit.counter.parent.children[1], hit.counter, "original counter remains intact");
        eq(hit.counter.parent.needReflow, true, "new icon invalidates native layout");
        eq(hit.iconBmp.tile.width, 16.0, "attached skill art has usable indicator dimensions");
        eq(hit.iconBmp.dom.styles.src, hit.iconBmp.tile, "DOM style preserves tile on later style refresh");
        eq(hit.iconBmp.visible, true, "new damage icon is visible");
        eq(hit.counter.filter, filter, "Fancy damage gradient remains on the number");
        eq(hit.counter.dropShadow, shadow, "native shadow remains on the number");
        eq(hit.counter.text, "1,234", "damage amount is unchanged");
        DamageSkillIcons.apply(hit, config);
        eq(G.bitmapCreates, before + 1, "repeated application does not duplicate icons");
        eq(hit.counter.parent.children.length, 2, "exactly one icon and counter remain");

        // The reported failure occurs after attachment: native stylesheet
        // refresh hides iconBmp, excluding it from the number's flow layout.
        G.refreshStyles(hit.iconBmp.dom, {visible:false});
        eq(hit.iconBmp.visible, true, "skill icon survives delayed native hidden-icon styling");
        hit.counter.parent.visible = false;
        G.refreshStyles(hit.iconBmp.dom, {visible:false});
        eq(hit.iconBmp.visible, true, "repeated style refresh retains the icon override");
        eq(hit.counter.parent.visible, false, "icon override never reveals a hidden parent/HUD");
        hit.counter.parent.visible = true;
        DamageSkillIcons.apply(hit, config);
        eq(hit.counter.parent.children.length, 2, "style refresh and second hook keep one icon");

        var statusTile:Dynamic = {status:"bleed"};
        var status = display(source, statusTile);
        var nativeBitmap = status.iconBmp;
        before = G.bitmapCreates;
        DamageSkillIcons.apply(status, config);
        eq(status.iconBmp, nativeBitmap, "reuses existing native status bitmap");
        eq(G.bitmapCreates, before, "native status bitmap is not duplicated");
        eq(status.iconBmp.tile, hit.iconBmp.tile, "same skill reuses cached icon wrapper");
        G.refreshStyles(status.iconBmp.dom, {visible:false});
        eq(status.iconBmp.visible, true, "reused native status bitmap gets persistent skill visibility");
        var orphan = display({kind:"Unknown"}, statusTile);
        DamageSkillIcons.apply(orphan, config);
        eq(orphan.iconBmp.tile, statusTile, "unknown skill preserves native status fallback");
        G.refreshStyles(orphan.iconBmp.dom, {visible:false});
        eq(orphan.iconBmp.visible, false, "unknown native status fallback retains native visibility rules");
        var noArt = display({kind:"Unknown"});
        DamageSkillIcons.apply(noArt, config);
        eq(noArt.iconBmp, null, "no misleading placeholder when no skill art exists");

        var child = display({kind:"ChildWithoutArt", sourceSkill:source});
        DamageSkillIcons.apply(child, config);
        eq(child.iconBmp.tile, hit.iconBmp.tile, "originating skill art is attached for child damage");
        var dataHit = display({kind:"FromData"});
        var definitions:Map<String, Dynamic> = ["FromData" => inf];
        G.data = {skill:{byId:definitions}};
        DamageSkillIcons.apply(dataHit, config);
        eq(dataHit.iconBmp.tile, hit.iconBmp.tile, "missing instance metadata falls back to native skill table");
        var heal = display(source);
        heal.nativeType = "ui.comp.HealDisplay";
        DamageSkillIcons.apply(heal, config);
        eq(heal.iconBmp.tile, hit.iconBmp.tile, "healing subclass gets its responsible skill icon");
        G.refreshStyles(heal.iconBmp.dom, {visible:false});
        eq(heal.iconBmp.visible, true, "healing icon survives its native style refresh");
        eq(heal.counter.text, "1,234", "healing amount remains unchanged");
        var healingOrigin = display({kind:"Regeneration", sourceSkill:source});
        healingOrigin.nativeType = "ui.comp.HealDisplay";
        DamageSkillIcons.apply(healingOrigin, config);
        eq(healingOrigin.iconBmp.tile, hit.iconBmp.tile, "heal-over-time without art uses the actual source skill");
        var unknownHeal = display({kind:"Unknown"});
        unknownHeal.nativeType = "ui.comp.HealDisplay";
        DamageSkillIcons.apply(unknownHeal, config);
        eq(unknownHeal.iconBmp, null, "unknown healing source does not invent an icon");
        config.disableDamageNumbers = true;
        var hidden = display(source);
        DamageSkillIcons.apply(hidden, config);
        eq(hidden.iconBmp, null, "suppressed numbers do not allocate icon widgets");
        config.disableDamageNumbers = false;
        config.showSkillIconNextToDamageNumber = false;
        var off = display(source);
        DamageSkillIcons.apply(off, config);
        eq(off.iconBmp, null, "disabling restores number-only behavior for new hits");
        config.showSkillIconNextToDamageNumber = true;
        DamageSkillIcons.apply({dmg:{skill:source}}, config);
        eq(G.bitmapCreates, before + 4, "missing native counter skips attachment safely");

        var messages:Array<String> = [];
        var originalTrace = haxe.Log.trace;
        haxe.Log.trace = (v:Dynamic, ?pos:haxe.PosInfos) -> messages.push(Std.string(v));
        before = G.bitmapCreates;
        for (i in 0...100) {
            DamageSkillIcons.apply(hit, config);
            DamageSkillIcons.apply(noArt, config);
        }
        eq(G.bitmapCreates, before, "repeated callbacks cannot duplicate the icon");
        eq(messages.length, 0, "normal damage-icon attachment produces no diagnostic logs");
        haxe.Log.trace = originalTrace;
    }

    static function healingRow():Dynamic {
        var row:Dynamic = {children:[], alpha:0.0};
        row.dom = {obj:row, classes:["heal"], styles:{}};
        row.dom.contentRoot = row.dom;
        var counter:Dynamic = {nativeType:"ui.comp.FmtText", parent:row, text:"+500", filter:{gradient:true}};
        row.children.push(counter);
        return row;
    }

    static function healingFeed():Void {
        var config = SettingsData.defaults();
        var skill:Dynamic = {kind:"Heal", owner:{otherPlayer:true}, inf:{id:"Heal", gfx:{tile:{width:96.0,height:96.0}}}};
        var heal:Dynamic = {skill:skill,amount:250.0,scale:2.0};
        var old = healingRow();
        var row = healingRow();
        var counter = row.children[0];
        var filter = counter.filter;
        var entry:Dynamic = {elt:row,elapsed:-0.3};
        var feed:Dynamic = {activeLines:[{elt:old,elapsed:0.5},entry]};
        DamageSkillIcons.applyHealingFeed(feed, heal, config);
        eq(row.children.length, 1, "disabled skill icons preserve the native received-heal row");
        config.showSkillIconNextToDamageNumber = true;
        DamageSkillIcons.applyHealingFeed(feed, heal, config);
        eq(row.children.length, 2, "received/self healing gets a skill icon in its actual effects-feed row");
        var icon = row.children[0];
        eq(icon.nativeType, "h2d.Bitmap", "healing icon is before the number");
        eq(icon.parent, row, "healing icon shares native scrolling and fading");
        eq(icon.tile.width, 16.0, "feed skill art has a compact size");
        eq(row.children[1], counter, "original healing text object remains intact");
        eq(counter.text, "+500", "native plus sign and scaled heal amount are preserved");
        eq(counter.filter, filter, "Fancy healing filter remains on the counter");
        eq(row.alpha, 0.0, "new icon cannot reveal a queued healing row prematurely");
        eq(entry.elapsed, -0.3, "healing queue timing is untouched");
        eq(old.children.length, 1, "earlier healing rows are not modified");
        G.refreshStyles(icon.dom, {visible:false});
        eq(icon.visible, true, "received-heal icon survives later native styling");
        DamageSkillIcons.applyHealingFeed(feed, heal, config);
        eq(row.children.length, 2, "repeated callback does not duplicate a healing icon");

        feed.activeLines = [{elt:old,elapsed:0.5}];
        DamageSkillIcons.applyHealingFeed(feed, {skill:skill,amount:2.0,scale:0.25}, config);
        eq(old.children.length, 1, "sub-one scaled heals cannot attach the new source to an older row");
        config.disableDamageNumbers = true;
        DamageSkillIcons.applyHealingFeed(feed, heal, config);
        eq(old.children.length, 1, "skipped native heal display cannot modify the previous row");
        config.disableDamageNumbers = false;
        DamageSkillIcons.applyHealingFeed(feed, {skill:{kind:"Unknown"},amount:500.0,scale:1.0}, config);
        eq(old.children.length, 1, "unknown healing source does not invent art");
        DamageSkillIcons.applyHealingFeed(feed, {skill:{kind:"Regeneration",sourceSkill:skill},amount:0.5,scale:2.0}, config);
        eq(old.children.length, 2, "one-point heal-over-time resolves source art after native backlog trimming");
        eq(old.children[0].tile, icon.tile, "received healing can resolve another player's skill without a local-caster filter");
        var notification = healingRow();
        notification.dom.classes = ["combat"];
        feed.activeLines = [{elt:notification}];
        DamageSkillIcons.applyHealingFeed(feed, heal, config);
        eq(notification.children.length, 1, "combat notifications never acquire healing icons");
        DamageSkillIcons.applyHealingFeed({activeLines:[]}, heal, config);
        DamageSkillIcons.applyHealingFeed(feed, null, config);
    }
}
