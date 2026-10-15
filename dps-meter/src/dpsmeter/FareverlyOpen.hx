package dpsmeter;
import dpsmeter.FareverlyUploader;

/** Game-thread state for a single explicit open action. Stale replies cannot open tabs. */
class FareverlyOpen {
    public var message(default, null):String = "";
    public var opening(default, null):Bool = false;
    var fightId = "";
    var serial = 0;
    var loading = false;
    var inFlight = false;
    var startedAt:Float = 0;
    var nextPoll:Float = 0;
    var openingUntil:Float = 0;
    public function new() {}
    public function select(id:String):Void { fightId = id; serial++; loading = false; inFlight = false; message = ""; }
    public function busy(now:Float):Bool return loading || opening || now < openingUntil;
    public function begin(now:Float):Null<FareverlyRequest> {
        if (fightId == "" || busy(now)) return null;
        loading = true; startedAt = now; message = "";
        return request(true);
    }
    function request(retry:Bool):FareverlyRequest {
        inFlight = true;
        return {id:++serial, fightId:fightId, retry:retry};
    }
    public function poll(now:Float):Null<FareverlyRequest> {
        if (!loading) return null;
        if (now - startedAt >= 35) { fail("The submission is still pending. Try again shortly."); return null; }
        return !inFlight && now >= nextPoll ? request(false) : null;
    }
    public function receive(response:FareverlyReport, now:Float):String {
        if (!loading || !inFlight || response.id != serial || response.fightId != fightId) return "";
        inFlight = false;
        if (response.status == "pending") { nextPoll = now + 0.75; return ""; }
        loading = false;
        var url = FareverlyUploader.reportUrl(response.url);
        if (response.status == "ready" && url != "") { opening = true; return url; }
        message = response.message == "" ? "This log is not available on Fareverly." : response.message;
        return "";
    }
    public function opened(now:Float):Void { if (opening) { opening = false; openingUntil = now + 2; } }
    public function fail(message:String):Void {
        loading = false; inFlight = false; opening = false; openingUntil = 0; serial++; this.message = message;
    }
}
