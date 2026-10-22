import dpsmeter.GameBranch;

class GameBranchTest {
    static var checks=0;
    static function check(condition:Bool):Void {
        checks++;
        if(!condition)throw "GameBranch check "+checks;
    }
    static function main():Void {
        check(GameBranch.detect(name->name=="get_steamBetaName"?"public-test-branch":null)=="public-test-branch");
        check(GameBranch.detect(name->name=="get_steamBetaName"?"":null)=="live");
        check(GameBranch.detect(_->throw "Missing native member", "0.3.0-ptr")=="ptr");
        check(GameBranch.detect(_->null, "0.3.0.30001")=="unknown");
        check(GameBranch.detect(name->name=="get_branchName"?"Public test branch - ":null)=="Public test branch -");
        check(GameBranch.isPtr("public-test-branch")&&GameBranch.isPtr("PTR")
            &&!GameBranch.isPtr("live"));
        check(GameBranch.uploadable("live")&&GameBranch.uploadable("main")
            &&!GameBranch.uploadable("public-test-branch")&&!GameBranch.uploadable("unknown")
            &&!GameBranch.uploadable("experimental"));
        check(GameBranch.recordMayUpload({gameBranch:"live"}));
        check(!GameBranch.recordMayUpload({gameBranch:"public-test-branch"}));
        check(!GameBranch.recordMayUpload({gameBranch:"unknown"}));
        check(GameBranch.recordMayUpload({gameVersion:"0.3.0.30001"}));
        trace("Game branch safety checks passed: "+checks);
    }
}
