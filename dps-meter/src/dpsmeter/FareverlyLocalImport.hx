package dpsmeter;

import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Deque;
import sys.thread.Thread;

/** A bounded, one-use loopback handoff. No file paths, upload API, or API keys. */
class FareverlyLocalImport {
    public static inline var MAX_BYTES = 5 * 1024 * 1024;
    public static inline var TIMEOUT = 90;
    final completed = new Deque<{error:String}>();
    final launch:String->Int;
    final entropy:Void->Bytes;
    var active = false;
    public function new(?launch:String->Int, ?entropy:Void->Bytes) {
        this.launch = launch == null ? FareverlyBrowser.openWindows : launch;
        this.entropy = entropy == null ? fareverly.NativeAccount.random : entropy;
    }
    public function open(record:Dynamic):Void {
        if (active) throw "Fareverly is already opening this log.";
        if (record == null) throw "Open an individual fight before opening Fareverly.";
        active = true;
        try Thread.create(() -> {
            var error = "";
            try transfer(Bytes.ofString(haxe.Json.stringify(record)))
            catch (failure:Dynamic) error = Std.string(failure);
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
    function transfer(payload:Bytes):Void {
        if (payload.length > MAX_BYTES) throw "Fareverly accepts logs up to 5 MiB. This local log is larger.";
        var random = entropy();
        if (random == null || random.length != 32) throw "Could not prepare a secure local import.";
        var token = random.toHex(); random.fill(0, random.length, 0);
        var server = new Socket();
        try {
            server.bind(new Host("127.0.0.1"), 0);
            server.listen(4);
            var port = server.host().port;
            var host = "127.0.0.1:" + port;
            var path = "/import/" + token;
            var url = fareverly.Protocol.ORIGIN + "/analyze#desktop=v1." + port + "." + token;
            var code = launch(url);
            if (code != 0) throw "Could not open Fareverly in your browser (Windows error " + code + ").";
            var deadline = haxe.Timer.stamp() + TIMEOUT;
            var delivered = false;
            while (!delivered && haxe.Timer.stamp() < deadline) {
                if (Socket.select([server], [], [], 0.25).read.length == 0) continue;
                var client = server.accept();
                try {
                    client.setTimeout(1);
                    var header = readHeader(client);
                    var method = authorized(header, host, path);
                    if (method == "GET") {
                        client.output.writeString(response("200 OK", payload.length, true));
                        client.output.writeFullBytes(payload, 0, payload.length);
                        client.output.flush(); delivered = true;
                    } else if (method == "OPTIONS") {
                        client.output.writeString(response("204 No Content", 0, true));
                        client.output.flush();
                    } else {
                        client.output.writeString(response("403 Forbidden", 0, false));
                        client.output.flush();
                    }
                } catch (_:Dynamic) {} // Malformed/slow peers never consume the handoff.
                try client.close() catch (_:Dynamic) {}
            }
            server.close(); payload.fill(0, payload.length, 0);
            if (!delivered) throw "Fareverly did not receive the log. Allow its local connection in your browser, then try again.";
        } catch (error:Dynamic) {
            try server.close() catch (_:Dynamic) {}
            payload.fill(0, payload.length, 0); throw error;
        }
    }
    static function readHeader(client:Socket):String {
        var buffer = new StringBuf();
        var tail = "";
        var deadline = haxe.Timer.stamp() + 2;
        for (_ in 0...4096) {
            if (haxe.Timer.stamp() > deadline) break;
            var c = client.input.readByte();
            if (c == 0 || c > 127) break;
            buffer.addChar(c); tail += String.fromCharCode(c);
            if (tail.length > 4) tail = tail.substr(tail.length - 4);
            if (tail == "\r\n\r\n") return buffer.toString();
        }
        throw "Invalid local request";
    }
    public static function authorized(header:String, host:String, path:String):String {
        var lines = header.split("\r\n"), first = lines.shift();
        var method = first == "GET " + path + " HTTP/1.1" ? "GET"
            : first == "OPTIONS " + path + " HTTP/1.1" ? "OPTIONS" : "";
        if (method == "") return "";
        var values = new Map<String, String>();
        for (line in lines) {
            if (line == "") continue;
            var colon = line.indexOf(":");
            if (colon <= 0 || line.charAt(0) == " " || line.charAt(0) == "\t") return "";
            var key = line.substr(0, colon).toLowerCase();
            if (values.exists(key)) return "";
            values.set(key, StringTools.trim(line.substr(colon + 1)));
        }
        if (values.get("host") != host || values.get("origin") != fareverly.Protocol.ORIGIN
            || values.exists("transfer-encoding") || (values.exists("content-length") && values.get("content-length") != "0")) return "";
        if (method == "OPTIONS" && values.get("access-control-request-method") != "GET") return "";
        return method;
    }
    static function response(status:String, length:Int, cors:Bool):String {
        return "HTTP/1.1 " + status + "\r\nContent-Type: application/json\r\nContent-Length: " + length
            + "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n"
            + (cors ? "Access-Control-Allow-Origin: https://fareverly.com\r\nVary: Origin\r\nAccess-Control-Allow-Methods: GET\r\nAccess-Control-Allow-Private-Network: true\r\n" : "") + "\r\n";
    }
}
