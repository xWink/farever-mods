import modconfig.CommonSettings;
import bettermodsettings.CommonSettingControls;
import sys.FileSystem;
import sys.io.File;

class CommonSettingsTest {
    static var checks = 0;
    static function check(ok:Bool, why:String):Void { checks++; if (!ok) throw why; }
    static function main():Void {
        var root = "build/common-settings-test-" + Std.random(0x3fffffff);
        var path = root + "/common/config.json";
        var definitions:Array<Dynamic> = [];
        for (type in ["text", "checkbox", "slider", "dropdown", "keybinding"]) {
            var definition:Dynamic = {type:type, key:type, isCommon:true};
            definitions.push(definition);
            check(CommonSettings.isCommon(definition), "Every value control supports common storage");
        }
        for (definition in [{type:"text"}, {type:"text",isCommon:false}, {type:"text",isCommon:"true"},
            {type:"button",isCommon:true}, {type:"title",isCommon:true}])
            check(!CommonSettings.isCommon(definition), "Common storage is explicit and applies only to values");
        check(Reflect.fields(CommonSettings.read(path)).length == 0 && !FileSystem.exists(root),
            "Reading absent common settings does not create files");
        var first:Dynamic = {text:"private key", checkbox:true, slider:80, dropdown:"private option", keybinding:49, own:5};
        CommonSettings.overlay(first, definitions, CommonSettings.read(path));
        check(Reflect.fields(first).length == 1 && first.own == 5, "Common settings never fall back to mod-local values");
        var values:Array<Dynamic> = ["  secret \u2605  ", true, 3.5, "Option B", {code:49,modifier:0}];
        for (i in 0...definitions.length) CommonSettings.write(definitions[i].key, values[i], path);
        var saved = CommonSettings.read(path);
        for (i in 0...definitions.length)
            check(haxe.Json.stringify(Reflect.field(saved, definitions[i].key)) == haxe.Json.stringify(values[i]),
                "Shared values preserve their exact string, boolean, number or keybinding type");
        var second:Dynamic = {own:8};
        CommonSettings.overlay(first, definitions, saved);
        CommonSettings.overlay(second, definitions, saved);
        check(first.text == second.text && first.own == 5 && second.own == 8, "Two mods share keys while keeping their private values");
        var controls = new CommonSettingControls(), updates = 0;
        var displayedA = "", displayedB = "";
        controls.add(definitions[0], first.text, value -> { check(controls.refreshing, "Programmatic refresh suppresses saving"); displayedA = value; updates++; });
        controls.add(definitions[0], second.text, value -> { displayedB = value; updates++; });
        controls.refresh(saved); check(updates == 0, "Unchanged values do not reset active controls");
        CommonSettings.write("text", "new shared value", path);
        controls.refresh(CommonSettings.read(path));
        check(updates == 2 && displayedA == "new shared value" && displayedB == displayedA,
            "Both tabs refresh when another mod saves the same common key");
        check(CommonSettings.read(path).checkbox == true, "Single-key edits preserve other common settings");
        controls.clear(); controls.refresh({text:"after close"});
        check(updates == 2 && !controls.refreshing, "Closed settings do not retain UI callbacks");
        for (bad in ["[]", "null", "42", "\"text\"", "{broken"]) {
            File.saveContent(path, bad); var failed = false;
            try CommonSettings.write("text", "replacement", path) catch (_:Dynamic) failed = true;
            check(failed && File.getContent(path) == bad, "Malformed common config is not overwritten");
        }
        FileSystem.deleteFile(path); FileSystem.deleteDirectory(root + "/common"); FileSystem.deleteDirectory(root);
        Sys.println('Common settings: $checks checks passed.');
    }
}
