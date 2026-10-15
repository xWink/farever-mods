package dpsmeter;

import dpsmeter.GameAccess as G;
import hlx.runtime.Bus;
import fareverly.Protocol;
import fareverly.SessionLease;

/** Uses BMS common settings and the ordinary button action event. */
class NativeFareverlyAccount {
    final worker = new FareverlyAccountWorker();
    final browser = new FareverlyBrowser();
    final readKey:Void->String;
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
    var cancelled = false;
    public function new(saveCredential:(Credential, String)->Bool, ?readKey:Void->String) {
        this.readKey = readKey == null ? () -> FareverlyConfig.read() : readKey;
        this.saveCredential = saveCredential;
        owner = HlxRuntime.moduleName();
        var prefix = "better-mod-settings/action/" + owner + "/";
        Bus.subscribe(prefix + "fareverlySignIn", (_:Dynamic) -> start());
        settingsChanged(false);
    }
    public function settingsChanged(notifySuccess:Bool = true):Void {
        var key:String;
        try key = readKey() catch (_:Dynamic) { status.value = "Common settings could not be read."; return; }
        if (active && key != observedKey) worker.cancel();
        var edited = notifySuccess && key != observedKey;
        observedKey = key;
        worker.settings(localAccount, key, edited);
    }
    function start():Void {
        if (active) return;
        var key:String;
        try key = readKey() catch (_:Dynamic) { notice("Common settings could not be read. Check hlx/config/common/config.json."); return; }
        if (localAccount == "") { notice("Enter the game with your character before generating a key."); return; }
        if (!SessionLease.acquire(owner)) { notice("A Fareverly sign-in is already in progress in another mod."); return; }
        active = true; cancelled = false; openedUri = ""; status.value = "Preparing Steam sign-in...";
        generation = worker.start(localAccount, key != "", key);
    }
    public function uploadMessage(message:String):Void { if (!active && message != "") status.value = message; }
    public function disconnect():Void { cancelled = true; closeDialog(); localAccount = ""; worker.settings("", observedKey); worker.cancel(); }
    public function update(hero:Dynamic):Void {
        var account = NativePlayerIdentity.accountId(hero);
        if (account == null) account = "";
        if (account != localAccount) { if (active) worker.cancel(); localAccount = account; settingsChanged(false); }
        if (opening) try { if (browser.poll()) opening = false; }
        catch (_:Dynamic) { opening = false; worker.cancel(); status.value = "Could not open your browser. Try signing in again."; }
        var event = worker.receive();
        while (event != null) {
            if (event.generation < generation) { event = worker.receive(); continue; }
            var finished = active && !event.active;
            if (finished) SessionLease.release(owner);
            active = event.active;
            // Native Cancel already closes the dialog. Do not replace it with
            // another modal/backdrop or act on a response queued before Cancel.
            if (cancelled) { event = worker.receive(); continue; }
            status.value = event.message;
            if (event.code != "") status.value = "Code: " + event.code + "\n" + event.message;
            if (event.persist) {
                if (saveCredential(event.credential, event.expectedKey))
                    status.value = event.manualResult ? "Fareverly key verified and saved." : "Steam connected. Your Fareverly key has been saved. It is shared with other Fareverly mods.";
                else status.value = "The key could not be saved, or the textbox changed during sign-in. Your current common settings were kept.";
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
        G.call("hl.types.ArrayObj", "pushDyn", buttons, [{ic:pending ? "Cancel" : "Confirm", input:null, checkEnable:null, onBack:true}]);
        dialogOwner = ui;
        dialog = G.call("ui.BaseUI", "displayDialog", ui, ["Fareverly", LiteralText.escape(message), buttons, function(choice:String):Void {
            // BaseDialog closes itself after invoking this callback.
            dialog = null; dialogOwner = null;
            if (pending && choice == "Cancel") { cancelled = true; worker.cancel(); }
        }]);
        var nativeButtons = G.field(dialog, "buttons");
        G.call("ui.comp.Button", "setText", G.call("hl.types.ArrayObj", "getDyn", nativeButtons, [0]), [pending ? "Cancel sign-in" : "OK"]);
    }
    function open(url:String):Bool {
        if (opening) return false;
        try { browser.open(url); opening = true; return true; }
        catch (_:Dynamic) { status.value = "Could not open Fareverly in your browser."; return false; }
    }
}
