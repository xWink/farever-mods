package moresettings;

import moresettings.GameAccess as G;

private typedef WeaponJob = {
    var view:Dynamic;
    var slot:Int;
    var index:Int;
    var valid:Bool;
}

/** Coalesce obsolete weapon construction while retaining the native work queue. */
class AppearanceJobs {
    var jobs:Array<WeaponJob> = [];
    var ready:Array<Dynamic> = [];
    var flushing:Bool = false;
    var depth:Int = 0;

    public function new() {}

    public function cancel(view:Dynamic, slot:Int, index:Int):Void {
        for (job in jobs) if (job.view == view && job.slot == slot && job.index == index) job.valid = false;
    }

    public function schedule(view:Dynamic, path:String, prefab:Dynamic, slot:Int, index:Int):Bool {
        if (G.field(view, "async") != true || G.field(view, "gameObject") == null || jobs.length >= 256) return false;
        // Resolve before changing any scene state. A missing API leaves the
        // entire request on the native path.
        var worker = G.staticCall("lib.Workers", "get", []);
        var addJob = G.bind("lib.Workers", "addJob");
        var addWeapon = G.bind("client.UnitView", "addWeapon");
        var checkReady = G.bind("client.UnitView", "checkReady");
        cancel(view, slot, index);
        G.call("client.UnitView", "clearWeapon", view, [slot, index]);
        if (path == null) return true;
        var job:WeaponJob = {view: view, slot: slot, index: index, valid: true};
        var owner = G.field(view, "gameObject");
        jobs.push(job);
        try addJob([worker, function() {
            jobs.remove(job);
            // The native closure checks parent. Also reject removed owners and
            // requests replaced before construction reached the front of the queue.
            if (!job.valid || G.field(view, "parent") == null || G.field(view, "gameObject") != owner || G.field(owner, "removed") == true) return;
            addWeapon([view, path, prefab, slot, index]);
            checkReady([view]);
        }, false]) catch (e:Dynamic) {
            jobs.remove(job);
            throw e;
        }
        return true;
    }

    public function deferReady(view:Dynamic):Bool {
        if (depth == 0 || flushing || G.field(view, "async") != true || G.field(view, "gameObject") == null) return false;
        if (ready.indexOf(view) < 0) ready.push(view);
        return true;
    }

    public function beginWorker():Void { depth++; }

    /** Game-frame boundary recovery if native work threw before its postfix. */
    public function recoverWorker():Void {
        if (depth > 0) { depth = 0; finishWorker(); }
    }

    public function finishWorker():Void {
        if (depth > 0) depth--;
        if (depth > 0) return;
        var pending = ready; ready = [];
        flushing = true;
        var failure:Dynamic = null;
        for (view in pending) if (G.field(view, "parent") != null)
            try G.call("client.UnitView", "checkReady", view) catch (e:Dynamic) { if (failure == null) failure = e; }
        flushing = false;
        if (failure != null) throw failure;
    }

    public function dispose():Void {
        for (job in jobs) job.valid = false;
        jobs = []; ready = []; depth = 0;
    }
}
