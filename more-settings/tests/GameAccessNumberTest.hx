import moresettings.GameAccess as G;

/** Uses the production bridge on HashLink; no replacement GameAccess adapter. */
class GameAccessNumberTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ": expected " + expected + ", got " + actual;
    }
    @:hlNative("std", "gc_stats")
    static function stats(total:hl.Ref<Float>, count:hl.Ref<Float>, memory:hl.Ref<Float>):Void {}

    static function main():Void {
        eq(G.number(null, 7), 7, "null fallback");
        eq(G.number(0, 7), 0, "zero is a value");
        eq(G.number(-2147483648), -2147483648.0, "signed Int boundary");
        eq(G.number(2147483647), 2147483647.0, "positive Int boundary");
        eq(G.number(1.2345678901234567), 1.2345678901234567, "Float precision is preserved");
        eq(G.number(1e100), 1e100, "large finite Float");
        var f32:hl.F32 = 0.125;
        var u8:hl.UI8 = 255;
        var u16:hl.UI16 = 65535;
        eq(G.number(f32), 0.125, "native single-precision float");
        eq(G.number(u8), 255, "native unsigned byte");
        eq(G.number(u16), 65535, "native unsigned short");
        eq(G.number("12.5"), 12.5, "numeric string fallback");
        eq(G.number(" -3.75rest"), -3.75, "existing parseFloat semantics");
        eq(G.number("", 7), 7, "empty string fallback");
        eq(G.number("invalid", 7), 7, "invalid string fallback");
        eq(G.number(true, 7), 7, "boolean is not a number");
        eq(G.number(Math.NaN, 7), 7, "NaN fallback");
        eq(G.number(Math.POSITIVE_INFINITY, 7), 7, "positive infinity fallback");
        eq(G.number(Math.NEGATIVE_INFINITY, 7), 7, "negative infinity fallback");
        eq(G.integer(42.9), 42, "integer truncates positive Float");
        eq(G.integer(-42.9), -42, "integer truncates negative Float");
        eq(G.integer("42.9"), 42, "integer accepts numeric strings");
        eq(G.integer(null, 8), 8, "integer fallback");

        var values:Array<Dynamic> = [12, 3.5, -9, 0.125];
        var sum = 0.;
        for (i in 0...1000) sum += G.number(values[i & 3]);
        var bytesBefore = 0., countBefore = 0., memoryBefore = 0.;
        var bytesAfter = 0., countAfter = 0., memoryAfter = 0.;
        stats(bytesBefore, countBefore, memoryBefore);
        for (i in 0...100000) sum += G.number(values[i & 3]) + G.integer(values[i & 3]);
        stats(bytesAfter, countAfter, memoryAfter);
        eq(sum, 317281.25, "numeric reads remain observable");
        eq(bytesAfter - bytesBefore, 0., "numeric reads allocate no strings or other objects");
        eq(countAfter - countBefore, 0., "numeric read allocation count");
        Sys.println('GameAccess numeric conversion: $checks checks passed.');
    }
}
