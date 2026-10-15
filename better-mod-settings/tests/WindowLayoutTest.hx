import bettermodsettings.NativeWindowLayout;

class WindowLayoutTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void {
        checks++;
        if (!ok) throw message;
    }
    static function node(name:String):Dynamic return {name:name, dom:{styles:{}}, flowProperties:{isAbsolute:true}};
    static function order(window:Dynamic):String {
        var children:Array<Dynamic> = window.children;
        return [for (child in children) child.name].join(",");
    }
    static function main():Void {
        var background = node("background"), body = node("body"), header = node("header"), tabs = node("tabs");
        var title = {}, close = {};
        header.headerTitle = title; header.closeBtn = close;
        var window:Dynamic = {header:header, titleWindowContent:body, children:[background,body,header], dom:{styles:{}}};
        NativeWindowLayout.headerFirst(window);
        check(order(window) == "background,header,body", "Header precedes content even without compatible mods");
        var children:Array<Dynamic> = window.children; children.push(tabs);
        NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "background,header,tabs,body", "Header, tabs, and body have explicit visual order");
        for (_ in 0...3) NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "background,header,tabs,body", "Repeated layout cannot move the title back to the bottom");
        check(header.minWidth == 990 && header.maxWidth == 990, "Header spans the same inner width as the settings body");
        check(body.paddingTop == 0, "Content no longer reserves space for overlaid tabs");
        check(tabs.minHeight == 70 && tabs.maxHeight == 70 && tabs.paddingTop == 10 && tabs.paddingBottom == 10,
            "Tab strip fits the 50px buttons with 10px top and bottom spacing");
        check(window.verticalSpacing == 0, "No extra window-level gap separates the tabs and body");
        check(window.layout == "Vertical" && window.reverse == false, "Native flow runs from top to bottom");
        for (child in [header,tabs,body]) {
            check(child.flowProperties.isAbsolute == false, "Content participates in normal layout");
            check(Reflect.field(child.dom.styles, "position") == false, "CSS cannot restore overlay positioning");
            check(!Reflect.hasField(child, "x") && !Reflect.hasField(child, "y"), "No hard-coded pixel positioning");
        }
        check(header.headerTitle == title && header.closeBtn == close, "Title and native close button remain together");
        check(background.flowProperties.isAbsolute == true, "Native background layout is preserved");
        var backdrop = node("flow-background"), interactive = node("interactive");
        window.background = backdrop; window.interactive = interactive;
        window.children = [backdrop,interactive,background,body,header,tabs];
        NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "flow-background,interactive,background,header,tabs,body", "Flow internal children do not offset the header order");
        NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "flow-background,interactive,background,header,tabs,body", "Repeated flow reordering preserves internal children");
        Sys.println('Window layout: $checks checks passed.');
    }
}
