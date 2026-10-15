package dpsmeter;
import sys.thread.Deque;
import sys.thread.Thread;

/** Launching the default browser may block Windows, so it never runs on the game thread. */
class FareverlyBrowser {
    final completed = new Deque<{error:String}>();
    final launch:String->Int;
    var active = false;
    public function new(?launch:String->Int) this.launch = launch == null ? openWindows : launch;
    static function openWindows(url:String):Int {
        if (Sys.systemName() != "Windows") throw "Opening Fareverly requires Windows.";
        // open() accepts only a canonical HTTPS report URL with a restricted ID alphabet.
        return Sys.command('start "" "' + url + '"');
    }
    public function open(url:String):Void {
        if (url == null || url == "" || url.length > 2048 || FareverlyUploader.reportUrl(url) != url)
            throw "This Fareverly report address is unavailable.";
        if (active) throw "Fareverly is already opening in your browser.";
        active = true;
        try Thread.create(() -> {
            var error = "";
            try {
                var result = launch(url);
                if (result != 0) error = "Could not open Fareverly in your browser (Windows error " + result + "). Try again.";
            } catch (failure:Dynamic) error = Std.string(failure);
            completed.add({error:error});
        }) catch (error:Dynamic) { active = false; throw error; }
    }
    public function poll():Bool {
        var result = completed.pop(false);
        if (result == null) return false;
        active = false;
        if (result.error != "") throw result.error;
        return true;
    }
}
