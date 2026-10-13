import itemutilities.NativePresetRename as Rename;
import itemutilities.InspectAccess as G;

class NativePresetRenameTest {
    static var checks=0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var valid=true, saved="unchanged", saves=0;
        var save=(value:String) -> { saved=value; saves++; };
        Rename.open({},"Preset 3",() -> valid,save);
        var dialog=G.lastDialog, box=dialog.input, input=box.input;
        check(input.text=="Preset 3", "Dialog starts with the clicked preset's current label");
        input.text="12345678901234567890"; input.cursorIndex=20; input.selectionIndex=18; box.onChange();
        check(input.text=="123456789012345" && input.cursorIndex==15 && input.selectionIndex==15,
            "Pasting long names clamps input and cursor/selection to 15");
        input.text="Raid "; box.onChange(); check(input.text=="Raid ", "Spaces remain usable while typing");
        dialog.confirm("  Raid A  "); check(saved=="Raid A" && saves==1, "Confirm cleans and saves once");
        dialog.confirm("Again"); check(saves==1, "Repeated/stale confirmation cannot save twice");
        Rename.open({},saved,() -> valid,save); dialog=G.lastDialog;
        dialog.cancel(); dialog.confirm("Cancelled"); check(saved=="Raid A" && saves==1, "Cancel never writes");
        Rename.open({},saved,() -> valid,save); dialog=G.lastDialog;
        valid=false; dialog.confirm("Wrong character"); check(saves==1, "Character/session change invalidates pending save");
        valid=true;
        Rename.open({},saved,() -> valid,save); dialog=G.lastDialog;
        Rename.invalidate(); dialog.confirm("Old name"); check(saves==1, "Reset cannot resurrect a pending name");
        Rename.open({},saved,() -> valid,save); dialog=G.lastDialog;
        Rename.open({},"New dialog",() -> valid,save); dialog.confirm("Old dialog"); check(saves==1,"Only the latest dialog may save");
        G.lastDialog.confirm("12345678901234567890"); check(saved=="123456789012345" && saves==2,"Confirmation independently enforces the limit");
        Rename.open({},saved,() -> valid,save); G.lastDialog.confirm(" \t ");
        check(saved=="" && saves==3,"Clearing the input restores the default label");
        trace('Native preset rename: $checks checks passed');
    }
}
