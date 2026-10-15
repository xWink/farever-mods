import dpsmeter.NativeFareverlyAccount;
import dpsmeter.FareverlyAccountWorker;
import dpsmeter.FareverlyBrowser;
import dpsmeter.GameAccess as G;
import dpsmeter.MeterConfig;
import fareverly.Protocol;
import hlx.runtime.Bus;

class FareverlyDialogTest {
    static var checks = 0;
    static var uri = "https://fareverly.com/connect/12345678-1234-1234-1234-123456789abc";
    static function check(ok:Bool, message:String):Void { checks++; if (!ok) throw message; }
    static function event(generation:Int, active:Bool):AccountEvent return {generation:generation, active:active, manualResult:false,
        message:active ? "Match this code in your browser." : "Steam sign-in cancelled.", code:active ? "ABCD-1234" : "",
        account:"private-account-id", url:active ? uri : "", credential:Protocol.empty(), persist:false, expectedKey:""};
    static function main():Void {
        var saves = 0;
        var controller = new NativeFareverlyAccount(MeterConfig.defaults(), (_,_) -> { saves++; return true; });
        var worker = FareverlyAccountWorker.last;
        var hero = {accountId:"private-account-id"};
        controller.update(hero);
        Bus.publish("better-mod-settings/action/dps-meter/fareverlySignIn", null);
        worker.events.push(event(1,true)); controller.update(hero);
        var dialog = G.latest;
        check(G.created == 1 && FareverlyBrowser.opened.length == 1, "Sign-in opens one dialog and automatically opens the browser");
        check(dialog.message.indexOf("ABCD-1234") >= 0 && dialog.message.indexOf("private-account-id") < 0,
            "Popup shows the code without the Farever account ID");
        check(dialog.buttons.length == 1 && dialog.buttons[0].text == "Cancel sign-in", "Pending sign-in has only a Cancel button");
        check(dialog.descriptors[0].onBack == true, "Escape/back uses the same cancellation action");
        G.choose(dialog, 0);
        check(worker.cancellations == 1 && G.removed == 1, "Cancel signals the worker and lets native UI close once");
        worker.events.push(event(1,true)); // A response already queued at click time.
        var completed = event(1,false); completed.persist = true;
        worker.events.push(completed); controller.update(hero);
        check(G.created == 1 && G.removed == 1 && G.ui.windows.length == 0, "Cancellation never flashes a replacement modal");
        check(FareverlyBrowser.opened.length == 1 && saves == 0, "Late cancelled events cannot reopen browser or save a key");
        Bus.publish("better-mod-settings/action/dps-meter/fareverlySignIn", null);
        worker.events.push(event(2,true)); controller.update(hero);
        check(G.created == 2 && FareverlyBrowser.opened.length == 2, "A fresh attempt works after cancellation");
        completed = event(2,false); completed.persist = true; completed.message = "Saved";
        worker.events.push(completed); controller.update(hero);
        check(saves == 1 && G.latest.buttons.length == 1 && G.latest.buttons[0].text == "OK", "Successful authorization still saves and shows its result");
        controller.disconnect();
        Sys.println('Fareverly dialog: $checks checks passed.');
    }
}
