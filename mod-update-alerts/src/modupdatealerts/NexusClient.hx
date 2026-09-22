package modupdatealerts;

import modupdatealerts.UpdateModel.InstalledMod;

typedef NexusMod = {
    var name:String;
    var version:String;
    var files:Array<Dynamic>;
}

/** Anonymous, read-only public metadata. No downloads, credentials, or browser scraping. */
class NexusClient {
    var games:Map<String,String> = [];
    var cache:Map<String,Null<NexusMod>> = [];
    final stopped:Void->Bool;
    final deadline:Float;
    var nextRequest:Float=0;
    public function new(stopped:Void->Bool) {
        this.stopped = stopped;
        deadline = haxe.Timer.stamp() + 180;
    }
    function progress():Void {
        if (stopped()) throw "Update check cancelled";
        if (haxe.Timer.stamp() > deadline) throw "Update check time budget exhausted";
    }
    function query(query:String, variables:Dynamic):Dynamic {
        progress();
        var delay=nextRequest-haxe.Timer.stamp();
        if(delay>0) Sys.sleep(delay);
        nextRequest=haxe.Timer.stamp()+0.35;
        var request = new sys.Http("https://api.nexusmods.com/v2/graphql");
        request.cnxTimeout = 15;
        request.noShutdown = true;
        request.setHeader("Content-Type", "application/json");
        request.setHeader("User-Agent", "Farever-Mod-Update-Alerts/1.0");
        request.setPostData(haxe.Json.stringify({query:query,variables:variables}));
        var status=0, error="";
        request.onStatus = value -> status=value;
        request.onError = value -> error=value;
        var output=new haxe.io.BytesOutput();
        #if hl
        var socket=new MetadataSocket(true,progress);
        #else
        var socket=new sys.ssl.Socket();
        socket.verifyCert=true;
        socket.setTimeout(15);
        #end
        try request.customRequest(true,output,socket,"POST")
        catch (e:Dynamic) { socket.close(); throw e; }
        socket.close();
        if (status != 200 || error != "") throw "Nexus metadata request failed (HTTP " + status + ")";
        var response:Dynamic=haxe.Json.parse(output.getBytes().toString());
        if (Reflect.field(response,"errors") != null) {
            // Do not log entire server replies or local inventory.
            return null;
        }
        return Reflect.field(response,"data");
    }
    public function fetch(domain:String, modId:Int):Null<NexusMod> {
        progress();
        var key=UpdateModel.identity(domain,modId);
        if (cache.exists(key)) return cache.get(key);
        if (!games.exists(domain)) {
            var data=query("query($domain:String!){game(domainName:$domain){id}}",{domain:domain});
            var game=data==null?null:Reflect.field(data,"game");
            if (game==null) { cache.set(key,null); return null; }
            games.set(domain,Std.string(Reflect.field(game,"id")));
        }
        var data=query("query($game:ID!,$mod:ID!){mod(gameId:$game,modId:$mod){name version} modFiles(gameId:$game,modId:$mod){fileId sqid name version date categoryId changelogText}}",
            {game:games.get(domain),mod:Std.string(modId)});
        if (data==null) { cache.set(key,null); return null; }
        var info:Dynamic=Reflect.field(data,"mod");
        var files:Dynamic=Reflect.field(data,"modFiles");
        if (info==null || !Std.isOfType(files,Array)) { cache.set(key,null); return null; }
        var result:NexusMod={name:InstalledMods.text(info,"name"),version:InstalledMods.text(info,"version"),files:cast files};
        cache.set(key,result);
        return result;
    }

    /** The author's page version is the advertised release. Newer files may be
        betas, even when categorized as main/update downloads. */
    public static function hasDownload(info:NexusMod):Bool {
        for (file in info.files) if (matchesRelease(file,info.version)) return true;
        return false;
    }
    static function matchesRelease(file:Dynamic,version:String):Bool {
        var category=Reflect.field(file,"categoryId");
        return (category==1 || category==2)
            && UpdateModel.compare(InstalledMods.text(file,"version"),version)==0;
    }
    public static function changelog(info:NexusMod):String {
        var notes:Array<String>=[],seen:Map<String,Bool>=[],length=0;
        for (file in info.files) {
            if (!matchesRelease(file,info.version)) continue;
            var lines:Dynamic=Reflect.field(file,"changelogText");
            if (!Std.isOfType(lines,Array)) continue;
            for (line in (cast lines:Array<Dynamic>)) {
                if (!Std.isOfType(line,String)) continue;
                var text=ChangelogText.plain(line);
                if (text=="" || seen.exists(text)) continue;
                seen[text]=true;notes.push(text);length+=text.length;
                if (length>=16000 || notes.length>=100)
                    return notes.join("\n\n").substr(0,16000)+"\n\n[More notes are available on Nexus Mods.]";
            }
        }
        return notes.join("\n\n");
    }
}
