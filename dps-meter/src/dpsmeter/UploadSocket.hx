package dpsmeter;

import haxe.io.Bytes;
import haxe.io.Error;
import sys.net.Host;
import sys.net.Socket;

/** Adapt nonblocking sockets to sys.Http on the uploader thread.
    HashLink's TLS send does not release the GC lock while a blocking send waits. */
class UploadSocket extends Socket {
    final transport:Socket;
    final deadline:Float;
    final onProgress:Void->Void;
    var closed:Bool = false;

    public function new(secure:Bool, onProgress:Void->Void) {
        super();
        this.onProgress = onProgress;
        deadline = haxe.Timer.stamp() + 30;
        if (secure) {
            var tls = new sys.ssl.Socket();
            tls.verifyCert = true;
            transport = tls;
        } else transport = new Socket();
        transport.setBlocking(false);
        input = new UploadInput(transport.input, this);
        output = new UploadOutput(transport.output, this);
    }

    // This object delegates to transport; it must not allocate a second socket.
    override function init():Void {}

    public function progress():Void {
        if (haxe.Timer.stamp() >= deadline) throw "Upload timed out";
        onProgress();
    }

    public function pause():Void {
        progress();
        Sys.sleep(0.01);
    }

    override public function connect(host:Host, port:Int):Void {
        progress();
        transport.connect(host, port);
        var connecting = [transport];
        while (Socket.select(null, connecting, null, 0.01).write.length == 0) progress();
        if (Std.isOfType(transport, sys.ssl.Socket)) {
            var tls:sys.ssl.Socket = cast transport;
            while (true) {
                progress();
                try { tls.handshake(); break; }
                catch (e:Dynamic) { if (e != Error.Blocked) throw e; pause(); }
            }
        }
    }

    override public function setTimeout(timeout:Float):Void transport.setTimeout(timeout);
    override public function shutdown(read:Bool, write:Bool):Void transport.shutdown(read, write);
    override public function close():Void {
        if (closed) return;
        closed = true;
        transport.close();
    }
}

private class UploadInput extends haxe.io.Input {
    final source:haxe.io.Input;
    final socket:UploadSocket;
    var ended:Bool = false;
    var received:Int = 0;
    public function new(source:haxe.io.Input, socket:UploadSocket) {
        this.source = source;
        this.socket = socket;
    }
    override public function readByte():Int {
        var byte = Bytes.alloc(1);
        readBytes(byte, 0, 1);
        return byte.get(0);
    }
    override public function readBytes(bytes:Bytes, pos:Int, len:Int):Int {
        while (true) {
            socket.progress();
            // sys.Http retries EOF during incomplete headers. Stop that retry
            // instead of spinning forever when a server closes before replying.
            if (ended) throw "Server closed before completing its response";
            try {
                var count = source.readBytes(bytes, pos, len);
                received += count;
                if (received > 65536) throw "Upload response exceeded 64 KiB";
                return count;
            }
            catch (e:haxe.io.Eof) { ended = true; throw e; }
            catch (e:Dynamic) { if (e != Error.Blocked) throw e; socket.pause(); }
        }
    }
}

private class UploadOutput extends haxe.io.Output {
    final target:haxe.io.Output;
    final socket:UploadSocket;
    public function new(target:haxe.io.Output, socket:UploadSocket) {
        this.target = target;
        this.socket = socket;
    }
    override public function writeByte(value:Int):Void {
        var byte = Bytes.alloc(1);
        byte.set(0, value);
        writeBytes(byte, 0, 1);
    }
    override public function writeBytes(bytes:Bytes, pos:Int, len:Int):Int {
        while (true) {
            socket.progress();
            try {
                var written = target.writeBytes(bytes, pos, len);
                if (written > 0 || len == 0) return written;
            } catch (e:Dynamic) { if (e != Error.Blocked) throw e; }
            socket.pause();
        }
    }
}
