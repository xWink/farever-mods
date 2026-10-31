package groupfinder;
import hlx.runtime.Bus;
import fareverly.Protocol;
import fareverly.SessionLease;
import groupfinder.GroupTransport;
import modconfig.CommonSettings;

/** Uses the same hidden credential and login lease as DPS Meter and Marketplace. */
class GroupLogin {
    final c:GroupController;
    final api:GroupApi;
    var signingIn=false;
    var verifying=false;
    var savedKey="";
    public function new(c:GroupController,api:GroupApi) {
        this.c=c;this.api=api;savedKey=readKey();api.onEvent=receive;
        Bus.subscribe(CommonSettings.CHANGED_TOPIC,(_:Dynamic)->{
            var key=readKey();if(key!=savedKey){savedKey=key;end();c.reconnect();}
        });
        var action="better-mod-settings/action/"+HlxRuntime.moduleName()+"/";
        Bus.subscribe(action+"fareverlySignIn",(_:Dynamic)->signIn());
        Bus.subscribe(action+"fareverlyVerify",(_:Dynamic)->verify());
    }
    public static function readKey():String {
        try {var v=Reflect.field(CommonSettings.read(),"fareverlyApiKey");return Std.isOfType(v,String)?v:"";}catch(_:Dynamic)return "";
    }
    public function end():Void {signingIn=verifying=false;SessionLease.release(HlxRuntime.moduleName());c.view.closeFareverlyNotice();}
    function signIn():Void {
        if(signingIn||verifying)return;
        if(c.party==null||c.party.region==""){c.view.showFareverlyNotice("Enter the game with your character before connecting to Fareverly.");return;}
        if(!SessionLease.acquire(HlxRuntime.moduleName())){c.view.showFareverlyNotice("A Fareverly sign-in is already running in another mod.");return;}
        try {api.auth("auth",GroupNative.random());signingIn=true;c.view.showFareverlyNotice("Preparing Steam sign-in...",true);}
        catch(e:Dynamic){end();c.view.showFareverlyNotice(Std.string(e));}
    }
    function verify():Void {
        if(signingIn||verifying)return;
        if(c.party==null){c.view.showFareverlyNotice("Enter the game with your character before verifying Fareverly.");return;}
        if(!Protocol.validKey(readKey())){c.view.showFareverlyNotice(Protocol.LOGIN_REQUIRED);return;}
        verifying=true;api.auth("verify");c.view.showFareverlyNotice("Verifying Fareverly connection...");
    }
    public function cancel():Void {api.auth("cancel-auth");end();}
    function receive(e:GroupEvent):Void switch(e.op) {
        case "auth","auth-end":
            if(signingIn) {
                signingIn=e.op=="auth";if(!signingIn)SessionLease.release(HlxRuntime.moduleName());
                c.view.showFareverlyNotice((e.code==null||e.code==""?"":"Code: "+e.code+"\n")+e.message,signingIn);
            }
        case "credential":
            if(signingIn) {
                end();var message=Protocol.CONNECTED;
                try {
                    var values=CommonSettings.read();if(readKey()!=e.expectedKey)throw "The API key changed during sign-in. Your current key was kept.";
                    Reflect.setField(values,"fareverlyApiKey",e.credential.accessToken);
                    sys.FileSystem.createDirectory(haxe.io.Path.directory(CommonSettings.PATH));
                    GroupNative.write(sys.FileSystem.fullPath(CommonSettings.PATH),haxe.Json.stringify(values,null,"  "));
                    Bus.publish(CommonSettings.CHANGED_TOPIC,{key:"fareverlyApiKey"});
                }catch(error:Dynamic)message=Std.string(error);
                c.view.showFareverlyNotice(message);
            }
        case "verification":if(verifying){verifying=false;c.view.showFareverlyNotice(e.message);}
        case "error":if(signingIn||verifying){end();c.view.showFareverlyNotice(e.message);}
        default:
    };
}
