package dpsmeter;

import fareverly.AuthFlow;
import fareverly.Protocol;
import fareverly.SecureStore;
import fareverly.NativeAccount;
import sys.thread.Deque;
import sys.thread.Lock;
import sys.thread.Thread;

private typedef AccountCommand = {kind:String, account:String, key:String, rotate:Bool, generation:Int};
typedef AccountEvent = {generation:Int, active:Bool, message:String, code:String, account:String, url:String, credential:Credential};

/** Separate from the upload queue so a slow ranked request cannot stall sign-in. */
class FareverlyAccountWorker {
    final commands = new Deque<AccountCommand>();
    final cancellations = new Deque<Bool>();
    final events = new Deque<AccountEvent>();
    final wake = new Lock();
    var flow:AuthFlow;
    var credential:Credential = Protocol.empty();
    var lastEvent = "";
    var nextRead:Float = 0;
    var manualKey:Null<String>;
    var manualAt:Float = 0;
    var account = "";
    var status = "Sign in through Steam to connect Fareverly.";
    var transport:FareverlyHttp;
    var requestedGeneration = 0;
    var generation = 0;
    public function new() Thread.create(run);
    public function start(account:String, rotate:Bool):Int { var id = ++requestedGeneration; commands.add({kind:"start", account:account, rotate:rotate, key:"", generation:id}); wake.release(); return id; }
    public function edit(account:String, key:String):Void { commands.add({kind:"edit", account:account, rotate:false, key:key, generation:requestedGeneration}); wake.release(); }
    public function setAccount(account:String):Void { commands.add({kind:"account", account:account, rotate:false, key:"", generation:requestedGeneration}); wake.release(); }
    public function cancel():Void { cancellations.add(true); wake.release(); }
    public function receive():Null<AccountEvent> return events.pop(false);
    function progress():Void {
        if (cancellations.pop(false) != null) {
            flow.cancel(); manualKey = null; status = flow.message;
            throw "Sign-in cancelled";
        }
    }
    function emit():Void {
        var value:AccountEvent = {generation:generation, active:flow.active, message:flow.active ? flow.message : status,
            code:flow.userCode, account:flow.accountId, url:flow.verificationUri, credential:credential};
        var signature = haxe.Json.stringify(value);
        if (signature == lastEvent) return;
        lastEvent = signature; events.add(value);
    }
    function run():Void {
        transport = new FareverlyHttp(progress);
        flow = new AuthFlow(transport.authenticated, () -> Date.now().getTime() / 1000);
        while (true) {
            try {
                var cancelled = cancellations.pop(false) != null;
                if (cancelled) { flow.cancel(); manualKey = null; status = flow.message; }
                var command = commands.pop(false);
                while (command != null) {
                    switch (command.kind) {
                        case "account":
                            if (account != command.account) {
                                if (flow.active) { flow.cancel(); status = "Steam sign-in cancelled because the local account changed."; }
                                manualKey = null; account = command.account;
                            }
                        case "start":
                            generation = command.generation;
                            if (!cancelled && !flow.active && Protocol.validAccount(command.account)) {
                                account = command.account; manualKey = null;
                                try flow.begin(account, command.rotate, NativeAccount.random())
                                catch (_:Dynamic) status = "Could not start secure sign-in. Install the complete DPS Meter update, including its desktop plugin.";
                            }
                        case "edit":
                            if (!flow.active) { account = command.account; manualKey = StringTools.trim(command.key); manualAt = haxe.Timer.stamp() + 0.75; }
                        default:
                    }
                    command = commands.pop(false);
                }
                var now = Date.now().getTime() / 1000;
                if (now >= nextRead && !flow.active && manualKey == null) {
                    nextRead = now + 5;
                    var value = SecureStore.read();
                    if (haxe.Json.stringify(value) != haxe.Json.stringify(credential)) {
                        credential = value;
                        status = value.accessToken == "" ? "Sign in through Steam to connect Fareverly." : "Fareverly key loaded.";
                    }
                }
                if (manualKey != null && haxe.Timer.stamp() >= manualAt) saveManual();
                var wasActive = flow.active;
                flow.step();
                if (wasActive && !flow.active) status = flow.message;
                if (flow.credential != null) {
                    // Never exchange again after one-time delivery. Retry only the local atomic write.
                    var saved = false;
                    for (_ in 0...3) try { SecureStore.save(flow.credential); saved = true; break; } catch (_:Dynamic) {}
                    if (saved) {
                        credential = flow.credential;
                        status = "Steam connected. Your Fareverly key has been saved.";
                    } else status = "Steam approved, but the key could not be saved. Fix folder permissions, then Generate new key.";
                    flow.clearCredential(); nextRead = now + 5;
                }
                emit();
            } catch (_:Dynamic) {
                if (!flow.active) status = "Could not read or save Fareverly settings. Local combat logs are kept.";
                emit();
            }
            wake.wait(0.25);
        }
    }
    function saveManual():Void {
        var key = manualKey; manualKey = null;
        if (key == "") {
            SecureStore.save(Protocol.empty()); credential = Protocol.empty(); status = "Fareverly key cleared. Sign in through Steam to reconnect."; return;
        }
        if (!Protocol.validKey(key)) { status = "Enter a complete Fareverly API key, or sign in through Steam."; return; }
        if (!Protocol.validAccount(account)) { status = "Enter the game with your character before connecting a key."; return; }
        var response = transport.authenticated("GET", Protocol.ORIGIN + "/api/v1/account", null, key);
        var value:Dynamic = null; try value = haxe.Json.parse(response.body) catch (_:Dynamic) {}
        if (response.status != 200 || response.error != "" || value == null) {
            status = response.status == 401 ? Protocol.error("unauthorized") : "Could not verify this key. Try pasting it again later."; return;
        }
        if (value.account_id != account) { status = Protocol.error("account_mismatch"); return; }
        if (!Std.isOfType(value.steam_id, String) || !~/^[0-9]{17}$/.match(value.steam_id)
            || !Std.isOfType(value.scopes, Array) || (cast value.scopes:Array<Dynamic>).indexOf("logs:upload") < 0) {
            status = "This key does not grant combat-log uploads."; return;
        }
        var saved:Credential = {accessToken:key, accountId:account, steamId:value.steam_id, expiresAt:""};
        SecureStore.save(saved); credential = saved; status = "Fareverly key verified and saved.";
    }
}
