import modupdatealerts.UpdatePopup;
import modupdatealerts.GameAccess;

/** Keep display-tree removal distinct from the game's modal window registry. */
@:access(modupdatealerts.UpdatePopup)
class PopupLifecycleTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic):Void {
        checks++;
        if(actual!=expected) throw 'Expected $expected, got $actual';
    }
    public static function run():Int {
        checks=0;
        var other:Dynamic={parent:{},removed:false};
        var window:Dynamic={parent:{},removed:false};
        var owner:Dynamic={windows:[other,window]};
        var popup=new UpdatePopup(), calls=0, selected=false;
        popup.owner=owner;popup.window=window;popup.ignore=true;
        popup.onDismiss=function(value:Bool):Void {calls++;selected=value;};
        // This is the callback used by both X and the Escape hook.
        popup.dismiss();
        eq(owner.windows.length,1);eq(owner.windows[0],other);
        eq(window.parent,null);eq(other.removed,false);
        eq(popup.owner,null);eq(calls,1);eq(selected,true);
        popup.dismiss();popup.dispose();
        eq(calls,1);eq(owner.windows.length,1);

        // Disconnect/character changes must clean the old owner's registry,
        // even when BaseUI.current already points at a different UI.
        var newWindow:Dynamic={parent:{},removed:false};
        var newUi:Dynamic={windows:[newWindow]};
        GameAccess.currentUi=newUi;
        owner.windows=[window];window.parent={};window.removed=false;
        popup=new UpdatePopup();popup.owner=owner;popup.window=window;
        eq(popup.update(newUi),false);
        eq(owner.windows.length,0);eq(newUi.windows.length,1);
        eq(newWindow.removed,false);

        // Construction may fail before an owner/window is fully established.
        popup=new UpdatePopup();popup.window={parent:{},removed:false};
        var partial=popup.window;
        popup.dispose();eq(partial.parent,null);
        popup.dispose();eq(popup.window,null);
        menuReadiness();
        changelogNavigation();
        GameAccess.currentUi=null;
        GameAccess.icons=null;
        return checks;
    }
    static function menuReadiness():Void {
        // Main-menu eligibility does not require a GameApp or a hero.
        var ui:Dynamic={menuRoot:{},root:{parent:{}},style:{},s2d:{width:1920,height:1080},
            currentScreen:{removed:false,splashscreen:true,splashscreenContainer:{alpha:1.0}}};
        GameAccess.icons={byId:{}};
        eq(UpdatePopup.ready(ui),false);
        ui.currentScreen.splashscreenContainer.alpha=0.0;
        eq(UpdatePopup.ready(ui),true);
        ui.currentScreen={removed:false}; // Character-select screen.
        eq(UpdatePopup.ready(ui),true);
        ui.currentScreen.removed=true;
        eq(UpdatePopup.ready(ui),false);
        ui.currentScreen=null;
        eq(UpdatePopup.ready(ui),false);
        ui.currentScreen={};ui.menuRoot=null; // In-game UI stays quiet.
        eq(UpdatePopup.ready(ui),false);
    }
    static function changelogNavigation():Void {
        var popup=new UpdatePopup(),dismissed=0;
        popup.updates=[for(i in 0...7) {name:'Mod $i',domain:"farever",modId:i+1,
            current:"1",latest:"2",changelog:i==6 ? "[literal] & notes" : ""}];
        popup.columns=[{},{},{}];popup.changes=[{}];popup.rows=[[{},{},{}]];
        popup.back={};popup.detailTitle={};popup.notesPanel={scrollPosY:55.0};popup.notesText={};
        popup.previous={};popup.next={};popup.pageText={};popup.page=1;
        popup.onDismiss=function(_) dismissed++;
        popup.openChangelog(6);
        eq(popup.columns[0].visible,false);eq(popup.changes[0].visible,false);
        eq(popup.back.visible,true);eq(popup.notesPanel.visible,true);
        eq(popup.notesPanel.scrollPosY,0.0);
        eq(popup.notesText.text,"&#91;literal] &amp; notes");
        eq(popup.previous.visible,false);eq(popup.pageText.visible,false);
        popup.detailIndex=-1;popup.refresh(); // Back preserves the table page.
        eq(popup.page,1);eq(popup.rows[0][0].text,"Mod 6");
        eq(popup.previous.visible,true);eq(popup.notesPanel.visible,false);
        popup.openChangelog(0);
        eq(popup.notesText.text,"No changelog was provided for this release on Nexus Mods.");
        eq(dismissed,0);
    }
}
