import itemutilities.NativeUtilityUi as UI;
import itemutilities.InspectAccess as G;
import itemutilities.OverlayRect;

enum PointerKind { EPush; EMove; }

class NativeUtilityUiTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var scene=G.object("Scene",null), window=G.object("window",scene), header=G.object("flow",window);
        var viewport=G.object("scroll-viewport",window), slot=G.object("slot",viewport);
        var clicks=0, toggles=0, selected=-1, saves=0;
        var rect=new OverlayRect(10,20,42,50), presets=new OverlayRect(20,50,222,86);
        G.ui={top:null};
        UI.beginFrame();
        UI.button(header,"deposit",rect,"materials","Deposit crafting components",() -> clicks++);
        UI.badge(slot); UI.lockInput(slot,() -> toggles++);
        UI.presets(header,"presets",presets,false,0,i -> selected=i,() -> saves++);
        UI.endFrame();
        var button=header.children[0], bar=header.children[1], dropdown=bar.children[0], save=bar.children[1];
        var badge=slot.children[0], input=slot.children[1];
        check(button.parent==header && bar.parent==header, "Buttons and preset bar stay in the owning window");
        check(button.absolute && bar.absolute && badge.absolute && input.absolute, "Utilities do not change native flow layout");
        check(badge.parent==slot && input.parent==slot && slot.parent==viewport, "Slot graphics and input inherit the native scroll mask");
        check(scene.children.length==1, "No always-on-top scene graphics or invisible input blockers");
        check(input.propagateEvents==false && input.enableRightButton==true, "Lock editing captures equipped-item actions");
        input.onClick({button:0}); input.onClick({button:1});
        check(toggles==1, "Left click toggles once; right click cannot trigger equipment actions");
        var wheel:Dynamic={propagate:false}; input.onWheel(wheel);
        check(wheel.propagate, "Lock edit mode still permits inventory scrolling");
        button.onClick(); check(clicks==1, "Native buttons retain their action");
        check(dropdown.options.length==5 && dropdown.options[4].name=="Preset 5", "All five presets remain available");
        check(dropdown.select.width==dropdown.width && dropdown.select.width < save.x
            && dropdown.select.height==save.height, "The actual preset button fits beside Set at the same height");
        check(dropdown.select.children.length==3 && dropdown.select.children[0].type=="selected-icon"
            && dropdown.select.children[1].type=="selected-text" && dropdown.select.children[2].type=="dropdown-arrow",
            "Styling preserves the native dropdown children and does not add a filtered background");
        check(dropdown.select.background.shader.backgroundColor.value==save.background.shader.backgroundColor.value,
            "Dropdown matches Set's visible shader color, including alpha, without a background tile");
        check(selected==-1, "Initial selection does not apply a preset");
        dropdown.onSelectOption(null); check(selected==0, "Reselecting the current preset reapplies it");
        dropdown.selectedIndex=4; dropdown.onSelectOption(null); check(selected==4, "Preset selection reaches the existing action");
        save.onClick(); check(saves==1, "Set saves once");

        var foreground=G.object("tooltip",scene);
        var geometry=G.geometryCalls;
        dropdown.select.hasHover=true;
        UI.beginFrame();
        UI.button(header,"deposit",rect,"materials","Deposit crafting components",() -> clicks++);
        UI.badge(slot); UI.lockInput(slot,() -> toggles++);
        UI.presets(header,"presets",presets,false,4,i -> selected=i,() -> saves++);
        UI.endFrame();
        check(Reflect.field(dropdown.select.background.styles,"background")==save.background.shader.backgroundColor.value,
            "Native background has a persistent color style matching Set");
        check(dropdown.select.background.color.value==0xFFCCCCCC,
            "Hover darkens the existing native background without touching its layout");
        check(button.parent==header && badge.parent==slot && button.visible && badge.visible, "Overlapping UI never hides the whole button or badge");
        check(scene.children[1]==foreground && scene.children.length==2, "Utilities cannot reorder themselves above foreground UI");
        check(G.geometryCalls==geometry && header.children.length==2 && slot.children.length==2, "Steady frames reuse controls and artwork");

        dropdown.listWindow=G.object("dropdown-list",scene);
        G.ui.top=G.object("option",dropdown.listWindow);
        UI.onPointerEvent({kind:EPush}); check(dropdown.listWindow!=null, "Pressing an option keeps its native release available");
        G.ui.top=foreground; UI.onPointerEvent({kind:EMove}); check(dropdown.listWindow!=null,"Hover does not dismiss presets");
        UI.onPointerEvent({kind:EPush}); check(dropdown.listWindow==null,"Outside presses close the preset list");
        dropdown.listWindow=G.object("dropdown-list",scene); UI.onWindowDisplayed(foreground);
        check(dropdown.listWindow==null,"Opening another window cannot leave a preset popup above it");

        dropdown.listWindow=G.object("dropdown-list",scene);
        UI.beginFrame(); UI.presets(header,"presets",presets,true,4,i -> selected=i,() -> saves++); UI.endFrame();
        check(!dropdown.enable && !save.enable && dropdown.listWindow==null,"Busy presets disable controls and close the list");
        selected=-1; dropdown.onSelectOption(null); save.onClick();
        check(selected==-1 && saves==1,"Busy actions cannot fire through stale callbacks");
        check(button.parent==null && input.parent==null && badge.parent==null,"Turning off controls removes graphics and hit targets");
        button.onClick(); input.onClick({button:0});
        check(clicks==1 && toggles==1,"Removed controls cannot act through retained callbacks");
        UI.beginFrame(); UI.presets(header,"presets",presets,false,1,i -> selected=i,() -> saves++); UI.endFrame();
        check(dropdown.enable && save.enable && dropdown.selectedIndex==1,"Hotkey selection and enabled state refresh silently");
        dropdown.listWindow=G.object("dropdown-list",scene);
        UI.beginFrame(); UI.endFrame();
        check(bar.parent==null && dropdown.listWindow==null,"Leaving a tab cleans up its separate dropdown window");
        UI.beginFrame(); UI.badge(slot); UI.lockInput(slot,() -> toggles++); UI.endFrame();
        UI.forget(slot); check(slot.children.length==0,"Recycled/removed slots immediately lose their utilities");
        UI.beginFrame(); UI.badge(slot, "junk-badge"); UI.lockInput(slot, () -> toggles++); UI.endFrame();
        var trash:Dynamic = slot.children[0];
        check(trash.parent==slot && trash.x==40 && trash.y==7, "Trash badge uses the lock badge's top-right placement");
        var trashInput:Dynamic=slot.children[1]; trashInput.onClick({button:0});
        check(toggles==2 && trashInput.propagateEvents==false, "Junk mode also captures the underlying item action");
        UI.beginFrame(); UI.badge(slot); UI.endFrame();
        check(trash.parent==null && slot.children.length==1, "Switching marker kinds removes the old badge");
        UI.forget(slot);
        testRename(scene);
        trace('Native utility UI: $checks checks passed');
    }

    static function testRename(scene:Dynamic):Void {
        var owner=G.object("window",scene), rect=new OverlayRect(0,0,202,36);
        var names=["Raid <fire>", "Boss", "Solo", "PvP", "Farming"], renamed=-1, applied=0, saved=0;
        var draw=(busy:Bool,character:String) -> {
            UI.beginFrame();
            UI.presets(owner,"named",rect,busy,2,_ -> applied++,() -> saved++,names,i -> renamed=i,character);
            UI.endFrame();
        };
        draw(false,"db:1");
        var dropdown=owner.children[0].children[0], builds=G.optionsBuilds;
        check(dropdown.options[0].name=="Raid &lt;fire&gt;", "Names are literal text, not FmtText markup");
        check(dropdown.selectText.useEllipsis && dropdown.selectText.maxWidthText==92,
            "Long labels stay inside the closed dropdown beside Set");
        for (slot in 0...5) {
            dropdown.listWindow=G.object("dropdown-list",scene);
            dropdown.items[slot].onRightClick();
            check(renamed==slot && dropdown.listWindow==null && dropdown.selectedIndex==2 && applied==0 && saved==0,
                "Right click opens the clicked slot's rename without selecting/applying/saving its setup");
        }
        draw(false,"db:1"); check(G.optionsBuilds==builds,"Steady frames never rebuild rows or callbacks");
        var old=dropdown.items[0].onRightClick;
        names[0]="New raid"; draw(false,"db:1");
        check(G.optionsBuilds==builds+1 && dropdown.options[0].name=="New raid" && applied==0,
            "Confirmed name changes refresh labels without applying a preset");
        renamed=-1; dropdown.listWindow=G.object("dropdown-list",scene); old();
        check(renamed==-1,"Replaced option callbacks cannot rename another slot/context");
        var current=dropdown.items[0].onRightClick;
        draw(false,"db:10"); check(dropdown.listWindow==null,"Character changes dismiss the old popup even with identical names");
        dropdown.listWindow=G.object("dropdown-list",scene); current(); check(renamed==-1,"Old character's rows cannot rename new character");
        current=dropdown.items[0].onRightClick;
        draw(true,"db:10"); dropdown.listWindow=G.object("dropdown-list",scene); current();
        check(renamed==-1,"Busy preset cannot be renamed by a stale callback");
        draw(false,"db:10"); dropdown.listWindow=G.object("dropdown-list",scene);
        UI.forget(owner); current(); check(renamed==-1,"Removed window cannot open a rename dialog");
    }
}
