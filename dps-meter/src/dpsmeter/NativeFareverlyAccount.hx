package dpsmeter;

import dpsmeter.GameAccess as G;
import hlx.runtime.Bus;
import dpsmeter.MeterConfig.MeterSettings;
import fareverly.Protocol;
import fareverly.SessionLease;

/** BMS uses the ordinary DPS Meter config and its existing change/action events. */
class NativeFareverlyAccount {
    final worker = new FareverlyAccountWorker();
    final browser = new FareverlyBrowser();
    final config:MeterSettings;
    final saveCredential:(Credential, String)->Bool;
    var observedKey = "";
    final status:Dynamic = {value:"Sign in through Steam to connect Fareverly."};
    var dialog:Dynamic;
    var dialogOwner:Dynamic;
    var localAccount = "";
    var opening = false;
    var active = false;
    var openedUri = "";
    var owner:String;
    var generation = 0;
    public function new(config:MeterSettings, saveCredential:(Credential, String)->Bool) {
        this.config = config; this.saveCredential = saveCredential;
        owner = HlxRuntime.moduleName();
        var prefix = "better-mod-settings/action/" + owner + "/";
        Bus.subscribe(prefix + "fareverlySignIn", (_:Dynamic) -> start(FareverlyConfig.key(config) != ""));
        settingsChanged();
    }
    public function settingsChanged():Void {
        var key = FareverlyConfig.key(config);
        if (active && key != observedKey) worker.cancel();
        observedKey = key;
        worker.settings(localAccount, key, FareverlyConfig.credential(config));
    }
    function start(replace:Bool):Void {
        if (active) return;
        if (localAccount == "") { notice("Enter the game with your character before generating a key."); return; }
        if (!SessionLease.acquire(owner)) { notice("A Fareverly sign-in is already in progress in another mod."); return; }
        active = true; openedUri = ""; status.value = "Preparing Steam sign-in...";
        generation = worker.start(localAccount, replace, FareverlyConfig.key(config));
    }
    public function uploadMessage(message:String):Void { if (!active && message != "") status.value = message; }
    public function disconnect():Void { closeDialog(); localAccount = ""; worker.setAccount(""); worker.cancel(); }
    public function update(hero:Dynamic):Void {
        var account = NativePlayerIdentity.accountId(hero);
        if (account == null) account = "";
        if (account != localAccount) { if (active) worker.cancel(); localAccount = account; worker.setAccount(account); settingsChanged(); }
        if (opening) try { if (browser.poll()) opening = false; }
        catch (_:Dynamic) { opening = false; worker.cancel(); status.value = "Could not open your browser. Try signing in again."; }
        var event = worker.receive();
        while (event != null) {
            if (event.generation < generation) { event = worker.receive(); continue; }
            var finished = active && !event.active;
            if (finished) SessionLease.release(owner);
            active = event.active;
            status.value = event.message;
            if (event.code != "") status.value = "Code: " + event.code + "\nFarever account: " + event.account + "\n" + event.message;
            if (event.persist) {
                if (saveCredential(event.credential, event.expectedKey))
                    status.value = event.manualResult ? "Fareverly key verified and saved." : "Steam connected. Your Fareverly key has been saved. Reopen Mod Settings to display it.";
                else status.value = "The key could not be saved, or the textbox changed during sign-in. Your current DPS Meter settings were kept.";
            }
            if (finished || event.manualResult) notice(status.value);
            if (event.url != "" && event.url != openedUri) {
                openedUri = event.url;
                notice(status.value, true);
                if (!open(event.url)) worker.cancel();
            }
            event = worker.receive();
        }
    }
    function closeDialog():Void {
        if (dialog != null && dialogOwner != null && G.field(dialog, "allocated") == true)
            G.call("ui.BaseUI", "removeWindow", dialogOwner, [dialog]);
        dialog = null; dialogOwner = null;
    }
    function notice(message:String, pending:Bool = false):Void {
        closeDialog();
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null) return;
        var buttons = G.call("hl.types.ArrayObj", "slice", G.field(ui, "windows"), [0, 0]);
        G.call("hl.types.ArrayObj", "pushDyn", buttons, [{ic:"Confirm", input:null, checkEnable:null, onBack:!pending}]);
        if (pending) G.call("hl.types.ArrayObj", "pushDyn", buttons, [{ic:"Cancel", input:null, checkEnable:null, onBack:true}]);
        dialogOwner = ui;
        dialog = G.call("ui.BaseUI", "displayDialog", ui, ["Fareverly", LiteralText.escape(message), buttons, function(choice:String):Void {
            // Closing the code popup does not abort an approved browser flow.
            if (pending && choice == "Cancel") worker.cancel();
        }]);
        var nativeButtons = G.field(dialog, "buttons");
        G.call("ui.comp.Button", "setText", G.call("hl.types.ArrayObj", "getDyn", nativeButtons, [0]), [pending ? "Continue in browser" : "OK"]);
        if (pending) G.call("ui.comp.Button", "setText", G.call("hl.types.ArrayObj", "getDyn", nativeButtons, [1]), ["Cancel sign-in"]);
    }
    function open(url:String):Bool {
        if (opening) return false;
        try { browser.open(url); opening = true; return true; }
        catch (_:Dynamic) { status.value = "Could not open Fareverly in your browser."; return false; }
    }
}
