package modupdatealerts;

import haxe.Int64;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

private typedef Value = {sequence:Int64, value:Null<String>};
private typedef Table = {number:Int, size:Int, first:String, last:String};

private class Cursor {
    public final bytes:Bytes;
    public var pos:Int = 0;
    public function new(bytes:Bytes) this.bytes = bytes;
    public function byte():Int {
        if (pos >= bytes.length) throw "Truncated database record";
        return bytes.get(pos++);
    }
    public function var64():Int64 {
        var result = Int64.ofInt(0);
        for (i in 0...10) {
            var b = byte();
            if (i == 9 && b > 1) throw "Invalid database integer";
            result = result | (Int64.ofInt(b & 127) << (i * 7));
            if (b < 128) return result;
        }
        throw "Invalid database integer";
    }
    public function varint():Int {
        var value = var64();
        if (value.high != 0 || value.low < 0) throw "Database field exceeds supported size";
        return value.low;
    }
    public function take(size:Int):Bytes {
        if (size < 0 || size > bytes.length - pos) throw "Truncated database field";
        var result = bytes.sub(pos, size); pos += size; return result;
    }
    public function slice():Bytes return take(varint());
}

/** Read only LevelDB files; never open its LOCK, recover, compact, or write the database.
    Follows CURRENT/MANIFEST so obsolete tables and deleted values cannot reappear.
    Only the requested key range's values leave this reader. */
class LevelDbSnapshot {
    static inline var LIMIT = 256 * 1024 * 1024;
    final root:String;
    final prefix:String;
    final progress:Void->Void;
    var bytesRead = 0;
    var signatures:Map<String,String> = [];
    var values:Map<String,Value> = [];
    static final crcTable = [for (i in 0...256) {
        var crc = i;
        for (_ in 0...8) crc = (crc >>> 1) ^ ((crc & 1) != 0 ? 0x82F63B78 : 0);
        crc;
    }];

    public function new(root:String, prefix:String, progress:Void->Void) {
        this.root = root; this.prefix = prefix; this.progress = progress;
    }
    public function read():Map<String,String> {
        // A concurrent flush/compaction changes the manifest or WAL. Retry a
        // complete view instead of mixing generations or using a stale backup.
        for (attempt in 0...3) {
            try return snapshot() catch (error:Dynamic) {
                if (attempt == 2) throw "Current Vortex database read failed: " + Std.string(error);
                progress();
            }
        }
        throw "Current Vortex database unavailable";
    }
    function signature(path:String):String {
        var stat = FileSystem.stat(path);
        return stat.size + ":" + stat.mtime.getTime();
    }
    function readAt(path:String, offset:Int, length:Int):Bytes {
        progress();
        if (!signatures.exists(path)) signatures[path] = signature(path);
        if (length < 0 || length > 32 * 1024 * 1024 || offset < 0
            || offset > FileSystem.stat(path).size - length || bytesRead > LIMIT - length)
            throw "Database read limit exceeded";
        bytesRead += length;
        var input = File.read(path, true);
        try {
            input.seek(offset, sys.io.FileSeek.SeekBegin);
            var bytes = input.read(length); input.close();
            if (bytes.length != length) throw "Truncated database file";
            return bytes;
        } catch (e:Dynamic) { input.close(); throw e; }
    }
    function all(path:String):Bytes return readAt(path, 0, FileSystem.stat(path).size);
    static function numberName(number:Int, extension:String):String
        return StringTools.lpad(Std.string(number), "0", 6) + extension;
    function logNames(logNumber:Int, previous:Int):Array<String> {
        var names = [];
        for (name in FileSystem.readDirectory(root)) if (~/^[0-9]+\.log$/.match(name)) {
            var n = Std.parseInt(name);
            if (n >= logNumber || n == previous) names.push(name);
        }
        names.sort(Reflect.compare); return names;
    }
    function relevant(key:String):Bool return key == prefix || StringTools.startsWith(key, prefix + "###");
    function overlaps(first:String, last:String):Bool
        return Reflect.compare(last, prefix) >= 0 && Reflect.compare(first, prefix + "$") < 0;
    static function userKey(key:Bytes):String {
        if (key.length < 8) throw "Invalid internal database key";
        return key.getString(0, key.length - 8);
    }
    function snapshot():Map<String,String> {
        bytesRead = 0; signatures = []; values = [];
        var current = all(root + "/CURRENT").toString();
        var manifest = StringTools.trim(current);
        if (!~/^MANIFEST-[0-9]+$/.match(manifest)) throw "Unsupported database manifest";
        var tables:Map<Int,Table> = [];
        var logNumber = -1, previous = 0;
        logRecords(all(root + "/" + manifest), function(record) {
            var c = new Cursor(record);
            while (c.pos < record.length) switch (c.varint()) {
                case 1:
                    if (c.slice().toString() != "leveldb.BytewiseComparator") throw "Unsupported database comparator";
                case 2: logNumber = c.varint();
                case 3, 4: c.var64();
                case 5: c.varint(); c.slice();
                case 6: c.varint(); tables.remove(c.varint());
                case 7:
                    c.varint(); var n = c.varint(), size = c.varint();
                    tables[n] = {number:n, size:size, first:userKey(c.slice()), last:userKey(c.slice())};
                case 9: previous = c.varint();
                default: throw "Unsupported database manifest tag";
            }
        });
        if (logNumber < 0) throw "Missing current database log";
        var logs = logNames(logNumber, previous);
        if (logs.length == 0) throw "Missing current database log";
        for (table in tables) if (overlaps(table.first, table.last)) {
            var path = root + "/" + numberName(table.number, ".ldb");
            if (!FileSystem.exists(path)) path = root + "/" + numberName(table.number, ".sst");
            if (FileSystem.stat(path).size != table.size) throw "Database table changed";
            readTable(path, table.size);
        }
        for (name in logs) logRecords(all(root + "/" + name), batch);
        if (all(root + "/CURRENT").toString() != current || logs.join(",") != logNames(logNumber, previous).join(","))
            throw "Database generation changed";
        for (path => before in signatures) if (signature(path) != before) throw "Database changed while reading";
        var result:Map<String,String> = [];
        for (key => entry in values) if (entry.value != null) result[key] = entry.value;
        return result;
    }
    static function maskedCrc(bytes:Bytes, pos:Int, length:Int):Int {
        var crc = -1;
        for (i in pos...pos + length) crc = crcTable[(crc ^ bytes.get(i)) & 255] ^ (crc >>> 8);
        crc = ~crc;
        return ((crc >>> 15) | (crc << 17)) + 0xA282EAD8;
    }
    function logRecords(bytes:Bytes, consume:Bytes->Void):Void {
        var pos = 0, fragments:Null<haxe.io.BytesBuffer> = null;
        while (pos < bytes.length) {
            progress();
            var remaining = 32768 - pos % 32768;
            if (remaining < 7) { pos += remaining; continue; }
            if (bytes.length - pos < 7) throw "Incomplete database log header";
            var length = bytes.get(pos + 4) | (bytes.get(pos + 5) << 8), type = bytes.get(pos + 6);
            if (type == 0 && length == 0) {
                // LevelDB may preallocate/zero-pad the rest of a block.
                var end = Std.int(Math.min(bytes.length, pos + remaining));
                for (i in pos...end) if (bytes.get(i) != 0) throw "Invalid log padding";
                pos = end; continue;
            }
            if (length > remaining - 7 || length > bytes.length - pos - 7) throw "Incomplete database log record";
            if (bytes.getInt32(pos) != maskedCrc(bytes, pos + 6, length + 1)) throw "Database log checksum mismatch";
            var payload = bytes.sub(pos + 7, length); pos += 7 + length;
            switch (type) {
                case 1:
                    if (fragments != null) throw "Incomplete database log fragments";
                    consume(payload);
                case 2:
                    if (fragments != null) throw "Incomplete database log fragments";
                    fragments = new haxe.io.BytesBuffer(); fragments.add(payload);
                case 3, 4:
                    if (fragments == null) throw "Missing database log fragment";
                    fragments.add(payload);
                    if (type == 4) { consume(fragments.getBytes()); fragments = null; }
                default: throw "Unsupported database log record";
            }
        }
        if (fragments != null) throw "Incomplete database log fragments";
    }
    function remember(key:String, sequence:Int64, type:Int, bytes:Bytes):Void {
        if (!relevant(key)) return;
        if (type != 0 && type != 1) throw "Unsupported database value type";
        var previous = values[key];
        if (previous == null || Int64.compare(sequence, previous.sequence) > 0)
            values[key] = {sequence:sequence, value:type == 0 ? null : bytes.toString()};
    }
    function batch(bytes:Bytes):Void {
        if (bytes.length < 12) throw "Truncated database batch";
        var sequence = bytes.getInt64(0), count = bytes.getInt32(8);
        if (count < 0 || count > bytes.length) throw "Invalid database batch count";
        var c = new Cursor(bytes); c.pos = 12;
        for (i in 0...count) {
            var type = c.byte(), key = c.slice().toString();
            if (type != 0 && type != 1) throw "Unsupported database batch operation";
            var value = type == 1 ? c.slice() : Bytes.alloc(0);
            remember(key, sequence + Int64.ofInt(i), type, value);
        }
        if (c.pos != bytes.length) throw "Invalid database batch length";
    }
    function block(path:String, offset:Int, size:Int):Bytes {
        if (size < 0 || size > 16 * 1024 * 1024) throw "Database block too large";
        var bytes = readAt(path, offset, size + 5);
        if (bytes.getInt32(size + 1) != maskedCrc(bytes, 0, size + 1)) throw "Database table checksum mismatch";
        return switch (bytes.get(size)) {
            case 0: bytes.sub(0, size);
            case 1: snappy(bytes.sub(0, size));
            default: throw "Unsupported database compression";
        };
    }
    function entries(bytes:Bytes, consume:Bytes->Bytes->Void):Void {
        if (bytes.length < 4) throw "Invalid database block";
        var restarts = bytes.getInt32(bytes.length - 4);
        if (restarts < 1 || restarts > (bytes.length - 4) / 4) throw "Invalid database restart table";
        var end = bytes.length - 4 - restarts * 4, c = new Cursor(bytes.sub(0, end)), previous = Bytes.alloc(0);
        while (c.pos < end) {
            progress();
            var shared = c.varint(), unshared = c.varint(), size = c.varint();
            if (shared > previous.length || shared + unshared > 1024 * 1024) throw "Invalid database key prefix";
            var suffix = c.take(unshared), key = Bytes.alloc(shared + unshared);
            key.blit(0, previous, 0, shared); key.blit(shared, suffix, 0, unshared);
            consume(key, c.take(size)); previous = key;
        }
    }
    function readTable(path:String, size:Int):Void {
        if (size < 48) throw "Truncated database table";
        var footer = readAt(path, size - 48, 48), c = new Cursor(footer);
        if (footer.getInt32(40) != 0x8B80FB57 || footer.getInt32(44) != 0xDB477524) throw "Unsupported database table";
        c.varint(); c.varint(); // metaindex handle
        var offset = c.varint(), length = c.varint(), first = "";
        entries(block(path, offset, length), function(key, handle) {
            var last = userKey(key), matches = overlaps(first, last); first = last;
            if (!matches) return;
            var h = new Cursor(handle), offset = h.varint(), length = h.varint();
            entries(block(path, offset, length), function(key, value) {
                var tail = key.length - 8;
                if (tail < 0) throw "Invalid internal database key";
                remember(userKey(key), key.getInt64(tail) >>> 8, key.get(tail), value);
            });
        });
    }
    /** Raw Snappy blocks used by LevelDB, with checked back-references. */
    public static function snappy(bytes:Bytes):Bytes {
        var c = new Cursor(bytes), size = c.varint();
        if (size > 16 * 1024 * 1024) throw "Expanded database block too large";
        var result = Bytes.alloc(size), pos = 0;
        while (c.pos < bytes.length) {
            var tag = c.byte(), type = tag & 3, length = 0, offset = 0;
            if (type == 0) {
                length = tag >>> 2;
                if (length < 60) length++;
                else {
                    var count = length - 59; length = 0;
                    for (i in 0...count) length |= c.byte() << (i * 8);
                    length++;
                }
                if (length <= 0 || length > size - pos) throw "Invalid Snappy literal";
                result.blit(pos, c.take(length), 0, length);
            } else {
                switch (type) {
                    case 1: length = 4 + ((tag >>> 2) & 7); offset = ((tag & 224) << 3) | c.byte();
                    case 2: length = 1 + (tag >>> 2); offset = c.byte() | (c.byte() << 8);
                    case 3: length = 1 + (tag >>> 2); offset = c.byte() | (c.byte() << 8) | (c.byte() << 16) | (c.byte() << 24);
                }
                if (offset <= 0 || offset > pos || length > size - pos) throw "Invalid Snappy back-reference";
                for (i in 0...length) result.set(pos + i, result.get(pos + i - offset));
            }
            pos += length;
        }
        if (pos != size) throw "Incomplete Snappy block";
        return result;
    }
}
