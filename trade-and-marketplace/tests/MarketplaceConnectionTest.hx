import marketplace.MarketController;
import marketplace.MarketWorker;
import fareverly.Protocol;
import modconfig.CommonSettings;
import hlx.runtime.Bus;
import sys.FileSystem;
import sys.io.File;

@:access(marketplace.MarketController)
class MarketplaceConnectionTest {
    static var checks=0;
    static var topic="better-mod-settings/action/trade-and-marketplace/fareverlyVerify";
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    public static function run():Void {
        var cwd=Sys.getCwd(),root=cwd+"build/market-connection-"+Std.random(0x3fffffff);
        FileSystem.createDirectory(root);Sys.setCwd(root);
        try test() catch(e:Dynamic){Sys.setCwd(cwd);remove(root);throw e;}
        Sys.setCwd(cwd);remove(root);
        Sys.println('Marketplace connection: $checks checks passed.');
    }
    static function test():Void {
        var c=new MarketController(),worker=MarketWorker.current;
        Bus.publish(topic,null);
        check(worker.sent.length==0,"Verification requires a logged-in character");
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        c.player=player;c.account="test-account";c.server="europe";
        Bus.publish(topic,null);
        check(worker.sent.length==0&&c.view.notices[c.view.notices.length-1]==Protocol.LOGIN_REQUIRED,
            "Missing credentials request login without making a request");
        c.key="fv1_"+StringTools.lpad("","K",43);
        CommonSettings.write("fareverlyApiKey",c.key);CommonSettings.write("otherModSetting",42);
        var saved=File.getContent(CommonSettings.PATH);
        c.ready=true;c.rows=[{id:"keep-listing"}];c.selected=c.rows[0];c.filters["search"]="sword";
        var selected=c.selected,buy=c.buy;
        Bus.publish(topic,null);Bus.publish(topic,null);
        check(worker.sent.length==1&&worker.sent[0].op=="verify"&&c.verifying,
            "The settings button requests one check of the existing connection");
        check(!c.view.isOpen()&&!c.busy&&c.selected==selected&&c.rows[0]==selected&&c.buy==buy&&c.filters["search"]=="sword",
            "Verification does not open the marketplace or reset listing and draft state");
        worker.incoming.push({generation:c.generation,op:"verification",message:Protocol.CONNECTED});c.update(app,0);
        check(!c.verifying&&c.view.notices[c.view.notices.length-1]==Protocol.CONNECTED,
            "Successful verification displays the shared connection confirmation");
        check(File.getContent(CommonSettings.PATH)==saved,"Verification leaves shared credentials and other settings unchanged");
        for(notice in c.view.notices)check(notice.indexOf(c.key)<0,"No dialog exposes the saved secret");
        Bus.publish(topic,null);
        worker.incoming.push({generation:c.generation,op:"verification",message:"Could not verify Fareverly connection. Try again later."});c.update(app,0);
        check(!c.verifying&&c.view.notices[c.view.notices.length-1].indexOf("Could not verify")>=0,
            "Verification errors are visible and allow another attempt");
        Bus.publish(topic,null);var previous=c.generation,notices=c.view.notices.length;
        c.disconnect();worker.incoming.push({generation:previous,op:"verification",message:Protocol.CONNECTED});
        c.update({me:null},0);
        check(c.view.notices.length==notices&&!c.verifying,"Leaving the game ignores late verification results");
    }
    static function remove(path:String):Void {
        if(FileSystem.isDirectory(path)){for(name in FileSystem.readDirectory(path))remove(path+"/"+name);FileSystem.deleteDirectory(path);}
        else FileSystem.deleteFile(path);
    }
}
