package bettermodsettings;

import haxe.Json;
import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixResult;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class BetterModSettingsMod {
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var activeEscapeMenu:Dynamic;
    static var modSettingsButton:Dynamic;
    static var nativeSettingsWindow:Dynamic;
    static var openingNativeSettingsWindow:Bool = false;
    static var compatibleMods:Array<Dynamic> = [];
    static var pendingSettingsNotifications:Map<String, Bool> = new Map();
    static var capturingKeybind:Dynamic;
    static var nativeOptionLabelStyle:Dynamic;
    static var pendingOptionLabels:Array<Dynamic> = [];
    static var pendingOptionRows:Array<Dynamic> = [];
    static var pendingTabLabels:Array<Dynamic> = [];
    static var labelStyleFramesRemaining:Int = 0;
    static var pendingTabHeaderProperties:Dynamic;
    static var pendingTabViewportProperties:Dynamic;
    static var pendingTabButtons:Array<Dynamic> = [];
    static var pendingTabFallbackWidths:Array<Int> = [];
    static var pendingTabPreviousArrow:Dynamic;
    static var pendingTabNextArrow:Dynamic;
    static var pendingTabPageWidth:Int = 0;
    static var pendingTabSpacing:Int = 0;
    static var tabPaginationFramesRemaining:Int = 0;

    static var propertiesType:hl.Bytes;
    static var componentType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var titleWindowType:hl.Bytes;
    static var baseUIType:hl.Bytes;
    static var flowType:hl.Bytes;
    static var flowAlignType:hl.Bytes;
    static var flowOverflowType:hl.Bytes;
    static var flowPropertiesType:hl.Bytes;
    static var checkBoxType:hl.Bytes;
    static var buttonType:hl.Bytes;
    static var textType:hl.Bytes;
    static var hxdKeyType:hl.Bytes;
    static var arrayObjType:hl.Bytes;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getComponentMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var setMinWidthMember:hlx.runtime.ResolvedMember;
    static var setMinHeightMember:hlx.runtime.ResolvedMember;
    static var setMaxWidthMember:hlx.runtime.ResolvedMember;
    static var setMaxHeightMember:hlx.runtime.ResolvedMember;
    static var setPaddingMember:hlx.runtime.ResolvedMember;
    static var setPaddingLeftMember:hlx.runtime.ResolvedMember;
    static var setPaddingRightMember:hlx.runtime.ResolvedMember;
    static var setVerticalSpacingMember:hlx.runtime.ResolvedMember;
    static var setHorizontalSpacingMember:hlx.runtime.ResolvedMember;
    static var setHorizontalAlignMember:hlx.runtime.ResolvedMember;
    static var setOverflowMember:hlx.runtime.ResolvedMember;
    static var setMultilineMember:hlx.runtime.ResolvedMember;
    static var setFillWidthMember:hlx.runtime.ResolvedMember;
    static var setNeedReflowMember:hlx.runtime.ResolvedMember;
    static var setFlowPropertyAbsoluteMember:hlx.runtime.ResolvedMember;
    static var setSelectedMember:hlx.runtime.ResolvedMember;
    static var setButtonTextMember:hlx.runtime.ResolvedMember;
    static var setTitleTextMember:hlx.runtime.ResolvedMember;
    static var setUiSelectedMember:hlx.runtime.ResolvedMember;
    static var isKeyPressedMember:hlx.runtime.ResolvedMember;
    static var getKeyNameMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var initStyleMember:hlx.runtime.ResolvedMember;
    static var getObjectByNameMember:hlx.runtime.ResolvedMember;
    static var getChildAtMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var getNumChildrenMember:hlx.runtime.ResolvedMember;
    static var addChildMember:hlx.runtime.ResolvedMember;
    static var arrayRemoveMember:hlx.runtime.ResolvedMember;
    static var arrayInsertMember:hlx.runtime.ResolvedMember;
    static var setFontMember:hlx.runtime.ResolvedMember;
    static var setTextColorMember:hlx.runtime.ResolvedMember;
    static var setTextMaxWidthMember:hlx.runtime.ResolvedMember;
    static var setTextLineBreakMember:hlx.runtime.ResolvedMember;
    static var getTextWidthMember:hlx.runtime.ResolvedMember;
    static var getOuterWidthMember:hlx.runtime.ResolvedMember;
    static var getFlowPropertiesMember:hlx.runtime.ResolvedMember;
    static var displayWindowMember:hlx.runtime.ResolvedMember;

    static function main():Void {}

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        capturePressedKey();
        refreshPendingOptionLabelStyles();
        refreshPendingTabPagination();
        flushSettingsNotifications();
    }

    @:hlx.prefix(ui.win.BaseWindow.closeSelfOnOpen)
    static function keepGameMenuOpenWhileConstructingSettings(
        instance:Dynamic,
        openedWindow:Dynamic
    ):HlxPrefixResult<Bool> {
        // TitleWindow auto-displays from inside its constructor. At that point
        // nativeSettingsWindow has not yet been assigned, so guard the brief
        // construction phase and prevent only the active Game Menu from closing.
        return openingNativeSettingsWindow && instance == activeEscapeMenu
            ? SkipWith(false)
            : Continue;
    }

    @:hlx.postfix(ui.win.EscapeMenu.init)
    static function afterEscapeMenuInit(instance:Dynamic, result:Void):Void {
        activeEscapeMenu = instance;
        modSettingsButton = null;

        try {
            if (!resolveUiMembers()) {
                trace("[BetterModSettings] Required UI members were not resolved");
                return;
            }

            var optionsButton:Dynamic = HlxRuntime.resolveField(instance, "optionsBtn");
            var optionsProperties:Dynamic = optionsButton == null
                ? null
                : HlxRuntime.resolveField(optionsButton, "dom");
            if (optionsProperties == null) {
                trace("[BetterModSettings] Options button DOM was not found");
                return;
            }

            var menuListProperties:Dynamic = HlxRuntime.callResolved(
                getParentPropertiesMember,
                [optionsProperties]
            );
            if (menuListProperties == null) {
                trace("[BetterModSettings] Escape menu list DOM was not found");
                return;
            }

            var createdProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                menuListProperties,
                ["Mod Settings"],
                { id: "betterModSettingsButton" }
            ]);
            if (createdProperties == null) {
                trace("[BetterModSettings] Button DOM creation returned null");
                return;
            }

            modSettingsButton = HlxRuntime.resolveField(createdProperties, "obj");
            if (modSettingsButton == null) {
                trace("[BetterModSettings] Created button object was null");
                return;
            }

            placeButtonAfter(
                menuListProperties,
                modSettingsButton,
                optionsButton
            );
            HlxRuntime.callResolved(setOnClickMember, [modSettingsButton, openSettings]);
        } catch (error:Dynamic) {
            modSettingsButton = null;
            trace("[BetterModSettings] Could not add Escape menu button: " + Std.string(error));
        }
    }

    static function placeButtonAfter(
        parentProperties:Dynamic,
        button:Dynamic,
        anchor:Dynamic
    ):Void {
        if (parentProperties == null || button == null || anchor == null)
            return;

        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (h2dObjectType == null)
            return;
        if (getChildIndexMember == null)
            getChildIndexMember = HlxRuntime.resolveMember(
                h2dObjectType,
                "getChildIndex"
            );
        if (arrayObjType == null)
            arrayObjType = HlxRuntime.resolveType("hl.types.ArrayObj");
        if (arrayObjType != null && arrayRemoveMember == null)
            arrayRemoveMember = HlxRuntime.resolveMember(arrayObjType, "remove");
        if (arrayObjType != null && arrayInsertMember == null)
            arrayInsertMember = HlxRuntime.resolveMember(arrayObjType, "insert");
        if (getChildIndexMember == null || arrayRemoveMember == null
            || arrayInsertMember == null)
            return;

        var parent:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
        if (parent == null)
            return;
        var rawAnchorIndex:Dynamic = HlxRuntime.callResolved(
            getChildIndexMember,
            [parent, anchor]
        );
        if (rawAnchorIndex == null)
            return;
        var anchorIndex:Int = cast rawAnchorIndex;
        if (anchorIndex < 0)
            return;

        // addChildAt reparents the live DOMKit button, which invalidates the
        // menu's DOM hierarchy. Reorder only the parent's child array instead:
        // both buttons retain the same parent and DOMKit ownership.
        var children:Dynamic = HlxRuntime.resolveField(parent, "children");
        if (children == null)
            return;
        var removed:Dynamic = HlxRuntime.callResolved(
            arrayRemoveMember,
            [children, button]
        );
        if (removed != true)
            return;
        HlxRuntime.callResolved(
            arrayInsertMember,
            [children, anchorIndex + 1, button]
        );

        if (flowType == null)
            flowType = HlxRuntime.resolveType("h2d.Flow");
        if (flowType != null && setNeedReflowMember == null)
            setNeedReflowMember = HlxRuntime.resolveMember(
                flowType,
                "set_needReflow"
            );
        if (setNeedReflowMember != null)
            HlxRuntime.callResolved(setNeedReflowMember, [parent, true]);
    }

    static function openSettings():Void {
        try {
            if (!resolveUiMembers() || activeEscapeMenu == null)
                return;

            if (titleWindowType == null)
                titleWindowType = HlxRuntime.resolveType("ui.win.TitleWindow");
            if (titleWindowType == null) {
                trace("[BetterModSettings] Native TitleWindow type was not resolved");
                return;
            }

            // TitleWindow auto-displays before its constructor returns. The
            // prefix above must be active during that call so BaseUI keeps the
            // EscapeMenu beside this companion window.
            openingNativeSettingsWindow = true;
            nativeSettingsWindow = HlxRuntime.constructInstanceByName(
                titleWindowType,
                2,
                ["Options", null]
            );
            openingNativeSettingsWindow = false;
            if (nativeSettingsWindow == null) {
                trace("[BetterModSettings] Native Mod Settings window creation returned null");
                return;
            }

            // After construction, keep the same long-term behavior as the
            // native Options window and EscapeMenu. The constructor-time prefix
            // handled the one display pass that occurred before this assignment.
            var windowFlags:Dynamic = HlxRuntime.resolveField(activeEscapeMenu, "windowFlags");
            if (windowFlags != null)
                HlxRuntime.setField(nativeSettingsWindow, "windowFlags", windowFlags);

            var windowProperties:Dynamic = HlxRuntime.resolveField(nativeSettingsWindow, "dom");
            if (windowProperties == null) {
                trace("[BetterModSettings] Native Mod Settings window DOM was not found");
                return;
            }

            applyNativeOptionsWindowComponent(windowProperties);
            sizeNativeSettingsWindow(windowProperties);
            setNativeWindowTitle(windowProperties);
            pendingOptionLabels = [];
            pendingOptionRows = [];
            pendingTabLabels = [];
            labelStyleFramesRemaining = 0;

            discoverCompatibleMods();
            buildSettingsContent(windowProperties);
            displayNativeSettingsWindow();

        } catch (error:Dynamic) {
            openingNativeSettingsWindow = false;
            nativeSettingsWindow = null;
            trace("[BetterModSettings] Could not open native settings window: " + Std.string(error));
        }
    }

    static function applyNativeOptionsWindowComponent(windowProperties:Dynamic):Void {
        try {
            if (componentType == null)
                componentType = HlxRuntime.resolveType("domkit.Component");
            if (componentType != null && getComponentMember == null)
                getComponentMember = HlxRuntime.resolveStaticMember(componentType, "get");
            if (getComponentMember == null)
                return;

            // Native Options is positioned as a companion to EscapeMenu by the
            // options-window component's top-level style. The bare TitleWindow
            // component is centered independently and therefore overlaps it.
            var optionsComponent:Dynamic = HlxRuntime.callResolved(
                getComponentMember,
                ["options-window", null]
            );
            if (optionsComponent != null)
                HlxRuntime.setField(windowProperties, "component", optionsComponent);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not apply native Options window layout: " + Std.string(error));
        }
    }

    static function sizeNativeSettingsWindow(windowProperties:Dynamic):Void {
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [nativeSettingsWindow, 1000]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [nativeSettingsWindow, 1000]);

            applyInlineStyle(windowProperties, "width", 1000);
            applyInlineStyle(windowProperties, "min-width", 1000);
            applyInlineStyle(windowProperties, "max-width", 1000);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size native settings window: " + Std.string(error));
        }
    }

    static function displayNativeSettingsWindow():Void {
        try {
            if (baseUIType == null)
                baseUIType = HlxRuntime.resolveType("ui.BaseUI");
            if (baseUIType == null) {
                trace("[BetterModSettings] Native BaseUI type was not resolved");
                return;
            }
            if (displayWindowMember == null)
                displayWindowMember = HlxRuntime.resolveMember(baseUIType, "displayWindow");
            var baseUI:Dynamic = HlxRuntime.resolveStaticField(baseUIType, "current");
            if (baseUI == null || displayWindowMember == null) {
                trace("[BetterModSettings] Native window manager was not resolved");
                return;
            }

            // Match EscapeMenu's real Options handler: displayWindow(window, null).
            // This registers and positions the window without replacing the menu.
            HlxRuntime.callResolved(displayWindowMember, [
                baseUI,
                nativeSettingsWindow,
                null
            ]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not display native settings window: " + Std.string(error));
        }
    }

    static function setNativeWindowTitle(windowProperties:Dynamic):Void {
        try {
            var windowObject:Dynamic = HlxRuntime.resolveField(windowProperties, "obj");
            if (windowObject == null)
                return;
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            // DOMKit IDs are not h2d.Object names, so getObjectByName("title")
            // cannot find this node. Find the native title by the localized text
            // that TitleWindow just rendered.
            var titleObject:Dynamic = findTextObjectByValue(windowObject, "Options", 6);
            if (titleObject == null)
                return;
            if (textType == null)
                textType = HlxRuntime.resolveType("h2d.Text");
            if (textType != null && setTitleTextMember == null)
                setTitleTextMember = HlxRuntime.resolveMember(textType, "set_text");
            if (setTitleTextMember != null)
                HlxRuntime.callResolved(setTitleTextMember, [titleObject, "Mod Settings"]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not update native window title: " + Std.string(error));
        }
    }

    static function sizeBody(bodyProperties:Dynamic):Void {
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setMinHeightMember == null)
                setMinHeightMember = HlxRuntime.resolveMember(flowType, "set_minHeight");
            if (setMaxHeightMember == null)
                setMaxHeightMember = HlxRuntime.resolveMember(flowType, "set_maxHeight");
            var body:Dynamic = HlxRuntime.resolveField(bodyProperties, "obj");
            if (body == null)
                return;
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [body, 990]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [body, 990]);
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [body, 520]);
            if (setMaxHeightMember != null)
                HlxRuntime.callResolved(setMaxHeightMember, [body, 520]);

            // Flow dimensions are later overwritten by DOMKit's component CSS.
            // Inline styles participate in that same cascade and survive reflow.
            if (propertiesType == null)
                propertiesType = HlxRuntime.resolveType("domkit.Properties");
            if (propertiesType != null && initStyleMember == null)
                initStyleMember = HlxRuntime.resolveMember(propertiesType, "initStyle");
            if (initStyleMember != null) {
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "width", 990]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "min-width", 990]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "max-width", 990]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "height", 520]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "min-height", 520]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "max-height", 520]);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size settings body: " + Std.string(error));
        }
    }

    static function discoverCompatibleMods():Void {
        compatibleMods = [];
        var modsPath = "hlx/mods";
        try {
            if (!FileSystem.exists(modsPath) || !FileSystem.isDirectory(modsPath))
                return;

            for (folder in FileSystem.readDirectory(modsPath)) {
                var folderPath = modsPath + "/" + folder;
                var formatPath = folderPath + "/configFormats.json";
                if (!FileSystem.isDirectory(folderPath)
                    || !FileSystem.exists(formatPath))
                    continue;

                try {
                    var format:Dynamic = Json.parse(File.getContent(formatPath));
                    var configFile = stringField(format, "configFile", "config.json");
                    if (!isSafeConfigFileName(configFile)) {
                        trace("[BetterModSettings] Skipping " + folder + ": invalid configFile");
                        continue;
                    }
                    var settingsPath = folderPath + "/" + configFile;
                    if (!FileSystem.exists(settingsPath))
                        continue;
                    var values:Dynamic = Json.parse(File.getContent(settingsPath));
                    var definitions:Array<Dynamic> = cast Reflect.field(format, "configs");
                    if (definitions == null)
                        continue;
                    compatibleMods.push({
                        id: folder,
                        name: stringField(format, "displayName", folder),
                        settingsPath: settingsPath,
                        definitions: definitions,
                        values: values
                    });
                } catch (error:Dynamic) {
                    trace("[BetterModSettings] Skipping " + folder + ": " + Std.string(error));
                }
            }

            compatibleMods.sort(function(a:Dynamic, b:Dynamic):Int {
                var left = Std.string(Reflect.field(a, "name")).toLowerCase();
                var right = Std.string(Reflect.field(b, "name")).toLowerCase();
                return left < right ? -1 : (left > right ? 1 : 0);
            });
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Mod discovery failed: " + Std.string(error));
        }
    }

    static function buildSettingsContent(windowProperties:Dynamic):Void {
        if (compatibleMods.length == 0) {
            createText(windowProperties, "No compatible mods were found.", "noCompatibleMods");
            return;
        }

        var tabsAttributes:Dynamic = { id: "modTabs" };
        Reflect.setField(tabsAttributes, "class", "tabs");

        // TitleWindow redirects its DOM contentRoot to bg-deco after building
        // its own chrome. Native tabs are created before that redirect, as
        // direct children of the window object. Temporarily reproduce that
        // construction state so this element is styled and laid out as the
        // real Options tabs, then restore the body root for OptionsContent.
        var bodyContentRoot:Dynamic = HlxRuntime.resolveField(
            windowProperties,
            "contentRoot"
        );
        var windowObject:Dynamic = HlxRuntime.resolveField(windowProperties, "obj");
        if (windowObject == null)
            return;
        HlxRuntime.setField(windowProperties, "contentRoot", windowObject);
        var tabs:Dynamic = HlxRuntime.callResolved(createNewMember, [
            "element", windowProperties, [], tabsAttributes
        ]);
        HlxRuntime.setField(windowProperties, "contentRoot", bodyContentRoot);
        if (tabs == null)
            return;
        increaseHorizontalSpacing(tabs, 20);
        prepareTabSizing(tabs);
        var previousPageArrow = createTabPageArrow(
            tabs,
            "ArrowLeft",
            "modTabsPreviousPage"
        );
        var tabViewport:Dynamic = HlxRuntime.callResolved(createNewMember, [
            "flow",
            tabs,
            [],
            { id: "modTabsViewport", layout: "horizontal" }
        ]);
        var tabPageWidth = prepareTabPageViewport(tabs, tabViewport);

        // This must be the native OptionsContent component, not a generic flow
        // carrying the same CSS classes. Its component identity is what activates
        // the game's Options body background and OptionLine typography.
        var bodyProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
            "options-content",
            windowProperties,
            [0],
            { id: "modSettingsBody" }
        ]);
        if (bodyProperties == null)
            bodyProperties = windowProperties;
        sizeBody(bodyProperties);
        var settingsParentProperties = prepareNativeOptionsBody(bodyProperties);

        var panels:Array<Dynamic> = [];
        var tabButtons:Array<Dynamic> = [];
        var tabWidths:Array<Int> = [];
        for (index in 0...compatibleMods.length) {
            var mod:Dynamic = compatibleMods[index];
            var modName = Std.string(Reflect.field(mod, "name"));
            var tab:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                tabs,
                [modName],
                { id: "modTab" + index }
            ]);
            var tabButton:Dynamic = tab == null ? null : HlxRuntime.resolveField(tab, "obj");
            tabButtons.push(tabButton);
            if (tabButton != null) {
                moveObjectToFlow(tabViewport, tabButton);
                prepareSettingControl(tabViewport, tab, false);
                centerFlowContents(tab);
                tabWidths.push(prepareSingleLineTab(tab, modName));
                var selectedIndex = index;
                HlxRuntime.callResolved(setOnClickMember, [tabButton, function():Void {
                    showPanel(panels, tabButtons, selectedIndex);
                }]);
            } else
                tabWidths.push(0);

            var panelAttributes:Dynamic = {
                id: "modPanel" + index,
                layout: "vertical"
            };

            var panelProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "flow", settingsParentProperties, [], panelAttributes
            ]);
            var panel:Dynamic = panelProperties == null
                ? null
                : HlxRuntime.resolveField(panelProperties, "obj");
            panels.push(panel);
            if (panelProperties != null) {
                // The native Options container already supplies the body
                // background, viewport size, and content insets. Keep each
                // switchable mod panel transparent and add only row spacing.
                styleFlow(panelProperties, 0, 24, 0);
                setPersistentPanelLayout(panelProperties, 0, 0, 24);
                buildModSettings(panelProperties, mod);
            }
        }

        var nextPageArrow = createTabPageArrow(
            tabs,
            "ArrowRight",
            "modTabsNextPage"
        );
        configureTabPagination(
            tabs,
            tabViewport,
            tabButtons,
            tabWidths,
            previousPageArrow,
            nextPageArrow,
            tabPageWidth
        );
        showPanel(panels, tabButtons, 0);
    }

    static function prepareNativeOptionsBody(bodyProperties:Dynamic):Dynamic {
        try {
            var body:Dynamic = HlxRuntime.resolveField(bodyProperties, "obj");
            if (body == null)
                return bodyProperties;
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && setVisibleMember == null)
                setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");

            // Keep OptionsList and its Block visible: the native stylesheet targets
            // this exact ancestry when styling the body and OptionLine labels.
            var inputList:Dynamic = HlxRuntime.resolveField(body, "inputList");
            if (inputList != null && setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [inputList, false]);

            var optionsList:Dynamic = HlxRuntime.resolveField(body, "optionsList");
            if (optionsList == null)
                return bodyProperties;
            // HashLink keeps OptionsList.lines as ArrayObj, which cannot be
            // safely iterated as Haxe Array<Dynamic>. Keep the generated Block
            // because it is the native Options scroll container, but hide its
            // generated option rows before inserting our mod panels into it.
            var nativeContainer:Dynamic = HlxRuntime.resolveField(optionsList, "container");
            nativeOptionLabelStyle = findFirstTextObject(nativeContainer, 4);
            hideNativeOptionsRows(nativeContainer);

            var applyButton:Dynamic = HlxRuntime.resolveField(optionsList, "applyBtn");
            if (applyButton != null && setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [applyButton, false]);

            var nativeContainerProperties:Dynamic = nativeContainer == null
                ? null
                : HlxRuntime.resolveField(nativeContainer, "dom");
            if (nativeContainerProperties != null) {
                // The native component defaults to the stock Options viewport
                // height, which leaves unused space in our taller fixed window.
                // Match the scroll viewport to the 520 px body height.
                setFixedFlowHeight(nativeContainerProperties, 520);
                return nativeContainerProperties;
            }
            var optionsListProperties:Dynamic = HlxRuntime.resolveField(optionsList, "dom");
            return optionsListProperties == null ? bodyProperties : optionsListProperties;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not prepare native options body: " + Std.string(error));
            return bodyProperties;
        }
    }

    static function hideNativeOptionsRows(container:Dynamic):Void {
        if (container == null)
            return;
        try {
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && getChildAtMember == null)
                getChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "getChildAt");
            if (h2dObjectType != null && getNumChildrenMember == null)
                getNumChildrenMember = HlxRuntime.resolveMember(
                    h2dObjectType,
                    "get_numChildren"
                );
            if (h2dObjectType != null && setVisibleMember == null)
                setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
            if (getChildAtMember == null || getNumChildrenMember == null
                || setVisibleMember == null)
                return;

            // Preserve Flow's own background, input surface, and scrollbar.
            var background:Dynamic = HlxRuntime.resolveField(container, "background");
            var interactive:Dynamic = HlxRuntime.resolveField(container, "interactive");
            var scrollBar:Dynamic = HlxRuntime.resolveField(container, "scrollBar");
            var count:Int = cast HlxRuntime.callResolved(
                getNumChildrenMember,
                [container]
            );
            for (index in 0...count) {
                var child:Dynamic = HlxRuntime.callResolved(
                    getChildAtMember,
                    [container, index]
                );
                if (child == null || child == background || child == interactive
                    || child == scrollBar)
                    continue;
                HlxRuntime.callResolved(setVisibleMember, [child, false]);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not hide native option rows: " + Std.string(error));
        }
    }

    static function showPanel(
        panels:Array<Dynamic>,
        tabButtons:Array<Dynamic>,
        selectedIndex:Int
    ):Void {
        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (h2dObjectType != null && setVisibleMember == null)
            setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
        if (setVisibleMember == null)
            return;
        if (uiElementType != null && setUiSelectedMember == null)
            setUiSelectedMember = HlxRuntime.resolveMember(uiElementType, "set_selected");

        for (index in 0...panels.length) {
            if (panels[index] != null)
                HlxRuntime.callResolved(setVisibleMember, [panels[index], index == selectedIndex]);
            if (index < tabButtons.length && tabButtons[index] != null
                && setUiSelectedMember != null)
                HlxRuntime.callResolved(setUiSelectedMember, [
                    tabButtons[index],
                    index == selectedIndex
                ]);
        }
    }

    static function buildModSettings(parentProperties:Dynamic, mod:Dynamic):Void {
        var definitions:Array<Dynamic> = cast Reflect.field(mod, "definitions");
        for (index in 0...definitions.length) {
            var definition = definitions[index];
            var key = stringField(definition, "key", "");
            var type = stringField(definition, "type", "");
            var label = stringField(definition, "label", key);
            if (key.length == 0)
                continue;

            var settingParent = createOptionRow(parentProperties, label, index);

            if (type == "checkbox") {
                var checked = boolValue(Reflect.field(mod, "values"), key, false);
                var checkProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "check-box",
                    settingParent,
                    [""],
                    { id: "setting" + index }
                ]);
                var check:Dynamic = checkProperties == null
                    ? null
                    : HlxRuntime.resolveField(checkProperties, "obj");
                prepareSettingControl(settingParent, checkProperties, true);
                if (check != null) {
                    setCheckboxValue(check, checked);
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.setField(check, "onValueChange", function(value:Bool):Void {
                        saveSetting(targetMod, targetKey, value);
                    });
                }
            } else if (type == "slider") {
                var min = numberField(definition, "min", 0.0);
                var max = numberField(definition, "max", 100.0);
                var step = numberField(definition, "step", 1.0);
                var value = numberValue(Reflect.field(mod, "values"), key, min);
                var sliderProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "slider",
                    settingParent,
                    [min, max, step, value],
                    { id: "setting" + index }
                ]);
                var slider:Dynamic = sliderProperties == null
                    ? null
                    : HlxRuntime.resolveField(sliderProperties, "obj");
                // The native slider reserves a value column after its right
                // arrow. Shift the complete control by that column's width so
                // the arrow shares the checkbox/keybinding alignment guide.
                // Flow's child offset is visual only and does not affect the
                // fixed window measurement or the slider's internal spacing.
                prepareSettingControl(settingParent, sliderProperties, false, 52);
                if (slider != null) {
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.setField(slider, "onChange", function(newValue:Float):Void {
                        saveSetting(targetMod, targetKey, newValue);
                    });
                }
            } else if (type == "keybinding") {
                var keyCode = intValue(Reflect.field(mod, "values"), key, 0);
                var keyProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "button",
                    settingParent,
                    [keyName(keyCode)],
                    { id: "setting" + index }
                ]);
                var keyButton:Dynamic = keyProperties == null
                    ? null
                    : HlxRuntime.resolveField(keyProperties, "obj");
                prepareSettingControl(settingParent, keyProperties, false);
                if (keyButton != null) {
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.callResolved(setOnClickMember, [keyButton, function():Void {
                        beginKeyCapture(targetMod, targetKey, keyButton);
                    }]);
                }
            }
        }
    }

    static function findFirstTextObject(root:Dynamic, depth:Int):Dynamic {
        if (root == null || depth < 0)
            return null;
        try {
            var font:Dynamic = HlxRuntime.resolveField(root, "font");
            if (font != null)
                return root;
        } catch (_:Dynamic) {}

        try {
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && getChildAtMember == null)
                getChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "getChildAt");
            if (h2dObjectType != null && getNumChildrenMember == null)
                getNumChildrenMember = HlxRuntime.resolveMember(h2dObjectType, "get_numChildren");
            if (getChildAtMember == null || getNumChildrenMember == null)
                return null;
            var count:Int = cast HlxRuntime.callResolved(getNumChildrenMember, [root]);
            for (index in 0...count) {
                var child:Dynamic = HlxRuntime.callResolved(getChildAtMember, [root, index]);
                var found = findFirstTextObject(child, depth - 1);
                if (found != null)
                    return found;
            }
        } catch (_:Dynamic) {}
        return null;
    }

    static function findTextObjectByValue(
        root:Dynamic,
        expected:String,
        depth:Int
    ):Dynamic {
        if (root == null || depth < 0)
            return null;
        try {
            var value:Dynamic = HlxRuntime.resolveField(root, "text");
            if (value != null && Std.string(value) == expected)
                return root;
        } catch (_:Dynamic) {}

        try {
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && getChildAtMember == null)
                getChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "getChildAt");
            if (h2dObjectType != null && getNumChildrenMember == null)
                getNumChildrenMember = HlxRuntime.resolveMember(h2dObjectType, "get_numChildren");
            if (getChildAtMember == null || getNumChildrenMember == null)
                return null;
            var count:Int = cast HlxRuntime.callResolved(getNumChildrenMember, [root]);
            for (index in 0...count) {
                var child:Dynamic = HlxRuntime.callResolved(getChildAtMember, [root, index]);
                var found = findTextObjectByValue(child, expected, depth - 1);
                if (found != null)
                    return found;
            }
        } catch (_:Dynamic) {}
        return null;
    }

    static function applyNativeOptionLabelStyle(line:Dynamic):Void {
        if (line == null || nativeOptionLabelStyle == null)
            return;
        try {
            var label = findFirstTextObject(line, 4);
            if (label == null)
                return;
            pendingOptionLabels.push(label);
            labelStyleFramesRemaining = 4;
            if (textType == null)
                textType = HlxRuntime.resolveType("h2d.Text");
            if (textType == null)
                return;
            if (setFontMember == null)
                setFontMember = HlxRuntime.resolveMember(textType, "set_font");
            if (setTextColorMember == null)
                setTextColorMember = HlxRuntime.resolveMember(textType, "set_textColor");

            var font:Dynamic = HlxRuntime.resolveField(nativeOptionLabelStyle, "font");
            var color:Dynamic = 0x8A5F46;
            if (font != null && setFontMember != null)
                HlxRuntime.callResolved(setFontMember, [label, font]);
            if (color != null && setTextColorMember != null)
                HlxRuntime.callResolved(setTextColorMember, [label, color]);

            for (field in ["scaleX", "scaleY", "letterSpacing", "lineSpacing"]) {
                try {
                    var value:Dynamic = HlxRuntime.resolveField(nativeOptionLabelStyle, field);
                    if (value != null)
                        HlxRuntime.setField(label, field, value);
                } catch (_:Dynamic) {}
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not apply native option label style: " + Std.string(error));
        }
    }

    static function refreshPendingOptionLabelStyles():Void {
        if (labelStyleFramesRemaining <= 0
            || (pendingOptionLabels.length == 0
                && pendingOptionRows.length == 0
                && pendingTabLabels.length == 0))
            return;
        labelStyleFramesRemaining--;
        try {
            for (line in pendingOptionRows)
                centerOptionRowLabelAndSeparator(line);

            if (pendingTabLabels.length > 0) {
                if (textType == null)
                    textType = HlxRuntime.resolveType("h2d.Text");
                if (textType != null && setTextMaxWidthMember == null)
                    setTextMaxWidthMember = HlxRuntime.resolveMember(textType, "set_maxWidth");
                if (textType != null && setTextLineBreakMember == null)
                    setTextLineBreakMember = HlxRuntime.resolveMember(textType, "set_lineBreak");
                for (tabLabel in pendingTabLabels) {
                    if (tabLabel == null)
                        continue;
                    if (setTextMaxWidthMember != null)
                        HlxRuntime.callResolved(setTextMaxWidthMember, [tabLabel, null]);
                    if (setTextLineBreakMember != null)
                        HlxRuntime.callResolved(setTextLineBreakMember, [tabLabel, false]);
                }
            }

            if (nativeOptionLabelStyle != null && pendingOptionLabels.length > 0) {
                if (textType == null)
                    textType = HlxRuntime.resolveType("h2d.Text");
                if (textType == null)
                    return;
                if (setFontMember == null)
                    setFontMember = HlxRuntime.resolveMember(textType, "set_font");
                if (setTextColorMember == null)
                    setTextColorMember = HlxRuntime.resolveMember(textType, "set_textColor");

                var font:Dynamic = HlxRuntime.resolveField(nativeOptionLabelStyle, "font");
                var color:Dynamic = 0x8A5F46;
                for (label in pendingOptionLabels) {
                    if (label == null)
                        continue;
                    if (font != null && setFontMember != null)
                        HlxRuntime.callResolved(setFontMember, [label, font]);
                    if (setTextColorMember != null)
                        HlxRuntime.callResolved(setTextColorMember, [label, color]);
                    for (field in ["scaleX", "scaleY", "letterSpacing", "lineSpacing"]) {
                        try {
                            var value:Dynamic = HlxRuntime.resolveField(nativeOptionLabelStyle, field);
                            if (value != null)
                                HlxRuntime.setField(label, field, value);
                        } catch (_:Dynamic) {}
                    }
                }
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not refresh native option row styles: " + Std.string(error));
            labelStyleFramesRemaining = 0;
        }
        if (labelStyleFramesRemaining <= 0) {
            pendingOptionLabels = [];
            pendingOptionRows = [];
            pendingTabLabels = [];
        }
    }

    static function createOptionRow(
        parentProperties:Dynamic,
        label:String,
        index:Int
    ):Dynamic {
        try {
            var optionInfo:Dynamic = {
                id: "BetterModSettings" + index,
                name: label,
                props: { hideRelease: false }
            };
            var lineProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "option-line",
                parentProperties,
                [optionInfo],
                { id: "settingRow" + index }
            ]);
            if (lineProperties == null)
                return parentProperties;
            setFlowHorizontalSpacing(lineProperties, 12);
            var line:Dynamic = HlxRuntime.resolveField(lineProperties, "obj");
            applyNativeOptionLabelStyle(line);
            pendingOptionRows.push(line);
            centerOptionRowLabelAndSeparator(line);
            disableOptionRowHover(line);
            var container:Dynamic = line == null ? null : HlxRuntime.resolveField(line, "container");
            var containerProperties:Dynamic = container == null
                ? null
                : HlxRuntime.resolveField(container, "dom");
            return containerProperties == null ? parentProperties : containerProperties;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not create native option row: " + Std.string(error));
            return parentProperties;
        }
    }

    static function centerOptionRowLabelAndSeparator(line:Dynamic):Void {
        if (line == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && getFlowPropertiesMember == null)
                getFlowPropertiesMember = HlxRuntime.resolveMember(flowType, "getProperties");
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");
            if (getFlowPropertiesMember == null || flowAlignType == null)
                return;

            var middle:Dynamic = HlxRuntime.constructEnum(flowAlignType, "Middle", []);
            if (middle == null)
                return;
            var container:Dynamic = HlxRuntime.resolveField(line, "container");
            var interactive:Dynamic = HlxRuntime.resolveField(line, "interactive");

            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && getChildAtMember == null)
                getChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "getChildAt");
            if (h2dObjectType != null && getNumChildrenMember == null)
                getNumChildrenMember = HlxRuntime.resolveMember(h2dObjectType, "get_numChildren");
            if (getChildAtMember == null || getNumChildrenMember == null)
                return;

            var count:Int = cast HlxRuntime.callResolved(getNumChildrenMember, [line]);
            for (index in 0...count) {
                var child:Dynamic = HlxRuntime.callResolved(getChildAtMember, [line, index]);
                if (child == null || child == container || child == interactive)
                    continue;
                var childProperties:Dynamic = HlxRuntime.callResolved(
                    getFlowPropertiesMember,
                    [line, child]
                );
                if (childProperties != null)
                    HlxRuntime.setField(childProperties, "verticalAlign", middle);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not align native option row: " + Std.string(error));
        }
    }

    static function disableOptionRowHover(line:Dynamic):Void {
        if (line == null)
            return;
        try {
            // OptionLine installs a full-row Interactive for tooltips and hover
            // styling. Our generated rows have neither, and its hover style
            // overwrites the copied native label scale. Hide only that overlay;
            // the controls inside the row remain independently interactive.
            var interactive:Dynamic = HlxRuntime.resolveField(line, "interactive");
            if (interactive == null)
                return;
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && setVisibleMember == null)
                setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
            if (setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [interactive, false]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not disable option row hover: " + Std.string(error));
        }
    }

    static function beginKeyCapture(mod:Dynamic, key:String, button:Dynamic):Void {
        capturingKeybind = { mod: mod, key: key, button: button };
        setKeyButtonText(button, "Press a key...");
    }

    static function capturePressedKey():Void {
        if (capturingKeybind == null)
            return;
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType == null)
            return;
        if (isKeyPressedMember == null)
            isKeyPressedMember = HlxRuntime.resolveStaticMember(hxdKeyType, "isPressed");
        if (isKeyPressedMember == null)
            return;

        for (keyCode in 1...512) {
            var pressed:Dynamic = HlxRuntime.callResolved(isKeyPressedMember, [keyCode]);
            if (pressed != true)
                continue;
            var capture = capturingKeybind;
            capturingKeybind = null;
            if (keyCode == 27) {
                var values:Dynamic = Reflect.field(Reflect.field(capture, "mod"), "values");
                setKeyButtonText(
                    Reflect.field(capture, "button"),
                    keyName(intValue(values, Std.string(Reflect.field(capture, "key")), 0))
                );
                return;
            }
            saveSetting(
                Reflect.field(capture, "mod"),
                Std.string(Reflect.field(capture, "key")),
                keyCode
            );
            setKeyButtonText(Reflect.field(capture, "button"), keyName(keyCode));
            return;
        }
    }

    static function setKeyButtonText(button:Dynamic, text:String):Void {
        if (buttonType == null)
            buttonType = HlxRuntime.resolveType("ui.comp.Button");
        if (buttonType != null && setButtonTextMember == null)
            setButtonTextMember = HlxRuntime.resolveMember(buttonType, "setText");
        if (setButtonTextMember != null)
            HlxRuntime.callResolved(setButtonTextMember, [button, text]);
    }

    static function keyName(keyCode:Int):String {
        if (keyCode <= 0)
            return "Not set";
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType != null && getKeyNameMember == null)
            getKeyNameMember = HlxRuntime.resolveStaticMember(hxdKeyType, "getKeyName");
        if (getKeyNameMember != null) {
            var name:Dynamic = HlxRuntime.callResolved(getKeyNameMember, [keyCode]);
            if (name != null && Std.string(name).length > 0)
                return Std.string(name);
        }
        return "Key " + keyCode;
    }

    static function prepareTabSizing(properties:Dynamic):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");
            if (flowType == null)
                return;

            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setMultilineMember == null)
                setMultilineMember = HlxRuntime.resolveMember(flowType, "set_multiline");
            if (setHorizontalAlignMember == null)
                setHorizontalAlignMember = HlxRuntime.resolveMember(
                    flowType,
                    "set_horizontalAlign"
                );

            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [flow, 990]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [flow, 990]);
            if (setMultilineMember != null)
                HlxRuntime.callResolved(setMultilineMember, [flow, false]);

            var left:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Left", []);
            if (left != null && setHorizontalAlignMember != null)
                HlxRuntime.callResolved(setHorizontalAlignMember, [flow, left]);

            setHorizontalPadding(properties, 10);
            applyInlineStyle(properties, "width", 990);
            applyInlineStyle(properties, "min-width", 990);
            applyInlineStyle(properties, "max-width", 990);
            applyInlineStyle(properties, "padding-left", 10);
            applyInlineStyle(properties, "padding-right", 10);
            applyInlineStyle(properties, "multiline", false);
            if (left != null)
                applyInlineStyle(properties, "halign", left);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not prepare tab sizing: " + Std.string(error));
        }
    }

    static function prepareSingleLineTab(
        properties:Dynamic,
        labelText:String
    ):Int {
        if (properties == null)
            return 120;
        try {
            var button:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (button == null)
                return 120;
            var label:Dynamic = findFirstTextObject(button, 4);
            if (textType == null)
                textType = HlxRuntime.resolveType("h2d.Text");
            if (textType != null && setTextMaxWidthMember == null)
                setTextMaxWidthMember = HlxRuntime.resolveMember(textType, "set_maxWidth");
            if (textType != null && setTextLineBreakMember == null)
                setTextLineBreakMember = HlxRuntime.resolveMember(textType, "set_lineBreak");
            if (textType != null && getTextWidthMember == null)
                getTextWidthMember = HlxRuntime.resolveMember(textType, "get_textWidth");
            if (label != null) {
                pendingTabLabels.push(label);
                labelStyleFramesRemaining = 4;
                if (setTextMaxWidthMember != null)
                    HlxRuntime.callResolved(setTextMaxWidthMember, [label, null]);
                if (setTextLineBreakMember != null)
                    HlxRuntime.callResolved(setTextLineBreakMember, [label, false]);
            }

            var measuredWidth:Float = 0.0;
            if (label != null && getTextWidthMember != null) {
                var measured:Dynamic = HlxRuntime.callResolved(getTextWidthMember, [label]);
                if (measured != null)
                    measuredWidth = cast measured;
            }
            var rawTextWidth:Float = labelText.length * 7;
            if (rawTextWidth > measuredWidth)
                measuredWidth = rawTextWidth;
            var width = Std.int(Math.ceil(measuredWidth)) + 40;
            if (width < 120)
                width = 120;

            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && setFillWidthMember == null)
                setFillWidthMember = HlxRuntime.resolveMember(flowType, "set_fillWidth");
            if (flowType != null && setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (flowType != null && setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setFillWidthMember != null)
                HlxRuntime.callResolved(setFillWidthMember, [button, false]);
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [button, width]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [button, width]);

            applyInlineStyle(properties, "fill-width", false);
            applyInlineStyle(properties, "width", width);
            applyInlineStyle(properties, "min-width", width);
            applyInlineStyle(properties, "max-width", width);
            return width;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size tab: " + Std.string(error));
            return 120;
        }
    }

    static function createTabPageArrow(
        parentProperties:Dynamic,
        iconName:String,
        id:String
    ):Dynamic {
        if (parentProperties == null)
            return null;
        try {
            var arrowProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button-icon",
                parentProperties,
                [iconName],
                { id: id }
            ]);
            if (arrowProperties == null)
                return null;
            prepareSettingControl(parentProperties, arrowProperties, false);
            centerFlowContents(arrowProperties);
            setFixedFlowWidth(arrowProperties, 32);
            return arrowProperties;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not create tab page arrow: " + Std.string(error));
            return null;
        }
    }

    static function prepareTabPageViewport(
        parentProperties:Dynamic,
        viewportProperties:Dynamic
    ):Int {
        if (parentProperties == null || viewportProperties == null)
            return 0;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");
            if (flowOverflowType == null)
                flowOverflowType = HlxRuntime.resolveType("h2d.FlowOverflow");
            if (flowType == null)
                return 0;

            var parent:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
            var viewport:Dynamic = HlxRuntime.resolveField(viewportProperties, "obj");
            if (parent == null || viewport == null)
                return 0;

            // The outer row only separates each arrow from the tab viewport.
            // Tab-to-tab spacing is controlled independently inside the viewport.
            var arrowGap = 10;
            var tabGap = 20;
            setFlowHorizontalSpacing(parentProperties, arrowGap);
            var viewportWidth = 970 - 64 - arrowGap * 2;
            if (viewportWidth < 120)
                viewportWidth = 120;

            setFixedFlowWidth(viewportProperties, viewportWidth);
            setFixedFlowHeight(viewportProperties, 50);
            setFlowHorizontalSpacing(viewportProperties, tabGap);
            prepareSettingControl(parentProperties, viewportProperties, false);

            if (setMultilineMember == null)
                setMultilineMember = HlxRuntime.resolveMember(flowType, "set_multiline");
            if (setOverflowMember == null)
                setOverflowMember = HlxRuntime.resolveMember(flowType, "set_overflow");
            if (setHorizontalAlignMember == null)
                setHorizontalAlignMember = HlxRuntime.resolveMember(
                    flowType,
                    "set_horizontalAlign"
                );

            if (setMultilineMember != null)
                HlxRuntime.callResolved(setMultilineMember, [viewport, false]);
            var hidden:Dynamic = flowOverflowType == null
                ? null
                : HlxRuntime.constructEnum(flowOverflowType, "Hidden", []);
            if (hidden != null && setOverflowMember != null)
                HlxRuntime.callResolved(setOverflowMember, [viewport, hidden]);
            var left:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Left", []);
            if (left != null && setHorizontalAlignMember != null)
                HlxRuntime.callResolved(setHorizontalAlignMember, [viewport, left]);

            applyInlineStyle(viewportProperties, "multiline", false);
            if (hidden != null)
                applyInlineStyle(viewportProperties, "overflow", hidden);
            if (left != null)
                applyInlineStyle(viewportProperties, "halign", left);
            return viewportWidth;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not prepare tab viewport: " + Std.string(error));
            return 0;
        }
    }

    static function moveObjectToFlow(
        parentProperties:Dynamic,
        child:Dynamic
    ):Void {
        if (parentProperties == null || child == null)
            return;
        try {
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && addChildMember == null)
                addChildMember = HlxRuntime.resolveMember(h2dObjectType, "addChild");
            var parent:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
            if (parent != null && addChildMember != null)
                HlxRuntime.callResolved(addChildMember, [parent, child]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not move tab into its viewport: " + Std.string(error));
        }
    }

    static function setFixedFlowWidth(properties:Dynamic, width:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setFillWidthMember == null)
                setFillWidthMember = HlxRuntime.resolveMember(flowType, "set_fillWidth");
            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");

            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setFillWidthMember != null)
                HlxRuntime.callResolved(setFillWidthMember, [flow, false]);
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [flow, width]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [flow, width]);

            applyInlineStyle(properties, "fill-width", false);
            applyInlineStyle(properties, "width", width);
            applyInlineStyle(properties, "min-width", width);
            applyInlineStyle(properties, "max-width", width);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not set fixed tab element width: " + Std.string(error));
        }
    }

    static function setFixedFlowHeight(properties:Dynamic, height:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinHeightMember == null)
                setMinHeightMember = HlxRuntime.resolveMember(flowType, "set_minHeight");
            if (setMaxHeightMember == null)
                setMaxHeightMember = HlxRuntime.resolveMember(flowType, "set_maxHeight");

            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [flow, height]);
            if (setMaxHeightMember != null)
                HlxRuntime.callResolved(setMaxHeightMember, [flow, height]);

            applyInlineStyle(properties, "height", height);
            applyInlineStyle(properties, "min-height", height);
            applyInlineStyle(properties, "max-height", height);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not set fixed tab viewport height: " + Std.string(error));
        }
    }

    static function buildTabPages(
        tabWidths:Array<Int>,
        spacing:Int,
        availableWidth:Int
    ):Array<Array<Int>> {
        var pages:Array<Array<Int>> = [];
        var page:Array<Int> = [];
        var pageTabsWidth = 0;

        for (index in 0...tabWidths.length) {
            var width = tabWidths[index];
            if (width <= 0)
                continue;

            var candidateWidth = pageTabsWidth + width;
            if (page.length > 0)
                candidateWidth += spacing * page.length;
            if (page.length > 0 && candidateWidth > availableWidth) {
                pages.push(page);
                page = [];
                pageTabsWidth = 0;
            }

            page.push(index);
            pageTabsWidth += width;
        }

        if (page.length > 0)
            pages.push(page);
        return pages;
    }

    static function showTabPage(
        headerProperties:Dynamic,
        viewportProperties:Dynamic,
        tabButtons:Array<Dynamic>,
        tabWidths:Array<Int>,
        pages:Array<Array<Int>>,
        pageIndex:Int
    ):Void {
        if (pageIndex < 0 || pageIndex >= pages.length)
            return;
        try {
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && setVisibleMember == null)
                setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
            if (setVisibleMember == null)
                return;

            // Native tab styling is applied after construction and otherwise
            // restores centered distribution. Reassert the fixed navigation
            // geometry whenever a page is shown.
            setFlowHorizontalSpacing(headerProperties, 10);
            setFlowHorizontalSpacing(viewportProperties, 20);
            setFixedFlowWidth(viewportProperties, 886);
            setFixedFlowHeight(viewportProperties, 50);
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");
            if (flowType != null && setHorizontalAlignMember == null)
                setHorizontalAlignMember = HlxRuntime.resolveMember(
                    flowType,
                    "set_horizontalAlign"
                );
            var viewport:Dynamic = HlxRuntime.resolveField(
                viewportProperties,
                "obj"
            );
            var left:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Left", []);
            var middle:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Middle", []);
            if (viewport != null && left != null
                && setHorizontalAlignMember != null)
                HlxRuntime.callResolved(setHorizontalAlignMember, [
                    viewport,
                    left
                ]);
            if (left != null)
                applyInlineStyle(viewportProperties, "halign", left);

            if (flowPropertiesType == null)
                flowPropertiesType = HlxRuntime.resolveType("h2d.FlowProperties");
            if (flowPropertiesType != null
                && setFlowPropertyAbsoluteMember == null)
                setFlowPropertyAbsoluteMember = HlxRuntime.resolveMember(
                    flowPropertiesType,
                    "set_isAbsolute"
                );

            var page = pages[pageIndex];
            var tabX = 0;
            for (index in 0...tabButtons.length) {
                var button = tabButtons[index];
                if (button != null) {
                    var visible = page.indexOf(index) >= 0;
                    // Native tab styling reapplies Middle to each absolute
                    // child. Account for that centered origin in the offset so
                    // the first tab starts at the viewport's left edge and each
                    // later tab follows it at the requested spacing.
                    if (flowType != null && getFlowPropertiesMember == null)
                        getFlowPropertiesMember = HlxRuntime.resolveMember(
                            flowType,
                            "getProperties"
                        );
                    var tabFlowProperties:Dynamic = getFlowPropertiesMember == null
                        ? null
                        : HlxRuntime.callResolved(
                            getFlowPropertiesMember,
                            [viewport, button]
                        );
                    if (tabFlowProperties != null) {
                        HlxRuntime.setField(
                            tabFlowProperties,
                            "horizontalAlign",
                            middle
                        );
                        HlxRuntime.setField(tabFlowProperties, "paddingLeft", 0);
                        HlxRuntime.setField(tabFlowProperties, "paddingRight", 0);
                        HlxRuntime.setField(
                            tabFlowProperties,
                            "offsetX",
                            visible && index < tabWidths.length
                                ? tabX - Std.int((886 - tabWidths[index]) * 0.5)
                                : 0
                        );
                        HlxRuntime.setField(tabFlowProperties, "lineBreak", false);
                        HlxRuntime.setField(tabFlowProperties, "autoSizeWidth", null);
                        if (setFlowPropertyAbsoluteMember != null)
                            HlxRuntime.callResolved(
                                setFlowPropertyAbsoluteMember,
                                [tabFlowProperties, true]
                            );
                        else
                            HlxRuntime.setField(
                                tabFlowProperties,
                                "isAbsolute",
                                true
                            );
                    }
                    HlxRuntime.callResolved(setVisibleMember, [
                        button,
                        visible
                    ]);
                    if (visible) {
                        if (index < tabWidths.length)
                            tabX += tabWidths[index] + 20;
                    }
                }
            }

            if (flowType != null && setNeedReflowMember == null)
                setNeedReflowMember = HlxRuntime.resolveMember(flowType, "set_needReflow");
            if (viewport != null && setNeedReflowMember != null)
                HlxRuntime.callResolved(setNeedReflowMember, [viewport, true]);
            var header:Dynamic = HlxRuntime.resolveField(
                headerProperties,
                "obj"
            );
            if (header != null && setNeedReflowMember != null)
                HlxRuntime.callResolved(setNeedReflowMember, [header, true]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not show tab page: " + Std.string(error));
        }
    }

    static function configureTabPagination(
        headerProperties:Dynamic,
        viewportProperties:Dynamic,
        tabButtons:Array<Dynamic>,
        fallbackWidths:Array<Int>,
        previousArrowProperties:Dynamic,
        nextArrowProperties:Dynamic,
        availableWidth:Int
    ):Void {
        if (headerProperties == null || viewportProperties == null
            || previousArrowProperties == null
            || nextArrowProperties == null || tabButtons.length == 0
            || availableWidth <= 0)
            return;
        try {
            var viewport:Dynamic = HlxRuntime.resolveField(
                viewportProperties,
                "obj"
            );
            var previousArrow:Dynamic = HlxRuntime.resolveField(
                previousArrowProperties,
                "obj"
            );
            var nextArrow:Dynamic = HlxRuntime.resolveField(
                nextArrowProperties,
                "obj"
            );
            if (viewport == null || previousArrow == null || nextArrow == null)
                return;

            var spacingValue:Dynamic = HlxRuntime.resolveField(
                viewport,
                "horizontalSpacing"
            );
            pendingTabHeaderProperties = headerProperties;
            pendingTabViewportProperties = viewportProperties;
            pendingTabButtons = tabButtons;
            pendingTabFallbackWidths = fallbackWidths;
            pendingTabPreviousArrow = previousArrow;
            pendingTabNextArrow = nextArrow;
            pendingTabPageWidth = availableWidth;
            pendingTabSpacing = spacingValue == null ? 0 : Std.int(spacingValue);
            // Wait for the native stylesheet and the tab label no-wrap pass to
            // finish, then paginate using the buttons' rendered outer widths.
            tabPaginationFramesRemaining = 4;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not queue tab pagination: " + Std.string(error));
        }
    }

    static function refreshPendingTabPagination():Void {
        if (tabPaginationFramesRemaining <= 0)
            return;
        tabPaginationFramesRemaining--;
        if (tabPaginationFramesRemaining > 0)
            return;

        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && getOuterWidthMember == null)
                getOuterWidthMember = HlxRuntime.resolveMember(
                    flowType,
                    "get_outerWidth"
                );

            var measuredWidths:Array<Int> = [];
            for (index in 0...pendingTabButtons.length) {
                var width = index < pendingTabFallbackWidths.length
                    ? pendingTabFallbackWidths[index]
                    : 120;
                var button = pendingTabButtons[index];
                if (button != null && getOuterWidthMember != null) {
                    var measured:Dynamic = HlxRuntime.callResolved(
                        getOuterWidthMember,
                        [button]
                    );
                    if (measured != null && Std.int(measured) > 0)
                        width = Std.int(measured);
                }
                measuredWidths.push(width);
            }

            var pages = buildTabPages(
                measuredWidths,
                pendingTabSpacing,
                pendingTabPageWidth
            );
            if (pages.length == 0)
                return;

            var headerProperties = pendingTabHeaderProperties;
            var viewportProperties = pendingTabViewportProperties;
            var tabButtons = pendingTabButtons;
            var previousArrow = pendingTabPreviousArrow;
            var nextArrow = pendingTabNextArrow;
            var currentPage = 0;

            HlxRuntime.callResolved(setOnClickMember, [
                previousArrow,
                function():Void {
                    currentPage = currentPage <= 0
                        ? pages.length - 1
                        : currentPage - 1;
                    showTabPage(
                        headerProperties,
                        viewportProperties,
                        tabButtons,
                        measuredWidths,
                        pages,
                        currentPage
                    );
                }
            ]);
            HlxRuntime.callResolved(setOnClickMember, [
                nextArrow,
                function():Void {
                    currentPage = currentPage >= pages.length - 1
                        ? 0
                        : currentPage + 1;
                    showTabPage(
                        headerProperties,
                        viewportProperties,
                        tabButtons,
                        measuredWidths,
                        pages,
                        currentPage
                    );
                }
            ]);
            showTabPage(
                headerProperties,
                viewportProperties,
                tabButtons,
                measuredWidths,
                pages,
                currentPage
            );
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not finalize tab pagination: " + Std.string(error));
        }

        pendingTabHeaderProperties = null;
        pendingTabViewportProperties = null;
        pendingTabButtons = [];
        pendingTabFallbackWidths = [];
        pendingTabPreviousArrow = null;
        pendingTabNextArrow = null;
        pendingTabPageWidth = 0;
        pendingTabSpacing = 0;
    }

    static function setFlowHorizontalSpacing(properties:Dynamic, spacing:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && setHorizontalSpacingMember == null)
                setHorizontalSpacingMember = HlxRuntime.resolveMember(flowType, "set_horizontalSpacing");
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow != null && setHorizontalSpacingMember != null)
                HlxRuntime.callResolved(setHorizontalSpacingMember, [flow, spacing]);
            applyInlineStyle(properties, "hspacing", spacing);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not space native option row: " + Std.string(error));
        }
    }

    static function increaseHorizontalSpacing(
        properties:Dynamic,
        additionalSpacing:Int
    ):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && setHorizontalSpacingMember == null)
                setHorizontalSpacingMember = HlxRuntime.resolveMember(
                    flowType,
                    "set_horizontalSpacing"
                );
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null || setHorizontalSpacingMember == null)
                return;
            var currentSpacing:Dynamic = HlxRuntime.resolveField(
                flow,
                "horizontalSpacing"
            );
            var spacing:Int = additionalSpacing;
            if (currentSpacing != null)
                spacing += Std.int(currentSpacing);
            HlxRuntime.callResolved(setHorizontalSpacingMember, [flow, spacing]);
            applyInlineStyle(properties, "hspacing", spacing);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not space native tabs: " + Std.string(error));
        }
    }

    static function centerFlowContents(properties:Dynamic):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && setHorizontalAlignMember == null)
                setHorizontalAlignMember = HlxRuntime.resolveMember(
                    flowType,
                    "set_horizontalAlign"
                );
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            var middle:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Middle", []);
            if (flow == null || middle == null)
                return;
            if (setHorizontalAlignMember != null)
                HlxRuntime.callResolved(setHorizontalAlignMember, [flow, middle]);
            applyInlineStyle(properties, "halign", middle);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not center native tab text: " + Std.string(error));
        }
    }

    static function setHorizontalPadding(properties:Dynamic, padding:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setPaddingLeftMember == null)
                setPaddingLeftMember = HlxRuntime.resolveMember(flowType, "set_paddingLeft");
            if (setPaddingRightMember == null)
                setPaddingRightMember = HlxRuntime.resolveMember(flowType, "set_paddingRight");
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setPaddingLeftMember != null)
                HlxRuntime.callResolved(setPaddingLeftMember, [flow, padding]);
            if (setPaddingRightMember != null)
                HlxRuntime.callResolved(setPaddingRightMember, [flow, padding]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not inset settings panel: " + Std.string(error));
        }
    }

    static function setPersistentPanelLayout(
        properties:Dynamic,
        horizontalPadding:Int,
        topPadding:Int,
        verticalSpacing:Int
    ):Void {
        if (properties == null)
            return;
        try {
            // Inline DOMKit styles survive the native Options stylesheet reflow.
            applyInlineStyle(properties, "padding-left", horizontalPadding);
            applyInlineStyle(properties, "padding-right", horizontalPadding);
            applyInlineStyle(properties, "padding-top", topPadding);
            applyInlineStyle(properties, "vspacing", verticalSpacing);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not persist settings panel layout: " + Std.string(error));
        }
    }

    static function prepareSettingControl(
        parentProperties:Dynamic,
        controlProperties:Dynamic,
        removeBackground:Bool,
        horizontalOffset:Int = 0
    ):Void {
        if (parentProperties == null || controlProperties == null)
            return;
        try {
            var parent:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
            var control:Dynamic = HlxRuntime.resolveField(controlProperties, "obj");
            if (parent == null || control == null)
                return;

            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && getFlowPropertiesMember == null)
                getFlowPropertiesMember = HlxRuntime.resolveMember(flowType, "getProperties");
            if (flowAlignType == null)
                flowAlignType = HlxRuntime.resolveType("h2d.FlowAlign");

            var middle:Dynamic = flowAlignType == null
                ? null
                : HlxRuntime.constructEnum(flowAlignType, "Middle", []);
            if (middle != null) {
                if (getFlowPropertiesMember != null) {
                    var flowProperties:Dynamic = HlxRuntime.callResolved(
                        getFlowPropertiesMember,
                        [parent, control]
                    );
                    if (flowProperties != null) {
                        HlxRuntime.setField(flowProperties, "verticalAlign", middle);
                        if (horizontalOffset != 0)
                            HlxRuntime.setField(flowProperties, "offsetX", horizontalOffset);
                    }
                }
                applyInlineStyle(controlProperties, "valign", middle);
            }
            if (horizontalOffset != 0)
                applyInlineStyle(controlProperties, "offset-x", horizontalOffset);

            if (removeBackground) {
                applyInlineStyle(controlProperties, "background-alpha", 0.0);
                var background:Dynamic = HlxRuntime.resolveField(control, "background");
                if (background != null)
                    HlxRuntime.setField(background, "alpha", 0.0);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not style setting control: " + Std.string(error));
        }
    }

    static function applyInlineStyle(
        properties:Dynamic,
        name:String,
        value:Dynamic
    ):Void {
        if (propertiesType == null)
            propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (propertiesType != null && initStyleMember == null)
            initStyleMember = HlxRuntime.resolveMember(propertiesType, "initStyle");
        if (initStyleMember != null)
            HlxRuntime.callResolved(initStyleMember, [properties, name, value]);
    }

    static function styleFlow(
        properties:Dynamic,
        padding:Int,
        verticalSpacing:Int,
        horizontalSpacing:Int
    ):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setPaddingMember == null)
                setPaddingMember = HlxRuntime.resolveMember(flowType, "set_padding");
            if (setVerticalSpacingMember == null)
                setVerticalSpacingMember = HlxRuntime.resolveMember(flowType, "set_verticalSpacing");
            if (setHorizontalSpacingMember == null)
                setHorizontalSpacingMember = HlxRuntime.resolveMember(flowType, "set_horizontalSpacing");

            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setPaddingMember != null)
                HlxRuntime.callResolved(setPaddingMember, [flow, padding]);
            if (setVerticalSpacingMember != null)
                HlxRuntime.callResolved(setVerticalSpacingMember, [flow, verticalSpacing]);
            if (setHorizontalSpacingMember != null)
                HlxRuntime.callResolved(setHorizontalSpacingMember, [flow, horizontalSpacing]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not style settings flow: " + Std.string(error));
        }
    }

    static function createText(parentProperties:Dynamic, text:String, id:String):Void {
        HlxRuntime.callResolved(createNewMember, [
            "text", parentProperties, [text], { id: id }
        ]);
    }

    static function setCheckboxValue(check:Dynamic, value:Bool):Void {
        if (checkBoxType == null)
            checkBoxType = HlxRuntime.resolveType("ui.comp.CheckBox");
        if (checkBoxType != null && setSelectedMember == null)
            setSelectedMember = HlxRuntime.resolveMember(checkBoxType, "set_selected");
        if (setSelectedMember != null)
            HlxRuntime.callResolved(setSelectedMember, [check, value]);
        else
            HlxRuntime.setField(check, "selected", value);
    }

    static function saveSetting(mod:Dynamic, key:String, value:Dynamic):Void {
        try {
            var settingsPath = Std.string(Reflect.field(mod, "settingsPath"));
            var values:Dynamic = Json.parse(File.getContent(settingsPath));
            Reflect.setField(values, key, value);
            Reflect.setField(mod, "values", values);
            File.saveContent(
                settingsPath,
                Json.stringify(values, null, "  ")
            );
            queueSettingsNotification(mod);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not save " + key + ": " + Std.string(error));
        }
    }

    static function queueSettingsNotification(mod:Dynamic):Void {
        var modId = stringField(mod, "id", "");
        if (modId.length > 0)
            pendingSettingsNotifications.set(modId, true);
    }

    static function flushSettingsNotifications():Void {
        var notifications = pendingSettingsNotifications;
        pendingSettingsNotifications = new Map();

        for (modId in notifications.keys()) {
            try {
                Bus.publish(SETTINGS_CHANGED_TOPIC_PREFIX + modId, null);
            } catch (error:Dynamic) {
                trace("[BetterModSettings] Could not notify " + modId
                    + " of a settings change: " + Std.string(error));
            }
        }
    }

    static function stringField(object:Dynamic, key:String, fallback:String):String {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : Std.string(value);
    }

    static function isSafeConfigFileName(fileName:String):Bool {
        return fileName.length > 0
            && fileName.indexOf("/") < 0
            && fileName.indexOf("\\") < 0
            && fileName.indexOf("..") < 0;
    }

    static function numberField(object:Dynamic, key:String, fallback:Float):Float {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
    }

    static function boolValue(object:Dynamic, key:String, fallback:Bool):Bool {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        return Reflect.field(object, key) == true;
    }

    static function intValue(object:Dynamic, key:String, fallback:Int):Int {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
    }

    static function numberValue(object:Dynamic, key:String, fallback:Float):Float {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
    }

    static function resolveUiMembers():Bool {
        if (propertiesType == null)
            propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (uiElementType == null)
            uiElementType = HlxRuntime.resolveType("ui.UIElement");
        if (propertiesType == null || uiElementType == null)
            return false;

        if (createNewMember == null)
            createNewMember = HlxRuntime.resolveStaticMember(propertiesType, "createNew");
        if (getParentPropertiesMember == null)
            getParentPropertiesMember = HlxRuntime.resolveMember(propertiesType, "get_parent");
        if (setOnClickMember == null)
            setOnClickMember = HlxRuntime.resolveMember(uiElementType, "set_onClick");
        return createNewMember != null
            && getParentPropertiesMember != null
            && setOnClickMember != null;
    }
}
