import moresettings.BeeEffectPolicy;
import moresettings.BombletEffectPolicy;
import moresettings.VisualRateLimit;
import moresettings.VisualQuota;
import moresettings.VisualDamageBudget;
import moresettings.HoldRepeat;
import moresettings.SettingsData;

class PerformanceVisualsTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic,message:String):Void {
        checks++;
        if(actual!=expected)throw message+": expected "+Std.string(expected)+", got "+Std.string(actual);
    }
    static function main():Void {
        var c=SettingsData.defaults();
        eq(c.performanceOptimization,false,"Performance effects remain opt-in");
        eq(c.preventCtrlFFullscreen,false,"Ctrl+F fix remains opt-in");
        eq(c.holdSkillRepeat,false,"Hold-to-repeat remains opt-in");
        eq(c.damageNumberScale,100,"Default damage scale is neutral");
        eq(c.damageNumberOpacity,100,"Default damage alpha is neutral");
        eq(c.damageNumberLimit,20,"Damage number limit defaults to previous throughput");
        eq(c.beeVisualLimit,100,"Bee visual slider defaults to maximum");
        eq(c.bombletVisualLimit,100,"Bomblet visual slider defaults to maximum");
        eq(c.showEnemyDistance,false,"Enemy distance is opt-in");
        for (key in ["damageNumberLimit","beeVisualLimit","bombletVisualLimit"]) {
            Reflect.setField(c,key,-20);
        }
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,0,"Damage number budget lower clamp");
        eq(c.beeVisualLimit,0,"Bee visual count lower clamp");
        eq(c.bombletVisualLimit,0,"Bomblet visual count lower clamp");
        c.damageNumberLimit=999;c.beeVisualLimit=999;c.bombletVisualLimit=999;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,200,"Damage number budget upper clamp");
        eq(c.beeVisualLimit,100,"Bee visual count upper clamp");
        eq(c.bombletVisualLimit,100,"Bomblet visual count upper clamp");
        c.disableDamageNumbers=true;
        SettingsData.normalize(c);
        eq(c.damageNumberLimit,0,"Old disable setting migrates to zero");
        eq(c.disableDamageNumbers,false,"Old disable flag clears after migration");
        c.damageNumberLimit=20;
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
            "Disabled optimization has no visual effect");
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
            "Damage number slider zero suppresses all widgets");
        budget.configure(200);
        eq(budget.maximum,200,"Slider maximum allows two hundred simultaneous widgets");
        eq(budget.allow(0,widget->widget.parent!=null),true,
            "Two hundred per second first number");
        eq(budget.allow(0.004,widget->widget.parent!=null),false,
            "Two hundred per second still rate-limits tiny bursts");
        eq(budget.allow(0.006,widget->widget.parent!=null),true,
            "Two hundred per second permits number after five milliseconds");
        budget.configure(20);
        eq(budget.maximum,20,"Live slider updates replace the old hardcoded limit");
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
        moresettings.BeeEffects.configure(true,100);
        eq(moresettings.BeeEffects.enabled,false,
            "Bee slider max preserves normal visuals");
        moresettings.BeeEffects.configure(true,2);
        eq(moresettings.BeeEffects.enabled,true,
            "Lower bee slider enables visual optimization");
        moresettings.BeeEffects.configure(false,2);
        eq(moresettings.BeeEffects.enabled,false,
            "Performance toggle off disables bee limitations");
        moresettings.BombletEffects.configure(true,100);
        eq(moresettings.BombletEffects.enabled,false,
            "Bomblet slider maximum preserves normal visuals");
        moresettings.BombletEffects.configure(true,4);
        eq(moresettings.BombletEffects.enabled,true,
            "Bomblet visual limiter can be enabled");
        moresettings.BombletEffects.configure(false,4);
        eq(moresettings.BombletEffects.enabled,false,
            "Performance toggle off disables bomblet limitations");
        moresettings.PerformanceDamageNumbers.configure(false,0);
        eq(moresettings.PerformanceDamageNumbers.suppress(),true,
            "Damage limit 0 hides numbers even without performance toggle");
        moresettings.PerformanceDamageNumbers.configure(false,20);
        eq(moresettings.PerformanceDamageNumbers.suppress(),false,
            "No damage throttling when performance optimization is disabled");
        // updateSkillInputs also polls non-skill controls. These must remain
        // native, single-press actions even when hold-repeat is enabled.
        for(action in ["Item", "Item1", "UseItem", "QuickItem1", "ConsumeItem",
            "Potion", "Flask", "Dodge", "Dash", "DodgeRoll", "Mount",
            "SummonMount", "Unmount", "Ride", "Glider"]) {
            eq(HoldRepeat.repeatableSkillAction(action),false,
                action+": item/dodge/mount buttons never repeat");
        }
        for(action in ["Skill1", "Skill2", "Skill3", "Attack",
            "SecondarySkill", "WeaponSkill1", "UltimateSkill"]) {
            eq(HoldRepeat.repeatableSkillAction(action),true,
                action+": combat skill buttons remain repeatable");
        }
        for(action in ["Jump", "Roll", "Interact", "Block", "Inventory"]) {
            eq(HoldRepeat.repeatableSkillAction(action),false,
                action+": movement or UI commands remain native");
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
