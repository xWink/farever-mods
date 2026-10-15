import bettermodsettings.NativeWindowLayout;

class WindowLayoutTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void {
        checks++;
        if (!ok) throw message;
    }
    static function node(name:String):Dynamic {
        var object:Dynamic = {name:name, flowProperties:{isAbsolute:true, paddingTop:70, paddingBottom:10, paddingLeft:5, paddingRight:5}};
        object.dom = {obj:object, styles:{}};
        return object;
    }
    static function order(window:Dynamic):String {
        var children:Array<Dynamic> = window.children;
        return [for (child in children) child.name].join(",");
    }
    static function main():Void {
        var background = node("background"), body = node("body"), header = node("header"), tabs = node("tabs");
        var title = {}, close = {};
        header.headerTitle = title; header.closeBtn = close;
        var window = node("window");
        window.header = header; window.titleWindowContent = body; window.children = [background,body,header];
        window.flowProperties.verticalAlign = "Middle";
        window.flowProperties.offsetY = -330;
        NativeWindowLayout.headerFirst(window);
        check(order(window) == "background,header,body", "Header precedes content even without compatible mods");
        var children:Array<Dynamic> = window.children; children.push(tabs);
        NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "background,header,tabs,body", "Header, tabs, and body have explicit visual order");
        for (_ in 0...3) NativeWindowLayout.headerFirst(window, tabs);
        check(order(window) == "background,header,tabs,body", "Repeated layout cannot move the title back to the bottom");
        check(window.flowProperties.verticalAlign == "Middle" && window.flowProperties.offsetY == -330,
            "Compacting the contents preserves native centered window positioning");
        check(window.verticalAlign == "Top" && !Reflect.hasField(window.dom.styles, "valign"),
            "Only content alignment is overridden; the window cannot be moved above its centered anchor");
        check(header.minWidth == 996 && header.maxWidth == 996 && header.fillWidth == false,
            "Header stops four pixels before the outer edge without stretching back over it");
        check(body.paddingTop == 0, "Content no longer reserves space for overlaid tabs");
        check(tabs.minHeight == 70 && tabs.maxHeight == 70 && tabs.paddingTop == 10 && tabs.paddingBottom == 10,
            "Tab strip fits the 50px buttons with 10px top and bottom spacing");
        check(window.paddingLeft == 0 && window.paddingRight == 0, "Window padding cannot inset the full-width header");
        var options = node("options"); options.parent = body; options.fillHeight = true;
        NativeWindowLayout.compactBody(options);
        check(options.flowProperties.paddingLeft == 5 && options.flowProperties.paddingRight == 5
            && options.fillWidth == false && body.paddingLeft == 0 && body.paddingRight == 0,
            "Body reserves both side borders without double-counting native title-content padding");
        check(NativeWindowLayout.BODY_WIDTH + options.flowProperties.paddingLeft + options.flowProperties.paddingRight
            == NativeWindowLayout.WINDOW_WIDTH, "Body and its side insets fit within the window");
        check(options.paddingTop == 0 && options.flowProperties.paddingTop == 0 && options.fillHeight == false,
            "OptionsContent cannot reintroduce the overlay tab gap");
        check(window.verticalSpacing == 0, "No extra window-level gap separates the tabs and body");
        check(window.layout == "Vertical" && window.reverse == false, "Native flow runs from top to bottom");
        for (child in [header,tabs,body]) {
            check(child.flowProperties.paddingTop == 0 && child.flowProperties.paddingBottom == 0
                && child.flowProperties.paddingLeft == 0 && child.flowProperties.paddingRight == 0,
                "Native overlay margins are removed from the parent flow");
            check(Reflect.field(child.dom.styles, "margin-top") == 0 && child.fillHeight == false,
                "CSS refresh cannot restore overlay gaps or stretch the tabs");
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
