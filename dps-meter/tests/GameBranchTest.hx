import dpsmeter.GameBranch;
import dpsmeter.GameAccess as G;

class GameBranchTest {
    static var checks=0;
    static function check(condition:Bool):Void {
        checks++;
        if(!condition)throw "GameBranch check "+checks;
    }
    static function main():Void {
        // Missing live-only beta getter must never reach the native resolver.
        var calls:Array<String>=[];
        check(GameBranch.captureWith("0.3.1.31641",
            (owner,name)->owner=="Main"&&name=="get_branchName",
            (owner,name)->{calls.push(owner+"."+name);return "MAIN";})=="MAIN");
        check(calls.length==1&&calls[0]=="Main.get_branchName");
        calls=[];
        check(GameBranch.captureWith("0.3.1.31690",
            (owner,name)->owner=="Main"&&(name=="get_steamBetaName"||name=="get_branchName"),
            (owner,name)->{
                calls.push(owner+"."+name);
                return name=="get_steamBetaName"?"public-test-branch":"MAIN";
            })=="public-test-branch");
        check(calls.length==1&&calls[0]=="Main.get_steamBetaName");
        check(GameBranch.captureWith("0.3.1.31641",(owner,name)->false,
            (owner,name)->throw "Absent native getters must not be called")=="unknown");
        // Exercise the production capture path with the interpreter bridge.
        G.globals["Main.get_branchName"]=true;
        G.globals["gameBranch"]="MAIN";
        check(GameBranch.capture("0.3.1.31641")=="MAIN");
        G.globals["Main.get_steamBetaName"]=true;
        G.globals["gameBeta"]="public-test-branch";
        check(GameBranch.capture("0.3.1.31690")=="public-test-branch");
        for(key in ["Main.get_branchName","Main.get_steamBetaName","gameBranch","gameBeta"])
            G.globals.remove(key);
        check(GameBranch.detect(name->name=="get_steamBetaName"?"public-test-branch":null)=="public-test-branch");
        check(GameBranch.detect(name->name=="get_steamBetaName"?"":null)=="live");
        check(GameBranch.detect(_->throw "Missing native member", "0.3.0-ptr")=="ptr");
        check(GameBranch.detect(_->null, "0.3.0.30001")=="unknown");
        check(GameBranch.detect(name->name=="get_branchName"?"Public test branch - ":null)=="Public test branch -");
        check(GameBranch.isPtr("public-test-branch")&&GameBranch.isPtr("PTR")
            &&!GameBranch.isPtr("live"));
        check(GameBranch.uploadable("MAIN") && GameBranch.uploadable("main")
            && GameBranch.uploadable(" MAIN "));
        for(branch in ["live","default","public","release","stable","production",
            "public-test-branch","PTR","unknown","experimental","",null])
            check(!GameBranch.uploadable(branch));
        check(GameBranch.sessionMayUpload(true,"MAIN"));
        check(!GameBranch.sessionMayUpload(false,"MAIN"));
        for(branch in ["PTR","unknown","live","public-test-branch",""])
            check(!GameBranch.sessionMayUpload(true,branch));
        check(GameBranch.recordMayUpload({gameBranch:"MAIN"}));
        check(GameBranch.recordMayUpload({gameBranch:" main "}));
        var invalidRecordBranches:Array<Dynamic>=["PTR","public-test-branch","unknown",
            "experimental","live","stable","production","",null,123,true];
        for(branch in invalidRecordBranches)
            check(!GameBranch.recordMayUpload({gameBranch:branch}));
        check(!GameBranch.recordMayUpload({gameVersion:"0.3.0.30001"}));
        check(!GameBranch.recordMayUpload({gameBranchMissing:true}));
        check(!GameBranch.recordMayUpload(null));
        trace("Game branch safety checks passed: "+checks);
    }
}
