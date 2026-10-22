import trade.TradeWindowFlags;

enum MockWindowFlag {
    PreventCloseOther;
    AutoRegisterLayer;
    NeedLayer;
    FreeCursor;
    BlockInputs;
    BlockSkills;
}

class WindowFlagsTest {
    static var checks=0;
    static function check(ok:Bool):Void {
        checks++;
        if(!ok)throw "WindowFlags assertion "+checks;
    }
    static function lookup(name:String):Dynamic return switch(name) {
            case "PreventCloseOther":MockWindowFlag.PreventCloseOther;
            case "AutoRegisterLayer":MockWindowFlag.AutoRegisterLayer;
            case "NeedLayer":MockWindowFlag.NeedLayer;
            case "FreeCursor":MockWindowFlag.FreeCursor;
            case "BlockInputs":MockWindowFlag.BlockInputs;
            case "BlockSkills":MockWindowFlag.BlockSkills;
            default:null;
        };
    static function main():Void {
        var names=["PreventCloseOther","AutoRegisterLayer","NeedLayer","FreeCursor","BlockInputs","BlockSkills"];
        var all=TradeWindowFlags.resolve(names,lookup);
        check(all.mask==63&&all.found==6&&all.missing.length==0);
        // PTR may omit one or more flags. Remaining flags still apply;
        // missing values must never reach Type.enumIndex(null).
        var ptr=TradeWindowFlags.resolve(names,name->
            name=="BlockSkills"||name=="NeedLayer"?null:lookup(name));
        check(ptr.found==4&&ptr.missing.join(",")=="NeedLayer,BlockSkills");
        check(ptr.mask==((1<<0)|(1<<1)|(1<<3)|(1<<4)));
        var none=TradeWindowFlags.resolve(names,_ -> null);
        check(none.found==0&&none.mask==0&&none.missing.length==6);
        var faulty=TradeWindowFlags.resolve(names,name->
            name=="NeedLayer"?throw "Member unavailable":lookup(name));
        check(faulty.found==5&&faulty.missing[0]=="NeedLayer");
        var invalid=TradeWindowFlags.resolve(["Invalid"],_ -> "not an enum");
        check(invalid.mask==0&&invalid.found==0&&invalid.missing.length==1);
        trace("Window flag compatibility checks passed: "+checks);
    }
}
