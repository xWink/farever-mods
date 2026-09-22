import modupdatealerts.UpdateModel;
import modupdatealerts.UpdateModel.AvailableUpdate;
import modupdatealerts.InstalledMods;
import modupdatealerts.NexusClient;
import modupdatealerts.ReminderStore;
import modupdatealerts.PopupRetry;
import modupdatealerts.LevelDbSnapshot;
import modupdatealerts.VortexState;
import modupdatealerts.UpdateWorker;
import modupdatealerts.ChangelogText;
import modupdatealerts.LiteralText;
import sys.io.File;
import sys.FileSystem;

class UpdaterTest {
    static var checks=0;
    static function eq(a:Dynamic,b:Dynamic):Void {checks++;if(a!=b)throw 'Expected $b, got $a'+haxe.CallStack.toString(haxe.CallStack.callStack());}
    static function u(id:Int,a:String,b:String):AvailableUpdate
        return {name:"Mod "+id,domain:"farever",modId:id,current:a,latest:b};
    static function main():Void {
        checks+=PopupLifecycleTest.run();
        for(p in [["1.10.0","1.9.0"],["2","1.99.99"],["1.0.0","1.0.0-rc.1"],["1.0.0-rc.10","1.0.0-rc.2"]]) {
            eq(UpdateModel.compare(p[0],p[1]),1);eq(UpdateModel.compare(p[1],p[0]),-1);
        }
        for(p in [["v1.0.0","1"],["1.2.0+build","1.2"]])eq(UpdateModel.compare(p[0],p[1]),0);
        for(v in ["","latest","1.2 broken","999999999999999999999"])eq(UpdateModel.compare(v,"1"),null);
        var ignored:Map<String,String>=[];
        var list=[u(1,"1","2"),u(2,"2","3")];
        eq(UpdateModel.needsReminder(list,ignored),true);
        UpdateModel.dismiss(list,ignored);
        eq(UpdateModel.needsReminder(list,ignored),false);
        eq(UpdateModel.needsReminder([list[1],list[0]],ignored),false);
        eq(UpdateModel.needsReminder([list[0]],ignored),false);
        eq(UpdateModel.needsReminder([],ignored),false);
        eq(UpdateModel.needsReminder([u(1,"1","3"),list[1]],ignored),true);
        eq(UpdateModel.needsReminder([list[0],list[1],u(3,"1","2")],ignored),true);
        eq(UpdateModel.needsReminder([u(1,"0","1")],ignored),false);
        UpdateModel.dismiss([u(1,"1","3")],ignored);
        eq(ignored.get("farever/2"),"3");
        eq(UpdateModel.needsReminder([u(1,"1","2")],ignored),false);
        eq(UpdateModel.needsReminder([u(1,"2","3")],ignored),false);
        for(p in ["../x","C:/x","/x","a/../../x","a\\..\\x"])eq(InstalledMods.safeRelative(p),false);
        eq(InstalledMods.safeRelative("hlx/mods/foo/foo.hl"),true);
        var record:Dynamic={state:"installed",attributes:{source:"nexus",modId:15,version:"1.5.0",name:"Minimap",game:["farever"]}};
        eq(InstalledMods.fromVortex(record).version,"1.5.0");
        record.attributes.downloadGame="site";eq(InstalledMods.fromVortex(record).domain,"site");
        record.attributes.source="other";eq(InstalledMods.fromVortex(record),null);
        var files:Array<Dynamic>=[{version:"1.5.1",date:1789696451,categoryId:7},{version:"1.6.0",date:1789890908,categoryId:1}];
        var source="Minimap-15-1-5-1-1789696451";
        var modern="game-version-driver 16 0.0.1 2026-09-20T20-28Z FgeIvI3Az";

        var retry=new PopupRetry(), menu:Dynamic={}, game:Dynamic={};
        eq(retry.ready(menu,0),true);
        eq(retry.failed(0,"building header: not ready"),true);
        eq(retry.ready(menu,4),false); eq(retry.ready(menu,5),true);
        eq(retry.failed(5,"building header: not ready"),false); // No duplicate log spam.
        eq(retry.ready(menu,14),false); eq(retry.ready(menu,15),true);
        eq(retry.failed(15,"building header: not ready"),false);
        eq(retry.ready(menu,34),false); eq(retry.ready(menu,35),true); // The old three-attempt cutoff.
        retry.failed(35,"building header: not ready");
        eq(retry.ready(game,36),true); // Menu -> game resets the backoff immediately.
        eq(retry.failed(36,"building header: not ready"),true);
        eq(retry.ready(game,40),false); eq(retry.ready(game,41),true);
        eq(retry.failed(41,"building checkbox: failure"),true); // A different error is reported.
        retry.succeeded(); eq(retry.ready(game,41),true);
        for(i in 0...10) {
            retry.failed(i*100,"temporarily unavailable");
            eq(retry.ready(game,i*100+60),true); // Delays are bounded, attempts are not.
        }
        eq(NexusClient.hasDownload({name:"Minimap",version:"1.6.0",files:files}),true);
        eq(NexusClient.hasDownload({name:"Minimap",version:"1.5.1",files:files}),false);
        downloadTests();
        var root="tests/tmp-"+Std.random(10000000);
        try {
            var base=root+"/game/hlx/mods/example";
            FileSystem.createDirectory(base);File.saveContent(base+"/example.hl","fixture");
            var state=root+"/state/reminders.json";
            ReminderStore.save(state,ignored);eq(ReminderStore.load(state).get("farever/1"),"3");
            UpdateModel.dismiss([u(1,"1","4")],ignored);
            ReminderStore.save(state,ignored);eq(ReminderStore.load(state).get("farever/1"),"4");
            File.saveContent(state,"broken");eq(ReminderStore.load(state).get("farever/1"),"3");
            FileSystem.deleteFile(state+".bak");
            eq([for(k in ReminderStore.load(state).keys())k].length,0);
            var staging=FileSystem.absolutePath(root+"/staging");
            FileSystem.createDirectory(staging+"/"+source+"/hlx/mods/example");
            File.saveContent(staging+"/"+source+"/hlx/mods/example/example.hl","fixture");
            var manifest:Dynamic={version:1,gameId:"farever",stagingPath:staging,files:[
                {relPath:"hlx/mods/example/example.hl",source:source,time:FileSystem.stat(base+"/example.hl").mtime.getTime()},
                {relPath:"removed.hl",source:"removed",time:0}]};
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            var scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");
            eq(scan.deployed.length,1);eq(scan.deployed[0].source,source);eq(scan.deployed[0].metadata,null);
            var backup=root+"/vortex/temp/state_backups_full";FileSystem.createDirectory(backup);
            record.attributes.source="nexus";record.attributes.downloadGame="farever";
            var mods:Dynamic={};Reflect.setField(mods,source,record);
            File.saveContent(backup+"/hourly.json",haxe.Json.stringify({persistent:{mods:{farever:mods}}}));
            // A backup is never authoritative, even if newer than deployment.
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed[0].metadata,null);
            installFixture(root+"/vortex/state.v2");
            databaseTests(root+"/vortex");
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");
            eq(scan.deployed.length,1);eq(scan.deployed[0].metadata.version,"1.6.0");
            eq(UpdateModel.compare("1.6.0",scan.deployed[0].metadata.version),0);
            eq(UpdateModel.compare("1.7.0",scan.deployed[0].metadata.version),1);
            eq(scan.deployed[0].metadata.modId,15);
            discoveryRetryTests(root);
            // Same size and timestamps do not prove that staging was deployed.
            File.saveContent(staging+"/"+source+"/hlx/mods/example/example.hl","changed");
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed.length,0);
            File.saveContent(staging+"/"+source+"/hlx/mods/example/example.hl","fixture");
            manifest.files[0].time=0;
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed.length,0);
            // A changed test build must not hide other verified deployed mods.
            FileSystem.createDirectory(root+"/game/hlx/mods/driver");
            var driver=root+"/game/hlx/mods/driver/driver.hl";File.saveContent(driver,"driver fixture");
            FileSystem.createDirectory(staging+"/"+modern+"/hlx/mods/driver");
            File.saveContent(staging+"/"+modern+"/hlx/mods/driver/driver.hl","driver fixture");
            manifest.files.push({relPath:"hlx/mods/driver/driver.hl",source:modern,time:FileSystem.stat(driver).mtime.getTime()});
            File.saveContent(root+"/game/vortex.deployment.json",haxe.Json.stringify(manifest));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");
            eq(scan.deployed.length,1);eq(scan.deployed[0].source,modern);eq(scan.deployed[0].metadata.version,"0.0.1");
            // Broken current state must never fall back to old backup versions.
            File.saveContent(root+"/vortex/state.v2/CURRENT","bad manifest");
            scan=new InstalledMods();scan.scan(root+"/game",root+"/vortex");eq(scan.deployed[0].metadata,null);
            eq(scan.diagnostics.join(" ").indexOf("backup snapshots")>=0,true);
            ReminderStore.save(root+"/game/hlx/config/mod-updater/reminders.json",ignored);
            eq(ReminderStore.loadForRoot(root+"/game").get("farever/1"),"4");
            ReminderStore.save(root+"/game/hlx/config/mod-update-alerts/reminders.json",[]);
            eq(ReminderStore.loadForRoot(root+"/game").get("farever/1"),null);
            var info:Dynamic={name:"Example",modId:15,domain:"farever",version:"1.2.3",binary:"example.hl",sha256:haxe.crypto.Sha256.make(File.getBytes(base+"/example.hl")).toHex()};
            File.saveContent(base+"/update-info.json",haxe.Json.stringify(info));
            scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");eq(scan.manual.length,1);
            File.saveContent(base+"/example.hl","replaced");
            scan=new InstalledMods();scan.scan(root+"/game",root+"/empty");eq(scan.manual.length,0);
        }catch(e:Dynamic){remove(root);throw e;}
        remove(root);Sys.println('Mod Update Alerts: $checks checks passed.');
    }
    static function downloadTests():Void {
        // A newer file is not advertised until the author updates the page.
        var release={name:"Item Utilities",version:"1.8.2",files:(cast [
            {version:"1.8.2",categoryId:7},
            {version:"1.8.3",categoryId:1,changelogText:["Not advertised yet"]}
        ]:Array<Dynamic>)};
        eq(NexusClient.hasDownload(release),false);
        eq(NexusClient.changelog(release),"");
        release.files.push({version:"1.8.2",categoryId:1,changelogText:["Stable changes"]});
        eq(NexusClient.hasDownload(release),true);
        eq(UpdateModel.compare(release.version,"1.8.2"),0);
        eq(NexusClient.changelog(release),"Stable changes");
        release.files.push({version:"2.0.0-beta.1",categoryId:1,changelogText:["Beta only"]});
        release.files.push({version:"2.0.0",categoryId:2,changelogText:["Future release"]});
        release.files.push({version:"1.8.2",categoryId:3,changelogText:["Optional file"]});
        eq(NexusClient.changelog(release),"Stable changes");
        release.version="1.8.3";
        eq(NexusClient.hasDownload(release),true);
        eq(NexusClient.changelog(release),"Not advertised yet");
        var dismissed:Map<String,String>=["farever/9"=>"1.8.2"];
        var updates=[u(9,"1.8.2",release.version)];
        eq(UpdateModel.needsReminder(updates,dismissed),true);
        UpdateModel.dismiss(updates,dismissed);
        eq(UpdateModel.needsReminder([u(9,"1.7.0",release.version)],dismissed),false);
        release.version="9.0.0"; // A page-only version is not a download.
        eq(NexusClient.hasDownload(release),false);
        release.files=[{version:"9.0.0",categoryId:7},{version:"unknown",categoryId:1}];
        eq(NexusClient.hasDownload(release),false);
        release.files=[];
        eq(NexusClient.hasDownload(release),false);
        release.files=[{version:"9",categoryId:2,changelogText:(["A","A","",null,42,"B"]:Array<Dynamic>)},
            {version:"9.0.0",categoryId:1,changelogText:["A"]}];
        eq(NexusClient.hasDownload(release),true);
        eq(NexusClient.changelog(release),"A\n\nB");
        release.files=[{version:"9.0.0",categoryId:1}];
        eq(NexusClient.hasDownload(release),true); // Missing notes never block an alert.
        eq(NexusClient.changelog(release),"");
        release.files=[{version:"9.0.0",categoryId:1,changelogText:[for(i in 0...120) 'Change $i']}];
        eq(NexusClient.changelog(release).indexOf("More notes are available")>=0,true);
        eq(NexusClient.changelog(release).indexOf("Change 100")<0,true);
        eq(ChangelogText.plain("<p><b>Fixed</b><br>More &amp; better</p>"),"Fixed\nMore & better");
        eq(ChangelogText.plain("[list][*][b]Fix[/b][/list]"),"- Fix");
        eq(ChangelogText.plain("&#92; &#x41; &quot;test&quot;"),'\\ A "test"');
        eq(ChangelogText.plain("a\x00b\r\nc"),"ab\nc");
        eq(LiteralText.escape(ChangelogText.plain("&#91;skill&#93; $test() &lt;img&gt;")),
            "&#91;skill] &#36;test() &lt;img&gt;");
    }
    static function discoveryRetryTests(root:String):Void {
        var path=root+"/vortex/state.v2", current=File.getContent(path+"/CURRENT");
        var baseline=new InstalledMods();baseline.scan(root+"/game",root+"/vortex");
        File.saveContent(path+"/CURRENT","temporarily unavailable");
        var worker=new UpdateWorker(root+"/game"), delays:Array<Float>=[];
        // Replace real sleeps: two failed scans followed by recovery in the
        // same launch. Both records and deployed binaries are scanned afresh.
        worker.wait=function(seconds) {
            delays.push(seconds);
            if(delays.length==2) File.saveContent(path+"/CURRENT",current);
            return true;
        };
        var inventory=worker.discover(root+"/vortex");
        eq(delays.join(","),"5,15");
        eq(inventory.retryable,false);
        eq(inventory.deployed[0].metadata.version,"1.6.0");
        eq(inventory.diagnostics.join("\n"),baseline.diagnostics.join("\n")); // Recovered errors stay quiet.
        delays=[];
        inventory=worker.discover(root+"/vortex");
        eq(delays.length,0); // Healthy startup never waits.
        File.saveContent(path+"/CURRENT","unsupported manifest");
        worker.wait=function(seconds) {delays.push(seconds);return true;};
        inventory=worker.discover(root+"/vortex");
        eq(delays.join(","),"5,15");
        eq(inventory.retryable,true);
        eq(inventory.deployed[0].metadata,null);
        eq(inventory.diagnostics.length,baseline.diagnostics.length+1);
        eq(inventory.diagnostics[0].indexOf("Unsupported database manifest")>=0,true);
        worker.wait=function(seconds) {worker.stop();return false;};
        fails(function() worker.discover(root+"/vortex"));
        File.saveContent(path+"/CURRENT",current);
        fails(function() worker.discover(root+"/vortex")); // Already cancelled.
    }
    static function installFixture(path:String):Void {
        FileSystem.createDirectory(path);
        var files:Dynamic=haxe.Json.parse(File.getContent("tests/fixtures/vortex-state.json"));
        for(name in Reflect.fields(files)) File.saveBytes(path+"/"+name,
            haxe.zip.Uncompress.run(haxe.crypto.Base64.decode(Reflect.field(files,name))));
    }
    static function fails(fn:Void->Void):Void {
        var failed=false;try fn() catch(_:Dynamic) failed=true;eq(failed,true);
    }
    static function databaseTests(root:String):Void {
        var path=root+"/state.v2",prefix="persistent###mods###farever";
        var values=new LevelDbSnapshot(path,prefix,function() {}).read();
        eq(values.get(prefix+"###current-minimap###attributes###version"),'"1.6.0"');
        eq(values.get(prefix+"###current-minimap###attributes###obsolete"),null);
        eq(values.get("confidential###synthetic-test-only"),null);
        eq(values.get(prefix+"###removed-mod###state"),null);
        eq(haxe.Json.parse(values.get(prefix+"###padding-wal###description")).length,72000);
        var records=VortexState.read(root,function() {});
        eq(records.get("Minimap-15-1-5-1-1789696451").attributes.version,"1.6.0");
        eq(records.exists("removed"),false);eq(records.exists("not-deployed"),true);
        eq(records.exists("current-minimap"),false);
        eq(records.exists("ambiguous"),false);
        eq(values.get("persistent###mods###farever-other###unrelated"),null);
        // CURRENT can switch during compaction. The reader must discard that
        // first view and read the replacement generation from the beginning.
        var baseline=0;
        new LevelDbSnapshot(path,prefix,function() baseline++).read();
        var current=File.getContent(path+"/CURRENT"),calls=0;
        File.saveBytes(path+"/MANIFEST-999998",File.getBytes(path+"/"+StringTools.trim(current)));
        values=new LevelDbSnapshot(path,prefix,function() {
            calls++;
            if(calls==2) File.saveContent(path+"/CURRENT","MANIFEST-999998\n");
        }).read();
        eq(calls>baseline,true);
        eq(values.get(prefix+"###current-minimap###attributes###version"),'"1.6.0"');
        File.saveContent(path+"/CURRENT",current);FileSystem.deleteFile(path+"/MANIFEST-999998");
        var logs=[for(name in FileSystem.readDirectory(path)) if(StringTools.endsWith(name,".log"))name];
        var log=path+"/"+logs[0],original=File.getBytes(log),corrupt=original.sub(0,original.length);
        corrupt.set(corrupt.length-1,corrupt.get(corrupt.length-1)^1);File.saveBytes(log,corrupt);
        fails(function() new LevelDbSnapshot(path,prefix,function() {}).read());
        File.saveBytes(log,original.sub(0,original.length-1));
        fails(function() new LevelDbSnapshot(path,prefix,function() {}).read());
        File.saveBytes(log,original);
        eq(LevelDbSnapshot.snappy(haxe.io.Bytes.ofHex("0500610101")).toString(),"aaaaa");
        eq(LevelDbSnapshot.snappy(haxe.io.Bytes.ofHex("0500610f01000000")).toString(),"aaaaa");
        fails(function() LevelDbSnapshot.snappy(haxe.io.Bytes.ofHex("0500610102")));
        fails(function() LevelDbSnapshot.snappy(haxe.io.Bytes.ofHex("ffffff7f")));
    }
    static function remove(p:String):Void {
        if(!FileSystem.exists(p))return;
        if(FileSystem.isDirectory(p)){for(n in FileSystem.readDirectory(p))remove(p+"/"+n);FileSystem.deleteDirectory(p);}
        else FileSystem.deleteFile(p);
    }
}
