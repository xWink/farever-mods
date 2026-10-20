import moresettings.DungeonLeaveButton;
import moresettings.GameAccess as G;
import moresettings.SettingsData;

class DungeonLeaveButtonTest {
    static var checks = 0;
    static function eq(actual:Bool, expected:Bool, message:String):Void {
        checks++;
        if (actual != expected) throw message;
    }

    static function main():Void {
        eq(SettingsData.defaults().leaveDungeonButton, true, "enabled by default");
        var hero:Dynamic = {isInCombat: false,dead:false};
        var layer:Dynamic = {mainActivity: {types: ["st.activity.Dungeon"]}};
        var player:Dynamic = {hero: hero, layer: layer};
        G.data = {player: player};
        var button:Dynamic = {visible: false,minWidth:100,maxWidth:100,btnText:{text:"Leave",textMultiline:true,lineBreak:true}};
        var hud:Dynamic = {leaveBtn: button, removed: false};
        DungeonLeaveButton.attach(hud);
        eq(DungeonLeaveButton.visibility(button, false), true, "exit portal no longer hides the button outside combat");
        eq(DungeonLeaveButton.visibility(button, true), true, "native shown button stays shown");
        hero.isInCombat = true;
        eq(DungeonLeaveButton.visibility(button, true), false, "combat hides even a natively shown button");
        eq(DungeonLeaveButton.visibility(button, false), false, "combat keeps a hidden button hidden");
        hero.isInCombat = false;
        eq(DungeonLeaveButton.visibility(button, false), true, "leaving combat restores the button");
        player.hero = null;
        eq(DungeonLeaveButton.visibility(button, true), false, "missing hero cannot expose a stale button");
        player.hero = hero;
        for (activity in [null, {types: ["st.Activity"]}]) {
            layer.mainActivity = activity;
            for (nativeValue in [false, true])
                eq(DungeonLeaveButton.visibility(button, nativeValue), nativeValue, "non-dungeon visibility stays native");
        }
        eq(SettingsData.defaults().leaveRiftButton,true,"rift option enabled by default");
        layer.mainActivity={types:["st.activity.Rift"]};
        DungeonLeaveButton.enabled=false;
        eq(DungeonLeaveButton.visibility(button,false),true,"rift option works independently of dungeon option");
        eq(button.btnText.text=="Leave Rift",true,"rift caption");
        eq(button.minWidth>=140&&button.maxWidth>=140,true,"rift caption gets a wider button");
        eq(button.btnText.textMultiline||button.btnText.lineBreak,false,"rift caption stays on one line");
        hero.isInCombat=true;
        eq(DungeonLeaveButton.visibility(button,true),false,"combat hides rift exit");
        hero.dead=true;
        eq(DungeonLeaveButton.visibility(button,false),true,"dead hero can leave an active rift");
        DungeonLeaveButton.riftEnabled=false;
        eq(DungeonLeaveButton.visibility(button,false),false,"dead hero still respects disabled rift setting");
        DungeonLeaveButton.riftEnabled=true;
        layer.mainActivity={types:["st.activity.Dungeon"]};DungeonLeaveButton.enabled=true;
        eq(DungeonLeaveButton.visibility(button,true),false,"death exception does not change dungeon combat rule");
        layer.mainActivity={types:["st.activity.Rift"]};
        hero.dead=false;
        eq(DungeonLeaveButton.visibility(button,true),false,"reviving during combat hides rift exit again");
        hero.isInCombat=false;player.hero=null;
        eq(DungeonLeaveButton.visibility(button,true),false,"missing hero hides rift exit");player.hero=hero;
        eq(DungeonLeaveButton.visibility(button,false),true,"leaving combat restores rift exit");
        DungeonLeaveButton.riftEnabled=false;
        eq(DungeonLeaveButton.visibility(button,false),false,"disabled rift option restores native visibility");
        eq(button.btnText.text=="Leave",true,"disabled rift option restores native caption");
        eq(button.minWidth==100&&button.maxWidth==100,true,"native button width restored");
        eq(button.btnText.textMultiline&&button.btnText.lineBreak,true,"native wrapping restored");
        DungeonLeaveButton.riftEnabled=true;
        eq(DungeonLeaveButton.visibility(button,false),true,"rift toggle works without rebuilding HUD");
        layer.mainActivity={types:["st.Activity"]};
        eq(DungeonLeaveButton.visibility(button,false),false,"world transition hides exit");
        eq(button.btnText.text=="Leave",true,"world transition restores caption");
        layer.mainActivity = {types: ["st.activity.Dungeon"]};
        DungeonLeaveButton.enabled = false;
        eq(DungeonLeaveButton.visibility(button, false), false, "disable restores the native portal rule");
        DungeonLeaveButton.enabled = true;
        eq(DungeonLeaveButton.visibility(button, false), true, "reenable needs no HUD rebuild");
        eq(DungeonLeaveButton.visibility({visible: false}, false), false, "other UI stays untouched");
        hud.removed = true;
        eq(DungeonLeaveButton.visibility(button, false), false, "removed HUD stays native");
        hud.removed = false;
        var replacement:Dynamic = {visible: false};
        DungeonLeaveButton.attach({leaveBtn: replacement, removed: false});
        eq(DungeonLeaveButton.visibility(button, false), false, "old button released on rebuild");
        eq(DungeonLeaveButton.visibility(replacement, false), true, "replacement button uses current setting");
        layer.mainActivity={types:["st.activity.Rift"]};
        eq(DungeonLeaveButton.visibility(replacement,false),true,"unconstrained replacement can show rift exit");
        DungeonLeaveButton.riftEnabled=false;
        eq(DungeonLeaveButton.visibility(replacement,false),false,"disable unconstrained replacement");
        eq(replacement.minWidth==null&&replacement.maxWidth==null,true,"unset native constraints are restored as null");
        DungeonLeaveButton.clear();
        eq(DungeonLeaveButton.visibility(replacement, false), false, "world disposal releases the HUD");
        Sys.println('Dungeon leave button: $checks checks passed.');
    }
}
