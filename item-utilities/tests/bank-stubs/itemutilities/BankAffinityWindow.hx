package itemutilities;
class BankAffinityWindow {
    public static var created = 0;
    public static var disposed = 0;
    public static var lastDialog:Dynamic;
    public function new(bank:Dynamic, dialog:Dynamic, state:BankAffinityState, changed:Void->Void) {
        created++; lastDialog = dialog;
    }
    public function update():Bool return true;
    public function dispose():Void disposed++;
}
