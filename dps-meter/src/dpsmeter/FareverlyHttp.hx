package dpsmeter;

import haxe.io.Bytes;
typedef FareverlyResponse = fareverly.Protocol.Response;

/** Worker-only HTTP with bounded response memory and cooperative local saves. */
class FareverlyHttp {
    final progress:Void->Void;
    public function new(progress:Void->Void) this.progress = progress;
    public function request(method:String, url:String, body:Bytes):FareverlyResponse return authenticated(method, url, body, "");
    public function authenticated(method:String, url:String, body:Bytes, token:String):FareverlyResponse {
        if (url != "https://fareverly.com/api/v1/logs" && url != "https://fareverly.com/api/v1/account"
            && url != "https://fareverly.com/api/v1/encounters" && url != "https://fareverly.com/api/v1/auth/device"
            && url != "https://fareverly.com/api/v1/auth/token")
            throw "Unsupported Fareverly endpoint.";
        var result:FareverlyResponse = {status:0, body:"", retryAfter:"", error:""};
        var http = new sys.Http(url);
        var output = new BoundedResponse();
        var socket:UploadSocket = null;
        try {
            progress();
            http.cnxTimeout = 30; http.noShutdown = true;
            http.setHeader("Accept", "application/json");
            if (token != "") {
                if (!fareverly.Protocol.validKey(token) || (url != "https://fareverly.com/api/v1/logs" && url != "https://fareverly.com/api/v1/account"))
                    throw "Invalid credential destination.";
                http.setHeader("Authorization", "Bearer " + token);
            }
            http.setHeader("User-Agent", "Farever-DPS-Meter/Fareverly-1");
            if (body != null) { http.setHeader("Content-Type", "application/json"); http.setPostBytes(body); }
            http.onStatus = value -> result.status = value;
            http.onError = value -> result.error = value;
            socket = new UploadSocket(true, progress);
            http.customRequest(method == "POST", output, socket, method);
        } catch (error:Dynamic) result.error = Std.string(error);
        if (socket != null) try socket.close() catch (_:Dynamic) {}
        result.body = output.getBytes().toString();
        if (http.responseHeaders != null) for (key => value in http.responseHeaders)
            if (key.toLowerCase() == "retry-after") result.retryAfter = value;
        return result;
    }
}
private class BoundedResponse extends haxe.io.BytesOutput {
    public function new() super();
    override public function writeByte(value:Int):Void {
        if (length >= 65536) throw "Fareverly response exceeded 64 KiB";
        super.writeByte(value);
    }
    override public function writeBytes(bytes:Bytes, pos:Int, len:Int):Int {
        if (length + len > 65536) throw "Fareverly response exceeded 64 KiB";
        return super.writeBytes(bytes, pos, len);
    }
}
