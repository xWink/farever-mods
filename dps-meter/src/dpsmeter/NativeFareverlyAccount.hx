package dpsmeter;

import dpsmeter.GameAccess as G;
import hlx.runtime.Bus;
import hlx.runtime.Registry;
import fareverly.SessionLease;

/** BMS bindings keep credentials out of the ordinary/exportable mod config. */
class NativeFareverlyAccount {
    final worker = new FareverlyAccountWorker();
    final browser = new FareverlyBrowser();
    final key:Dynamic = {value:"", enabled:true, onChange:null};
    final status:Dynamic = {value:"Sign in through Steam to connect Fareverly."};
    final signIn:Dynamic = {enabled:true};
    final rotate:Dynamic = {enabled:true};
    final cancel:Dynamic = {enabled:false};
    var localAccount = "";
    var opening = false;
    var active = false;
    var openedUri = "";
    var owner:String;
    var generation = 0;
    public function new() {
        owner = HlxRuntime.moduleName();
        Registry.register("better-mod-settings/bindings", owner + "/fareverlyApiKey", key);
        Registry.register("better-mod-settings/bindings", owner + "/fareverlyStatus", status);
        Registry.register("better-mod-settings/bindings", owner + "/fareverlySignIn", signIn);
        Registry.register("better-mod-settings/bindings", owner + "/fareverlyRotate", rotate);
        Registry.register("better-mod-settings/bindings", owner + "/fareverlyCancel", cancel);
        key.onChange = function(value:String):Bool {
            // BMS owns the incoming String identity; rewrap before JSON persistence.
            var raw:hl.Bytes = G.field(value, "bytes");
            value = @:privateAccess String.__alloc__(raw, G.integer(G.field(value, "length")));
            if (active) return false;
            key.value = value; worker.edit(localAccount, value); return true;
        };
        var prefix = "better-mod-settings/action/" + owner + "/";
        Bus.subscribe(prefix + "fareverlySignIn", (_:Dynamic) -> start(false));
        Bus.subscribe(prefix + "fareverlyRotate", (_:Dynamic) -> start(true));
        Bus.subscribe(prefix + "fareverlyCancel", (_:Dynamic) -> worker.cancel());
        Bus.subscribe(prefix + "fareverlySupport", (_:Dynamic) -> open("https://fareverly.com/contact"));
    }
    function start(replace:Bool):Void {
        if (active) return;
        if (localAccount == "") { status.value = "Enter the game with your character before signing in."; return; }
        if (!SessionLease.acquire(owner)) { status.value = "A Fareverly sign-in is already in progress in another mod."; return; }
        active = true; openedUri = ""; status.value = "Preparing Steam sign-in...";
        controls(); generation = worker.start(localAccount, replace);
    }
    public function uploadMessage(message:String):Void { if (!active && message != "") status.value = message; }
    public function disconnect():Void { localAccount = ""; worker.setAccount(""); worker.cancel(); }
    public function update(hero:Dynamic):Void {
        var account = NativePlayerIdentity.accountId(hero);
        if (account == null) account = "";
        if (account != localAccount) { if (active) worker.cancel(); localAccount = account; worker.setAccount(account); }
        if (opening) try { if (browser.poll()) opening = false; }
        catch (_:Dynamic) { opening = false; worker.cancel(); status.value = "Could not open your browser. Try signing in again."; }
        var event = worker.receive();
        while (event != null) {
            if (event.generation < generation) { event = worker.receive(); continue; }
            if (active && !event.active) SessionLease.release(owner);
            active = event.active;
            key.value = event.credential.accessToken;
            status.value = event.message;
            if (event.code != "") status.value = "Code: " + event.code + "\nFarever account: " + event.account + "\n" + event.message;
            controls();
            if (event.url != "" && event.url != openedUri) {
                openedUri = event.url;
                if (!open(event.url)) worker.cancel();
            }
            event = worker.receive();
        }
    }
    function controls():Void { signIn.enabled = !active; rotate.enabled = !active; cancel.enabled = active; key.enabled = !active; }
    function open(url:String):Bool {
        if (opening) return false;
        try { browser.open(url); opening = true; return true; }
        catch (_:Dynamic) { status.value = "Could not open Fareverly in your browser."; return false; }
    }
}
