import moresettings.ProcTiming;

class ProcTimingTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw '$why: expected $b, got $a';
    }
    static function status(id:String, remaining:Float, infinite = false):Dynamic
        return {kind:id, duration:infinite ? -1.0 : 10.0, remaining:remaining, removed:false};
    static function main():Void {
        var owner:Dynamic = {statuses:{array:[]}, time:{serverNow:105.0}};
        var skill:Dynamic = {owner:owner, inf:{id:"Bow_Craft_Skill1", vars:{time:8.0}}, script:{Proc:"Bow_Craft_Passive_Status"}};
        var a = status("Bow_Craft_Passive_Status", 2.0);
        var b = status("Bow_Craft_Passive_Status", 7.0);
        owner.statuses.array = [a,b,status("Unrelated", 90)];
        eq(ProcTiming.remaining(skill), 7.0, "any remaining proc instance keeps the button available");
        b.removed = true;
        eq(ProcTiming.remaining(skill), 2.0, "removed status is ignored");
        a.remaining = 8.0;
        eq(ProcTiming.remaining(skill), 8.0, "native refresh updates duration");
        a.persistent = true;
        eq(ProcTiming.remaining(skill), null, "non-expiring status does not get a fake deadline");
        a.persistent = false; a.remaining = 0.0;
        eq(ProcTiming.remaining(skill), null, "expired timer is hidden");
        skill.inf.id = "Unknown";
        eq(ProcTiming.remaining(skill), null, "unrelated timed buffs never label unknown procs");
        skill.inf.id = "DM_Multispin_Skill1"; skill.script = {lastHitTime:100.0};
        eq(ProcTiming.remaining(skill), 3.0, "recast uses the native server timestamp and window");
        skill.script.lastHitTime = 104.0;
        eq(ProcTiming.remaining(skill), 7.0, "new hit refreshes recast deadline");
        skill.inf.id = "Fists_LightMonk_Skill1";
        skill.script = {marks:[status("Fists_LightMonk_Skill1_Status", 1.0),status("Fists_LightMonk_Skill1_Status", 4.0)]};
        eq(ProcTiming.remaining(skill), 4.0, "last surviving enemy mark governs recast expiry");
        skill.inf.id = "Fists_LightMonk_Skill1_Recast";
        eq(ProcTiming.remaining(skill), 4.0, "alternate recast button shares mark deadline");
        skill.inf.id = "Book_WaterOrbs_Skill2";
        owner.statuses.array = [status("Book_WaterOrbs_Skill2_Recast_Proc", 5.0), status("Book_WaterOrbs_Orb_Charge", 2.0)];
        eq(ProcTiming.remaining(skill), 2.0, "orb expiry can end recast before its window");
        owner.statuses.array[1].duration = -1;
        eq(ProcTiming.remaining(skill), 5.0, "infinite orbs still use bounded recast window");
        skill.inf.id = "Staff_Censer_Ultimate";
        owner.statuses.array = [status("Staff_Censer_Ultimate_Proc", 0.0, true)];
        eq(ProcTiming.remaining(skill), null, "untimed ultimate is not assigned a cooldown countdown");
        skill.inf.id = "Infusion_Manfish_DPS_Ultimate";
        owner.statuses.array = [status("Infusion_Manfish_DPS_Ultimate_Proc", 6.0)];
        eq(ProcTiming.remaining(skill), 6.0, "temporary signature override follows its granting status");
        eq(ProcTiming.label(0.001), "0.1", "never displays zero before expiry");
        eq(ProcTiming.label(2.91), "3.0", "fractional deadline rounds up");
        eq(ProcTiming.label(3), "3", "whole seconds after precision threshold");
        eq(ProcTiming.label(7.1), "8", "seconds round up like a countdown");
        eq(ProcTiming.label(60.1), "1:01", "long timers remain compact");
        eq(ProcTiming.label(null), "", "absent timer is blank");
        eq(ProcTiming.label(Math.NaN), "", "invalid timer is blank");
        trace('Proc timing: $checks checks passed');
    }
}
