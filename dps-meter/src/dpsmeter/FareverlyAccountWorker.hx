package dpsmeter;

import fareverly.AuthFlow;
import fareverly.Protocol;
import fareverly.NativeAccount;
import sys.thread.Deque;
import sys.thread.Lock;
import sys.thread.Thread;

private typedef AccountCommand = {kind:String, account:String, key:String, rotate:Bool, generation:Int, ?credential:Credential};
typedef AccountEvent = {generation:Int, active:Bool, manualResult:Bool, message:String, code:String, account:String, url:String, credential:Credential, persist:Bool, expectedKey:String};

/** Separate from the upload queue so a slow ranked request cannot stall sign-in. */
class FareverlyAccountWorker {
    final commands = new Deque<AccountCommand>();
    final cancellations = new Deque<Bool>();
    final events = new Deque<AccountEvent>();
    final wake = new Lock();
    var flow:AuthFlow;
    var credential:Credential = Protocol.empty();
    var lastEvent = "";
    var persist = false;
    var expectedKey = "";
    var configuredKey = "";
    var manualKey:Null<String>;
    var manualAt:Float = 0;
    var account = "";
    var status = "Sign in through Steam to connect Fareverly.";
    var transport:FareverlyHttp;
    var requestedGeneration = 0;
    var generation = 0;
    var manualResult = false;
    public function new() Thread.create(run);
    public function start(account:String, rotate:Bool, key:String):Int { var id = ++requestedGeneration; commands.add({kind:"start", account:account, rotate:rotate, key:key, generation:id}); wake.release(); return id; }
    public function settings(account:String, key:String, value:Credential):Void { commands.add({kind:"settings", account:account, rotate:false, key:key, credential:value, generation:requestedGeneration}); wake.release(); }
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
        var value:AccountEvent = {generation:generation, active:flow.active, manualResult:manualResult, message:flow.active ? flow.message : status,
            code:flow.userCode, account:flow.accountId, url:flow.verificationUri, credential:credential, persist:persist, expectedKey:expectedKey};
        var signature = haxe.Json.stringify(value);
        if (signature == lastEvent) return;
        lastEvent = signature; events.add(value); manualResult = false; persist = false;
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
                                account = command.account; manualKey = null; expectedKey = command.key;
                                try flow.begin(account, command.rotate, NativeAccount.random())
                                catch (_:Dynamic) status = "Could not start secure sign-in. Install the complete DPS Meter update, including its desktop plugin.";
                            }
                        case "settings":
                            var changed = configuredKey != command.key || account != command.account;
                            configuredKey = command.key; account = command.account;
                            if (flow.active && changed) { flow.cancel(); status = "Steam sign-in cancelled because the API-key setting changed."; }
                            credential = command.credential;
                            if (!flow.active && (changed || (manualKey == null && credential.accessToken == "" && Protocol.validKey(configuredKey)))) {
                                expectedKey = configuredKey;
                                manualKey = credential.accessToken == "" && configuredKey != "" ? configuredKey : null;
                                manualAt = haxe.Timer.stamp() + 0.75;
                            }
                        default:
                    }
                    command = commands.pop(false);
                }
                if (manualKey != null && haxe.Timer.stamp() >= manualAt) { manualResult = true; saveManual(); }
                var wasActive = flow.active;
                flow.step();
                if (wasActive && !flow.active) status = flow.message;
                if (flow.credential != null) {
                    // Deliver once to the game thread. It owns the normal config
                    // object and reloads other BMS edits before saving this key.
                    credential = flow.credential;
                    persist = true;
                    status = "Steam connected. Saving your Fareverly key...";
                    flow.clearCredential();
                }
                emit();
            } catch (_:Dynamic) {
                if (!flow.active) status = "Could not verify Fareverly account settings. Local combat logs are kept.";
                emit();
            }
            wake.wait(0.25);
        }
    }
    function saveManual():Void {
        var key = manualKey; manualKey = null;
        if (key == "") {
            credential = Protocol.empty(); status = "Fareverly key cleared. Sign in through Steam to reconnect."; return;
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
        credential = saved; persist = true; expectedKey = key; status = "Fareverly key verified. Saving...";
    }
}
