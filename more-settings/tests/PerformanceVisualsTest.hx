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
        var active=new Array<Dynamic>();
        for(i in 0...8) {
            var o:Dynamic={parent:{}};
            eq(budget.allow(i*0.11, widget->widget.parent!=null),true,
                "Attached widget budget admits number "+i);
            budget.created(o);
            active.push(o);
        }
        eq(budget.allow(2,widget->widget.parent!=null),false,"At most eight attached widgets");
        active[0].parent=null;
        eq(budget.allow(2.11,widget->widget.parent!=null),true,
            "Detached damage number releases its visual slot");
        budget.reset();
        eq(budget.allow(3,widget->widget.parent!=null),true,
            "Reset restores the native number budget");
        var repeat=new HoldRepeat();
        eq(repeat.sample(true,true,true,1,true),true,"Native first press preserved");
        eq(repeat.sample(true,true,true,1.05,false),false,"Repeat never fires early");
        eq(repeat.sample(true,true,true,1.101,false),true,"Held skill repeats at 100 ms");
        eq(repeat.sample(true,true,true,1.105,false),false,"Cannot spam multiple checks in a frame");
        eq(repeat.sample(true,false,true,1.11,false),false,"Releasing cancels pending repeats");
        eq(repeat.sample(true,true,true,1.12,false),false,"New hold does not start with a synthetic press");
        eq(repeat.sample(true,true,true,1.22,false),true,"New hold repeats after its own delay");
        eq(repeat.sample(false,true,true,1.4,false),false,"Disabled setting preserves native input");
        eq(repeat.sample(true,true,false,1.5,false),false,"Blocked input never synthesizes a press");
        eq(HoldRepeat.blockFullscreen(true,"Fullscreen",true,true),true,"Ctrl+F intercepted");
        eq(HoldRepeat.blockFullscreen(true,"Fullscreen",false,true),false,"F alone is unaffected");
        eq(HoldRepeat.blockFullscreen(true,"Other",true,true),false,"Other Ctrl+F commands unaffected");
        eq(HoldRepeat.blockFullscreen(false,"Fullscreen",true,true),false,"Ctrl+F fix optional");
        Sys.println("Performance visual/input policies: "+checks+" checks passed");
    }
}
