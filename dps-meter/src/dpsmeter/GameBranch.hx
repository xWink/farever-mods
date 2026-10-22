package dpsmeter;

import dpsmeter.GameAccess as G;

/**
 * The recorded game version does not by itself identify the Steam beta.
 * Capture a separate branch label from the native game at session startup.
 * Unknown builds stay local rather than risking PTR leaderboard submissions.
 */
class GameBranch {
    public static inline var UNKNOWN="unknown";
    public static inline var LIVE="live";

    public static function capture(?version=""):String {
        return captureWith(version,
            (owner,name)->G.current(owner,name)!=null,
            (owner,name)->G.staticCall(owner,name,[]));
    }

    /** Static functions are fields on the game's reflection companion.
     * Check for their presence before binding them: HLX logs a native ERROR
     * if a missing getter is passed to resolveStaticMember on live builds. */
    public static function captureWith(version:String, exists:(String,String)->Bool,
        read:(String,String)->Dynamic):String {
        // PTR exposes the beta-name getter under Main. Some live builds omit
        // it but still expose the regular branch getter (e.g. MAIN).
        return detect(name->{
            for(owner in ["Main","Config"])try {
                if(!exists(owner,name))continue;
                var branch=read(owner,name);
                if(branch!=null)return branch;
            }catch(_:Dynamic){}
            return null;
        },version);
    }

    /** An available beta-name getter returning the empty string means live. */
    public static function detect(probe:String->Dynamic,?version=""):String {
        var resolved=false;
        for(name in ["get_steamBetaName","get_branchName"]) {
            try {
                var raw=probe(name);
                if(raw==null)continue;
                resolved=true;
                var text=StringTools.trim(Std.string(raw));
                if(text!="")return text;
            }catch(_:Dynamic){}
        }
        if(version!=null&&isPtr(version))return "ptr";
        return resolved?LIVE:UNKNOWN;
    }

    public static function isPtr(branch:String):Bool {
        var text=branch==null?"":branch.toLowerCase();
        return text.indexOf("public-test-branch")>=0||text.indexOf("ptr")>=0
            ||text.indexOf("test-branch")>=0||text.indexOf("public test branch")>=0;
    }

    public static function uploadable(branch:String):Bool {
        var text=branch==null?"":StringTools.trim(branch).toLowerCase();
        // Never guess that a named beta branch is a production build.
        return ["live","default","public","release","stable","main","production"].indexOf(text)>=0;
    }

    /** Pre-branch archives keep their old behavior; new unknown/beta logs
        cannot enter a submission queue or be retried from an existing one. */
    public static function recordMayUpload(record:Dynamic):Bool {
        if(record==null)return false;
        if(!Reflect.hasField(record,"gameBranch"))return true;
        var branch=Reflect.field(record,"gameBranch");
        // Blank comes from pre-branch archives and uninitialized test fixtures.
        // Actual new sessions store either a resolved branch or "unknown";
        // unknown is deliberately blocked, so PTR cannot silently upload.
        return Std.isOfType(branch,String)&&(branch==""||uploadable(branch));
    }
}
