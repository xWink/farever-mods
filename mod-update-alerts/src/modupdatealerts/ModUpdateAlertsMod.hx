package modupdatealerts;

import hlx.runtime.HlxPrefixResult;

@:build(hlx.runtime.Mod.build())
class ModUpdateAlertsMod {
    static var worker:UpdateWorker;
    static var popup:UpdatePopup;
    static var session=new AlertSession();
    static var retry=new PopupRetry();

    static function main():Void {}

    @:hlx.postfix(App.init)
    static function appInitialized(app:Dynamic,ignored:Void):Void {
        try startWorker() catch(error:Dynamic)
            trace("[Mod Update Alerts] Could not start update check: "+Std.string(error));
    }

    static function startWorker():Void {
        // Starting threads during HLX module loading can deadlock the loader.
        // App.init has finished by this point; no particular screen is required.
        if(worker==null) {
            var created=new UpdateWorker(Sys.getCwd());
            sys.thread.Thread.create(created.run);
            worker=created;
        }
    }

    @:hlx.postfix(ui.BaseUI.update)
    static function update(ui:Dynamic,dt:Float,ignored:Void):Void {
        try {
            if(ui==null) return;
            // Also covers a loader attached after the application initialized.
            startWorker();
            if(GameAccess.current("ui.BaseUI","current")!=ui) return;
            var changed=false;
            while(true) {
                var result=worker.results.pop(false);
                if(result==null) break;
                session.accept(result);
                changed=true;
                if(result.complete) for(note in result.notes) trace("[Mod Update Alerts] "+note);
            }
            if(popup!=null) {
                if(popup.update(ui)) {
                    if(changed) popup.replaceUpdates(session.updates,session.selected);
                    return;
                }
                popup=null;
            }
            if(!session.shouldShow()) return;
            if(!retry.ready(ui,haxe.Timer.stamp()) || !UpdatePopup.ready(ui)) return;
            popup=new UpdatePopup();
            popup.open(ui,session.updates,function(suppress:Bool):Void {
                session.close();
                popup=null;
            }, function(value:Bool):Void {
                worker.saves.add(session.select(value));
            }, session.selected);
            retry.succeeded();
        } catch (error:Dynamic) {
            UpdatePopup.constructing=false;
            var stage=popup==null ? "update check" : popup.stage;
            if(popup!=null) try popup.dispose() catch (_:Dynamic) {}
            popup=null;
            var detail=Std.string(error), message=stage+": "+detail;
            if(retry.failed(haxe.Timer.stamp(),message))
                trace("[Mod Update Alerts] Could not show updates ("+message+"). Will retry when the UI is ready.");
        }
    }

    @:hlx.prefix(ui.BaseUI.dispose)
    static function leavingUi(ui:Dynamic):HlxPrefixResult<Void> {
        // Unregister from the old UI before it is torn down. An undismissed
        // alert can then open on the next active UI, including gameplay.
        if(popup!=null && popup.owner==ui) {
            var old=popup;popup=null;
            try old.dispose() catch(error:Dynamic)
                trace("[Mod Update Alerts] Could not remove popup during UI transition: "+Std.string(error));
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
