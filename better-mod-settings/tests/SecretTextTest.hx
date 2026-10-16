import bettermodsettings.NativeSecretText;
import bettermodsettings.TextSetting;

class SecretTextTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function click(dom:Dynamic):Void {
        var button = Reflect.field(dom, "obj");
        Reflect.callMethod(button, Reflect.field(button, "onClick"), []);
    }
    static function hasPupil(dom:Dynamic):Bool {
        var commands:Array<Dynamic> = Reflect.field(Reflect.field(Reflect.field(dom, "obj"), "graphic"), "commands");
        return commands.indexOf("drawCircle") >= 0;
    }
    static function main():Void {
        var changes = 0;
        var selection = {start:1, length:3};
        var undo = ["previous secret"];
        var redo = ["next secret"];
        var onChange = function():Void changes++;
        var onFocus = function(_:Dynamic):Void {};
        var input:Dynamic = {text:"aB 123", cursorIndex:4, selectionRange:selection,
            undo:undo, redo:redo, onChange:onChange, onFocus:onFocus};
        var other:Dynamic = {text:"second"};
        var parent:Dynamic = {obj:{}, styles:{}, children:[]};
        var textbox:Dynamic = {obj:{}, styles:{}};
        NativeSecretText.prepareRow(parent, textbox);
        NativeSecretText.hideAll(true);
        var eye = NativeSecretText.attach(parent, input, "secret1");
        var otherEye = NativeSecretText.attach(parent, other, "secret2");
        eq(parent.obj.layout, "Horizontal", "Textbox and eye share a horizontal row");
        eq(parent.obj.multiline, false, "Eye cannot wrap below the textbox");
        eq(parent.obj.maxWidth, 280, "Control group reserves enough space before the scrollbar");
        eq(textbox.obj.maxWidth + parent.obj.horizontalSpacing + eye.obj.maxWidth + parent.obj.paddingRight,
            parent.obj.maxWidth, "Textbox, gap, eye, and right clearance fit inside the row");
        eq(eye.obj.minWidth, 34, "Eye has a nonzero native hit target before style reflow");
        eq(eye.obj.minHeight, 34, "Eye hit target has full button height");
        eq(eye.obj.flowProperties.verticalAlign, "Middle", "Eye is centered beside the textbox");
        eq(textbox.obj.flowProperties.verticalAlign, "Middle", "Textbox uses the same vertical alignment");
        eq(eye.obj.flowProperties.isAbsolute, false, "Eye stays inside the measured row");
        eq(NativeSecretText.display(input, input.text), "******", "New settings mask secrets");
        eq(hasPupil(eye), false, "New eye is closed");
        eq((cast eye.obj.graphic.commands:Array<String>).filter(x -> x == "moveTo").length, 4, "Closed eye has three lashes");
        eye.obj.btnText = {textColor:0x70574B};
        NativeSecretText.refreshColors();
        eq(eye.obj.graphic.lineColor, eye.obj.btnText.textColor, "Eye matches native button text");
        eq(eye.obj.textTip, null, "Closed eye has no tooltip");
        eq(eye.parent, parent, "Eye stays in the textbox row");
        eq(Reflect.field(eye.styles, "fill-width"), false, "Eye does not stretch the row");
        eq(NativeSecretText.display({}, "ordinary text"), "ordinary text", "Unregistered textboxes stay unchanged");

        click(eye);
        eq(NativeSecretText.display(input, input.text), "aB 123", "First click reveals the original value");
        eq(hasPupil(eye), true, "Revealed eye has its pupil");
        eq((cast eye.obj.graphic.commands:Array<String>).filter(x -> x == "moveTo").length, 4, "Open eye retains the three lashes");
        eye.obj.btnText.textColor = 0x896E60;
        NativeSecretText.refreshColors();
        eq(eye.obj.graphic.lineColor, 0x896E60, "Eye tracks native hover colour");
        eq(hasPupil(eye), true, "Theme refresh preserves reveal state");
        eq(eye.obj.textTip, null, "Open eye has no tooltip");
        eq(NativeSecretText.display(other, other.text), "******", "Revealing one secret leaves others hidden");
        click(eye);
        eq(NativeSecretText.display(input, input.text), "******", "Second click hides the value again");
        eq(hasPupil(eye), false, "Second click closes the eye");

        for (value in ["", "new value", "café 日本語 🎨", "ab\r\ncd", "***"]) {
            input.text = value;
            Reflect.callMethod(input, input.onChange, []);
            eq(NativeSecretText.display(input, value), TextSetting.mask(value), "Edits remain masked");
            click(eye);
            eq(NativeSecretText.display(input, value), value, "Reveal uses the latest edit, including empty text");
            click(eye);
            eq(input.text, value, "Masking never overwrites the editable value");
        }
        eq(changes, 5, "Only edits trigger onChange, never eye clicks");
        eq(input.cursorIndex, 4, "Toggling preserves the cursor index");
        eq(input.selectionRange, selection, "Toggling preserves selection");
        eq(input.undo, undo, "Toggling preserves undo history");
        eq(input.redo, redo, "Toggling preserves redo history");
        eq(input.onChange, onChange, "Native editing callback is retained");
        eq(input.onFocus, onFocus, "Native focus callback is retained");

        click(eye);
        click(otherEye);
        NativeSecretText.hideAll();
        eq(hasPupil(eye), false, "Leaving a tab closes its eye");
        eq(hasPupil(otherEye), false, "Tab changes close every eye");
        eq(NativeSecretText.display(other, other.text), "******", "Returning to a tab is masked");
        click(eye);
        NativeSecretText.hideAll(true);
        var reopened = NativeSecretText.attach(parent, input, "reopened");
        eq(hasPupil(reopened), false, "Reopening never inherits reveal state");
        eq(NativeSecretText.display(input, "reopened"), "********", "Reopened input is masked");
        click(eye);
        eq(hasPupil(reopened), false, "Stale window callback cannot reveal a new field");
        click(reopened);
        eq(NativeSecretText.display(input, "reopened"), "reopened", "New window eye still toggles normally");
        NativeSecretText.hideAll(true);
        Sys.println('Secret controls: $checks checks passed.');
    }
}
