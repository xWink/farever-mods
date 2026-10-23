import moresettings.BeeEffectPolicy;
import moresettings.BombletEffectPolicy;
import moresettings.VisualRateLimit;
import moresettings.VisualQuota;
import moresettings.VisualDamageBudget;
import moresettings.HoldRepeat;
import moresettings.SettingsData;
import moresettings.VisualLimit;
import moresettings.BeeEffects;
import moresettings.BombletEffects;
import moresettings.PerformanceDamageNumbers;

class PerformanceVisualsTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic,message:String):Void {
        checks++;
        if(actual!=expected)throw message+": expected "+Std.string(expected)+", got "+Std.string(actual);
    }
    static function applyLimits(c:moresettings.SettingsData.MoreSettingsConfig):Void {
        SettingsData.normalize(c);
        BeeEffects.configure(VisualLimit.bees.count(c.beeVisualLimit));
        BombletEffects.configure(VisualLimit.bomblets.count(c.bombletVisualLimit));
        PerformanceDamageNumbers.configure(VisualLimit.damage.count(c.damageNumberLimit));
    }
    static function main():Void {
        var c=SettingsData.defaults();
        eq(c.performanceOptimization,false,"Performance effects remain opt-in");
        eq(c.preventCtrlFFullscreen,false,"Ctrl+F fix remains opt-in");
        eq(c.holdSkillRepeat,false,"Hold-to-repeat remains opt-in");
        eq(c.damageNumberScale,100,"Default damage scale is neutral");
        eq(c.damageNumberOpacity,100,"Default damage alpha is neutral");
        eq(c.damageNumberLimit,"Medium","Damage number dropdown defaults to Medium");
        eq(c.beeVisualLimit,"Max","Bee visual dropdown defaults to Max");
        eq(c.bombletVisualLimit,"Max","Bomblet visual dropdown defaults to Max");
        eq(c.showEnemyDistance,false,"Enemy distance is opt-in");
        var choices=["None","Low","Medium","High","Max"];
        var damageCounts=[0,10,25,50,-1],beeCounts=[0,2,10,30,-1],bombCounts=[0,5,25,50,-1];
        for (i in 0...choices.length) {
            eq(VisualLimit.damage.count(choices[i]),damageCounts[i],choices[i]+" damage count");
            eq(VisualLimit.bees.count(choices[i]),beeCounts[i],choices[i]+" bee count");
            eq(VisualLimit.bomblets.count(choices[i]),bombCounts[i],choices[i]+" Bomblet count");
            c.damageNumberLimit=choices[i];c.beeVisualLimit=choices[i];c.bombletVisualLimit=choices[i];
            SettingsData.normalize(c);
            eq(c.damageNumberLimit,choices[i],"Damage dropdown survives normalization");
            eq(c.beeVisualLimit,choices[i],"Bee dropdown survives normalization");
            eq(c.bombletVisualLimit,choices[i],"Bomblet dropdown survives normalization");
        }
        // Exercise the same dynamic JSON representation as a pre-upgrade config.
        c=cast haxe.Json.parse(haxe.Json.stringify(SettingsData.defaults()));
        c.damageNumberLimit=20;c.beeVisualLimit=100;c.bombletVisualLimit=100;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"Medium","Old damage default migrates to nearest preset");
        eq(c.beeVisualLimit,"Max","Old bee maximum stays game default");
        eq(c.bombletVisualLimit,"Max","Old Bomblet maximum stays game default");
        c.damageNumberLimit=0;c.beeVisualLimit=0;c.bombletVisualLimit=0;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"None","Old damage zero stays hidden");
        eq(c.beeVisualLimit,"None","Old bee zero stays hidden");
        eq(c.bombletVisualLimit,"None","Old Bomblet zero stays hidden");
        c.damageNumberLimit=49;c.beeVisualLimit=8;c.bombletVisualLimit=4;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"High","Custom damage slider migrates to nearest preset");
        eq(c.beeVisualLimit,"Medium","Custom bee slider migrates to nearest preset");
        eq(c.bombletVisualLimit,"Low","Custom Bomblet slider migrates to nearest preset");
        c.damageNumberLimit=null;c.beeVisualLimit="invalid";c.bombletVisualLimit=Math.NaN;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"Medium","Missing damage choice uses default");
        eq(c.beeVisualLimit,"Max","Invalid bee choice uses default");
        eq(c.bombletVisualLimit,"Max","Invalid Bomblet choice uses default");
        c.disableDamageNumbers=true;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"None","Old disable setting migrates to None");
        eq(c.disableDamageNumbers,false,"Old disable flag clears after migration");
        c.damageNumberLimit="Max";
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,"Max","Legacy checkbox cannot override a later selection");
        c.damageNumberScale=1;c.damageNumberOpacity=-5;
        SettingsData.normalize(c);
        eq(c.damageNumberScale,50,"Damage scale clamps at 50%");
        eq(c.damageNumberOpacity,0,"Damage opacity clamps at zero");
        c.damageNumberScale=999;c.damageNumberOpacity=200;
        SettingsData.normalize(c);
        eq(c.damageNumberScale,150,"Damage scale clamps at 150%");
        eq(c.damageNumberOpacity,100,"Damage opacity clamps at 100%");
        Reflect.setField(c,"damageNumberScale",null);
        Reflect.setField(c,"damageNumberOpacity",null);
        SettingsData.normalize(c);
        eq(c.damageNumberScale,100,"Missing legacy scale uses 100%");
        eq(c.damageNumberOpacity,100,"Missing legacy opacity uses 100%");
        eq(BeeEffectPolicy.aura(true,"GM_MassGrab_Skill2_Status","Honey_Aura",false),true,
            "Only Honey_Aura enrage visual can be skipped");
        eq(BeeEffectPolicy.aura(true,"GM_MassGrab_Skill2_Status","Other",false),false,
            "Other enrage FX unaffected");
        eq(BeeEffectPolicy.unit(true,"Summon_Bee",false),true,
            "Bee-model budget limited to the Summon_Bee kind");
        eq(BeeEffectPolicy.unit(true,"Summon_Bee",true),false,
            "Never suppress server-side bee behavior");
        eq(BeeEffectPolicy.projectile(true,"SummonBee_HoneyBolt",false),true,
            "HoneyBolt projectile FX in budget");
        eq(BeeEffectPolicy.projectile(false,"SummonBee_HoneyBolt",false),false,
            "Disabled visual limiter has no effect");
        eq(BombletEffectPolicy.explosion(true,"Infusion_Kobold_DPS","Bomblet",false),true,
            "Normal Bomblet cosmetic matched");
        eq(BombletEffectPolicy.explosion(true,"Infusion_Kobold_DPS","GoldenBomblet",false),true,
            "Golden Bomblet cosmetic matched");
        eq(BombletEffectPolicy.explosion(true,"Infusion_Kobold_DPS","Other",false),false,
            "Only the Bomblet step's visual is skipped");
        eq(BombletEffectPolicy.explosion(true,"Infusion_Kobold_DPS","Bomblet",true),false,
            "Bomblet damage on server remains untouched");
        eq(BombletEffectPolicy.travel(true,"Bomblet","Projectile_CheeseBomb",false),true,
            "Normal flying effect eligible");
        eq(BombletEffectPolicy.travel(true,"GoldenBomblet","Projectile_CheeseBomb_Gold",false),true,
            "Golden flying effect eligible");
        eq(BombletEffectPolicy.travel(true,"Bomblet","Other",false),false,
            "Unrelated travelling effects survive");
        var quota=new VisualQuota(2);
        var bee1:Dynamic={},bee2:Dynamic={},bee3:Dynamic={};
        eq(quota.admit(bee1),true,"First bee visible");
        eq(quota.admit(bee2),true,"Second bee visible");
        eq(quota.admit(bee2),true,"Already displayed bee remains visible");
        eq(quota.admit(bee3),false,"Third bee invisible but not removed");
        quota.release(bee1);
        eq(quota.admit(bee3),true,"Retired bee gives its visual slot back");
        quota.reset();
        eq(quota.admit(bee1),true,"Reset releases all model claims");
        var rate=new VisualRateLimit();
        eq(rate.allow(5),true,"First cosmetic event shown");
        eq(rate.allow(5.12),false,"Global rate cap suppresses burst");
        eq(rate.allow(5.26),true,"Later events are shown");
        eq(rate.allow(1),true,"Clock reset allows new event");
        var budget=new VisualDamageBudget();
        eq(budget.maximum,20,"Default floating damage budget is twenty");
        budget.configure(0);
        eq(budget.allow(0,widget->widget.parent!=null),false,
            "A zero damage budget suppresses all widgets");
        budget.configure(200);
        eq(budget.maximum,200,"Numeric budget supports two hundred simultaneous widgets");
        eq(budget.allow(0,widget->widget.parent!=null),true,
            "Two hundred per second first number");
        eq(budget.allow(0.004,widget->widget.parent!=null),false,
            "Two hundred per second still rate-limits tiny bursts");
        eq(budget.allow(0.006,widget->widget.parent!=null),true,
            "Two hundred per second permits number after five milliseconds");
        budget.configure(20);
        eq(budget.maximum,20,"Live budget updates replace the old limit");
        eq(budget.allow(0,widget->widget.parent!=null),true,
            "First damage number is allowed");
        eq(budget.allow(0.04,widget->widget.parent!=null),false,
            "Twenty new numbers per second still enforces a rate limit");
        eq(budget.allow(0.051,widget->widget.parent!=null),true,
            "A new number is allowed after fifty milliseconds");
        budget.reset();
        var active=new Array<Dynamic>();
        for(i in 0...20) {
            var o:Dynamic={parent:{}};
            eq(budget.allow(i*0.055, widget->widget.parent!=null),true,
                "Attached widget budget admits number "+i);
            budget.created(o);
            active.push(o);
        }
        eq(budget.allow(2,widget->widget.parent!=null),false,
            "At most twenty attached widgets");
        active[0].parent=null;
        eq(budget.allow(2.11,widget->widget.parent!=null),true,
            "Detached damage number releases its visual slot");
        budget.reset();
        eq(budget.allow(3,widget->widget.parent!=null),true,
            "Reset restores the native number budget");
        for (performance in [false,true]) {
            c.performanceOptimization=performance;
            c.damageNumberLimit="None";c.beeVisualLimit="None";c.bombletVisualLimit="None";
            applyLimits(c);
            eq(PerformanceDamageNumbers.suppress(),true,
                "None hides damage with performance="+performance);
            var bee:Dynamic={kind:"Summon_Bee",obj:{visible:true},isServer:false};
            BeeEffects.update(bee);
            eq(bee.obj.visible,false,"None hides bee with performance="+performance);
            var area:Dynamic={baseSkill:{inf:{id:"Infusion_Kobold_DPS"}},stepKind:"Bomblet",isServer:false};
            eq(BombletEffects.suppress(area),true,"None hides Bomblet with performance="+performance);
            var travel:Dynamic={id:"Bomblet",visuals:{bellFx:{set:"Projectile_CheeseBomb"}}};
            eq(BombletEffects.suppressTravel(travel,{isServer:false}),true,
                "None hides Bomblet travel with performance="+performance);
            area.isServer=true;
            eq(BombletEffects.suppress(area),false,"None never suppresses server Bomblet damage");
            area.isServer=false;
            c.damageNumberLimit="Max";c.beeVisualLimit="Max";c.bombletVisualLimit="Max";
            applyLimits(c);
            eq(bee.obj.visible,true,"Max restores previously hidden bee");
            eq(BeeEffects.enabled,false,"Max disables bee limit");
            eq(BombletEffects.suppress(area),false,"Max allows Bomblet visuals");
            eq(BombletEffects.suppressTravel(travel,{isServer:false}),false,"Max allows Bomblet travel");
            for (i in 0...250) {
                eq(PerformanceDamageNumbers.suppress(),false,"Max preserves native damage display "+i);
                PerformanceDamageNumbers.created({parent:{}});
            }
            c.damageNumberLimit="Low";c.beeVisualLimit="Low";c.bombletVisualLimit="Low";
            applyLimits(c);
            var bees:Array<Dynamic>=[for (i in 0...3) {kind:"Summon_Bee",obj:{visible:true},isServer:false}];
            for (item in bees) BeeEffects.update(item);
            eq(bees[0].obj.visible,true,"Low keeps first bee visible");
            eq(bees[1].obj.visible,true,"Low keeps second bee visible");
            eq(bees[2].obj.visible,false,"Low hides third bee independently of performance");
            for (i in 0...10) PerformanceDamageNumbers.created({parent:{}});
            eq(PerformanceDamageNumbers.suppress(),true,"Low limits damage to ten attached widgets");
            eq(BombletEffects.enabled,true,"Low enables Bomblet limiter independently of performance");
            eq(BombletEffects.suppress(area),false,"Low admits first Bomblet after live selection");
            // Switching to Max must also remove stale claims before limiting again.
            c.damageNumberLimit="Max";c.beeVisualLimit="Max";c.bombletVisualLimit="Max";
            applyLimits(c);
            eq(bees[2].obj.visible,true,"Max restores bee visibility after Low");
            c.damageNumberLimit="Low";
            applyLimits(c);
            eq(PerformanceDamageNumbers.suppress(),false,"Re-enabling limit starts with an empty budget");
        }
        // updateSkillInputs also polls non-skill controls. These must remain
        // native, single-press actions even when hold-repeat is enabled.
        for(action in ["Item", "Item1", "UseItem", "QuickItem1", "ConsumeItem",
            "Potion", "Flask", "Dodge", "Dash", "DodgeRoll", "Mount",
            "SummonMount", "Unmount", "Ride", "Glider"]) {
            eq(HoldRepeat.repeatableSkillAction(action),false,
                action+": item/dodge/mount buttons never repeat");
        }
        for(action in ["Attack", "Secondary", "WeaponSkill1", "WeaponSkill2",
            "WeaponSkill3", "WeaponSkill4", "Skill1", "Skill2", "Skill3", "Skill4",
            "SignatureSkill", "weaponskill1", "SIGNATURESKILL"]) {
            eq(HoldRepeat.repeatableSkillAction(action),true,
                action+": combat skill buttons remain repeatable");
        }
        // PlayerController.updateSpecificSkillInputs uses this same action
        // to draw and sheathe; holding it must never toggle repeatedly.
        for(action in ["DrawWeapon", "drawweapon", "DRAWWEAPON"]) {
            eq(HoldRepeat.repeatableSkillAction(action),false,
                action+": drawing/sheathing weapons never repeats");
        }
        for(action in ["Jump", "Roll", "Interact", "Block", "Inventory", "GroupSkill1",
            "CloseWindow", "TargetLock", "Skill5", "WeaponSkill5", "WeaponSkill1Extra",
            "SignatureSkillExtra", "SecondarySkill", "UltimateSkill", "UnknownAction", "", null]) {
            eq(HoldRepeat.repeatableSkillAction(action),false,
                action+": every action outside the skill allowlist stays native");
        }
        var repeat=new HoldRepeat();
        eq(repeat.sample(true,true,true,1,true),true,"Native first press preserved");
        eq(repeat.sample(true,true,true,1.05,false),false,"Repeat never fires early");
        eq(repeat.sample(true,true,true,1.101,false),true,"Held skill repeats at 100 ms");
        eq(repeat.sample(true,true,true,1.105,false),false,"Cannot spam multiple checks in a frame");
        eq(repeat.sample(true,false,true,1.11,false),false,"Releasing cancels pending repeats");
        eq(repeat.sample(true,true,true,1.12,false),false,"New hold does not start with a synthetic press");
        eq(repeat.sample(true,true,true,1.221,false),true,"New hold repeats after its own delay");
        eq(repeat.sample(false,true,true,1.4,false),false,"Disabled setting preserves native input");
        eq(repeat.sample(true,true,false,1.5,false),false,"Blocked input never synthesizes a press");
        eq(HoldRepeat.blockFullscreen(true,"Fullscreen",true,true),true,"Ctrl+F intercepted");
        eq(HoldRepeat.blockFullscreen(true,"Fullscreen",false,true),false,"F alone is unaffected");
        eq(HoldRepeat.blockFullscreen(true,"Other",true,true),false,"Other Ctrl+F commands unaffected");
        eq(HoldRepeat.blockFullscreen(false,"Fullscreen",true,true),false,"Ctrl+F fix optional");
        Sys.println("Performance visual/input policies: "+checks+" checks passed");
    }
}
