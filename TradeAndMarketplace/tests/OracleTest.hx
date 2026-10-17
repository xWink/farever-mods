import trade.TradeSession;
import trade.TradeOffer;
import trade.TradeWire;
import trade.TradePreview;
import trade.TradeTypes;
/** Differential test. Reference methods execute directly from the surviving bytecode. */
class OracleTest {
    @:hlNative("std","sys_resolve_type") static function resolve(type:hl.Type,companion:hl.Type):Dynamic return null;
    static var checks = 0;
    static var parser:Dynamic;
    static function remote(v:Dynamic):Dynamic return call(Type.createInstance(cast parser,[haxe.Json.stringify(v)]),"doParse",[]);
    static function original(c:Dynamic):Dynamic { var t:hl.BaseType = cast c; return resolve(t.__type__,hl.Type.getDynamic(t)); }
    static function call(o:Dynamic,name:String,args:Array<Dynamic>):Dynamic return Reflect.callMethod(o,Reflect.field(o,name),args);
    static function local(v:Dynamic):Dynamic {
        if (v == null) return null;
        var name = hl.Type.getDynamic(v).getTypeName();
        if (name == "String") return Std.string(v);
        if (name != null && StringTools.startsWith(name,"hl.types.Array")) {
            var out:Array<Dynamic> = []; var n:Null<Int> = Reflect.field(v,"length");
            if (n == null) n = call(v,"get_length",[]);
            for (i in 0...n) out.push(local(call(v,"getDyn",[i]))); return out;
        }
        if (!Reflect.isObject(v)) return v;
        var out:Dynamic = {}; for (key in Reflect.fields(v)) Reflect.setField(out,key,local(Reflect.field(v,key))); return out;
    }
    static function equal(a:Dynamic,b:Dynamic,label:String):Void {
        checks++;
        if (haxe.Json.stringify(a) != haxe.Json.stringify(local(b))) throw label+": "+haxe.Json.stringify(a)+" != "+haxe.Json.stringify(local(b));
    }
    static function snapshot(s:Dynamic):Dynamic {
        var fields = ["self","peer","id","phase","leader","mine","theirs","revision","peerRevision","ack","accepted","peerAccepted","received","peerReceived","error","changed","deadline","outbox"];
        return [for (f in fields) local(Reflect.field(s,f))];
    }
    static function item():TradeItem return {uid:"42",kind:"Copper",count:3,name:"Copper",detail:"Metal",color:0xabcdef,fingerprint:"fingerprint",preview:null};
    static function main() {
        parser = original(haxe.format.JsonParser);
        var sessionType = original(TradeSession), offerType = original(TradeOffer), wireType = original(TradeWire), previewType = original(TradePreview);
        var items = [item()];
        equal(TradeOffer.valid(items),call(offerType,"valid",[remote(items)]),"offer validity");
        equal(TradeOffer.hash(items),call(offerType,"hash",[remote(items)]),"offer hash");
        var p:TradeItemPreview = {flags:3,level:30,upgrade:2,rarity:"Rare",infusion:"Fire",bonus:"Power",mastery:"",slots:["Ruby",""],effects:[{skill:"Poison",source:"RoguePoison"}]};
        items[0].preview = p;
        equal(TradePreview.valid(p),call(previewType,"valid",[remote(p)]),"preview validity");
        equal(TradeOffer.hash(items),call(offerType,"hash",[remote(items)]),"preview hash");
        var native = Type.createInstance(cast wireType,["ABC"]), wire = new TradeWire("ABC");
        for (packet in [{id:"session",to:"bob",op:"invite"},{id:"session",to:"bob",op:"offer",items:items}]) {
            var encoded = wire.encode(packet,"Alice"), reference:Dynamic = call(native,"encode",[remote(packet),"Alice"]);
            equal(encoded,reference,"wire bytes");
            encoded.reverse(); for (part in encoded) equal(wire.receive("alice",part,1),call(native,"receive",["alice",part,1.0]),"reassembly");
        }
        for (seed in 0...100) {
            var a = new TradeSession("alice"), b = new TradeSession("bob");
            var ra = Type.createInstance(cast sessionType,["alice"]), rb = Type.createInstance(cast sessionType,["bob"]);
            equal(a.start("bob","s"+seed,0),call(ra,"start",["bob","s"+seed,0.0]),"start");
            for (step in 0...30) {
                var now:Float = step;
                if (step == 1) { b.join(now); call(rb,"join",[now]); }
                if (step == 3) { a.setOffer(items,now); call(ra,"setOffer",[remote(items),now]); }
                if (step == 5) { a.accept(now); call(ra,"accept",[now]); }
                if (step == 7) { b.accept(now); call(rb,"accept",[now]); }
                if (step == 8 && seed%3 == 0) { a.setOffer([],now); call(ra,"setOffer",[remote([]),now]); }
                if (step == 9 && seed%3 == 1) { a.cancelByUser(); call(ra,"cancelByUser",[null]); }
                if (step == 12 && seed%3 == 2) { a.gotItems(); call(ra,"gotItems",[]); b.gotItems(); call(rb,"gotItems",[]); }
                for (pair in [{s:a,t:b,r:ra,rt:rb},{s:b,t:a,r:rb,rt:ra}]) {
                    var pending = pair.s.outbox.copy(); pair.s.outbox = [];
                    var nativeBox = Reflect.field(pair.r,"outbox");
                    while (call(nativeBox,"get_length",[]) > 0) call(nativeBox,"shift",[]);
                    for (packet in pending) {
                        pair.t.receive(pair.s.self,packet,now); call(pair.rt,"receive",[pair.s.self,remote(packet),now]);
                        if (seed%2 == 0) { pair.t.receive(pair.s.self,packet,now); call(pair.rt,"receive",[pair.s.self,remote(packet),now]); }
                    }
                }
                a.tick(now); call(ra,"tick",[now]); b.tick(now); call(rb,"tick",[now]);
                equal(snapshot(a),snapshot(ra),"alice seed "+seed+" step "+step);
                equal(snapshot(b),snapshot(rb),"bob seed "+seed+" step "+step);
            }
        }
        Sys.println("Original-bytecode differential checks passed: "+checks);
    }
}
