package modupdatealerts;

import sys.thread.Deque;
import sys.thread.Mutex;
import modupdatealerts.UpdateModel.InstalledMod;
import modupdatealerts.UpdateModel.AvailableUpdate;

typedef CheckResult = {
    var updates:Array<AvailableUpdate>;
    var dismissed:Map<String,String>;
    var notes:Array<String>;
    var complete:Bool;
}

class UpdateWorker {
    public final results=new Deque<CheckResult>();
    public final saves=new Deque<Map<String,String>>();
    final mutex=new Mutex();
    var cancelled=false;
    final root:String;
    final state:String;
    public function new(root:String) {
        this.root=root;
        state=haxe.io.Path.join([root,"hlx","config","mod-update-alerts","reminders.json"]);
    }
    public function stop():Void { mutex.acquire(); cancelled=true; mutex.release(); }
    function stopped():Bool { mutex.acquire(); var result=cancelled; mutex.release(); return result; }
    /** Back off on the worker thread without delaying shutdown. */
    public dynamic function wait(seconds:Float):Bool {
        var until=haxe.Timer.stamp()+seconds;
        while (!stopped()) {
            var remaining=until-haxe.Timer.stamp();
            if (remaining<=0) return true;
            Sys.sleep(Math.min(0.1,remaining));
        }
        return false;
    }
    public function discover(?vortexPath:String):InstalledMods {
        var inventory=new InstalledMods();
        for (attempt in 0...3) {
            if (stopped()) throw "Installed-version scan cancelled";
            var deadline=haxe.Timer.stamp()+30;
            try inventory.scan(root,vortexPath,function() {
                if(stopped() || haxe.Timer.stamp()>deadline) throw "Installed-version scan cancelled or timed out";
            }) catch (error:Dynamic) {
                inventory.retryable=true;
                inventory.diagnostics.push("Installed-version scan incomplete: "+Std.string(error));
            }
            if (!inventory.retryable || attempt==2) return inventory;
            // Immediate LevelDB retries can all hit the same Vortex write or
            // deployment. Reverify records AND binaries after a real backoff.
            if (!wait(attempt==0 ? 5 : 15)) throw "Installed-version scan cancelled";
        }
        return inventory;
    }
    public function run():Void {
        var result:CheckResult={updates:[],dismissed:ReminderStore.loadForRoot(root),notes:[],complete:false};
        try {
            var inventory=discover();
            result.notes=inventory.diagnostics;
            var client=new NexusClient(stopped);
            var installed=inventory.manual.copy();
            for (entry in inventory.deployed) {
                if (stopped()) break;
                var info=entry.metadata;
                if (info!=null) installed.push(info);
                else if (!inventory.retryable) result.notes.push("No current Vortex version record for deployed mod: "+entry.source);
            }
            // Multiple modules/optional files may belong to one Nexus page. Use the newest
            // installed version so an older optional file cannot create a false update.
            var unique:Map<String,InstalledMod>=[];
            for (mod in installed) {
                var key=UpdateModel.identity(mod.domain,mod.modId), old=unique.get(key);
                if (old==null || UpdateModel.compare(mod.version,old.version)==1) unique.set(key,mod);
            }
            for (mod in unique) {
                if (stopped()) break;
                var latest=client.fetch(mod.domain,mod.modId);
                savePending();
                if (latest==null) { result.notes.push("Nexus metadata unavailable: "+mod.name); continue; }
                var comparison=UpdateModel.compare(latest.version,mod.version);
                if (comparison==null) result.notes.push("Unrecognized version format: "+mod.name);
                if (comparison==1 && NexusClient.hasDownload(latest)) {
                    result.updates.push({name:latest.name,domain:mod.domain,modId:mod.modId,current:mod.version,
                        latest:latest.version,changelog:NexusClient.changelog(latest)});
                    publish(result,false);
                }
            }
        } catch (error:Dynamic) result.notes.push("Update check incomplete: "+Std.string(error)+". Will retry next launch.");
        if (!stopped()) publish(result,true);
        // Keep disk writes off the game thread; one worker for the game process.
        while (true) {
            savePending();
            if (stopped()) break;
            Sys.sleep(0.1);
        }
    }
    function publish(result:CheckResult,complete:Bool):Void {
        // Never mutate an array/map already handed to the game thread.
        var updates=result.updates.copy();
        updates.sort((a,b)->Reflect.compare(a.name.toLowerCase(),b.name.toLowerCase()));
        results.add({updates:updates,dismissed:result.dismissed.copy(),
            notes:complete ? result.notes.copy() : [],complete:complete});
    }
    function savePending():Void {
        while(true) {
            var pending=saves.pop(false);
            if(pending==null) return;
            try ReminderStore.save(state,pending) catch (_:Dynamic)
                trace("[Mod Update Alerts] Could not save reminder preferences.");
        }
    }
}
