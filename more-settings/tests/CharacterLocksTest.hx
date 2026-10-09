import moresettings.CharacterLocks;
import moresettings.CharacterLockStore;
import moresettings.CharacterLockHooks;
import moresettings.GameAccess as G;
import hlx.runtime.HlxPrefixResult;
import sys.io.File;
import sys.FileSystem;

@:access(moresettings.CharacterLocks)
@:access(moresettings.CharacterLockHooks)
class CharacterLocksTest {
    static var checks = 0;
    static function eq(a:Dynamic,b:Dynamic,why:String):Void {
        checks++;
        if (a != b) throw why+': expected $b, got $a';
    }
    static function fails(f:Void->Void,why:String):Void {
        var failed = false;
        try f() catch (_:Dynamic) failed = true;
        eq(failed,true,why);
    }
    static function clean(path:String):Void {
        if (!FileSystem.exists(path)) return;
        if (FileSystem.isDirectory(path)) {
            for (child in FileSystem.readDirectory(path)) clean(path+"/"+child);
            FileSystem.deleteDirectory(path);
        } else FileSystem.deleteFile(path);
    }
    static function main():Void {
        var dir = "build/character-lock-test-"+Std.random(1000000000);
        FileSystem.createDirectory(dir);
        try { persistence(dir); controls(dir); } catch (e:Dynamic) { clean(dir); throw e; }
        clean(dir);
        Sys.println('Character locks: $checks checks passed.');
    }
    static function persistence(dir:String):Void {
        var path = dir+"/locks.json", a = "9007199254740993", b = "9007199254740994";
        var store = new CharacterLockStore(path);
        eq(store.locked(a),false,"new character starts unlocked");
        store.set(a,true);
        store = new CharacterLockStore(path);
        eq(store.locked(a),true,"lock survives restart");
        eq(store.locked(b),false,"adjacent 64-bit IDs never merge");
        store.set(b,true); store.set(a,false);
        store = new CharacterLockStore(path);
        eq(store.locked(a),false,"unlock survives restart");
        eq(store.locked(b),true,"unlock preserves other character");
        FileSystem.rename(path,path+".interrupted");
        eq(new CharacterLockStore(path).locked(a),true,"backup recovered after interrupted replacement");
        FileSystem.rename(path+".interrupted",path);
        File.saveContent(path+".tmp","obstacle"); FileSystem.deleteFile(path+".tmp");
        FileSystem.createDirectory(path+".tmp");
        fails(() -> store.set(b,false),"failed save reported");
        eq(store.locked(b),true,"failed unlock keeps protection in memory");
        eq(new CharacterLockStore(path).locked(b),true,"failed unlock keeps saved protection");
        for (id in ["", "0", "-1", "Wink", "1.5"])
            fails(() -> store.set(id,true),"reject unavailable or lossy identity");
        File.saveContent(path,"broken JSON");
        fails(() -> new CharacterLockStore(path).set(a,false),"corrupt file never silently replaced");
        eq(File.getContent(path),"broken JSON","corrupt original preserved");
        #if hl
        var native:hl.I64 = (1:hl.I64) << 53;
        native++;
        eq(CharacterLocks.id({heroID:native}),a,"native I64 stringification retains every bit");
        #end
    }
    static function controls(dir:String):Void {
        CharacterLocks.store = new CharacterLockStore(dir+"/ui.json");
        var screen = G.node(), a:Dynamic = {heroID:"101", header:{name:"Wink"}}, b:Dynamic = {heroID:"102", header:{name:"Wink"}};
        screen.windowHeader = G.node(screen); screen.deleteCharacterButton = G.node(screen);
        screen.currentEnable = true; screen.currentSelected = a;
        var clicks = 0, slotA = G.node(screen), slotB = G.node(screen);
        slotA.heroInfo = a; slotB.heroInfo = b;
        slotA.onClick = () -> { clicks++; screen.currentSelected = a; CharacterLocks.syncDelete(screen); };
        slotB.onClick = () -> { clicks++; screen.currentSelected = b; CharacterLocks.syncDelete(screen); };
        var originalA = slotA.onClick;
        screen.characterBtns = [slotA,slotB];
        CharacterLocks.attach(screen);
        var entry = CharacterLocks.entries.get(screen);
        eq(screen.deleteCharacterButton.enable,true,"unlocked selection deletable");
        entry.button.onClick(); slotA.onClick();
        eq(clicks,0,"lock-mode click does not select/play a character");
        eq(entry.rows[0].badge.visible,true,"locked row has badge");
        eq(entry.rows[1].badge.visible,false,"same-name character stays unlocked");
        eq(screen.deleteCharacterButton.enable,false,"delete disabled while editing");
        entry.button.onClick();
        eq(screen.deleteCharacterButton.enable,false,"selected locked character stays disabled");
        eq(CharacterLockHooks.beforeDelete(screen),Skip,"blocked before confirmation dialog");
        slotB.onClick();
        eq(clicks,1,"ordinary selection works outside lock mode");
        eq(screen.deleteCharacterButton.enable,true,"unlocked character can be deleted");
        eq(CharacterLockHooks.beforeDelete(screen),Continue,"unlocked dialog stays native");
        eq(CharacterLockHooks.beforeRequest(screen,a),Skip,"confirmation protects captured character despite changed selection");
        eq(CharacterLockHooks.beforeRequest(screen,b),Continue,"unlocked request stays native");
        slotA.onClick(); screen.deleteCharacterButton.enable = true;
        G.call("ui.UIElement", "set_enable", screen.deleteCharacterButton, [true]);
        eq(screen.deleteCharacterButton.enable,false,"native enable-all cannot unlock deletion");
        entry.button.onClick(); slotA.onClick(); entry.button.onClick();
        eq(screen.deleteCharacterButton.enable,true,"unmarking restores native deletion");
        eq(entry.rows[0].badge.visible,false,"unmarking removes badge");
        screen.currentEnable = false;
        G.call("ui.UIElement", "set_enable", screen.deleteCharacterButton, [true]);
        eq(screen.deleteCharacterButton.enable,false,"native busy state remains disabled");
        screen.currentEnable = true; screen.currentSelected = null;
        CharacterLocks.syncDelete(screen);
        eq(screen.deleteCharacterButton.enable,false,"empty selection cannot be deleted");
        screen.currentSelected = b; entry.button.onClick(); slotB.onClick();
        var detached = entry.button;
        CharacterLocks.forget(screen);
        eq(slotA.onClick,originalA,"removal restores native callbacks");
        eq(detached.parent,null,"removal detaches button");
        for (row in entry.rows) eq(row.badge.parent,null,"removal detaches badges");
        detached.onClick();
        CharacterLocks.attach(screen);
        entry = CharacterLocks.entries.get(screen);
        eq(entry.editing,false,"lock mode resets when reopening");
        eq(entry.rows[1].badge.visible,true,"saved lock returns when reopening");
        eq(screen.deleteCharacterButton.enable,false,"saved selection remains protected");
        var count = (cast screen.windowHeader.children:Array<Dynamic>).length;
        CharacterLocks.attach(screen);
        eq((cast screen.windowHeader.children:Array<Dynamic>).length,count,"rebuild does not duplicate controls");
        CharacterLocks.forget(screen);
        File.saveContent(dir+"/bad.json","bad");
        CharacterLocks.store = new CharacterLockStore(dir+"/bad.json");
        eq(CharacterLockHooks.beforeRequest(screen,a),Skip,"unreadable storage fails closed");
    }
}
