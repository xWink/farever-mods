package modupdatealerts;

import hlx.runtime.HlxPrefixResult;
import modupdatealerts.UpdateWorker.CheckResult;

@:build(hlx.runtime.Mod.build())
class ModUpdateAlertsMod {
    static var worker:UpdateWorker;
    static var result:CheckResult;
    static var popup:UpdatePopup;
    static var finished=false;
    static var selected=false;
    static var originalDismissed:Map<String,String>;
    static var retry=new PopupRetry();

    static function main():Void {}

    @:hlx.postfix(MenuApp.init)
    static function menuInitialized(app:Dynamic,ignored:Void):Void {
        try startWorker() catch(error:Dynamic)
            trace("[Mod Update Alerts] Could not start update check: "+Std.string(error));
    }

    static function startWorker():Void {
        // Starting threads during HLX module loading can deadlock the loader.
        // MenuApp.init has finished by this point; no character is required.
        if(worker==null) {
            var created=new UpdateWorker(Sys.getCwd());
            sys.thread.Thread.create(created.run);
            worker=created;
        }
    }

    @:hlx.postfix(MenuApp.update)
    static function update(app:Dynamic,dt:Float,ignored:Void):Void {
        try {
            var ui=GameAccess.field(app,"ui");
            if(ui==null) return;
            // Also covers a loader attached after the menu was initialized.
            startWorker();
            if(GameAccess.current("ui.BaseUI","current")!=ui) return;
            if(result==null) {
                result=worker.results.pop(false);
                if(result!=null) {
                    originalDismissed=result.dismissed.copy();
                    for(note in result.notes) trace("[Mod Update Alerts] "+note);
                    if(!UpdateModel.needsReminder(result.updates,result.dismissed)) finished=true;
                }
            }
            if(finished || result==null) return;
            if(popup!=null && popup.update(ui)) return;
            if(!retry.ready(ui,haxe.Timer.stamp()) || !UpdatePopup.ready(ui)) return;
            popup=new UpdatePopup();
            popup.open(ui,result.updates,function(suppress:Bool):Void {
                finished=true;
                popup=null;
            }, function(value:Bool):Void {
                selected=value;
                result.dismissed=originalDismissed.copy();
                if(value) UpdateModel.dismiss(result.updates,result.dismissed);
                worker.saves.add(result.dismissed.copy());
            }, selected);
            retry.succeeded();
        } catch (error:Dynamic) {
            UpdatePopup.constructing=false;
            var stage=popup==null ? "update check" : popup.stage;
            if(popup!=null) try popup.dispose() catch (_:Dynamic) {}
            popup=null;
            var detail=Std.string(error), message=stage+": "+detail;
            var initializing=detail=="Native title window content was not initialized";
            if(retry.failed(haxe.Timer.stamp(),message,initializing))
                trace("[Mod Update Alerts] Could not show updates ("+message+"). Will retry when the UI is ready.");
        }
    }

    @:hlx.prefix(MenuApp.dispose)
    static function leavingMenu(app:Dynamic):HlxPrefixResult<Void> {
        // A pending result survives character login, but the popup must not
        // follow the player into gameplay. Retry when the menu returns.
        if(popup!=null && popup.owner==GameAccess.field(app,"ui")) {
            var old=popup;popup=null;
            try old.dispose() catch(error:Dynamic)
                trace("[Mod Update Alerts] Could not remove popup while leaving menu: "+Std.string(error));
        }
        return Continue;
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressAutoDisplay(window:Dynamic):HlxPrefixResult<Void> {
        return UpdatePopup.constructing ? Skip : Continue;
    }

    @:hlx.prefix(ui.BaseUI.closeFirstClosableUI)
    static function closeOnEscape(ui:Dynamic,onlyEscapeClosable:Null<Bool>):HlxPrefixResult<Bool> {
        if(popup!=null && popup.owner==ui) {popup.dismiss();return SkipWith(true);}
        return Continue;
    }

    @:hlx.prefix(App.quit)
    static function stop(app:Dynamic):HlxPrefixResult<Void> {
        if(worker!=null) worker.stop();
        return Continue;
    }
}
