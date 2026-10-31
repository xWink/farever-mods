package groupfinder;

import haxe.io.Bytes;
typedef FareverlyResponse = fareverly.Protocol.Response;

/** Worker-only HTTP with bounded response memory and cooperative local saves. */
class GroupHttp {
    public static function validUrl(url:String):Bool return GroupProtocol.validUrl(url);
    final progress:Void->Void;
    public function new(progress:Void->Void) this.progress = progress;
    public function request(method:String, url:String, body:Bytes):FareverlyResponse return authenticated(method, url, body, "");
    public function authenticated(method:String, url:String, body:Bytes, token:String, ?headers:Map<String,String>):FareverlyResponse {
        if (!validUrl(url)) throw "Unsupported Fareverly endpoint.";
        var result:FareverlyResponse = {status:0, body:"", retryAfter:"", error:""};
        var http = new sys.Http(url);
        var output = new BoundedResponse();
        var socket:GroupSocket = null;
        try {
            progress();
            http.cnxTimeout = 30; http.noShutdown = true;
            http.setHeader("Accept", "application/json");
            if (token != "") {
                if (!fareverly.Protocol.validKey(token))
                    throw "Invalid credential destination.";
                http.setHeader("Authorization", "Bearer " + token);
            }
            if (headers != null) for (key => value in headers) http.setHeader(key,value);
            http.setHeader("User-Agent", "Farever-Group-Finder/1");
            if (body != null) { http.setHeader("Content-Type", "application/json"); http.setPostBytes(body); }
            http.onStatus = value -> result.status = value;
            http.onError = value -> result.error = value;
            socket = new GroupSocket(true, progress);
            http.customRequest(method == "POST", output, socket, method);
        } catch (error:Dynamic) result.error = Std.string(error);
        if (socket != null) try socket.close() catch (_:Dynamic) {}
        result.body = output.getBytes().toString();
        var requestId="";
        if (http.responseHeaders != null) for (key => value in http.responseHeaders) switch(key.toLowerCase()) {
            case "retry-after":result.retryAfter=value;
            case "x-request-id":requestId=value;
            default:
        }
        return result;
    }
}
private class BoundedResponse extends haxe.io.BytesOutput {
    public function new() super();
    override public function writeByte(value:Int):Void {
        if (length >= 1048576) throw "Fareverly response exceeded 1 MiB";
        super.writeByte(value);
    }
    override public function writeBytes(bytes:Bytes, pos:Int, len:Int):Int {
        if (length + len > 1048576) throw "Fareverly response exceeded 1 MiB";
        return super.writeBytes(bytes, pos, len);
    }
}
