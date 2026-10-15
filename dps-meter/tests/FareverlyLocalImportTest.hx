import dpsmeter.FareverlyLocalImport;
using StringTools;
import fareverly.Protocol;
import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Deque;

class FareverlyLocalImportTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function main():Void {
        // Real loopback sockets with a fake launcher. No production requests.
        var urls = new Deque<String>();
        var handoff = new FareverlyLocalImport(url -> { urls.add(url); return 0; }, () -> Bytes.alloc(32));
        var log = {id:"offline-local-import", name:"Local fixture", padding:StringTools.lpad("", "x", 1024 * 1024)};
        var before = haxe.Timer.stamp(); handoff.open(log);
        check(haxe.Timer.stamp() - before < .5, "Serialization and socket work never block the caller");
        var url = urls.pop(true);
        check(Protocol.localUrl(url), "Only canonical local handoff URLs are opened");
        var parts = url.split("#desktop=v1.")[1].split("."), port = Std.parseInt(parts[0]);
        var host = "127.0.0.1:" + port, path = "/import/" + parts[1];
        var request = "GET " + path + " HTTP/1.1\r\nHost: " + host + "\r\nOrigin: https://fareverly.com\r\n\r\n";
        check(send(port, StringTools.replace(request, "https://fareverly.com", "https://example.invalid")).indexOf("403 Forbidden") >= 0, "Foreign origins cannot read the log");
        check(send(port, StringTools.replace(request, path, "/import/wrong-token")).indexOf("403 Forbidden") >= 0, "Incorrect token cannot consume the log");
        var preflight = "OPTIONS " + path + " HTTP/1.1\r\nHost: " + host + "\r\nOrigin: https://fareverly.com\r\nAccess-Control-Request-Method: GET\r\nAccess-Control-Request-Private-Network: true\r\n\r\n";
        check(send(port, preflight).indexOf("204 No Content") >= 0, "Private network preflight is supported");
        for (bad in [StringTools.replace(request, "Host: " + host, "Host: example.invalid"), request.replace("\r\n\r\n", "\r\nOrigin: https://example.invalid\r\n\r\n"), request.replace("GET ", "POST ")])
            check(FareverlyLocalImport.authorized(bad, host, path) == "", "Rebinding, duplicate headers, and unsupported methods are denied");
        var repeated = false; try handoff.open(log) catch (_:Dynamic) repeated = true;
        check(repeated, "Repeated clicks cannot create multiple browser tabs");
        var reply = send(port, request), separator = reply.indexOf("\r\n\r\n");
        check(reply.indexOf("200 OK") >= 0 && reply.indexOf("Cache-Control: no-store") >= 0, "Response is JSON and cannot be cached");
        check(reply.substr(separator + 4) == haxe.Json.stringify(log), "Browser receives the whole original JSON");
        var deadline = haxe.Timer.stamp() + 3, done = false;
        while (!done && haxe.Timer.stamp() < deadline) { done = handoff.poll(); if (!done) Sys.sleep(.01); }
        check(done, "Import completes after one successful delivery");
        var refused = false; try send(port, request) catch (_:Dynamic) refused = true;
        check(refused, "Listener closes immediately after delivery");
        for (bad in [url.replace(parts[0], "65536"), url.replace("https://fareverly.com", "https://example.invalid"), url + "&extra=1"])
            check(!Protocol.browserUrl(bad), "Malformed handoff address is rejected");
        Sys.println("Fareverly local import: " + checks + " checks passed");
    }
    static function send(port:Int, request:String):String {
        var socket = new Socket(); socket.setTimeout(3);
        try {
            socket.connect(new Host("127.0.0.1"), port);
            socket.output.writeString(request); socket.output.flush();
            var response = socket.input.readAll().toString(); socket.close(); return response;
        } catch (error:Dynamic) { socket.close(); throw error; }
    }
}
