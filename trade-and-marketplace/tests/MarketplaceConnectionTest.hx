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
        try {test();login();} catch(e:Dynamic){Sys.setCwd(cwd);remove(root);throw e;}
        Sys.setCwd(cwd);remove(root);
        Sys.println('Marketplace connection: $checks checks passed.');
    }
    static function login():Void {
        var c=new MarketController(),worker=MarketWorker.current;
        var topic="better-mod-settings/action/trade-and-marketplace/fareverlySignIn";
        Bus.publish(topic,null);
        check(!c.view.isOpen()&&worker.sent.length==0,"Login without a character only shows a notice");
        var player:Dynamic={isMe:true,hero:{loadout:{banks:[]}}},app={me:player};
        c.player=player;c.account="test-account";c.server="europe";
        c.key="fv1_"+StringTools.lpad("","K",43);
        var original=File.getContent(CommonSettings.PATH),writes=marketplace.MarketNative.writes;
        Bus.publish(topic,null);Bus.publish(topic,null);
        check(!c.view.isOpen()&&c.signingIn&&worker.sent.length==1&&worker.sent[0].op=="auth"&&c.view.noticePending,
            "Login starts one authentication attempt with a cancellable popup and no marketplace window");
        worker.incoming.push({generation:c.generation,op:"auth",code:"ABCD-1234",
            message:"Match this code in your browser, then approve Steam sign-in. Connection may take up to 1 minute."});c.update(app,0);
        var progress=c.view.notices[c.view.notices.length-1];
        check(!c.view.isOpen()&&c.view.noticePending&&progress.indexOf("ABCD-1234")>=0
            &&StringTools.endsWith(progress,"Connection may take up to 1 minute."),"Sign-in progress is shown in the popup");
        var cancelledGeneration=c.generation;
        c.cancelSignIn();var count=c.view.notices.length;
        var credential={accessToken:"fv1_"+StringTools.lpad("","N",43),accountId:c.account,steamId:"76561198000000000",expiresAt:"2030-01-01T00:00:00.000Z"};
        worker.incoming.push({generation:cancelledGeneration,op:"auth",code:"LATE",message:"Late response"});
        worker.incoming.push({generation:cancelledGeneration,op:"credential",credential:credential,expectedKey:c.key});c.update(app,0);
        check(!c.signingIn&&!c.view.isOpen()&&!c.view.noticePending&&c.view.notices.length==count,
            "Cancellation suppresses late popups and keeps the marketplace closed");
        check(File.getContent(CommonSettings.PATH)==original&&marketplace.MarketNative.writes==writes,
            "Cancelled login never overwrites the saved credential");
        Bus.publish(topic,null);
        worker.incoming.push({generation:c.generation,op:"auth-end",message:"Steam sign-in was declined."});c.update(app,0);
        check(!c.signingIn&&!c.view.noticePending&&!c.view.isOpen()
            &&c.view.notices[c.view.notices.length-1]=="Steam sign-in was declined.","Sign-in failure displays a result popup");
        Bus.publish(topic,null);
        worker.incoming.push({generation:c.generation,op:"credential",credential:credential,expectedKey:c.key});c.update(app,0);
        check(!c.signingIn&&!c.view.noticePending&&!c.view.isOpen()
            &&c.view.notices[c.view.notices.length-1]==Protocol.CONNECTED,"Success shows the shared connection confirmation without opening the marketplace");
        var saved=CommonSettings.read();
        check(saved.fareverlyApiKey==credential.accessToken&&saved.otherModSetting==42&&marketplace.MarketNative.writes==writes+1,
            "Successful login keeps secure credential saving and other common settings intact");
        c.disconnect();
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
