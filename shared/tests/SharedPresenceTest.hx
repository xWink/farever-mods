import fareverly.PresenceConfig;
import modconfig.CommonSettings;
import groupfinder.GroupWorker;
import groupfinder.GroupHttp;
import marketplace.MarketWorker;
import marketplace.MarketHttp;
import sys.thread.Lock;
import sys.FileSystem;
import sys.io.File;

/** Both real workers read one saved setting; only HTTP is replaced with in-memory fixtures. */
class SharedPresenceTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function call(group:Bool,suffix:String):Dynamic {
        var until=haxe.Timer.stamp()+5;
        while(haxe.Timer.stamp()<until) {
            var value:Dynamic=group?GroupHttp.calls.pop(false):MarketHttp.calls.pop(false);
            if(value!=null&&StringTools.endsWith(value.url,suffix))return value;
            Sys.sleep(.01);
        }
        throw "Missing "+(group?"Group Finder":"Marketplace")+" "+suffix;
    }
    static function workers(?change:Bool):Void {
        var groupHold=new Lock(),marketHold=new Lock();GroupHttp.holdAccount=groupHold;MarketHttp.holdAccount=marketHold;
        var group=new GroupWorker(),market=new MarketWorker(),key="fv1_"+StringTools.lpad("","a",43);
        group.session("self",key,"europe");market.session("sender",key,"europe");
        call(true,"/account");call(false,"/account");
        if(change!=null)CommonSettings.write(PresenceConfig.KEY,change);
        var expected=PresenceConfig.busy();groupHold.release();marketHold.release();
        var a=haxe.Json.parse(call(true,"/heartbeat").body),b=haxe.Json.parse(call(false,"/heartbeat").body);
        check(a.server=="europe"&&a.busy==expected&&Reflect.fields(a).length==2,"Group Finder reads the latest shared state immediately before heartbeat");
        check(b.server=="europe"&&b.busy==expected&&Reflect.fields(b).length==2,"Marketplace sends the same shared state without suppressing presence");
        group.session("","","");market.session("","","");
    }
    static function main():Void {
        for(project in ["group-finder","trade-and-marketplace"]) {
            var definitions:Array<Dynamic>=haxe.Json.parse(File.getContent("../"+project+"/configFormats.json")).configs;
            var category="",keys:Array<String>=[];
            for(d in definitions) {
                if(d.type=="title")category=d.label;
                if(category=="Fareverly"&&d.key!=null)keys.push(d.key);
                if(d.key==PresenceConfig.KEY)check(CommonSettings.isCommon(d)&&d.type=="checkbox","Busy checkbox uses common storage");
                check(d.key!="openGroupFinder","Open Group Finder settings button removed");
            }
            check(keys.join(",")=="fareverlySignIn,fareverlyVerify,"+PresenceConfig.KEY,"Fareverly category puts shared busy setting last");
        }
        var previous=Sys.getCwd(),root=previous+"build/presence-test-"+Std.int(haxe.Timer.stamp()*1000);
        FileSystem.createDirectory(root);Sys.setCwd(root);
        check(!PresenceConfig.busy()&&!FileSystem.exists(CommonSettings.PATH),"Default is off without creating a settings file");
        workers();
        CommonSettings.write("unrelatedSetting",42);
        workers(true);workers(false);
        check(CommonSettings.read().unrelatedSetting==42,"Toggling busy preserves other shared settings");
        File.saveContent(CommonSettings.PATH,'{"fareverlyAppearBusy":"true"}');check(!PresenceConfig.busy(),"Only a boolean enables busy");
        File.saveContent(CommonSettings.PATH,'broken');check(!PresenceConfig.busy(),"Malformed settings do not stop heartbeats");
        Sys.setCwd(previous);
        FileSystem.deleteFile(root+"/"+CommonSettings.PATH);
        for(path in ["hlx/config/common","hlx/config","hlx",""])FileSystem.deleteDirectory(root+"/"+path);
        trace('Shared Fareverly presence passed ($checks checks)');Sys.exit(0);
    }
}
