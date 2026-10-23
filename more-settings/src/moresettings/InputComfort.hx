package moresettings;

import moresettings.GameAccess as G;

/** Input-side repeats only. Native skill legality/cooldowns remain authoritative. */
class InputComfort {
    public static var blockCtrlF:Bool = false;
    public static var holdSkills:Bool = false;
    static var inSkillInputs:Bool = false;
    static var controller:Dynamic;
    static var pulses:Map<String,HoldRepeat> = [];
    static var reported = false;
    static var loggedBlock = false;
    static var loggedRepeat = false;

    public static function reset():Void {
        inSkillInputs=false;controller=null;pulses=[];
    }
    public static function configure(ctrlF:Bool, hold:Bool):Void {
        if (blockCtrlF != ctrlF || holdSkills != hold) reset();
        blockCtrlF=ctrlF;holdSkills=hold;
    }
    public static function blockFullscreen(action:String):Bool {
        if (!blockCtrlF || action!="Fullscreen") return false;
        try {
            var ctrl=G.staticCall("hxd.Key","isDown",[17])==true
                || G.staticCall("hxd.Key","isDown",[162])==true
                || G.staticCall("hxd.Key","isDown",[163])==true
                || G.staticCall("hxd.Key","isPressed",[17])==true;
            var f=G.staticCall("hxd.Key","isDown",[70])==true
                || G.staticCall("hxd.Key","isPressed",[70])==true;
            var block=HoldRepeat.blockFullscreen(blockCtrlF,action,ctrl,f);
            if (block && !loggedBlock) {
                loggedBlock=true;trace("[More Settings] Ctrl+F fullscreen binding blocked.");
            }
            return block;
        }catch(e:Dynamic){warn(e);return false;}
    }
    public static function begin(current:Dynamic):Void {
        inSkillInputs=false;
        if (!holdSkills || current == null) {reset();return;}
        try {
            var unit=G.field(current,"unit"),player=G.field(unit,"player");
            if (player==null || G.field(player,"isMe")!=true
                || G.call("client.UnitController","get_gui",current)==null
                || G.call("client.UnitController","allInputsBlocked",current)==true) {
                reset();return;
            }
            if (controller!=current) {pulses=[];controller=current;}
            inSkillInputs=true;
        }catch(e:Dynamic){reset();warn(e);}
    }
    public static function end():Void inSkillInputs=false;
    public static function pressed(action:String,original:Bool):Bool {
        // This postfix runs globally, but we only repeat the actions that
        // the game itself queries *inside* UnitController.updateSkillInputs.
        if (!inSkillInputs || !holdSkills || action==null || action=="") return original;
        try {
            var held=G.staticCall("lib.Input","isDown",[action])==true;
            var pulse=pulses.get(action);
            if (pulse==null) {pulse=new HoldRepeat();pulses.set(action,pulse);}
            var result=pulse.sample(true,held,true,haxe.Timer.stamp(),original);
            if (result && !original && !loggedRepeat) {
                loggedRepeat=true;
                trace("[More Settings] Held skill inputs repeat at up to 10 presses/sec.");
            }
            return result;
        }catch(e:Dynamic){reset();warn(e);return original;}
    }
    static function warn(e:Dynamic):Void {
        if(!reported){reported=true;trace("[More Settings] Input comfort unavailable: "+Std.string(e));}
    }
}
