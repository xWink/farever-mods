package itemutilities;

import haxe.Json;
import haxe.ds.ObjectMap;
import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiComboFlags;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;
import itemutilities.CharacterResetStore.CharacterResetKind;

typedef ItemUtilitiesConfig = {
    var enabled:Bool;
    var holdInteractToQuickLoot:Bool;
    var showDepositMaterials:Bool;
    var showLockVisuals:Bool;
    var sortingIgnoresLockedItems:Bool;
    var instantMoteConversion:Bool;
    var preset1Hotkey:Int;
    var preset2Hotkey:Int;
    var preset3Hotkey:Int;
    var preset4Hotkey:Int;
    var preset5Hotkey:Int;
    var appearancePreset1Hotkey:Int;
    var appearancePreset2Hotkey:Int;
    var appearancePreset3Hotkey:Int;
    var appearancePreset4Hotkey:Int;
    var appearancePreset5Hotkey:Int;
    var appearancePresets:Array<Dynamic>;
    var selectedAppearancePresets:Array<Dynamic>;
    var skillPreset1Hotkey:Int;
    var skillPreset2Hotkey:Int;
    var skillPreset3Hotkey:Int;
    var skillPreset4Hotkey:Int;
    var skillPreset5Hotkey:Int;
    var skillPresets:Array<Dynamic>;
    var selectedSkillPresets:Array<Dynamic>;
    var talentPreset1Hotkey:Int;
    var talentPreset2Hotkey:Int;
    var talentPreset3Hotkey:Int;
    var talentPreset4Hotkey:Int;
    var talentPreset5Hotkey:Int;
    var talentPresets:Array<Dynamic>;
    var selectedTalentPresets:Array<Dynamic>;
    // Retain the original preset storage keys for existing configurations.
    // Each preset's `weapons` array now also stores armor and accessories.
    var weaponPresets:Array<Dynamic>;
    var selectedWeaponPresets:Array<Dynamic>;
    var lockedItems:Array<Dynamic>;
}

private enum abstract PresetKind(Int) {
    var Equipment = 0;
    var Talent = 1;
    var Skill = 2;
    var Appearance = 3;
}

private typedef TrackedInventorySlot = {
    var inventory:Dynamic;
    var index:Int;
    var slot:Dynamic;
    var listIndex:Int;
    var overlayId:String;
}

@:build(hlx.runtime.Mod.build())
class ItemUtilitiesMod {
    @:hlx.config
    static var config:ItemUtilitiesConfig = {
        enabled: true,
        holdInteractToQuickLoot: false,
        showDepositMaterials: true,
        showLockVisuals: true,
        sortingIgnoresLockedItems: false,
        instantMoteConversion: false,
        preset1Hotkey: 0,
        preset2Hotkey: 0,
        preset3Hotkey: 0,
        preset4Hotkey: 0,
        preset5Hotkey: 0,
        appearancePreset1Hotkey: 0,
        appearancePreset2Hotkey: 0,
        appearancePreset3Hotkey: 0,
        appearancePreset4Hotkey: 0,
        appearancePreset5Hotkey: 0,
        appearancePresets: [],
        selectedAppearancePresets: [],
        skillPreset1Hotkey: 0,
        skillPreset2Hotkey: 0,
        skillPreset3Hotkey: 0,
        skillPreset4Hotkey: 0,
        skillPreset5Hotkey: 0,
        skillPresets: [],
        selectedSkillPresets: [],
        talentPreset1Hotkey: 0,
        talentPreset2Hotkey: 0,
        talentPreset3Hotkey: 0,
        talentPreset4Hotkey: 0,
        talentPreset5Hotkey: 0,
        talentPresets: [],
        selectedTalentPresets: [],
        weaponPresets: [],
        selectedWeaponPresets: [],
        lockedItems: []
    };
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";
    static inline var CRAFTING_COMPONENT_TYPE = "CraftingComponent";

    static var enabled = new BoolRef(true);
    static var showDepositMaterials = new BoolRef(true);
    static var showLockVisuals = new BoolRef(true);
    static var sortingIgnoresLockedItems = new BoolRef(false);
    static var presetHotkeyKeys:Array<Int> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var skillPresetHotkeyKeys:Array<Int> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var selectedSkillPreset:Int = 0;
    static var selectedSkillPresetCharacterId:String;
    static var skillPresetTransfer = new SkillPresetTransfer();
    static var skillPresetHero:Dynamic;
    static var skillPresetHost:Dynamic;
    static var skillPresetSpecialization:Dynamic;
    static var skillPresetCharacterId:String;
    static var nextSkillPresetCheck:Float = 0;
    static var skillPresetStatus:String = "";
    static var appearancePresetHotkeyKeys:Array<Int> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var presetDropdown = new PresetDropdownState();
    static var selectedAppearancePreset:Int = 0;
    static var selectedAppearancePresetCharacterId:String;
    static var appearancePresetTransfer = new AppearancePresetTransfer();
    static var appearancePresetHero:Dynamic;
    static var appearancePresetHost:Dynamic;
    static var appearancePresetLoadout:Dynamic;
    static var appearancePresetCharacterId:String;
    static var nextAppearancePresetCheck:Float = 0;
    static var appearancePresetStatus:String = "";
    static var activeGearAppearance:Dynamic;
    static var talentPresetHotkeyKeys:Array<Int> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var selectedTalentPreset:Int = 0;
    static var selectedTalentPresetCharacterId:String;
    static var talentPresetTransfer = new TalentPresetTransfer();
    static var talentPresetHero:Dynamic;
    static var talentPresetHost:Dynamic;
    static var talentPresetSpecialization:Dynamic;
    static var talentPresetCharacterId:String;
    static var nextTalentPresetCheck:Float = 0;
    static var talentPresetStatus:String = "";
    static var activeTalentView:Dynamic;
    static var activeTalentRoot:Dynamic;

    static var quickLootState = new QuickLootState();
    static var quickLootInputDownMember:hlx.runtime.ResolvedMember;
    static var quickLootErrorLogged:Bool = false;

    static var activeBankWindow:Dynamic;
    static var activeScrapWindow:Dynamic;
    static var activeInventoryUI:Dynamic;
    static var activeCharacterUI:Dynamic;
    static var activeInventoryWindow:Dynamic;
    static var openInventoryWindows:Array<{ window:Dynamic, inventory:Dynamic }> = [];
    static var depositButton:Dynamic;
    static var sourceInventory:Dynamic;
    static var bankInventory:Dynamic;
    static var scrapInventory:Dynamic;
    static var scrapInventoryComp:Dynamic;
    static var depositing:Bool = false;
    static var depositMode:Int = 0;
    static var transferIndexes:Array<Int> = [];
    static var transferPosition:Int = 0;
    static var status:String = "";
    static var movedStacks:Int = 0;
    static var recyclerDepositing:Bool = false;
    static var recyclerTransferIndexes:Array<Int> = [];
    static var recyclerTransferPosition:Int = 0;
    static var lockedSortActive:Bool = false;
    static var lockedSortInventory:Dynamic;
    static var lockedSortDesiredItems:Array<Dynamic> = [];
    static var lockedSortTargetIndexes:Array<Int> = [];
    static var lockedSortFixedIndexes:Array<Bool> = [];
    static var lockedSortPosition:Int = 0;
    static var lockedSortCallback:Dynamic;
    static var lockedSortSucceeded:Bool = true;
    static var lockedSortWaiting:Bool = false;
    static var lockedSortPendingMoves:Array<Dynamic> = [];

    static var itemType:hl.Bytes;
    static var inventoryType:hl.Bytes;
    static var bankWindowType:hl.Bytes;
    static var scrapWindowType:hl.Bytes;
    static var scrapStationType:hl.Bytes;
    static var arrayObjType:hl.Bytes;
    static var arrayDynType:hl.Bytes;
    static var cursorType:hl.Bytes;
    static var systemType:hl.Bytes;
    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var isTypeMember:hlx.runtime.ResolvedMember;
    static var equalsMember:hlx.runtime.ResolvedMember;
    static var isMaxStackMember:hlx.runtime.ResolvedMember;
    static var getSlotStackSizeMember:hlx.runtime.ResolvedMember;
    static var getNextFreeIndexMember:hlx.runtime.ResolvedMember;
    static var requestTransferMember:hlx.runtime.ResolvedMember;
    static var completeItemMember:hlx.runtime.ResolvedMember;
    static var getMyHeroMember:hlx.runtime.ResolvedMember;
    static var getScrapInventoryMember:hlx.runtime.ResolvedMember;
    static var isScrappableMember:hlx.runtime.ResolvedMember;
    static var arrayGetDynMember:hlx.runtime.ResolvedMember;
    static var arrayDynGetDynMember:hlx.runtime.ResolvedMember;
    static var arrayDynGetLengthMember:hlx.runtime.ResolvedMember;
    static var setSystemCursorFn:Dynamic;
    static var buttonCursor:Dynamic;
    static var cursorResolutionAttempted:Bool = false;
    static var cursorErrorLogged:Bool = false;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var playClickFeedbackMember:hlx.runtime.ResolvedMember;
    static var setTextTipMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var addChildAtMember:hlx.runtime.ResolvedMember;
    static var gameAppType:hl.Bytes;
    static var hxdKeyType:hl.Bytes;
    static var isKeyPressedMember:hlx.runtime.ResolvedMember;
    static var getGameAppFn:Dynamic;
    static var eReasonType:hl.Bytes;
    static var lockedItemReason:Dynamic;

    // Item __uid values are hxbit object identities. Farever clones an item
    // during most transfers, so a lock record follows a disappearing UID to
    // the one newly-created item with the same immutable fingerprint.
    static var inventoryComps:Array<Dynamic> = [];
    static var playerInventoryComp:Dynamic;
    static var visibleSlots:Array<TrackedInventorySlot> = [];
    static var slotsByObject:ObjectMap<Dynamic, TrackedInventorySlot> = new ObjectMap();
    static var nextSlotOverlayId:Int = 0;
    static var lockEditMode:Bool = false;
    static var lockRecords:Array<Dynamic> = [];
    static var fingerprintCache:Map<String, {item:Dynamic, fingerprint:String}> = new Map();
    static var lockState = new ItemLockState();
    static var getIsLoadingMember:hlx.runtime.ResolvedMember;
    static var nextLockReconcileAt:Float = 0;
    static var weaponPresets:Array<Dynamic> = [];
    static var selectedWeaponPresets:Array<Dynamic> = [];
    static var selectedWeaponPreset:Int = 0;
    static var selectedWeaponPresetCharacterId:String;
    static var presetEquipQueue:Array<Dynamic> = [];
    static var presetEquipPosition:Int = 0;
    static var presetInventory:Dynamic;
    static var presetEquipment:Dynamic;
    static var presetEquippedIndexes:Array<Int> = [];
    static var presetTransferActive:Bool = false;
    static var lockErrors:Map<String, Bool> = new Map();
    static var activeTooltip:Dynamic;
    static var activeTooltipShownAt:Float = 0;
    static var activeBaseUI:Dynamic;
    static var windowOccluders:Array<OverlayRect>;
    static inline var INVENTORY_SLOT_SIZE = 48.0;
    static inline var TOOLTIP_BUTTON_DELAY = 0.2;
    static inline var TOOLTIP_OVERLAP_INSET = 4.0;
    static var overlayScaleX:Float = 1;
    static var overlayScaleY:Float = 1;
    static inline var ITEM_FINGERPRINT_VERSION = ItemLockState.FINGERPRINT_VERSION;
    static inline var LOCK_RECONCILE_INTERVAL = 0.2;
    static inline var DEPOSIT_CRAFTING = 0;
    static inline var DEPOSIT_ALL = 1;
    static inline var DEPOSIT_FOOD = 2;
    static inline var DEPOSIT_CONSUMABLE = 3;
    static inline var DEPOSIT_DEMON_ENCHANTMENT = 4;
    static inline var DEPOSIT_MISC = 5;

    static function main():Void {
        if (ConfigMigration.importLegacy())
            config = ModConfig.load(HlxRuntime.moduleName(), config);
        loadConfig();
        saveConfig();
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
        var resetKinds:Array<CharacterResetKind> = [Locks, Equipment, Talent, Skill, Appearance];
        for (kind in resetKinds) {
            var resetKind:CharacterResetKind = kind;
            Bus.subscribe(
                "better-mod-settings/action/" + HlxRuntime.moduleName() + "/" + Std.string(resetKind),
                function(_:Dynamic):Void resetCharacterData(resetKind)
            );
        }
        PlayerInspect.initialize(() -> enabled.get());
        ImGui.register(HlxRuntime.moduleName(), draw);
    }

    @:hlx.postfix(GameApp.finishedLoading)
    static function restoreLocksAfterLoading(instance:Dynamic, result:Void):Void {
        if (enabled.get()) reconcileItemLocks();
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function prepareQuickLoot(instance:Dynamic, dt:Float, result:Void):Void {
        // PlayerController.update only reaches updateInputs when gameplay
        // input is unblocked. Its next input query is the normal Interact press.
        quickLootState.prepare(instance, enabled.get() && config.holdInteractToQuickLoot);
    }

    @:hlx.postfix(client.PlayerController.update)
    static function finishQuickLoot(instance:Dynamic, dt:Float, result:Void):Void {
        quickLootState.finish(instance);
    }

    @:hlx.postfix(lib.Input.isPressed)
    static function holdInteractForLoot(key:String, result:Bool):Bool {
        var controller = quickLootState.takeInput(key);
        if (controller == null)
            return result;

        // The context was consumed before any nested input/interaction calls.
        // A real press remains untouched, including presses on NPCs and chests.
        if (!enabled.get() || !config.holdInteractToQuickLoot) {
            quickLootState.release(controller);
            return result;
        }
        if (result) {
            quickLootState.recordPress(controller, haxe.Timer.stamp());
            return result;
        }

        try {
            if (quickLootInputDownMember == null) {
                var inputType = HlxRuntime.resolveType("lib.Input");
                if (inputType != null)
                    quickLootInputDownMember = HlxRuntime.resolveStaticMember(inputType, "isDown");
            }
            // The action name retains keyboard/gamepad bindings, input modes,
            // and focus checks. Never synthesize a raw F-key press.
            if (quickLootInputDownMember == null
                || HlxRuntime.callResolved(quickLootInputDownMember, [key]) != true) {
                quickLootState.release(controller);
                return result;
            }

            // Wait for a genuine native press before repeating. PTR may buffer
            // it for one frame even while isDown already reports the key held.
            // False frames reset the hold delay; repeats stay capped at 20/sec.
            if (!quickLootState.allowRepeat(controller, haxe.Timer.stamp()))
                return result;
            // Native tryInteract still selects and validates the one target.
            quickLootState.repeat(controller);
            return true;
        } catch (e:Dynamic) {
            logQuickLootError(e);
        }
        return result;
    }

    @:hlx.prefix(client.PlayerController.tryInteract)
    static function beginQuickLootInteraction(instance:Dynamic):HlxPrefixResult<Void> {
        quickLootState.beginInteraction(instance);
        return Continue;
    }

    @:hlx.postfix(client.PlayerController.tryInteract)
    static function endQuickLootInteraction(instance:Dynamic, result:Void):Void {
        quickLootState.endInteraction(instance);
    }

    @:hlx.postfix(client.PlayerController.getClosestInteractible)
    static function filterQuickLootTarget(instance:Dynamic, result:Dynamic):Dynamic {
        if (!quickLootState.filtersTarget(instance))
            return result;
        if (result == null || !enabled.get() || !config.holdInteractToQuickLoot)
            return null;

        try {
            var type = hl.Type.getDynamic(result);
            while (type != null && type.kind == HObj) {
                if (type.getTypeName() == "ent.interactible.LootDrop")
                    return result;
                type = type.getSuper();
            }
        } catch (e:Dynamic) {
            logQuickLootError(e);
        }
        // Never substitute another nearby item or repeat a non-loot interaction.
        // Returning null leaves native range/check/RPC handling untouched.
        return null;
    }

    static function logQuickLootError(e:Dynamic):Void {
        if (quickLootErrorLogged) return;
        quickLootErrorLogged = true;
        trace("[ItemUtilities] Quick-loot failed: " + Std.string(e));
    }

    @:hlx.postfix(ui.win.BankWindow.init)
    static function afterBankInit(instance:Dynamic, result:Void):Void {
        activeBankWindow = instance;
        try bankInventory = HlxRuntime.resolveField(instance, "inventory") catch (_:Dynamic) {}
        depositButton = null;
        status = "";
        cancelDeposit();
        cancelRecyclerDeposit();
        refreshInventories();
    }

    @:hlx.postfix(ui.win.Scrap.init)
    static function afterScrapInit(instance:Dynamic, result:Void):Void {
        activeScrapWindow = instance;
        scrapInventory = resolveScrapInventory(instance);
        scrapInventoryComp = null;
        cancelDeposit();
        cancelRecyclerDeposit();
        selectSourceInventory();
        if (sourceInventory == null)
            ensureHeroInventory();
        selectPlayerInventoryComp();
        selectScrapInventoryComp();
    }

    @:hlx.postfix(ui.win.InventoryWindow.init)
    static function afterInventoryInit(instance:Dynamic, result:Void):Void {
        try {
            var inventory:Dynamic = HlxRuntime.resolveField(instance, "inventory");
            if (inventory == null)
                return;

            var known = false;
            for (entry in openInventoryWindows) {
                if (entry.window == instance) {
                    entry.inventory = inventory;
                    known = true;
                    break;
                }
            }
            if (!known)
                openInventoryWindows.push({ window: instance, inventory: inventory });

            selectSourceInventory();
            selectPlayerInventoryComp();
        } catch (_:Dynamic) {}
    }

    @:hlx.postfix(ui.win.InventoryUI.init)
    static function afterPlayerInventoryInit(instance:Dynamic, result:Void):Void {
        refreshActiveHero();
        activeInventoryUI = instance;
        var comp = fieldOrNull(instance, "inventoryComp");
        var inventory = fieldOrNull(comp, "inventory");
        if (comp != null)
            playerInventoryComp = comp;
        if (inventory != null)
            sourceInventory = inventory;
    }

    @:hlx.postfix(ui.win.CharacterUI.init)
    static function afterCharacterUIInit(instance:Dynamic, result:Void):Void {
        activeCharacterUI = instance;
        syncSelectedEquipmentPreset();
    }

    @:hlx.postfix(ui.win.GearAppearance.init)
    static function afterGearAppearanceInit(instance:Dynamic, result:Void):Void {
        activeGearAppearance = instance;
        syncSelectedAppearancePreset();
    }

    @:hlx.postfix(ui.win.TalentView.init)
    static function afterTalentViewInit(instance:Dynamic, result:Void):Void {
        activeTalentView = instance;
        activeTalentRoot = null;
        syncSelectedTalentPreset();
    }

    @:hlx.postfix(ui.win.InventoryComp.init)
    static function afterInventoryCompInit(instance:Dynamic, result:Void):Void {
        var inventory = fieldOrNull(instance, "inventory");
        var replaced = false;
        if (inventory != null) {
            for (index in 0...inventoryComps.length) {
                if (fieldOrNull(inventoryComps[index], "inventory") == inventory) {
                    inventoryComps[index] = instance;
                    replaced = true;
                    break;
                }
            }
        }
        if (!replaced && inventoryComps.indexOf(instance) < 0)
            inventoryComps.push(instance);
        selectPlayerInventoryComp();
        selectScrapInventoryComp();
    }

    @:hlx.postfix(ui.win.InventorySlot.init)
    static function afterInventorySlotInit(instance:Dynamic, result:Void):Void {
        registerSlot(instance);
    }

    @:hlx.postfix(ui.win.InventorySlot.checkItemChanged)
    static function afterInventorySlotChanged(instance:Dynamic, force:hl.Ref<Bool>, result:Bool):Bool {
        registerSlot(instance);
        return result;
    }

    @:hlx.postfix(ui.BaseElement.onRemove)
    static function afterSlotElementRemoved(instance:Dynamic, result:Void):Void {
        // This also runs for slots inside removed windows and tooltips.
        unregisterSlot(instance);
        if (instance == activeGearAppearance) activeGearAppearance = null;
        if (instance == activeTalentView) {
            activeTalentView = null;
            activeTalentRoot = null;
        }
    }

    @:hlx.prefix(ui.BaseUI.setTip)
    static function suppressLockEditItemTooltip(instance:Dynamic, element:Dynamic,
        anchor:Dynamic, position:Dynamic, nesting:Dynamic):HlxPrefixResult<Dynamic> {
        if (enabled.get() && presetDropdown.isOpen()) {
            var mouse = ImGui.getMousePos();
            if (presetDropdown.blocksTooltip(mouse.x, mouse.y)) return SkipWith(null);
        }
        if (!lockEditMode)
            return Continue;
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!isActiveLockSlot(entry, slot))
                continue;
            if (isAncestorOf(slot, element) || isAncestorOf(slot, anchor)) {
                activeBaseUI = instance;
                return SkipWith(null);
            }
        }
        return Continue;
    }

    @:hlx.postfix(ui.BaseUI.setTip)
    static function afterTooltipSet(instance:Dynamic, element:Dynamic, anchor:Dynamic,
        position:Dynamic, nesting:Dynamic, result:Dynamic):Dynamic {
        activeBaseUI = instance;
        if (result != null) {
            activeTooltip = result;
            activeTooltipShownAt = haxe.Timer.stamp();
        }
        return result;
    }

    @:hlx.postfix(ui.BaseUI.displayWindow)
    static function afterWindowDisplayed(instance:Dynamic, window:Dynamic,
        root:Dynamic, result:Void):Void {
        activeBaseUI = instance;
        windowOccluders = null;
    }

    @:hlx.prefix(st.Loadout.requestCompleteItem)
    static function completeMoteInstantly(instance:Dynamic, item:Dynamic):HlxPrefixResult<Dynamic> {
        if (!enabled.get() || !config.instantMoteConversion)
            return Continue;
        // Internal IDs cover every elemental mote, independently of language.
        var kind:String = fieldOrNull(item, "kind");
        if (kind == null || !StringTools.startsWith(kind, "MoteOf"))
            return Continue;

        if (completeItemMember == null)
            completeItemMember = HlxRuntime.resolveMember(
                HlxRuntime.resolveType("st.Loadout"), "completeItem");
        if (completeItemMember == null)
            return Continue;

        // Keep the game's conversion checks and recipe; skip starting the
        // Complete_Package skill, whose completion normally calls this method.
        HlxRuntime.callResolved(completeItemMember, [instance, item, null]);
        return Skip;
    }

    @:hlx.prefix(st.Loadout.canSellItem)
    static function preventLockedSale(instance:Dynamic, item:Dynamic):HlxPrefixResult<Bool> {
        return isItemLocked(item) ? SkipWith(false) : Continue;
    }

    // MerchantUI calls sellItem directly, without consulting canSellItem.
    @:hlx.prefix(st.Loadout.sellItem)
    static function preventLockedSaleRequest(instance:Dynamic, item:Dynamic,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        if (!isItemLocked(item))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(null);
    }

    @:hlx.prefix(st.Inventory.canRequestDropIndex)
    static function preventLockedDrop(instance:Dynamic, index:Int, count:Bool,
        force:hl.Ref<Bool>, unknown:Null<Int>):HlxPrefixResult<Bool> {
        var item = itemAt(instance, index);
        return isItemLocked(item) ? SkipWith(false) : Continue;
    }

    // InventorySlot's discard actions call requestDropIndex directly.
    @:hlx.prefix(st.Inventory.requestDropIndex)
    static function preventLockedDropRequest(instance:Dynamic, index:Int, count:Bool,
        force:hl.Ref<Bool>, unknown:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(instance, index);
        if (!isItemLocked(item))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(null);
    }

    @:hlx.prefix(st.Inventory.canRequestTransfer)
    static function preventLockedTransferCheck(instance:Dynamic, index:Int,
        destination:Dynamic, destinationIndex:Int, force:hl.Ref<Bool>,
        count:Null<Int>):HlxPrefixResult<Bool> {
        var item = itemAt(instance, index);
        return isItemLocked(item) && isProtectedTransferDestination(destination)
            ? SkipWith(false)
            : Continue;
    }

    @:hlx.prefix(st.Inventory.requestTransfer)
    static function preventLockedTransferRequest(instance:Dynamic, index:Int,
        destination:Dynamic, destinationIndex:Int, force:hl.Ref<Bool>,
        count:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(instance, index);
        if (!isItemLocked(item) || !isProtectedTransferDestination(destination))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(getLockedItemReason());
    }

    @:hlx.prefix(st.Loadout.checkRequestTransfer)
    static function preventLockedRightClickTransferCheck(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        return isItemLocked(item) && isProtectedTransferDestination(destination)
            ? SkipWith(getLockedItemReason())
            : Continue;
    }

    @:hlx.prefix(st.Loadout.requestTransfer)
    static function preventLockedRightClickTransferRequest(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        if (!isItemLocked(item) || !isProtectedTransferDestination(destination))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(getLockedItemReason());
    }

    static function isProtectedTransferDestination(inventory:Dynamic):Bool {
        return isBankInventory(inventory) || isScrapInventory(inventory);
    }

    static function isScrapInventory(inventory:Dynamic):Bool {
        if (inventory == null)
            return false;
        try {
            return Std.string(inventory).indexOf("ent.interactible.ScrapInventory") == 0;
        } catch (_:Dynamic) {
            return false;
        }
    }

    static function isBankInventory(inventory:Dynamic):Bool {
        if (inventory == null)
            return false;
        if (inventory == bankInventory)
            return true;
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        return loadout != null && inventory == fieldOrNull(loadout, "bank");
    }

    static function rejectActionCallback(callback:Dynamic):Void {
        if (callback != null)
            try Reflect.callMethod(null, callback, [false]) catch (_:Dynamic) {}
    }

    static function getLockedItemReason():Dynamic {
        if (lockedItemReason != null)
            return lockedItemReason;
        try {
            if (eReasonType == null)
                eReasonType = HlxRuntime.resolveType("EReason");
            if (eReasonType != null)
                lockedItemReason = HlxRuntime.constructEnum(eReasonType, "Custom", ["Item is locked"]);
        } catch (error:Dynamic) logLockError("locked reason", error);
        return lockedItemReason;
    }

    @:hlx.prefix(st.Inventory.requestSort)
    static function ignoreLockedItemsDuringSort(instance:Dynamic, indexes:Array<Int>,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        if (!sortingIgnoresLockedItems.get() || instance != sourceInventory || indexes == null)
            return Continue;

        var content = getContent(instance);
        if (content == null || !resolveMembers())
            return Continue;

        var fixedIndexes:Array<Bool> = [];
        var lockedCount = 0;
        for (index in 0...arrayLength(content)) {
            var locked = isItemLocked(itemAt(instance, index));
            fixedIndexes.push(locked);
            if (locked)
                lockedCount++;
        }
        if (lockedCount == 0)
            return Continue;

        var desiredItems:Array<Dynamic> = [];
        for (sourceIndex in indexes) {
            var item = itemAt(instance, sourceIndex);
            if (item != null && !isItemLocked(item))
                desiredItems.push(item);
        }

        var targetIndexes:Array<Int> = [];
        for (index in 0...fixedIndexes.length) {
            if (!fixedIndexes[index] && targetIndexes.length < desiredItems.length)
                targetIndexes.push(index);
        }

        cancelLockedSort(false);
        lockedSortActive = true;
        lockedSortInventory = instance;
        lockedSortDesiredItems = desiredItems;
        lockedSortTargetIndexes = targetIndexes;
        lockedSortFixedIndexes = fixedIndexes;
        lockedSortPosition = 0;
        lockedSortCallback = callback;
        lockedSortSucceeded = true;
        lockedSortWaiting = false;
        lockedSortPendingMoves = [];
        return SkipWith(null);
    }

    @:hlx.postfix(ui.win.TitleWindow.onRemove)
    static function afterTitleWindowRemove(instance:Dynamic, result:Void):Void {
        windowOccluders = null;
        var kept:Array<{ window:Dynamic, inventory:Dynamic }> = [];
        for (entry in openInventoryWindows)
            if (entry.window != instance) kept.push(entry);
        openInventoryWindows = kept;

        if (instance == activeInventoryWindow) {
            lockEditMode = false;
            cancelLockedSort(false);
            activeInventoryWindow = null;
            sourceInventory = null;
            playerInventoryComp = null;
        }
        if (instance == activeInventoryUI) {
            lockEditMode = false;
            cancelLockedSort(false);
            activeInventoryUI = null;
            playerInventoryComp = null;
        }
        if (instance == activeCharacterUI) {
            activeCharacterUI = null;
            cancelPresetTransfer();
        }
        if (instance == activeBankWindow) {
            cancelDeposit();
            activeBankWindow = null;
            depositButton = null;
            bankInventory = null;
        }
        if (instance == activeScrapWindow) {
            cancelRecyclerDeposit();
            activeScrapWindow = null;
            scrapInventory = null;
            scrapInventoryComp = null;
        }
        selectSourceInventory();
    }

    static function draw():Void {
        PlayerInspect.update();
        NativeUiLayout.beginFrame();
        presetDropdown.beginFrame();
        windowOccluders = null;
        refreshActiveHero();
        updateTalentPreset();
        updateSkillPreset();
        updateAppearancePreset();

        if (lockedSortActive && !lockedSortWaiting)
            transferNextLockedSortItem();

        if (activeBankWindow != null && enabled.get() && showDepositMaterials.get())
            drawBankHeaderButton();
        if (activeScrapWindow != null && enabled.get() && showDepositMaterials.get())
            drawRecyclerHeaderButton();

        if (enabled.get()) {
            if (activeInventoryUI == null || !isUiVisible(activeInventoryUI))
                lockEditMode = false;
            ensureHeroInventory();
            syncSelectedEquipmentPreset();
            syncSelectedTalentPreset();
            syncSelectedSkillPreset();
            syncSelectedAppearancePreset();
            selectPlayerInventoryComp();
            checkPresetHotkeys();
            checkTalentPresetHotkeys();
            checkSkillPresetHotkeys();
            checkAppearancePresetHotkeys();
            var now = haxe.Timer.stamp();
            if (now >= nextLockReconcileAt) {
                nextLockReconcileAt = now + LOCK_RECONCILE_INTERVAL;
                reconcileItemLocks();
            }
            drawEquipmentPresetButtons();
            drawTalentPresetButtons();
            drawSkillPresetButtons();
            drawAppearancePresetButtons();
            if (showLockVisuals.get()) {
                drawLockHeaderButton();
                if (lockEditMode)
                    drawLockSlotOverlays();
                drawLockedItemBadges();
            }
        }
        presetDropdown.endFrame();
    }

    /** Keep window bounds, content, and custom artwork in the same pixel space. */
    static function prepareOverlay(rect:OverlayRect, width:Float, height:Float, rounding:Float):Void {
        overlayScaleX = rect.width / width;
        overlayScaleY = rect.height / height;
        ImGui.setNextWindowPos(new ImVec2(rect.left, rect.top));
        // Explicitly resize on this frame instead of using last frame's content.
        ImGui.setNextWindowSize(new ImVec2(rect.width, rect.height));
        ImGui.setNextWindowScroll(new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize, new ImVec2(1, 1));
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, overlayStroke(rounding));
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, overlaySize(4, 3));
        ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, overlaySize(8, 4));
        ImGui.pushFont(null, overlayStroke(ImGui.getFontSize()));
    }

    static function finishOverlay():Void {
        ImGui.popFont();
        ImGui.popStyleVar(5);
    }

    static inline function overlaySize(width:Float, height:Float):ImVec2 {
        return new ImVec2(width * overlayScaleX, height * overlayScaleY);
    }

    static inline function iconPoint(origin:ImVec2, x:Float, y:Float):ImVec2 {
        return new ImVec2(origin.x + x * overlayScaleX, origin.y + y * overlayScaleY);
    }

    static inline function overlayStroke(value:Float):Float {
        return value * Math.min(overlayScaleX, overlayScaleY);
    }

    static function drawBankHeaderButton():Void {
        var sortButton:Dynamic = null;
        try {
            var comp:Dynamic = HlxRuntime.resolveField(activeBankWindow, "comp");
            sortButton = comp == null ? null : HlxRuntime.resolveField(comp, "sortButton");
        } catch (_:Dynamic) {}
        if (sortButton == null || !isUiVisible(sortButton))
            return;

        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -228, 0, 32, 30), DEPOSIT_MISC,
            "misc", " Deposit miscellaneous ");
        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -190, 0, 32, 30), DEPOSIT_DEMON_ENCHANTMENT,
            "demon", " Deposit demon enchantment ");
        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -152, 0, 32, 30), DEPOSIT_CONSUMABLE,
            "consumable", " Deposit consumable ");
        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -114, 0, 32, 30), DEPOSIT_FOOD,
            "food", " Deposit food ");
        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -76, 0, 32, 30), DEPOSIT_CRAFTING,
            "materials", " Deposit crafting components ");
        drawBankDepositButton(sortButton, NativeUiLayout.rect(sortButton, -38, 0, 32, 30), DEPOSIT_ALL,
            "all", " Deposit all ");
    }

    static function drawRecyclerHeaderButton():Void {
        if (!isUiVisible(activeScrapWindow))
            return;
        if (scrapInventory == null)
            scrapInventory = resolveScrapInventory(activeScrapWindow);
        if (scrapInventoryComp == null
            || fieldOrNull(scrapInventoryComp, "inventory") != scrapInventory)
            selectScrapInventoryComp();

        var sortButton = fieldOrNull(scrapInventoryComp, "sortButton");
        if (sortButton == null || !isUiVisible(sortButton))
            return;

        var rect = NativeUiLayout.rect(sortButton, -38, 0, 32, 30);
        if (rect == null || buttonCovered(rect.left, rect.top, rect.width, rect.height))
            return;

        prepareOverlay(rect, 32, 30, 5);
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.NoScrollWithMouse
            | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.40, 0.37, 0.35, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));
        if (!ImGui.begin("##item-utilities-recycler-header", null, flags)) {
            ImGui.end();
            ImGui.popStyleColor(4);
            finishOverlay();
            return;
        }

        if (ImGui.button("##recycler-deposit-all", overlaySize(32, 30))) {
            playButtonClickSound(sortButton);
            if (!recyclerDepositing)
                beginRecyclerDeposit();
        }
        drawDepositModeIcon(DEPOSIT_ALL);
        if (ImGui.isItemHovered()) {
            setGameButtonCursor();
            ImGui.setTooltip(" Deposit all ");
        }

        ImGui.end();
        ImGui.popStyleColor(4);
        finishOverlay();
    }

    static function drawBankDepositButton(sortButton:Dynamic, rect:OverlayRect,
        mode:Int, suffix:String, tooltip:String):Void {
        if (rect == null || buttonCovered(rect.left, rect.top, rect.width, rect.height))
            return;

        // Keep the utility in the Bank header without modifying Domkit's live
        // component tree (doing that after init can invalidate the whole UI).
        prepareOverlay(rect, 32, 30, 5);
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.NoScrollWithMouse
            | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.40, 0.37, 0.35, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));
        if (!ImGui.begin("##item-utilities-bank-header-" + suffix, null, flags)) {
            ImGui.end();
            ImGui.popStyleColor(4);
            finishOverlay();
            return;
        }

        if (ImGui.button("##deposit-" + suffix, overlaySize(32, 30))) {
            playButtonClickSound(sortButton);
            if (!depositing)
                beginDepositMode(mode);
        }
        drawDepositModeIcon(mode);
        if (ImGui.isItemHovered()) {
            setGameButtonCursor();
            ImGui.setTooltip(tooltip);
        }

        ImGui.end();
        ImGui.popStyleColor(4);
        finishOverlay();
    }

    static function drawEquipmentPresetButtons():Void {
        if (activeCharacterUI == null || !isUiVisible(activeCharacterUI))
            return;
        // The game's field is spelled "apperanceMode".
        if (fieldOrNull(activeCharacterUI, "apperanceMode") == true)
            return;
        var appearanceButton = fieldOrNull(activeCharacterUI, "appearanceModeBtn");
        if (appearanceButton == null || !isUiVisible(appearanceButton))
            return;

        var width:Float = 150;
        var height:Float = 36;
        try {
            var rawWidth = fieldOrNull(appearanceButton, "calculatedWidth");
            var rawHeight = fieldOrNull(appearanceButton, "calculatedHeight");
            if (rawWidth != null) {
                var measuredWidth:Float = cast rawWidth;
                if (measuredWidth > 0)
                    width = measuredWidth;
            }
            if (rawHeight != null) {
                var measuredHeight:Float = cast rawHeight;
                if (measuredHeight > 0)
                    height = measuredHeight;
            }
        } catch (_:Dynamic) return;

        var controlsWidth = PresetSlots.CONTROLS_WIDTH;
        var rect = NativeUiLayout.rect(appearanceButton, width + 32, 0, controlsWidth, height);
        if (presetControlsCovered(rect, Equipment))
            return;
        drawPresetButtons(rect, height, appearanceButton, Equipment);
    }

    static function drawTalentPresetButtons():Void {
        var view = activeTalentView;
        if (view == null || !isUiVisible(view) || fieldOrNull(view, "hero") != resolveHero())
            return;
        var tree = fieldOrNull(view, "elementsCont");
        if (activeTalentRoot == null) {
            var rootId = fieldOrNull(fieldOrNull(view, "tree"), "root");
            var children = fieldOrNull(tree, "children");
            // Find the root TalentGroup by its skill, allowing decorative
            // native children before it. Cache only for this TalentView.
            for (i in 0...arrayLength(children)) {
                var group = arrayGet(children, i);
                var buttons = fieldOrNull(group, "talentButtons");
                for (j in 0...arrayLength(buttons)) {
                    var button = arrayGet(buttons, j);
                    if (fieldOrNull(fieldOrNull(button, "skill"), "id") == rootId) {
                        activeTalentRoot = group;
                        break;
                    }
                }
                if (activeTalentRoot != null) break;
            }
        }
        var points = fieldOrNull(fieldOrNull(view, "availablePoints"), "parent");
        var rect = TalentPresetLayout.place(uiElementRect(points), uiElementRect(activeTalentRoot),
            uiElementRect(tree), NativeUiLayout.rect(view, 0, 0, PresetSlots.CONTROLS_WIDTH, 36));
        if (presetControlsCovered(rect, Talent)) return;
        drawPresetButtons(rect, 36, view, Talent);
    }

    static function drawSkillPresetButtons():Void {
        var view = activeCharacterUI;
        if (view == null || !isUiVisible(view)) return;
        // CharacterUI creates these fields only on the class Skills tab.
        // bottomTexts is inside bottomPanel, the full-width white footer.
        var count = fieldOrNull(view, "masteryCount");
        if (count == null || !isUiVisible(count)) return;
        var text = fieldOrNull(count, "parent");
        var footer = fieldOrNull(text, "parent");
        // Measure the text itself; its flow may stretch across unused space.
        var runeBounds = NativeUiLayout.objectBounds(count, 0);
        var skillBounds = NativeUiLayout.objectBounds(fieldOrNull(view, "skillCount"), 0);
        if (runeBounds == null || skillBounds == null) return;
        var textBounds = new OverlayRect(Math.min(runeBounds.left, skillBounds.left),
            Math.min(runeBounds.top, skillBounds.top), Math.max(runeBounds.right, skillBounds.right),
            Math.max(runeBounds.bottom, skillBounds.bottom));
        var rect = SkillPresetLayout.place(uiElementRect(footer), textBounds,
            NativeUiLayout.rect(view, 0, 0, PresetSlots.CONTROLS_WIDTH, 36));
        if (presetControlsCovered(rect, Skill)) return;
        drawPresetButtons(rect, 36, view, Skill);
    }

    static function drawAppearancePresetButtons():Void {
        if (activeCharacterUI == null || !isUiVisible(activeCharacterUI)
            || fieldOrNull(activeCharacterUI, "apperanceMode") != true) return;
        // CharacterUI keeps the same button field when its label changes
        // from Appearance to Character. Anchor to that live button rectangle.
        var button = fieldOrNull(activeCharacterUI, "appearanceModeBtn");
        if (button == null || !isUiVisible(button)) return;
        var rect = AppearancePresetLayout.place(uiElementRect(button),
            uiElementRect(fieldOrNull(button, "parent")), NativeUiLayout.rect(button, 0, 0, PresetSlots.CONTROLS_WIDTH, 36));
        if (presetControlsCovered(rect, Appearance)) return;
        drawPresetButtons(rect, 36, button, Appearance);
    }

    static function presetControlsCovered(rect:OverlayRect, kind:PresetKind):Bool {
        if (rect == null) return true;
        // A tooltip from a skill behind the popup must not stop submitting its
        // parent bar to ImGui. Real covering windows still hide the controls.
        return presetDropdown.covered(cast kind,
            tooltipOverlaps(rect.left, rect.top, rect.width, rect.height),
            windowOverlaps(rect.left, rect.top, rect.width, rect.height));
    }

    static function uiElementRect(element:Dynamic):OverlayRect {
        var width = fieldOrNull(element, "calculatedWidth");
        var height = fieldOrNull(element, "calculatedHeight");
        if (width == null || height == null) return null;
        return NativeUiLayout.rect(element, 0, 0, cast width, cast height);
    }

    static function drawPresetButtons(rect:OverlayRect, height:Float,
        referenceButton:Dynamic, kind:PresetKind):Void {
        prepareOverlay(rect, PresetSlots.CONTROLS_WIDTH, height, 6);
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.NoScrollWithMouse
            | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.70, 0.59, 0.54, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.541, 0.373, 0.275, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.60, 0.48, 0.43, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.98, 0.93, 0.90, 1));
        ImGui.pushStyleColor(ImGuiCol.FrameBg, new ImVec4(0.70, 0.59, 0.54, 1));
        ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, new ImVec4(0.541, 0.373, 0.275, 1));
        ImGui.pushStyleColor(ImGuiCol.FrameBgActive, new ImVec4(0.60, 0.48, 0.43, 1));
        ImGui.pushStyleColor(ImGuiCol.PopupBg, new ImVec4(0.81, 0.73, 0.69, 1));
        ImGui.pushStyleColor(ImGuiCol.Header, new ImVec4(0.70, 0.59, 0.54, 1));
        ImGui.pushStyleColor(ImGuiCol.HeaderHovered, new ImVec4(0.75, 0.65, 0.60, 1));
        ImGui.pushStyleColor(ImGuiCol.HeaderActive, new ImVec4(0.60, 0.48, 0.43, 1));
        var windowId = switch kind {
            case Equipment: "##item-utilities-weapon-presets";
            case Talent: "##item-utilities-talent-presets";
            case Skill: "##item-utilities-skill-presets";
            case Appearance: "##item-utilities-appearance-presets";
        };
        if (ImGui.begin(windowId, null, flags)) {
            var busy = switch kind {
                case Equipment: presetTransferActive;
                case Talent: talentPresetTransfer.active;
                case Skill: skillPresetTransfer.active;
                case Appearance: appearancePresetTransfer.active;
            };
            var selectedPreset = switch kind {
                case Equipment: selectedWeaponPreset;
                case Talent: selectedTalentPreset;
                case Skill: selectedSkillPreset;
                case Appearance: selectedAppearancePreset;
            };
            ImGui.beginDisabled(busy);
            // Match the Set button's height at every native UI scale. Combo
            // popups use their own window, so the options aren't clipped by
            // the single-row overlay (including on the Skills footer).
            ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, new ImVec2(8 * overlayScaleX,
                Math.max(0, (height * overlayScaleY - ImGui.getFontSize()) * 0.5)));
            ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, overlaySize(6, 6));
            ImGui.setNextItemWidth(PresetSlots.SELECTOR_WIDTH * overlayScaleX);
            var previewMin = ImGui.getCursorScreenPos();
            var popupOpen = ImGui.beginCombo("##preset-selector", "", ImGuiComboFlags.HeightLarge);
            if (popupOpen) {
                var popupPos = ImGui.getWindowPos(), popupSize = ImGui.getWindowSize();
                presetDropdown.update(cast kind, true, new OverlayRect(popupPos.x, popupPos.y,
                    popupPos.x + popupSize.x, popupPos.y + popupSize.y));
                ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.36, 0.26, 0.20, 1));
                for (preset in 0...PresetSlots.COUNT) {
                    var selected = selectedPreset == preset;
                    var rowMin = ImGui.getCursorScreenPos();
                    var rowMax = new ImVec2(rowMin.x + ImGui.getContentRegionAvail().x,
                        rowMin.y + 28 * overlayScaleY);
                    if (ImGui.selectable("##preset-option-" + preset, selected, 0, overlaySize(0, 28))) {
                        presetDropdown.update(cast kind, false);
                        playButtonClickSound(referenceButton);
                        switch kind {
                            case Equipment:
                                selectEquipmentPreset(preset);
                                activateEquipmentPreset(preset);
                            case Talent:
                                selectTalentPreset(preset);
                                activateTalentPreset(preset);
                            case Skill:
                                selectSkillPreset(preset);
                                activateSkillPreset(preset);
                            case Appearance:
                                selectAppearancePreset(preset);
                                activateAppearancePreset(preset);
                        }
                    }
                    drawPresetText(PresetSlots.label(preset), rowMin, rowMax);
                    if (selected) ImGui.setItemDefaultFocus();
                    if (ImGui.isItemHovered()) setGameButtonCursor();
                }
                ImGui.popStyleColor();
                ImGui.endCombo();
            } else presetDropdown.update(cast kind, false);
            drawPresetText(PresetSlots.label(selectedPreset),
                new ImVec2(previewMin.x + 8 * overlayScaleX, previewMin.y),
                new ImVec2(previewMin.x + PresetSlots.SELECTOR_WIDTH * overlayScaleX - height * overlayScaleY,
                    previewMin.y + height * overlayScaleY));
            ImGui.popStyleVar(2);
            if (ImGui.isItemHovered()) setGameButtonCursor();
            ImGui.sameLine();
            if (ImGui.button("##weapon-preset-set", overlaySize(PresetSlots.SET_WIDTH, height))) {
                playButtonClickSound(referenceButton);
                switch kind {
                    case Equipment: saveCurrentEquipmentToPreset(selectedWeaponPreset);
                    case Talent: saveCurrentTalentsToPreset(selectedTalentPreset);
                    case Skill: saveCurrentSkillsToPreset(selectedSkillPreset);
                    case Appearance: saveCurrentAppearancesToPreset(selectedAppearancePreset);
                }
            }
            drawPresetText("Set", ImGui.getItemRectMin(), ImGui.getItemRectMax(), true);
            if (ImGui.isItemHovered()) setGameButtonCursor();
            ImGui.endDisabled();
        }
        ImGui.end();
        ImGui.popStyleColor(11);
        finishOverlay();
    }

    static function drawPresetText(value:String, min:ImVec2, max:ImVec2, center:Bool = false):Void {
        var textSize = ImGui.calcTextSize(value);
        var weight = overlayStroke(0.65);
        var x = center ? min.x + (max.x - min.x - textSize.x - weight) * 0.5 : min.x;
        var y = min.y + (max.y - min.y - textSize.y) * 0.5;
        var drawList = ImGui.getWindowDrawList();
        var color = ImGui.getColorU32_Col(ImGuiCol.Text);
        // The same light overdraw used by the old Presets heading, retaining
        // the plugin font and disabled-state alpha without another font asset.
        ImGui.ImDrawList_PushClipRect(drawList, min, max, true);
        ImGui.ImDrawList_AddText_Vec2(drawList, new ImVec2(x, y), color, value);
        ImGui.ImDrawList_AddText_Vec2(drawList, new ImVec2(x + weight, y), color, value);
        ImGui.ImDrawList_PopClipRect(drawList);
    }

    static function syncSelectedTalentPreset():Void {
        var characterId = heroPersistentId(resolveHero());
        if (characterId == selectedTalentPresetCharacterId) return;
        selectedTalentPresetCharacterId = characterId;
        selectedTalentPreset = 0;
        talentPresetStatus = "";
        for (entry in config.selectedTalentPresets)
            if (recordString(entry, "characterId") == characterId) {
                var preset = recordInt(entry, "preset", 0);
                if (PresetSlots.valid(preset)) selectedTalentPreset = preset;
                return;
            }
    }

    static function selectTalentPreset(preset:Int):Void {
        if (!PresetSlots.valid(preset) || talentPresetTransfer.active) return;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null) return;
        selectedTalentPresetCharacterId = characterId;
        selectedTalentPreset = preset;
        for (entry in config.selectedTalentPresets)
            if (recordString(entry, "characterId") == characterId) {
                Reflect.setField(entry, "preset", preset);
                saveConfig();
                return;
            }
        config.selectedTalentPresets.push({characterId: characterId, preset: preset});
        saveConfig();
    }

    static function findTalentPreset(characterId:String, preset:Int):Dynamic {
        if (characterId == null) return null;
        for (entry in config.talentPresets)
            if (recordString(entry, "characterId") == characterId
                && recordInt(entry, "preset", -1) == preset) return entry;
        return null;
    }

    static function talentsReady(hero:Dynamic):Bool {
        if (hero == null || fieldOrNull(hero, "removed") == true
            || fieldOrNull(fieldOrNull(hero, "specialization"), "hero") != hero) return false;
        var app = currentGameApp();
        if (app == null || fieldOrNull(app, "hero") != hero || fieldOrNull(app, "host") == null)
            return false;
        if (getIsLoadingMember == null)
            getIsLoadingMember = HlxRuntime.resolveMember(gameAppType, "get_isLoading");
        return getIsLoadingMember != null
            && HlxRuntime.callResolved(getIsLoadingMember, [app]) == false;
    }

    static function saveCurrentTalentsToPreset(preset:Int):Void {
        if (!enabled.get() || talentPresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            if (characterId == null || !talentsReady(hero)) return;
            var specialization = fieldOrNull(hero, "specialization");
            var ranks = NativeTalents.current(specialization);
            TalentPresetPlan.validate(NativeTalents.rules(hero), ranks, NativeTalents.totalPoints(specialization));
            var existing = findTalentPreset(characterId, preset);
            if (existing == null) {
                existing = {characterId: characterId, preset: preset};
                config.talentPresets.push(existing);
            }
            Reflect.setField(existing, "classId", Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id")));
            Reflect.setField(existing, "talents", TalentPresetPlan.encode(ranks));
            saveConfig();
            talentPresetStatus = "Talent preset " + (preset + 1) + " saved.";
        } catch (error:Dynamic) {
            talentPresetStatus = Std.string(error);
            logLockError("save talent preset", error);
        }
    }

    static function activateTalentPreset(preset:Int):Void {
        if (!enabled.get() || talentPresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            var saved = findTalentPreset(characterId, preset);
            if (saved == null) {
                talentPresetStatus = "Press Set to save your current talents to preset " + (preset + 1) + ".";
                return;
            }
            if (!talentsReady(hero)) return;
            var classId = Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id"));
            if (recordString(saved, "classId") != classId) throw "This talent preset belongs to a different class.";
            var specialization = fieldOrNull(hero, "specialization");
            var current = NativeTalents.current(specialization);
            var target = TalentPresetPlan.decode(Reflect.field(saved, "talents"));
            var changes = TalentPresetPlan.build(NativeTalents.rules(hero), current, target,
                NativeTalents.totalPoints(specialization));
            if (changes.length == 0) {
                talentPresetStatus = "This talent preset is already active.";
                return;
            }
            talentPresetHero = hero;
            talentPresetHost = fieldOrNull(currentGameApp(), "host");
            talentPresetSpecialization = specialization;
            talentPresetCharacterId = characterId;
            nextTalentPresetCheck = 0;
            talentPresetTransfer.start(specialization, current, changes);
            talentPresetStatus = "Applying talent preset...";
        } catch (error:Dynamic) {
            talentPresetStatus = Std.string(error);
            logLockError("apply talent preset", error);
        }
    }

    static function updateTalentPreset():Void {
        if (!talentPresetTransfer.active) {
            // An asynchronous rejection can finish between draw callbacks.
            if (talentPresetHero != null) finishTalentPreset();
            return;
        }
        try {
            var hero = resolveHero();
            var app = currentGameApp();
            if (!enabled.get() || hero != talentPresetHero
                || fieldOrNull(app, "host") != talentPresetHost
                || heroPersistentId(hero) != talentPresetCharacterId || !talentsReady(hero)) {
                talentPresetTransfer.cancel("Talent preset stopped because the session changed.");
            } else {
                var now = haxe.Timer.stamp();
                if (now < nextTalentPresetCheck) return;
                nextTalentPresetCheck = now + 0.05;
                var specialization = fieldOrNull(hero, "specialization");
                if (specialization != talentPresetSpecialization) {
                    talentPresetTransfer.cancel("Talent preset stopped because the character changed.");
                } else {
                    // No talent-map scan while waiting for the RPC callback.
                    var current = talentPresetTransfer.needsRanks() ? NativeTalents.current(specialization) : null;
                    var change = talentPresetTransfer.next(specialization, now, current);
                    if (change != null) {
                        var requestId = talentPresetTransfer.requestId;
                        NativeTalents.setRank(specialization, change.skill, change.rank, function(success:Bool) {
                            talentPresetTransfer.acknowledge(requestId, success);
                        });
                    }
                }
            }
        } catch (error:Dynamic) {
            talentPresetTransfer.cancel(Std.string(error));
            logLockError("talent preset transfer", error);
        }
        if (!talentPresetTransfer.active) finishTalentPreset();
    }

    static function finishTalentPreset():Void {
        talentPresetStatus = talentPresetTransfer.error == "" ? "Talent preset applied." : talentPresetTransfer.error;
        talentPresetHero = null;
        talentPresetHost = null;
        talentPresetSpecialization = null;
        talentPresetCharacterId = null;
    }

    static function resetCharacterData(kind:CharacterResetKind):Void {
        var label = CharacterResetStore.label(kind);
        try {
            var characterId = heroPersistentId(resolveHero());
            if (characterId == null) throw "Log in to a character before resetting saved data.";
            // Read the latest file, preserving other settings and preset types.
            // Commit the deletion before changing runtime state or reporting it.
            var values:Dynamic = Json.parse(sys.io.File.getContent(
                "hlx/config/" + HlxRuntime.moduleName() + "/config.json"));
            var cleared = CharacterResetStore.cleared(values, characterId, kind);
            var remainingLocks = kind == Locks
                ? CharacterResetStore.withoutCharacter(lockRecords, characterId) : null;
            ModConfig.save(HlxRuntime.moduleName(), cleared);
            for (key in CharacterResetStore.fields(kind))
                Reflect.setField(config, key, Reflect.field(cleared, key));
            // Clear live caches as well, so the next save cannot resurrect data.
            // Cancelling preset queues sends no new equip/talent/skill requests.
            switch kind {
                case Locks:
                    lockRecords = remainingLocks;
                case Equipment:
                    weaponPresets = config.weaponPresets;
                    selectedWeaponPresets = config.selectedWeaponPresets;
                    cancelPresetTransfer();
                    selectedWeaponPreset = 0;
                    selectedWeaponPresetCharacterId = characterId;
                case Talent:
                    talentPresetTransfer.cancel();
                    talentPresetHero = null;
                    talentPresetHost = null;
                    talentPresetSpecialization = null;
                    talentPresetCharacterId = null;
                    selectedTalentPreset = 0;
                    selectedTalentPresetCharacterId = characterId;
                    talentPresetStatus = label + " reset for this character.";
                case Skill:
                    skillPresetTransfer.cancel();
                    skillPresetHero = null;
                    skillPresetHost = null;
                    skillPresetSpecialization = null;
                    skillPresetCharacterId = null;
                    selectedSkillPreset = 0;
                    selectedSkillPresetCharacterId = characterId;
                    skillPresetStatus = label + " reset for this character.";
                case Appearance:
                    appearancePresetTransfer.cancel();
                    appearancePresetHero = null;
                    appearancePresetHost = null;
                    appearancePresetLoadout = null;
                    appearancePresetCharacterId = null;
                    selectedAppearancePreset = 0;
                    selectedAppearancePresetCharacterId = characterId;
                    appearancePresetStatus = label + " reset for this character.";
            }
            status = label + " reset for this character.";
        } catch (error:Dynamic) {
            status = "Could not reset " + label.toLowerCase() + ".";
            switch kind {
                case Talent: talentPresetStatus = status;
                case Skill: skillPresetStatus = status;
                case Appearance: appearancePresetStatus = status;
                default:
            }
            logLockError("reset " + label.toLowerCase(), error);
        }
    }

    static function syncSelectedAppearancePreset():Void {
        var characterId = heroPersistentId(resolveHero());
        if (characterId == selectedAppearancePresetCharacterId) return;
        selectedAppearancePresetCharacterId = characterId;
        selectedAppearancePreset = 0;
        appearancePresetStatus = "";
        for (entry in config.selectedAppearancePresets)
            if (recordString(entry, "characterId") == characterId) {
                var preset = recordInt(entry, "preset", 0);
                if (PresetSlots.valid(preset)) selectedAppearancePreset = preset;
                return;
            }
    }

    static function selectAppearancePreset(preset:Int):Void {
        if (!PresetSlots.valid(preset) || appearancePresetTransfer.active) return;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null) return;
        selectedAppearancePresetCharacterId = characterId;
        selectedAppearancePreset = preset;
        for (entry in config.selectedAppearancePresets)
            if (recordString(entry, "characterId") == characterId) {
                Reflect.setField(entry, "preset", preset);
                saveConfig();
                return;
            }
        config.selectedAppearancePresets.push({characterId: characterId, preset: preset});
        saveConfig();
    }

    static function findAppearancePreset(characterId:String, preset:Int):Dynamic {
        if (characterId == null) return null;
        for (entry in config.appearancePresets)
            if (recordString(entry, "characterId") == characterId
                && recordInt(entry, "preset", -1) == preset) return entry;
        return null;
    }

    static function appearancesReady(hero:Dynamic):Bool {
        return talentsReady(hero) && fieldOrNull(fieldOrNull(hero, "loadout"), "owner") == hero
            && fieldOrNull(fieldOrNull(hero, "loadout"), "appearance") != null;
    }

    static function saveCurrentAppearancesToPreset(preset:Int):Void {
        if (!enabled.get() || appearancePresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            if (characterId == null || !appearancesReady(hero)) return;
            var loadout = fieldOrNull(hero, "loadout");
            var choices = NativeAppearance.current(loadout);
            NativeAppearance.validate(loadout, choices);
            var existing = findAppearancePreset(characterId, preset);
            if (existing == null) {
                existing = {characterId: characterId, preset: preset};
                config.appearancePresets.push(existing);
            }
            Reflect.setField(existing, "classId", Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id")));
            Reflect.setField(existing, "appearances", AppearancePresetPlan.encode(choices));
            saveConfig();
            appearancePresetStatus = "Appearance preset " + (preset + 1) + " saved.";
        } catch (error:Dynamic) {
            appearancePresetStatus = Std.string(error);
            logLockError("save appearance preset", error);
        }
    }

    static function activateAppearancePreset(preset:Int):Void {
        if (!enabled.get() || appearancePresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            var saved = findAppearancePreset(characterId, preset);
            if (saved == null) {
                appearancePresetStatus = "Press Set to save your current appearance to preset " + (preset + 1) + ".";
                return;
            }
            if (!appearancesReady(hero)) return;
            var classId = Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id"));
            if (recordString(saved, "classId") != classId) throw "This appearance preset belongs to a different class.";
            var loadout = fieldOrNull(hero, "loadout");
            var current = NativeAppearance.current(loadout);
            var target = AppearancePresetPlan.decode(Reflect.field(saved, "appearances"));
            NativeAppearance.validate(loadout, target);
            var changes = AppearancePresetPlan.build(current, target, NativeAppearance.rules());
            if (changes.length == 0) {
                appearancePresetStatus = "This appearance preset is already active.";
                return;
            }
            appearancePresetHero = hero;
            appearancePresetHost = fieldOrNull(currentGameApp(), "host");
            appearancePresetLoadout = loadout;
            appearancePresetCharacterId = characterId;
            nextAppearancePresetCheck = 0;
            appearancePresetTransfer.start(loadout, current, changes);
            appearancePresetStatus = "Applying appearance preset...";
        } catch (error:Dynamic) {
            appearancePresetStatus = Std.string(error);
            logLockError("apply appearance preset", error);
        }
    }

    static function updateAppearancePreset():Void {
        if (!appearancePresetTransfer.active) {
            // An asynchronous rejection can finish between draw callbacks.
            if (appearancePresetHero != null) finishAppearancePreset();
            return;
        }
        try {
            var hero = resolveHero();
            var app = currentGameApp();
            if (!enabled.get() || hero != appearancePresetHero
                || fieldOrNull(app, "host") != appearancePresetHost
                || heroPersistentId(hero) != appearancePresetCharacterId || !appearancesReady(hero)) {
                appearancePresetTransfer.cancel("Appearance preset stopped because the session changed.");
            } else {
                var now = haxe.Timer.stamp();
                if (now < nextAppearancePresetCheck) return;
                nextAppearancePresetCheck = now + 0.05;
                var loadout = fieldOrNull(hero, "loadout");
                if (loadout != appearancePresetLoadout) {
                    appearancePresetTransfer.cancel("Appearance preset stopped because the character changed.");
                } else {
                    // Read the appearance inventory only after the RPC reply.
                    var current = appearancePresetTransfer.needsState() ? NativeAppearance.current(loadout) : null;
                    var change = appearancePresetTransfer.next(loadout, now, current);
                    if (change != null) {
                        var requestId = appearancePresetTransfer.requestId;
                        NativeAppearance.apply(loadout, change.slot, change.item, function(success:Bool) {
                            appearancePresetTransfer.acknowledge(requestId, success);
                        });
                    }
                }
            }
        } catch (error:Dynamic) {
            appearancePresetTransfer.cancel(Std.string(error));
            logLockError("appearance preset transfer", error);
        }
        if (!appearancePresetTransfer.active) finishAppearancePreset();
    }

    static function finishAppearancePreset():Void {
        appearancePresetStatus = appearancePresetTransfer.error == "" ? "Appearance preset applied." : appearancePresetTransfer.error;
        var loadout = appearancePresetLoadout;
        appearancePresetHero = null;
        appearancePresetHost = null;
        appearancePresetLoadout = null;
        appearancePresetCharacterId = null;
        try NativeAppearance.refreshView(activeGearAppearance, loadout) catch (_:Dynamic) {}
    }

    static function syncSelectedSkillPreset():Void {
        var characterId = heroPersistentId(resolveHero());
        if (characterId == selectedSkillPresetCharacterId) return;
        selectedSkillPresetCharacterId = characterId;
        selectedSkillPreset = 0;
        skillPresetStatus = "";
        for (entry in config.selectedSkillPresets)
            if (recordString(entry, "characterId") == characterId) {
                var preset = recordInt(entry, "preset", 0);
                if (PresetSlots.valid(preset)) selectedSkillPreset = preset;
                return;
            }
    }

    static function selectSkillPreset(preset:Int):Void {
        if (!PresetSlots.valid(preset) || skillPresetTransfer.active) return;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null) return;
        selectedSkillPresetCharacterId = characterId;
        selectedSkillPreset = preset;
        for (entry in config.selectedSkillPresets)
            if (recordString(entry, "characterId") == characterId) {
                Reflect.setField(entry, "preset", preset);
                saveConfig();
                return;
            }
        config.selectedSkillPresets.push({characterId: characterId, preset: preset});
        saveConfig();
    }

    static function findSkillPreset(characterId:String, preset:Int):Dynamic {
        if (characterId == null) return null;
        for (entry in config.skillPresets)
            if (recordString(entry, "characterId") == characterId
                && recordInt(entry, "preset", -1) == preset) return entry;
        return null;
    }

    static function saveCurrentSkillsToPreset(preset:Int):Void {
        if (!enabled.get() || skillPresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            if (characterId == null || !talentsReady(hero)) return;
            var specialization = fieldOrNull(hero, "specialization");
            var current = NativeSkills.current(specialization);
            NativeSkills.ensureSynchronized(hero, current);
            var saved = SkillPresetPlan.saved(current, NativeSkills.runeSkills(current.runes));
            SkillPresetPlan.validate(saved, NativeSkills.rules(hero));
            var existing = findSkillPreset(characterId, preset);
            if (existing == null) {
                existing = {characterId: characterId, preset: preset};
                config.skillPresets.push(existing);
            }
            Reflect.setField(existing, "classId", Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id")));
            Reflect.setField(existing, "skills", saved);
            saveConfig();
            skillPresetStatus = "Skill preset " + (preset + 1) + " saved.";
        } catch (error:Dynamic) {
            skillPresetStatus = Std.string(error);
            logLockError("save skill preset", error);
        }
    }

    static function activateSkillPreset(preset:Int):Void {
        if (!enabled.get() || skillPresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            var saved = findSkillPreset(characterId, preset);
            if (saved == null) {
                skillPresetStatus = "Press Set to save your current skills to preset " + (preset + 1) + ".";
                return;
            }
            if (!talentsReady(hero)) return;
            var classId = Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id"));
            if (recordString(saved, "classId") != classId) throw "This skill preset belongs to a different class.";
            var specialization = fieldOrNull(hero, "specialization");
            var current = NativeSkills.current(specialization);
            NativeSkills.ensureSynchronized(hero, current);
            var target = SkillPresetPlan.decode(Reflect.field(saved, "skills"));
            NativeSkills.ensureCanApply(hero);
            var changes = SkillPresetPlan.build(current, target, NativeSkills.rules(hero),
                NativeSkills.runeSkills(current.runes));
            if (changes.length == 0) {
                skillPresetStatus = "This skill preset is already active.";
                return;
            }
            skillPresetHero = hero;
            skillPresetHost = fieldOrNull(currentGameApp(), "host");
            skillPresetSpecialization = specialization;
            skillPresetCharacterId = characterId;
            nextSkillPresetCheck = 0;
            skillPresetTransfer.start(specialization, current, changes);
            skillPresetStatus = "Applying skill preset...";
        } catch (error:Dynamic) {
            skillPresetStatus = Std.string(error);
            logLockError("apply skill preset", error);
        }
    }

    static function updateSkillPreset():Void {
        if (!skillPresetTransfer.active) {
            // An asynchronous rejection can finish between draw callbacks.
            if (skillPresetHero != null) finishSkillPreset();
            return;
        }
        try {
            var hero = resolveHero();
            var app = currentGameApp();
            if (!enabled.get() || hero != skillPresetHero
                || fieldOrNull(app, "host") != skillPresetHost
                || heroPersistentId(hero) != skillPresetCharacterId || !talentsReady(hero)) {
                skillPresetTransfer.cancel("Skill preset stopped because the session changed.");
            } else {
                NativeSkills.ensureCanApply(hero);
                var now = haxe.Timer.stamp();
                if (now < nextSkillPresetCheck) return;
                nextSkillPresetCheck = now + 0.05;
                var specialization = fieldOrNull(hero, "specialization");
                if (specialization != skillPresetSpecialization) {
                    skillPresetTransfer.cancel("Skill preset stopped because the character changed.");
                } else {
                    // Rune callbacks must arrive before reading for confirmation.
                    var current = skillPresetTransfer.needsState() ? NativeSkills.current(specialization) : null;
                    var change = skillPresetTransfer.next(specialization, now, current);
                    if (change != null) {
                        var requestId = skillPresetTransfer.requestId;
                        NativeSkills.apply(hero, change, function(success:Bool) {
                            skillPresetTransfer.acknowledge(requestId, success);
                        });
                    }
                }
            }
        } catch (error:Dynamic) {
            skillPresetTransfer.cancel(Std.string(error));
            logLockError("skill preset transfer", error);
        }
        if (!skillPresetTransfer.active) finishSkillPreset();
    }

    static function finishSkillPreset():Void {
        skillPresetStatus = skillPresetTransfer.error == "" ? "Skill preset applied." : skillPresetTransfer.error;
        skillPresetHero = null;
        skillPresetHost = null;
        skillPresetSpecialization = null;
        skillPresetCharacterId = null;
    }

    static function syncSelectedEquipmentPreset():Void {
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null || characterId == selectedWeaponPresetCharacterId)
            return;
        selectedWeaponPresetCharacterId = characterId;
        selectedWeaponPreset = 0;
        for (entry in selectedWeaponPresets) {
            if (recordString(entry, "characterId") == characterId) {
                var preset = recordInt(entry, "preset", 0);
                if (PresetSlots.valid(preset))
                    selectedWeaponPreset = preset;
                return;
            }
        }
    }

    static function selectEquipmentPreset(preset:Int):Void {
        if (!PresetSlots.valid(preset))
            return;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null)
            return;
        selectedWeaponPresetCharacterId = characterId;
        selectedWeaponPreset = preset;
        for (entry in selectedWeaponPresets) {
            if (recordString(entry, "characterId") == characterId) {
                Reflect.setField(entry, "preset", preset);
                saveConfig();
                return;
            }
        }
        selectedWeaponPresets.push({ characterId: characterId, preset: preset });
        saveConfig();
    }

    static function hasEquipmentPreset(preset:Int):Bool {
        return findEquipmentPreset(heroPersistentId(resolveHero()), preset) != null;
    }

    static function findEquipmentPreset(characterId:String, preset:Int):Dynamic {
        if (characterId == null)
            return null;
        for (entry in weaponPresets)
            if (recordString(entry, "characterId") == characterId
                && recordInt(entry, "preset", -1) == preset)
                return entry;
        return null;
    }

    static function saveCurrentEquipmentToPreset(preset:Int):Void {
        if (!PresetSlots.valid(preset) || presetTransferActive) return;
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        var loadout = fieldOrNull(hero, "loadout");
        var equipment = fieldOrNull(loadout, "equipment");
        if (characterId == null || equipment == null || !resolveMembers())
            return;

        var weapons:Array<Dynamic> = [];
        for (index in equipmentPresetSlotIndexes()) {
            var item = itemAt(equipment, index);
            if (item == null)
                continue;
            weapons.push({
                index: index,
                uid: itemUid(item),
                fingerprint: itemFingerprint(item)
            });
        }

        var existing = findEquipmentPreset(characterId, preset);
        if (existing == null)
            weaponPresets.push({
                characterId: characterId,
                preset: preset,
                weapons: weapons
            });
        else
            Reflect.setField(existing, "weapons", weapons);
        saveConfig();
    }

    static function equipmentPresetSlotIndexes():Array<Int> {
        var slotType = HlxRuntime.resolveType("st._Equipment.EquipmentSlot_Impl_");
        var iter = HlxRuntime.resolveStaticMember(slotType, "iter");
        var getIndex = HlxRuntime.resolveStaticMember(slotType, "getIndex");
        var indexes:Array<Int> = [];
        // Native display categories: Weapons, Left, Right. The latter two
        // are the armor/accessory columns, including separate ring slots.
        for (category in [3, 0, 1]) {
            var slots = HlxRuntime.callResolved(iter, [category, null]);
            for (i in 0...arrayLength(slots)) {
                var index:Int = HlxRuntime.callResolved(getIndex, [arrayGet(slots, i)]);
                if (index >= 0)
                    indexes.push(index);
            }
        }
        return indexes;
    }

    static function activateEquipmentPreset(preset:Int):Void {
        if (!PresetSlots.valid(preset) || presetTransferActive)
            return;
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        var saved = findEquipmentPreset(characterId, preset);
        var loadout = fieldOrNull(hero, "loadout");
        var inventory = fieldOrNull(loadout, "inventory");
        var equipment = fieldOrNull(loadout, "equipment");
        var weapons:Array<Dynamic> = saved == null ? null : cast Reflect.field(saved, "weapons");
        if (inventory == null || equipment == null || weapons == null || weapons.length == 0
            || !resolveMembers())
            return;

        presetEquipQueue = weapons.copy();
        presetEquipPosition = 0;
        presetInventory = inventory;
        presetEquipment = equipment;
        presetEquippedIndexes = [];
        presetTransferActive = true;
        equipNextPresetItem();
    }

    static function equipNextPresetItem():Void {
        if (!presetTransferActive)
            return;
        while (presetEquipPosition < presetEquipQueue.length) {
            var saved = presetEquipQueue[presetEquipPosition];
            presetEquipPosition++;
            var targetIndex = recordInt(saved, "index", -1);
            if (targetIndex < 0)
                continue;

            var source = findPresetItem(saved);
            if (source == null)
                continue;
            if (source.inventory == presetEquipment && source.index == targetIndex) {
                presetEquippedIndexes.push(targetIndex);
                continue;
            }
            if (!resolveMembers()) {
                cancelPresetTransfer();
                return;
            }

            var requestQueue = presetEquipQueue;
            var callback = function(success:Bool):Void {
                // A reply from before a reset must not advance a newly saved
                // and activated preset's queue.
                if (!presetTransferActive || presetEquipQueue != requestQueue) return;
                if (success)
                    presetEquippedIndexes.push(targetIndex);
                equipNextPresetItem();
            };
            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    source.inventory,
                    source.index,
                    presetEquipment,
                    targetIndex,
                    null,
                    null,
                    callback
                ]);
            } catch (_:Dynamic) {
                equipNextPresetItem();
            }
            return;
        }
        cancelPresetTransfer();
    }

    static function findPresetItem(saved:Dynamic):{ inventory:Dynamic, index:Int } {
        var wantedUid = recordString(saved, "uid");
        var wantedFingerprint = recordString(saved, "fingerprint");
        var sources:Array<{inventory:Dynamic, index:Int}> = [];
        var candidates:Array<{uid:String, fingerprint:String}> = [];
        for (inventory in [presetInventory, presetEquipment]) {
            var content = getContent(inventory);
            for (index in 0...arrayLength(content)) {
                // Do not reuse a ring already assigned to an earlier slot
                // when two saved rings have the same fingerprint.
                if (inventory == presetEquipment && presetEquippedIndexes.indexOf(index) >= 0)
                    continue;
                var item = itemAt(inventory, index);
                if (item == null)
                    continue;
                sources.push({inventory: inventory, index: index});
                candidates.push({uid: itemUid(item), fingerprint: itemFingerprint(item)});
            }
        }
        var selected = EquipmentPresetMatch.choose(wantedUid, wantedFingerprint, candidates);
        return selected < 0 ? null : sources[selected];
    }

    static function cancelPresetTransfer():Void {
        presetEquipQueue = [];
        presetEquipPosition = 0;
        presetInventory = null;
        presetEquipment = null;
        presetEquippedIndexes = [];
        presetTransferActive = false;
    }

    static function drawLockHeaderButton():Void {
        if (activeInventoryUI == null || !isUiVisible(activeInventoryUI)
            || playerInventoryComp == null)
            return;
        var sortButton = fieldOrNull(playerInventoryComp, "sortButton");
        if (sortButton == null || !isUiVisible(sortButton))
            return;
        var rect = NativeUiLayout.rect(sortButton, -38, 0, 32, 30);
        if (rect == null || buttonCovered(rect.left, rect.top, rect.width, rect.height))
            return;

        prepareOverlay(rect, 32, 30, 5);
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.NoScrollWithMouse
            | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleColor(ImGuiCol.Button,
            lockEditMode ? new ImVec4(0.58, 0.43, 0.25, 1) : new ImVec4(0.40, 0.37, 0.35, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered,
            lockEditMode ? new ImVec4(0.68, 0.52, 0.31, 1) : new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive,
            lockEditMode ? new ImVec4(0.49, 0.35, 0.20, 1) : new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));

        if (ImGui.begin("##item-utilities-lock-header", null, flags)) {
            if (ImGui.button("##item-lock-mode", overlaySize(32, 30))) {
                playButtonClickSound(sortButton);
                lockEditMode = !lockEditMode;
            }
            drawLockIcon();
            if (ImGui.isItemHovered()) {
                setGameButtonCursor();
                ImGui.setTooltip(lockEditMode ? " Done editing " : " Edit locks ");
            }
        }
        ImGui.end();
        ImGui.popStyleColor(4);
        finishOverlay();
    }

    static function drawLockIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var color = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));
        ImGui.ImDrawList_AddRect(drawList,
            iconPoint(min, 9, 13),
            iconPoint(min, 23, 24), color, overlayStroke(2.0), overlayStroke(2.0), 0);
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 11, 13),
            iconPoint(min, 11, 10), color, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 11, 10),
            iconPoint(min, 14, 6), color, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 14, 6),
            iconPoint(min, 19, 6), color, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 19, 6),
            iconPoint(min, 21, 10), color, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 21, 10),
            iconPoint(min, 21, 13), color, overlayStroke(2.0));
    }

    static function drawLockSlotOverlays():Void {
        var viewport = inventoryViewportBounds();
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!isActiveLockSlot(entry, slot))
                continue;
            var item = authoritativeSlotItem(entry, slot);
            if (item == null)
                continue;

            var rect = NativeUiLayout.rect(slot, 0, 0, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE);
            if (rect == null)
                continue;
            if (entry.inventory == sourceInventory) {
                // Clip the input window itself so hidden rows cannot intercept
                // clicks on the header or outside the bag at any UI scale.
                rect = rect.clippedTo(viewport);
                if (rect == null)
                    continue;
            }
            var x = rect.left;
            var y = rect.top;
            var width = rect.width;
            var height = rect.height;
            if (buttonCovered(x, y, width, height))
                continue;

            ImGui.setNextWindowPos(new ImVec2(x, y));
            ImGui.setNextWindowSize(new ImVec2(width, height));
            ImGui.setNextWindowScroll(new ImVec2(0, 0));
            ImGui.setNextWindowBgAlpha(0);
            var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
                | ImGuiWindowFlags.NoScrollWithMouse
                | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.NoFocusOnAppearing
                | ImGuiWindowFlags.NoBackground;
            ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
            // Partial rows may be smaller than ImGui's default minimum window.
            ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize, new ImVec2(1, 1));
            if (ImGui.begin(entry.overlayId, null, flags)) {
                if (ImGui.invisibleButton("##toggle", new ImVec2(width, height)))
                    toggleItemLock(item);
                if (ImGui.isItemHovered())
                    setGameButtonCursor();
            }
            ImGui.end();
            ImGui.popStyleVar(2);
        }
    }

    static function drawLockedItemBadges():Void {
        if (activeInventoryUI == null || !isUiVisible(activeInventoryUI))
            return;
        var viewport = inventoryViewportBounds();
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!isActiveLockSlot(entry, slot))
                continue;
            var item = authoritativeSlotItem(entry, slot);
            if (!isItemLocked(item))
                continue;

            var slotRect = NativeUiLayout.rect(slot, 0, 0, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE);
            if (slotRect == null || (entry.inventory == sourceInventory
                && !slotRect.intersects(viewport)))
                continue;

            var badge = NativeUiLayout.rect(slot, 40, 7, 16, 17);
            if (badge == null || buttonCovered(badge.left, badge.top, badge.width, badge.height))
                continue;

            prepareOverlay(badge, 16, 17, 0);
            ImGui.setNextWindowBgAlpha(0);
            var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
                | ImGuiWindowFlags.NoScrollWithMouse
                | ImGuiWindowFlags.NoSavedSettings
                | ImGuiWindowFlags.NoFocusOnAppearing | ImGuiWindowFlags.NoBackground
                | ImGuiWindowFlags.NoInputs;
            if (ImGui.begin("##item-lock-badge-" + itemUid(item), null, flags)) {
                ImGui.invisibleButton("##badge", overlaySize(16, 17));
                var drawList = ImGui.getWindowDrawList();
                var clip = entry.inventory == sourceInventory ? viewport : null;
                if (clip != null)
                    ImGui.ImDrawList_PushClipRect(drawList,
                        new ImVec2(clip.left, clip.top),
                        new ImVec2(clip.right, clip.bottom), true);
                drawSmallMetalLockIcon();
                if (clip != null)
                    ImGui.ImDrawList_PopClipRect(drawList);
            }
            ImGui.end();
            finishOverlay();
        }
    }

    static function drawSmallMetalLockIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var metal = ImGui.colorConvertFloat4ToU32(new ImVec4(0.72, 0.76, 0.82, 1));
        var keyhole = ImGui.colorConvertFloat4ToU32(new ImVec4(0.20, 0.22, 0.26, 1));

        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 5, 8),
            iconPoint(min, 5, 5), metal, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 5, 5),
            iconPoint(min, 7, 2), metal, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 7, 2),
            iconPoint(min, 10, 2), metal, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 10, 2),
            iconPoint(min, 12, 5), metal, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 12, 5),
            iconPoint(min, 12, 8), metal, overlayStroke(2.0));
        ImGui.ImDrawList_AddRectFilled(drawList,
            iconPoint(min, 3, 7),
            iconPoint(min, 14, 16), metal, overlayStroke(2.0), 0);
        ImGui.ImDrawList_AddCircleFilled(drawList,
            iconPoint(min, 8.5, 11), overlayStroke(1.25), keyhole, 8);
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 8.5, 11),
            iconPoint(min, 8.5, 14), keyhole, overlayStroke(1.5));
    }

    static function drawDepositModeIcon(mode:Int):Void {
        switch (mode) {
            case DEPOSIT_ALL: drawDepositAllIcon();
            case DEPOSIT_FOOD: drawFoodDepositIcon();
            case DEPOSIT_CONSUMABLE: drawConsumableDepositIcon();
            case DEPOSIT_DEMON_ENCHANTMENT: drawDemonDepositIcon();
            case DEPOSIT_MISC: drawMiscDepositIcon();
            default: drawCraftingDepositIcon();
        }
    }

    static function drawCraftingDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var metal = ImGui.colorConvertFloat4ToU32(new ImVec4(0.78, 0.82, 0.86, 1));
        var metalShade = ImGui.colorConvertFloat4ToU32(new ImVec4(0.52, 0.58, 0.64, 1));
        var handle = ImGui.colorConvertFloat4ToU32(new ImVec4(0.63, 0.42, 0.24, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Long upright handle, drawn first so the head sits over it.
        ImGui.ImDrawList_AddRectFilled(drawList,
            iconPoint(min, 9, 9),
            iconPoint(min, 13, 19), handle, overlayStroke(1.0), 0);

        // Classic horizontal hammer head: a broad striking face on the left
        // and a narrower peen on the right.
        ImGui.ImDrawList_AddRectFilled(drawList,
            iconPoint(min, 3, 5),
            iconPoint(min, 12, 11), metal, overlayStroke(1.0), 0);
        ImGui.ImDrawList_AddQuadFilled(drawList,
            iconPoint(min, 12, 6),
            iconPoint(min, 18, 7),
            iconPoint(min, 18, 9),
            iconPoint(min, 12, 10), metalShade);

        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawFoodDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var food = ImGui.colorConvertFloat4ToU32(new ImVec4(0.86, 0.42, 0.30, 1));
        var leaf = ImGui.colorConvertFloat4ToU32(new ImVec4(0.55, 0.76, 0.38, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Apple with a leaf.
        ImGui.ImDrawList_AddCircleFilled(drawList,
            iconPoint(min, 11, 12), overlayStroke(5.5), food, 12);
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 11, 7),
            iconPoint(min, 13, 4), leaf, overlayStroke(1.5));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 13, 5),
            iconPoint(min, 17, 6), leaf, overlayStroke(2.0));
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawConsumableDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var potion = ImGui.colorConvertFloat4ToU32(new ImVec4(0.55, 0.73, 0.92, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Small potion flask.
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 9, 5),
            iconPoint(min, 14, 5), potion, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 10, 6),
            iconPoint(min, 10, 10), potion, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 13, 6),
            iconPoint(min, 13, 10), potion, overlayStroke(2.0));
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            iconPoint(min, 10, 9),
            iconPoint(min, 5, 18),
            iconPoint(min, 16, 18), potion);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDemonDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var demon = ImGui.colorConvertFloat4ToU32(new ImVec4(0.76, 0.43, 0.86, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Gem flanked by two small horns.
        ImGui.ImDrawList_AddQuadFilled(drawList,
            iconPoint(min, 11, 7),
            iconPoint(min, 16, 12),
            iconPoint(min, 11, 18),
            iconPoint(min, 6, 12), demon);
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 7, 10),
            iconPoint(min, 4, 5), demon, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 15, 10),
            iconPoint(min, 18, 5), demon, overlayStroke(2.0));
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawMiscDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var misc = ImGui.colorConvertFloat4ToU32(new ImVec4(0.77, 0.68, 0.53, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Three varied pieces represent miscellaneous items.
        ImGui.ImDrawList_AddCircleFilled(drawList,
            iconPoint(min, 7, 8), overlayStroke(2.5), misc, 8);
        ImGui.ImDrawList_AddRectFilled(drawList,
            iconPoint(min, 11, 6),
            iconPoint(min, 16, 11), misc, overlayStroke(1.0), 0);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            iconPoint(min, 7, 13),
            iconPoint(min, 12, 18),
            iconPoint(min, 3, 18), misc);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDepositAllIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var star = ImGui.colorConvertFloat4ToU32(new ImVec4(0.91, 0.70, 0.39, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Four-point sparkle communicates "all" without crowding the icon.
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 11, 5),
            iconPoint(min, 11, 18), star, overlayStroke(2.5));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 5, 11),
            iconPoint(min, 17, 11), star, overlayStroke(2.5));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 7, 7),
            iconPoint(min, 15, 15), star, overlayStroke(1.5));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 15, 7),
            iconPoint(min, 7, 15), star, overlayStroke(1.5));

        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDepositArrowAndBucket(min:ImVec2, drawList:Dynamic,
        mark:Int):Void {

        // Down arrow and receiving tray communicate "deposit" at a glance.
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 23, 6),
            iconPoint(min, 23, 16), mark, overlayStroke(2.0));
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            iconPoint(min, 19, 14),
            iconPoint(min, 27, 14),
            iconPoint(min, 23, 19), mark);
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 18, 23),
            iconPoint(min, 28, 23), mark, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 18, 19),
            iconPoint(min, 18, 23), mark, overlayStroke(2.0));
        ImGui.ImDrawList_AddLine(drawList,
            iconPoint(min, 28, 19),
            iconPoint(min, 28, 23), mark, overlayStroke(2.0));
    }

    static function setGameButtonCursor():Void {
        try {
            if (cursorType == null)
                cursorType = HlxRuntime.resolveType("hxd.Cursor");
            if (systemType == null)
                systemType = HlxRuntime.resolveType("hxd.System");
            if (cursorType == null || systemType == null)
                return;
            if (buttonCursor == null)
                buttonCursor = HlxRuntime.constructEnum(cursorType, "Button", []);
            if (!cursorResolutionAttempted) {
                cursorResolutionAttempted = true;
                setSystemCursorFn = HlxRuntime.resolveStaticField(systemType, "setCursor");
            }
            if (buttonCursor != null && setSystemCursorFn != null)
                Reflect.callMethod(null, setSystemCursorFn, [buttonCursor]);
        } catch (error:Dynamic) {
            if (!cursorErrorLogged) {
                cursorErrorLogged = true;
                trace("[ItemUtilities] button cursor failed: " + Std.string(error));
            }
        }
    }

    static function beginDeposit():Void {
        beginDepositMode(DEPOSIT_CRAFTING);
    }

    static function beginDepositMode(mode:Int):Void {
        if (!refreshInventories() || !resolveMembers()) {
            status = "Inventory is not ready.";
            return;
        }

        cancelRecyclerDeposit();
        depositMode = mode;
        transferIndexes = [];
        transferPosition = 0;
        movedStacks = 0;

        var content = getContent(sourceInventory);
        if (content == null) {
            status = "Inventory is not ready.";
            return;
        }

        for (index in 0...arrayLength(content)) {
            var stack:Dynamic = arrayGet(content, index);
            if (stack == null)
                continue;
            var item:Dynamic = HlxRuntime.resolveField(stack, "item");
            if (item != null && matchesDepositMode(item))
                transferIndexes.push(index);
        }

        if (transferIndexes.length == 0) {
            status = "No matching unlocked items to deposit.";
            return;
        }

        depositing = true;
        status = "";
        transferNext();
    }

    static function transferNext():Void {
        if (!depositing || activeBankWindow == null) {
            cancelDeposit();
            return;
        }

        var content = getContent(sourceInventory);
        while (transferPosition < transferIndexes.length) {
            var sourceIndex = transferIndexes[transferPosition];
            var stack:Dynamic = content == null || sourceIndex >= arrayLength(content) ? null : arrayGet(content, sourceIndex);
            if (stack == null) {
                transferPosition++;
                continue;
            }

            var item:Dynamic = HlxRuntime.resolveField(stack, "item");
            if (item == null || !matchesDepositMode(item)) {
                transferPosition++;
                continue;
            }

            var destination = findDestination(item);
            if (destination.index < 0) {
                // Later items may still fit into existing bank stacks.
                transferPosition++;
                continue;
            }

            var count:Dynamic = destination.count;
            var callback = function(success:Bool):Void {
                if (!depositing)
                    return;
                if (!success) {
                    // A rejected transfer must not abort the remaining batch.
                    transferPosition++;
                    transferNext();
                    return;
                }
                movedStacks++;

                // A partially filled bank stack may not consume the whole source
                // stack. Retry this source slot until it is empty, then advance.
                var current = getContent(sourceInventory);
                var remaining:Dynamic = current == null || sourceIndex >= arrayLength(current) ? null : arrayGet(current, sourceIndex);
                if (remaining == null)
                    transferPosition++;
                transferNext();
            };

            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    sourceInventory,
                    sourceIndex,
                    bankInventory,
                    destination.index,
                    null,
                    count,
                    callback
                ]);
            } catch (_:Dynamic) {
                transferPosition++;
                transferNext();
            }
            return;
        }

        depositing = false;
        status = "Deposited " + movedStacks + " stack" + (movedStacks == 1 ? "." : "s.");
    }

    static function beginRecyclerDeposit():Void {
        if (!refreshRecyclerInventories() || !resolveRecyclerMembers())
            return;

        cancelDeposit();
        recyclerTransferIndexes = [];
        recyclerTransferPosition = 0;

        var content = getContent(sourceInventory);
        if (content == null)
            return;

        for (index in 0...arrayLength(content)) {
            var item = itemAt(sourceInventory, index);
            if (item != null && !isItemLocked(item) && isRecyclerEligible(item))
                recyclerTransferIndexes.push(index);
        }

        if (recyclerTransferIndexes.length == 0)
            return;

        recyclerDepositing = true;
        transferNextToRecycler();
    }

    static function transferNextToRecycler():Void {
        if (!recyclerDepositing || activeScrapWindow == null
            || !isUiVisible(activeScrapWindow)) {
            cancelRecyclerDeposit();
            return;
        }

        var content = getContent(sourceInventory);
        while (recyclerTransferPosition < recyclerTransferIndexes.length) {
            var sourceIndex = recyclerTransferIndexes[recyclerTransferPosition];
            var item = content == null || sourceIndex >= arrayLength(content)
                ? null
                : itemAt(sourceInventory, sourceIndex);
            if (item == null || isItemLocked(item) || !isRecyclerEligible(item)) {
                recyclerTransferPosition++;
                continue;
            }

            var free:Dynamic;
            try {
                free = HlxRuntime.callResolved(getNextFreeIndexMember, [scrapInventory, item]);
            } catch (_:Dynamic) {
                recyclerTransferPosition++;
                continue;
            }
            var destinationIndex:Int = cast free;
            if (destinationIndex < 0) {
                cancelRecyclerDeposit();
                return;
            }

            var callback = function(success:Bool):Void {
                if (!recyclerDepositing)
                    return;
                // Locked items, server-side eligibility changes, and other
                // rejected transfers should not abort the rest of the batch.
                recyclerTransferPosition++;
                transferNextToRecycler();
            };

            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    sourceInventory,
                    sourceIndex,
                    scrapInventory,
                    destinationIndex,
                    null,
                    null,
                    callback
                ]);
            } catch (_:Dynamic) {
                recyclerTransferPosition++;
                transferNextToRecycler();
            }
            return;
        }

        cancelRecyclerDeposit();
    }

    static function isRecyclerEligible(item:Dynamic):Bool {
        if (item == null || isScrappableMember == null)
            return false;
        try return HlxRuntime.callResolved(isScrappableMember, [item]) == true
        catch (_:Dynamic) return false;
    }

    static function transferNextLockedSortItem():Void {
        if (!lockedSortActive || lockedSortInventory == null) {
            cancelLockedSort(false);
            return;
        }

        if (lockedSortPendingMoves.length > 0) {
            dispatchLockedSortMove();
            return;
        }

        while (lockedSortPosition < lockedSortDesiredItems.length
            && lockedSortPosition < lockedSortTargetIndexes.length) {
            var desiredItem = lockedSortDesiredItems[lockedSortPosition];
            var targetIndex = lockedSortTargetIndexes[lockedSortPosition];
            var targetItem = itemAt(lockedSortInventory, targetIndex);

            // A lock added while sorting is in progress becomes fixed
            // immediately, even though it was not part of the initial set.
            if (isItemLocked(targetItem)) {
                lockedSortSucceeded = false;
                lockedSortPosition++;
                continue;
            }
            if (itemsEqual(targetItem, desiredItem)) {
                lockedSortPosition++;
                continue;
            }

            var sourceIndex = -1;
            var content = getContent(lockedSortInventory);
            for (index in 0...arrayLength(content)) {
                if (index == targetIndex
                    || (index < lockedSortFixedIndexes.length
                        && lockedSortFixedIndexes[index]))
                    continue;
                var candidate = itemAt(lockedSortInventory, index);
                if (!isItemLocked(candidate) && itemsEqual(candidate, desiredItem)) {
                    sourceIndex = index;
                    break;
                }
            }

            if (sourceIndex < 0) {
                lockedSortSucceeded = false;
                lockedSortPosition++;
                continue;
            }

            if (targetItem == null) {
                lockedSortPendingMoves.push({
                    source: sourceIndex,
                    destination: targetIndex
                });
            } else {
                // Farever's own compression code only requests transfers into
                // empty slots. Use one unlocked empty slot as a temporary so
                // an occupied target is reordered through the same safe path.
                var emptyIndex = -1;
                for (index in 0...arrayLength(content)) {
                    if (index != sourceIndex && index != targetIndex
                        && (index >= lockedSortFixedIndexes.length
                            || !lockedSortFixedIndexes[index])
                        && itemAt(lockedSortInventory, index) == null) {
                        emptyIndex = index;
                        break;
                    }
                }
                if (emptyIndex >= 0) {
                    lockedSortPendingMoves.push({
                        source: targetIndex,
                        destination: emptyIndex
                    });
                    lockedSortPendingMoves.push({
                        source: sourceIndex,
                        destination: targetIndex
                    });
                    lockedSortPendingMoves.push({
                        source: emptyIndex,
                        destination: sourceIndex
                    });
                } else {
                    // A completely full inventory has no temporary slot. The
                    // native transfer path can swap two different stacks.
                    lockedSortPendingMoves.push({
                        source: sourceIndex,
                        destination: targetIndex
                    });
                }
            }
            dispatchLockedSortMove();
            return;
        }

        finishLockedSort();
    }

    static function dispatchLockedSortMove():Void {
        if (!lockedSortActive || lockedSortWaiting
            || lockedSortPendingMoves.length == 0)
            return;
        var move = lockedSortPendingMoves[0];
        var sourceIndex:Int = cast Reflect.field(move, "source");
        var destinationIndex:Int = cast Reflect.field(move, "destination");
        var callback = function(success:Bool):Void {
            if (!lockedSortActive)
                return;
            lockedSortWaiting = false;
            if (!success) {
                lockedSortSucceeded = false;
                finishLockedSort();
                return;
            }
            lockedSortPendingMoves.shift();
            if (lockedSortPendingMoves.length == 0)
                lockedSortPosition++;
        };

        try {
            lockedSortWaiting = true;
            HlxRuntime.callResolved(requestTransferMember, [
                lockedSortInventory,
                sourceIndex,
                lockedSortInventory,
                destinationIndex,
                null,
                null,
                callback
            ]);
        } catch (_:Dynamic) {
            lockedSortWaiting = false;
            lockedSortSucceeded = false;
            finishLockedSort();
        }
    }

    static function itemsEqual(left:Dynamic, right:Dynamic):Bool {
        if (left == null || right == null || equalsMember == null)
            return left == right;
        try return HlxRuntime.callResolved(equalsMember, [left, right]) == true
        catch (_:Dynamic) return left == right;
    }

    static function finishLockedSort():Void {
        var callback = lockedSortCallback;
        var success = lockedSortSucceeded;
        cancelLockedSort(false);
        if (callback != null)
            try Reflect.callMethod(null, callback, [success]) catch (_:Dynamic) {}
    }

    static function findDestination(item:Dynamic):{ index:Int, count:Dynamic } {
        var bankContent = getContent(bankInventory);
        if (bankContent != null) {
            for (index in 0...arrayLength(bankContent)) {
                var stack:Dynamic = arrayGet(bankContent, index);
                if (stack == null)
                    continue;
                var other:Dynamic = HlxRuntime.resolveField(stack, "item");
                if (other == null)
                    continue;
                var same:Dynamic = HlxRuntime.callResolved(equalsMember, [item, other]);
                if (same != true)
                    continue;
                var full:Dynamic = HlxRuntime.callResolved(isMaxStackMember, [bankInventory, index]);
                if (full == true)
                    continue;

                var capacity:Dynamic = HlxRuntime.callResolved(getSlotStackSizeMember, [bankInventory, index]);
                var current:Dynamic = HlxRuntime.resolveField(stack, "count");
                var space:Int = cast capacity - cast current;
                return { index: index, count: space };
            }
        }

        var free:Dynamic = HlxRuntime.callResolved(getNextFreeIndexMember, [bankInventory, item]);
        return { index: cast free, count: null };
    }

    static function isCraftingComponent(item:Dynamic):Bool {
        return isItemType(item, CRAFTING_COMPONENT_TYPE);
    }

    static function matchesDepositMode(item:Dynamic):Bool {
        if (item == null || isItemLocked(item))
            return false;
        return switch (depositMode) {
            case DEPOSIT_ALL: true;
            case DEPOSIT_FOOD: isItemType(item, "Food");
            case DEPOSIT_CONSUMABLE:
                isItemType(item, "Consumable") && !isItemType(item, "Food")
                    && !isDemonEnchantment(item);
            case DEPOSIT_DEMON_ENCHANTMENT: isDemonEnchantment(item);
            case DEPOSIT_MISC:
                isItemType(item, "Misc") && !isDemonEnchantment(item);
            default: isCraftingComponent(item);
        };
    }

    static function isDemonEnchantment(item:Dynamic):Bool {
        return isItemType(item, "AugmentDemon")
            || isItemType(item, "AugmentDemonSigil");
    }

    static function isItemType(item:Dynamic, type:String):Bool {
        if (item == null || isTypeMember == null)
            return false;
        try {
            return HlxRuntime.callResolved(isTypeMember, [item, type]) == true;
        } catch (_:Dynamic) {
            return false;
        }
    }

    static function refreshInventories():Bool {
        if (activeBankWindow == null)
            return false;
        try {
            if (bankInventory == null)
                bankInventory = HlxRuntime.resolveField(activeBankWindow, "inventory");
            selectSourceInventory();
            if (sourceInventory == null)
                sourceInventory = resolveHeroInventory();
        } catch (_:Dynamic) {
            return false;
        }
        return sourceInventory != null && bankInventory != null;
    }

    static function refreshRecyclerInventories():Bool {
        if (activeScrapWindow == null || !isUiVisible(activeScrapWindow))
            return false;
        try {
            if (scrapInventory == null)
                scrapInventory = resolveScrapInventory(activeScrapWindow);
            selectSourceInventory();
            if (sourceInventory == null)
                ensureHeroInventory();
            selectPlayerInventoryComp();
            selectScrapInventoryComp();
        } catch (_:Dynamic) {
            return false;
        }
        return sourceInventory != null && scrapInventory != null
            && scrapInventoryComp != null;
    }

    static function resolveScrapInventory(window:Dynamic):Dynamic {
        if (window == null)
            return null;
        try {
            if (scrapWindowType == null)
                scrapWindowType = HlxRuntime.resolveType("ui.win.Scrap");
            if (scrapWindowType != null && getScrapInventoryMember == null)
                getScrapInventoryMember = HlxRuntime.resolveMember(
                    scrapWindowType,
                    "get_inventory"
                );
            return getScrapInventoryMember == null
                ? null
                : HlxRuntime.callResolved(getScrapInventoryMember, [window]);
        } catch (error:Dynamic) {
            logLockError("recycler inventory", error);
            return null;
        }
    }

    static function resolveHeroInventory():Dynamic {
        try {
            if (bankWindowType == null)
                bankWindowType = HlxRuntime.resolveType("ui.win.BankWindow");
            if (bankWindowType == null)
                return null;
            if (getMyHeroMember == null)
                getMyHeroMember = HlxRuntime.resolveMember(bankWindowType, "get_myHero");
            if (getMyHeroMember == null) {
                trace("[ItemUtilities] get_myHero could not be resolved");
                return null;
            }

            var hero:Dynamic = HlxRuntime.callResolved(getMyHeroMember, [activeBankWindow]);
            var loadout:Dynamic = hero == null ? null : HlxRuntime.resolveField(hero, "loadout");
            var inventory:Dynamic = loadout == null ? null : HlxRuntime.resolveField(loadout, "inventory");
            return inventory;
        } catch (error:Dynamic) {
            trace("[ItemUtilities] hero fallback failed: " + Std.string(error));
            return null;
        }
    }

    static function selectSourceInventory():Void {
        sourceInventory = null;
        activeInventoryWindow = null;
        for (entry in openInventoryWindows) {
            if (entry.window == activeBankWindow || entry.inventory == bankInventory
                || entry.window == activeScrapWindow || entry.inventory == scrapInventory)
                continue;
            activeInventoryWindow = entry.window;
            sourceInventory = entry.inventory;
            return;
        }
    }

    static function ensureHeroInventory():Void {
        if (sourceInventory != null)
            return;
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        if (loadout != null)
            sourceInventory = fieldOrNull(loadout, "inventory");
    }

    static function selectPlayerInventoryComp():Void {
        playerInventoryComp = null;
        if (sourceInventory == null)
            return;

        if (activeInventoryUI != null) {
            var inventoryUiComp = fieldOrNull(activeInventoryUI, "inventoryComp");
            if (inventoryUiComp != null
                && fieldOrNull(inventoryUiComp, "inventory") == sourceInventory) {
                playerInventoryComp = inventoryUiComp;
                return;
            }
        }

        // InventoryWindow.init creates and assigns its `comp` before this
        // mod's postfix runs. Prefer that direct reference: InventoryComp.init
        // is not reliably dispatched by every HLX/Farever build.
        if (activeInventoryWindow != null) {
            var directComp = fieldOrNull(activeInventoryWindow, "comp");
            if (directComp != null && fieldOrNull(directComp, "inventory") == sourceInventory) {
                playerInventoryComp = directComp;
                return;
            }
        }

        for (comp in inventoryComps) {
            if (fieldOrNull(comp, "inventory") == sourceInventory) {
                playerInventoryComp = comp;
                return;
            }
        }
    }

    static function selectScrapInventoryComp():Void {
        scrapInventoryComp = null;
        if (scrapInventory == null)
            return;
        for (comp in inventoryComps) {
            if (fieldOrNull(comp, "inventory") == scrapInventory
                && (activeScrapWindow == null
                    || isAncestorOf(activeScrapWindow, comp))) {
                scrapInventoryComp = comp;
                return;
            }
        }
    }

    static function isUiVisible(object:Dynamic):Bool {
        if (object == null || fieldOrNull(object, "parent") == null)
            return false;
        var current = object;
        while (current != null) {
            if (fieldOrNull(current, "visible") == false)
                return false;
            current = fieldOrNull(current, "parent");
        }
        return true;
    }

    static function inventoryViewportBounds():OverlayRect {
        var viewport = fieldOrNull(playerInventoryComp, "invContent");
        if (viewport == null || !isUiVisible(viewport))
            return null;
        var rawWidth = fieldOrNull(viewport, "calculatedWidth");
        var rawHeight = fieldOrNull(viewport, "calculatedHeight");
        if (rawWidth == null || rawHeight == null)
            return null;
        return NativeUiLayout.rect(viewport, 0, 0, cast rawWidth, cast rawHeight);
    }

    static function isActiveInventoryGridSlot(entry:Dynamic, slot:Dynamic):Bool {
        if (slot == null || entry.inventory != sourceInventory || !isUiVisible(slot))
            return false;
        var viewport = fieldOrNull(playerInventoryComp, "invContent");
        return viewport != null && isUiVisible(viewport) && isAncestorOf(viewport, slot);
    }

    static function isActiveLockSlot(entry:Dynamic, slot:Dynamic):Bool {
        return isActiveInventoryGridSlot(entry, slot)
            || isActiveEquipmentSlot(entry, slot);
    }

    static function isActiveEquipmentSlot(entry:Dynamic, slot:Dynamic):Bool {
        if (slot == null || activeCharacterUI == null
            || !isUiVisible(activeCharacterUI) || !isUiVisible(slot)
            || !isAncestorOf(activeCharacterUI, slot))
            return false;
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        var equipment = fieldOrNull(loadout, "equipment");
        return equipment != null && entry.inventory == equipment;
    }

    static function authoritativeSlotItem(entry:Dynamic, slot:Dynamic):Dynamic {
        var item = itemAt(entry.inventory, entry.index);
        return item != null ? item : displayedSlotItem(entry, slot);
    }

    static function displayedSlotItem(entry:Dynamic, slot:Dynamic):Dynamic {
        var item = fieldOrNull(slot, "item");
        return item != null ? item : itemAt(entry.inventory, entry.index);
    }

    static function registerSlot(slot:Dynamic):Void {
        // Initialization and item checks can run while a slot is detached.
        // Its next attached update registers it again, even with the same item.
        if (fieldOrNull(slot, "allocated") != true) {
            unregisterSlot(slot);
            return;
        }
        var inventory = fieldOrNull(slot, "inventory");
        var rawIndex = fieldOrNull(slot, "index");
        if (inventory == null || rawIndex == null) {
            unregisterSlot(slot);
            return;
        }
        var index:Int = cast rawIndex;
        // Key by the UI object so tooltip previews cannot replace grid slots.
        var entry = slotsByObject.get(slot);
        if (entry != null) {
            entry.inventory = inventory;
            entry.index = index;
            return;
        }
        // Inventory and equipment reuse slot indexes. ImGui needs a distinct,
        // stable window ID for each UI slot, even when the tracked list moves it.
        entry = {
            inventory: inventory,
            index: index,
            slot: slot,
            listIndex: visibleSlots.length,
            overlayId: "##item-lock-slot-" + nextSlotOverlayId++
        };
        slotsByObject.set(slot, entry);
        visibleSlots.push(entry);
    }

    static function unregisterSlot(slot:Dynamic):Void {
        var entry = slotsByObject.get(slot);
        if (entry == null)
            return;
        slotsByObject.remove(slot);
        // Fill the gap with the last entry, avoiding another list search or shift.
        var last = visibleSlots.pop();
        if (entry.listIndex < visibleSlots.length) {
            visibleSlots[entry.listIndex] = last;
            last.listIndex = entry.listIndex;
        }
    }

    static function buttonCovered(x:Float, y:Float, width:Float, height:Float):Bool {
        return tooltipOverlaps(x, y, width, height)
            || windowOverlaps(x, y, width, height);
    }

    static function tooltipOverlaps(x:Float, y:Float, width:Float, height:Float):Bool {
        try {
            var tip = activeTooltip;
            if (tip == null || fieldOrNull(tip, "parent") == null
                || fieldOrNull(tip, "visible") == false)
                return false;
            if (haxe.Timer.stamp() - activeTooltipShownAt < TOOLTIP_BUTTON_DELAY)
                return false;

            // Ignore the tooltip's transparent outer padding/shadow so a
            // merely adjacent tooltip does not make the button disappear.
            return objectOverlaps(tip, x, y, width, height, TOOLTIP_OVERLAP_INSET);
        } catch (error:Dynamic) {
            logLockError("tooltip bounds", error);
            return false;
        }
    }

    static function windowOverlaps(x:Float, y:Float, width:Float, height:Float):Bool {
        if (windowOccluders == null) collectWindowOccluders();
        var area = new OverlayRect(x, y, x + width, y + height);
        for (bounds in windowOccluders)
            if (bounds.intersects(area)) return true;
        return false;
    }

    static function collectWindowOccluders():Void {
        // The same panel protects badges, lock-edit hit targets, preset buttons
        // and deposit controls. Resolve it once per frame, not once per item.
        windowOccluders = [];
        try {
            var windows = fieldOrNull(activeBaseUI, "windows");
            for (index in 0...arrayLength(windows)) {
                var window = arrayGet(windows, index);
                if (window == null || window == activeBankWindow
                    || window == activeScrapWindow
                    || window == activeCharacterUI
                    || window == activeInventoryWindow
                    || isAncestorOf(window, activeInventoryUI)
                    || isAncestorOf(window, playerInventoryComp))
                    continue;
                if (!isUiVisible(window)) continue;
                var bounds = NativeUiLayout.windowBounds(window);
                if (bounds != null) windowOccluders.push(bounds);
            }
        } catch (error:Dynamic) {
            logLockError("window bounds", error);
        }
    }

    static function isAncestorOf(ancestor:Dynamic, object:Dynamic):Bool {
        if (ancestor == null || object == null)
            return false;
        var current = object;
        while (current != null) {
            if (current == ancestor)
                return true;
            current = fieldOrNull(current, "parent");
        }
        return false;
    }

    static function objectOverlaps(object:Dynamic, x:Float, y:Float,
        width:Float, height:Float, inset:Float):Bool {
        var bounds = NativeUiLayout.objectBounds(object, inset);
        return bounds != null && bounds.intersects(new OverlayRect(x, y, x + width, y + height));
    }

    static function toggleItemLock(item:Dynamic):Void {
        var locked = !isItemLocked(item);
        reconcileItemLocks();
        var uid = itemUid(item);
        var fingerprint = itemFingerprint(item);
        var characterId = heroPersistentId(resolveHero());
        if (uid == null || fingerprint == null || characterId == null)
            return;
        var current:Map<String, Dynamic> = new Map();
        if (!isLockLoadoutReady() || !collectTrackedItems(current))
            return;
        var tracked = current.get(uid);
        if (tracked == null || tracked.item != item || tracked.characterId != characterId)
            return;
        tracked.fingerprint = fingerprint;
        fingerprintCache.set(uid, {item: item, fingerprint: fingerprint});
        if (ItemLockState.setLocked(lockRecords, current, tracked, locked))
            saveConfig();
    }

    static function isItemLocked(item:Dynamic):Bool {
        if (!enabled.get() || item == null)
            return false;
        var app = currentGameApp();
        var hero = fieldOrNull(app, "hero");
        var characterId = hero == null ? null : characterIdFromApp(app);
        if (characterId == null || lockState.hero != hero || lockState.characterId != characterId)
            return false;
        for (record in lockRecords)
            if (record.characterId == characterId && record.restored == true
                && record.item == item)
                return true;
        return false;
    }

    static function reconcileItemLocks():Void {
        try {
            refreshActiveHero();
            if (lockRecords.length == 0 || !isLockLoadoutReady())
                return;
            var current:Map<String, Dynamic> = new Map();
            if (!collectTrackedItems(current))
                return;
            if (ItemLockState.reconcile(lockRecords, current, lockState.characterId, true))
                saveConfig();
        } catch (error:Dynamic) {
            logLockError("lock restoration", error);
        }
    }

    static function isLockLoadoutReady():Bool {
        var app = currentGameApp();
        if (app == null || lockState.hero == null || lockState.characterId == null)
            return false;
        if (getIsLoadingMember == null && gameAppType != null)
            getIsLoadingMember = HlxRuntime.resolveMember(gameAppType, "get_isLoading");
        // The native loading state covers initial replication. Merely seeing
        // an inventory object is insufficient: equipment may still be loading.
        return getIsLoadingMember != null
            && HlxRuntime.callResolved(getIsLoadingMember, [app]) == false;
    }

    static function itemMatchesFingerprint(item:Dynamic, saved:String):Bool {
        return item != null && ItemLockState.fingerprintMatches(saved, itemFingerprint(item));
    }

    static function collectTrackedItems(result:Map<String, Dynamic>):Bool {
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        var loadout = fieldOrNull(hero, "loadout");
        var inventory = fieldOrNull(loadout, "inventory");
        var equipment = fieldOrNull(loadout, "equipment");
        if (characterId == null || getContent(inventory) == null || getContent(equipment) == null)
            return false;
        // Only the current hero's containers belong to this character. UI
        // sourceInventory can still point at the previous hero during login.
        var inventories:Array<Dynamic> = [];
        addTrackedInventory(inventories, inventory, "inventory", characterId);
        addTrackedInventory(inventories, equipment, "equipment", characterId);
        var confirmed:Map<String, Dynamic> = new Map();
        for (record in lockRecords)
            if (record.characterId == characterId && record.restored == true)
                confirmed.set(record.uid, record.item);
        var complete = true;
        var nextCache:Map<String, {item:Dynamic, fingerprint:String}> = new Map();
        for (entry in inventories) {
            var content = getContent(entry.inventory);
            for (index in 0...arrayLength(content)) {
                var item = itemAt(entry.inventory, index);
                if (item == null) continue;
                var uid = itemUid(item);
                if (uid == null || fieldOrNull(item, "inf") == null) {
                    complete = false;
                    continue;
                }
                var cached = fingerprintCache.get(uid);
                var fingerprint = cached != null && cached.item == item
                    ? cached.fingerprint : null;
                // Refresh confirmed objects so upgrades/enchantments are saved.
                if (fingerprint == null || confirmed.get(uid) == item) {
                    fingerprint = itemFingerprint(item);
                }
                if (fingerprint == null) {
                    complete = false;
                    continue;
                }
                result.set(uid, {uid: uid, fingerprint: fingerprint,
                    item: item, inventory: entry.inventory,
                    location: entry.location, index: index, characterId: characterId});
                nextCache.set(uid, {item: item, fingerprint: fingerprint});
            }
        }
        // Do not retain discarded/transferred item objects for the session.
        fingerprintCache = nextCache;
        return complete;
    }

    static function addTrackedInventory(inventories:Array<Dynamic>, inventory:Dynamic,
        location:String, characterId:String):Void {
        if (inventory == null)
            return;
        for (entry in inventories) {
            if (entry.inventory == inventory) {
                if (entry.characterId == null && characterId != null)
                    entry.characterId = characterId;
                return;
            }
        }
        inventories.push({ inventory: inventory, location: location, characterId: characterId });
    }

    static function heroPersistentId(hero:Dynamic):String {
        var app = currentGameApp();
        if (hero == null || hero != fieldOrNull(app, "hero"))
            return null;
        return characterIdFromApp(app);
    }

    static function characterIdFromApp(app:Dynamic):String {
        var connectionInfo = fieldOrNull(app, "connectionInfo");
        var heroId = fieldOrNull(connectionInfo, "heroID");
        if (heroId == null)
            return null;
        var value = Std.string(heroId);
        return value.length == 0 || value == "0" ? null : "db:" + value;
    }

    static function gameConnectionInfo():Dynamic {
        return fieldOrNull(currentGameApp(), "connectionInfo");
    }

    static function currentGameApp():Dynamic {
        try {
            if (gameAppType == null)
                gameAppType = HlxRuntime.resolveType("GameApp");
            if (gameAppType != null && getGameAppFn == null)
                getGameAppFn = HlxRuntime.resolveStaticField(gameAppType, "get");
            var app = getGameAppFn == null
                ? null
                : Reflect.callMethod(null, getGameAppFn, []);
            return app;
        } catch (error:Dynamic) {
            logLockError("game app", error);
            return null;
        }
    }

    static function refreshActiveHero():Void {
        try {
            var app = currentGameApp();
            var hero = fieldOrNull(app, "hero");
            var loadout = fieldOrNull(hero, "loadout");
            var inventory = fieldOrNull(loadout, "inventory");
            if (!lockState.updateSession(lockRecords, hero, hero == null ? null : characterIdFromApp(app),
                fieldOrNull(app, "host"), inventory, fieldOrNull(loadout, "equipment")))
                return;
            sourceInventory = inventory;
            fingerprintCache = new Map();
            nextLockReconcileAt = 0;
        } catch (error:Dynamic) {
            logLockError("active hero refresh", error);
        }
    }

    static function resolveHero():Dynamic {
        // Resolution is read-only. Session tracking has its own identity and
        // cannot be pre-populated by UI initialization or preset lookups.
        return fieldOrNull(currentGameApp(), "hero");
    }

    static function itemAt(inventory:Dynamic, index:Int):Dynamic {
        var content = getContent(inventory);
        var stack = index < 0 || index >= arrayLength(content) ? null : arrayGet(content, index);
        return stack == null ? null : fieldOrNull(stack, "item");
    }

    static function itemUid(item:Dynamic):String {
        var value = fieldOrNull(item, "__uid");
        return value == null ? null : Std.string(value);
    }

    static function itemFingerprint(item:Dynamic):String {
        if (item == null)
            return null;
        try {
            return ITEM_FINGERPRINT_VERSION + Json.stringify(itemFingerprintParts(item));
        } catch (error:Dynamic) {
            logLockError("fingerprint", error);
            return null;
        }
    }

    static function itemFingerprintParts(item:Dynamic):Array<String> {
        var flags = fieldOrNull(item, "flags");
        var definition = fieldOrNull(item, "inf");
        return [
            fingerprintValue(fieldOrNull(item, "kind")),
            fingerprintValue(fieldOrNull(flags, "value")),
            fingerprintArray(fieldOrNull(item, "slots")),
            fingerprintValue(fieldOrNull(item, "level")),
            fingerprintValue(fieldOrNull(item, "upgradeLevel")),
            fingerprintValue(fieldOrNull(item, "rarity")),
            fingerprintValue(fieldOrNull(definition, "rarity")),
            // Absent on the live client; normalize null and empty to the
            // same identity as uninfused PTR gear.
            infusionIdentity(fieldOrNull(item, "infusion")),
            infusionIdentity(fieldOrNull(item, "infusionBonusStat"))
        ];
    }

    static function infusionIdentity(value:Dynamic):String {
        return value == null ? "" : Std.string(value);
    }

    static function fingerprintValue(value:Dynamic):String {
        return value == null ? "<null>" : Std.string(value);
    }

    static function fingerprintArray(value:Dynamic):String {
        // Replicated gear slots are exposed through hxbit.ArrayProxyData.
        // Its backing store is ArrayDyn, which needs its own resolved methods.
        var inner = fieldOrNull(value, "array");
        var parts:Array<String> = [];
        if (inner != null) {
            for (index in 0...arrayDynLength(inner))
                parts.push(fingerprintValue(arrayDynGet(inner, index)));
            return Json.stringify(parts);
        }
        for (index in 0...arrayLength(value))
            parts.push(fingerprintValue(arrayGet(value, index)));
        return Json.stringify(parts);
    }

    static function playButtonClickSound(referenceButton:Dynamic):Void {
        if (referenceButton == null)
            return;
        try {
            if (!resolveUiMembers())
                return;
            if (playClickFeedbackMember == null)
                playClickFeedbackMember = HlxRuntime.resolveMember(uiElementType, "playClickFeedBack");
            if (playClickFeedbackMember == null)
                return;
            // UIElement.click() calls this after a successful native click. It
            // owns the exact UI_Button_Click SFX and visual feedback without
            // invoking the Sort button's action.
            HlxRuntime.callResolved(playClickFeedbackMember, [referenceButton]);
        } catch (error:Dynamic) {
            logLockError("button click sound", error);
        }
    }

    static function fieldOrNull(object:Dynamic, name:String):Dynamic {
        if (object == null)
            return null;
        try return HlxRuntime.resolveField(object, name) catch (_:Dynamic) return null;
    }

    static function recordString(record:Dynamic, name:String):String {
        var value = Reflect.field(record, name);
        return value == null ? null : Std.string(value);
    }

    static function recordInt(record:Dynamic, name:String, fallback:Int):Int {
        var value = Reflect.field(record, name);
        return value == null ? fallback : cast value;
    }

    static function logLockError(area:String, error:Dynamic):Void {
        var message = Std.string(error);
        var key = area + ":" + message;
        if (lockErrors.exists(key))
            return;
        lockErrors.set(key, true);
        trace("[ItemUtilities] item locking error (" + area + "): " + message);
    }

    static function getContent(inventory:Dynamic):Dynamic {
        if (inventory == null)
            return null;
        try {
            // `content` is the authoritative replicated array, but Farever can
            // leave it null on the client while exposing the materialized slot
            // array through `stacks`.
            var content:Dynamic = HlxRuntime.resolveField(inventory, "content");
            if (content != null)
                return content;
            var stacks:Dynamic = HlxRuntime.resolveField(inventory, "stacks");
            if (stacks != null)
                return stacks;
        } catch (error:Dynamic) {
            trace("[ItemUtilities] inventory slot access failed: " + Std.string(error));
        }
        return null;
    }

    static function arrayLength(array:Dynamic):Int {
        if (array == null)
            return 0;
        try return cast HlxRuntime.resolveField(array, "length") catch (_:Dynamic) return 0;
    }

    static function arrayGet(array:Dynamic, index:Int):Dynamic {
        if (array == null)
            return null;
        try {
            if (arrayObjType == null)
                arrayObjType = HlxRuntime.resolveType("hl.types.ArrayObj");
            if (arrayObjType == null)
                return null;
            if (arrayGetDynMember == null)
                arrayGetDynMember = HlxRuntime.resolveMember(arrayObjType, "getDyn");
            if (arrayGetDynMember == null)
                return null;
            return HlxRuntime.callResolved(arrayGetDynMember, [array, index]);
        } catch (error:Dynamic) {
            trace("[ItemUtilities] typed array read failed at " + index + ": " + Std.string(error));
            return null;
        }
    }

    static function arrayDynLength(array:Dynamic):Int {
        if (array == null)
            return 0;
        try {
            if (arrayDynType == null)
                arrayDynType = HlxRuntime.resolveType("hl.types.ArrayDyn");
            if (arrayDynType == null)
                return 0;
            if (arrayDynGetLengthMember == null)
                arrayDynGetLengthMember = HlxRuntime.resolveMember(arrayDynType, "get_length");
            if (arrayDynGetLengthMember == null)
                return 0;
            var result = HlxRuntime.callResolved(arrayDynGetLengthMember, [array]);
            return result == null ? 0 : cast result;
        } catch (error:Dynamic) {
            logLockError("gear slot count", error);
            return 0;
        }
    }

    static function arrayDynGet(array:Dynamic, index:Int):Dynamic {
        if (array == null)
            return null;
        try {
            if (arrayDynType == null)
                arrayDynType = HlxRuntime.resolveType("hl.types.ArrayDyn");
            if (arrayDynType == null)
                return null;
            if (arrayDynGetDynMember == null)
                arrayDynGetDynMember = HlxRuntime.resolveMember(arrayDynType, "getDyn");
            if (arrayDynGetDynMember == null)
                return null;
            return HlxRuntime.callResolved(arrayDynGetDynMember, [array, index]);
        } catch (error:Dynamic) {
            logLockError("gear slot read", error);
            return null;
        }
    }

    static function resolveMembers():Bool {
        if (itemType == null) itemType = HlxRuntime.resolveType("st.Item");
        if (inventoryType == null) inventoryType = HlxRuntime.resolveType("st.Inventory");
        if (itemType == null || inventoryType == null)
            return false;

        if (isTypeMember == null) isTypeMember = HlxRuntime.resolveMember(itemType, "isType");
        if (equalsMember == null) equalsMember = HlxRuntime.resolveMember(itemType, "equals");
        if (isMaxStackMember == null) isMaxStackMember = HlxRuntime.resolveMember(inventoryType, "isMaxStack");
        if (getSlotStackSizeMember == null) getSlotStackSizeMember = HlxRuntime.resolveMember(inventoryType, "getSlotStackSize");
        if (getNextFreeIndexMember == null) getNextFreeIndexMember = HlxRuntime.resolveMember(inventoryType, "getNextFreeIndex");
        if (requestTransferMember == null) requestTransferMember = HlxRuntime.resolveMember(inventoryType, "requestTransfer");

        return isTypeMember != null && equalsMember != null
            && isMaxStackMember != null && getSlotStackSizeMember != null
            && getNextFreeIndexMember != null && requestTransferMember != null;
    }

    static function resolveRecyclerMembers():Bool {
        if (!resolveMembers())
            return false;
        if (scrapStationType == null)
            scrapStationType = HlxRuntime.resolveType("ent.interactible.ScrapStation");
        if (scrapStationType != null && isScrappableMember == null)
            isScrappableMember = HlxRuntime.resolveStaticMember(
                scrapStationType,
                "isScrappable"
            );
        return isScrappableMember != null;
    }

    static function installDepositButton():Void {
        try {
            if (!resolveUiMembers())
                return;

            var inventoryComp:Dynamic = HlxRuntime.resolveField(activeBankWindow, "comp");
            var sortButton:Dynamic = inventoryComp == null ? null : HlxRuntime.resolveField(inventoryComp, "sortButton");
            var sortProperties:Dynamic = sortButton == null ? null : HlxRuntime.resolveField(sortButton, "dom");
            if (sortProperties == null)
                return;

            var parentProperties:Dynamic = HlxRuntime.callResolved(getParentPropertiesMember, [sortProperties]);
            if (parentProperties == null)
                return;

            var createdProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button-icon",
                parentProperties,
                ["Item_Transfer"],
                { id: "depositCraftingMaterials" }
            ]);
            if (createdProperties == null)
                return;

            depositButton = HlxRuntime.resolveField(createdProperties, "obj");
            if (depositButton == null)
                return;

            HlxRuntime.callResolved(setOnClickMember, [depositButton, beginDeposit]);
            HlxRuntime.callResolved(setTextTipMember, [depositButton, "Deposit Crafting Components"]);

            // Domkit appends new components. Move ours immediately after Sort so
            // it behaves like a native part of the inventory header.
            var parentObject:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
            if (parentObject != null) {
                var sortIndex:Dynamic = HlxRuntime.callResolved(getChildIndexMember, [parentObject, sortButton]);
                if (sortIndex != null && cast sortIndex >= 0)
                    HlxRuntime.callResolved(addChildAtMember, [parentObject, depositButton, cast sortIndex + 1]);
            }

            syncDepositButtonVisibility();
        } catch (_:Dynamic) {
            depositButton = null;
        }
    }

    static function syncDepositButtonVisibility():Void {
        if (depositButton == null || !resolveUiMembers())
            return;
        try HlxRuntime.callResolved(setVisibleMember, [depositButton, enabled.get() && showDepositMaterials.get()]) catch (_:Dynamic) {}
    }

    static function resolveUiMembers():Bool {
        if (propertiesType == null) propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (uiElementType == null) uiElementType = HlxRuntime.resolveType("ui.UIElement");
        if (h2dObjectType == null) h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (propertiesType == null || uiElementType == null || h2dObjectType == null)
            return false;

        if (createNewMember == null) createNewMember = HlxRuntime.resolveStaticMember(propertiesType, "createNew");
        if (getParentPropertiesMember == null) getParentPropertiesMember = HlxRuntime.resolveMember(propertiesType, "get_parent");
        if (setOnClickMember == null) setOnClickMember = HlxRuntime.resolveMember(uiElementType, "set_onClick");
        if (setTextTipMember == null) setTextTipMember = HlxRuntime.resolveMember(uiElementType, "set_textTip");
        if (setVisibleMember == null) setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
        if (getChildIndexMember == null) getChildIndexMember = HlxRuntime.resolveMember(h2dObjectType, "getChildIndex");
        if (addChildAtMember == null) addChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "addChildAt");

        return createNewMember != null && getParentPropertiesMember != null
            && setOnClickMember != null && setTextTipMember != null && setVisibleMember != null
            && getChildIndexMember != null && addChildAtMember != null;
    }

    static function cancelDeposit():Void {
        depositing = false;
        transferIndexes = [];
        transferPosition = 0;
    }

    static function cancelRecyclerDeposit():Void {
        recyclerDepositing = false;
        recyclerTransferIndexes = [];
        recyclerTransferPosition = 0;
    }

    static function cancelLockedSort(notifyFailure:Bool):Void {
        var callback = lockedSortCallback;
        lockedSortActive = false;
        lockedSortInventory = null;
        lockedSortDesiredItems = [];
        lockedSortTargetIndexes = [];
        lockedSortFixedIndexes = [];
        lockedSortPosition = 0;
        lockedSortCallback = null;
        lockedSortSucceeded = true;
        lockedSortWaiting = false;
        lockedSortPendingMoves = [];
        if (notifyFailure && callback != null)
            try Reflect.callMethod(null, callback, [false]) catch (_:Dynamic) {}
    }

    static function checkPresetHotkeys():Void {
        if (presetTransferActive)
            return;
        for (preset in 0...PresetSlots.COUNT) {
            var key = presetHotkeyKeys[preset];
            if (key > 0 && isGameKeyPressed(key)) {
                selectEquipmentPreset(preset);
                activateEquipmentPreset(preset);
                return;
            }
        }
    }

    static function checkTalentPresetHotkeys():Void {
        if (talentPresetTransfer.active) return;
        for (preset in 0...PresetSlots.COUNT) {
            var key = talentPresetHotkeyKeys[preset];
            // BMS centrally consumes assignment input before hxd.Key sees it.
            if (key > 0 && isGameKeyPressed(key)) {
                selectTalentPreset(preset);
                activateTalentPreset(preset);
                return;
            }
        }
    }

    static function checkAppearancePresetHotkeys():Void {
        if (appearancePresetTransfer.active) return;
        for (preset in 0...PresetSlots.COUNT) {
            var key = appearancePresetHotkeyKeys[preset];
            // BMS centrally consumes assignment input before hxd.Key sees it.
            if (key > 0 && isGameKeyPressed(key)) {
                selectAppearancePreset(preset);
                activateAppearancePreset(preset);
                return;
            }
        }
    }

    static function checkSkillPresetHotkeys():Void {
        if (skillPresetTransfer.active) return;
        for (preset in 0...PresetSlots.COUNT) {
            var key = skillPresetHotkeyKeys[preset];
            // BMS centrally consumes assignment input before hxd.Key sees it.
            if (key > 0 && isGameKeyPressed(key)) {
                selectSkillPreset(preset);
                activateSkillPreset(preset);
                return;
            }
        }
    }

    static function isGameKeyPressed(keyCode:Int):Bool {
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType != null && isKeyPressedMember == null)
            isKeyPressedMember = HlxRuntime.resolveStaticMember(hxdKeyType, "isPressed");
        if (isKeyPressedMember == null)
            return false;
        try return HlxRuntime.callResolved(isKeyPressedMember, [keyCode]) == true
        catch (_:Dynamic) return false;
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        try {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            var data:Dynamic = config;
            var wasEnabled = enabled.get();
            if (Reflect.hasField(data, "enabled"))
                enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "showDepositMaterials"))
                showDepositMaterials.set(Reflect.field(data, "showDepositMaterials"));
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals.set(Reflect.field(data, "showLockVisuals"));
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems.set(Reflect.field(data, "sortingIgnoresLockedItems"));
            loadPresetHotkeyConfig(data);
            if ((!enabled.get() && wasEnabled) || !showDepositMaterials.get()) {
                cancelDeposit();
                cancelRecyclerDeposit();
            }
            if (!enabled.get() || !showLockVisuals.get())
                lockEditMode = false;
            if (!enabled.get() || !sortingIgnoresLockedItems.get())
                cancelLockedSort(false);
            syncDepositButtonVisibility();
        } catch (_:Dynamic) {}
    }

    static function loadConfig():Void {
        try {
            var data:Dynamic = config;
            if (Reflect.hasField(data, "enabled")) enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "showDepositMaterials")) showDepositMaterials.set(Reflect.field(data, "showDepositMaterials"));
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals.set(Reflect.field(data, "showLockVisuals"));
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems.set(Reflect.field(data, "sortingIgnoresLockedItems"));
            loadPresetHotkeyConfig(data);
            if (Reflect.hasField(data, "selectedWeaponPresets")) {
                var savedSelections:Array<Dynamic> =
                    cast Reflect.field(data, "selectedWeaponPresets");
                if (savedSelections != null) {
                    for (entry in savedSelections) {
                        var selectionCharacterId = recordString(entry, "characterId");
                        var selectedPreset = recordInt(entry, "preset", -1);
                        if (selectionCharacterId != null
                            && StringTools.startsWith(selectionCharacterId, "db:")
                            && PresetSlots.valid(selectedPreset))
                            selectedWeaponPresets.push({
                                characterId: selectionCharacterId,
                                preset: selectedPreset
                            });
                    }
                }
            }
            if (Reflect.hasField(data, "weaponPresets")) {
                var savedPresets:Array<Dynamic> = cast Reflect.field(data, "weaponPresets");
                if (savedPresets != null) {
                    for (entry in savedPresets) {
                        var characterId = recordString(entry, "characterId");
                        var preset = recordInt(entry, "preset", -1);
                        var weapons:Array<Dynamic> = cast Reflect.field(entry, "weapons");
                        if (characterId != null && StringTools.startsWith(characterId, "db:")
                            && PresetSlots.valid(preset) && weapons != null)
                            weaponPresets.push({
                                characterId: characterId,
                                preset: preset,
                                weapons: weapons
                            });
                    }
                }
            }
            if (Reflect.hasField(data, "lockedItems")) {
                var saved:Array<Dynamic> = cast Reflect.field(data, "lockedItems");
                if (saved != null) {
                    for (record in saved) {
                        var uid = recordString(record, "uid");
                        var fingerprint = recordString(record, "fingerprint");
                        var location = recordString(record, "location");
                        var characterId = recordString(record, "characterId");
                        if (uid != null && fingerprint != null && location != "bank"
                            && characterId != null
                            && StringTools.startsWith(characterId, "db:")) {
                            lockRecords.push({
                                uid: uid,
                                fingerprint: fingerprint,
                                known: [],
                                location: location,
                                index: recordInt(record, "index", -1),
                                characterId: characterId,
                                restored: false
                            });
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    static function loadPresetHotkeyConfig(data:Dynamic):Void {
        if (config.appearancePresets == null) config.appearancePresets = [];
        if (config.selectedAppearancePresets == null) config.selectedAppearancePresets = [];
        if (config.skillPresets == null) config.skillPresets = [];
        if (config.selectedSkillPresets == null) config.selectedSkillPresets = [];
        if (config.talentPresets == null) config.talentPresets = [];
        if (config.selectedTalentPresets == null) config.selectedTalentPresets = [];
        presetHotkeyKeys = PresetSlots.hotkeys(data, "preset");
        talentPresetHotkeyKeys = PresetSlots.hotkeys(data, "talentPreset");
        skillPresetHotkeyKeys = PresetSlots.hotkeys(data, "skillPreset");
        appearancePresetHotkeyKeys = PresetSlots.hotkeys(data, "appearancePreset");
    }

    static function saveConfig():Void {
        var savedLocks:Array<Dynamic> = [];
        for (record in lockRecords) {
            savedLocks.push({
                uid: recordString(record, "uid"),
                fingerprint: recordString(record, "fingerprint"),
                location: recordString(record, "location"),
                index: recordInt(record, "index", -1),
                characterId: recordString(record, "characterId")
            });
        }
        try {
            config.enabled = enabled.get();
            config.showDepositMaterials = showDepositMaterials.get();
            config.showLockVisuals = showLockVisuals.get();
            config.sortingIgnoresLockedItems = sortingIgnoresLockedItems.get();
            PresetSlots.saveHotkeys(config, "preset", presetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "appearancePreset", appearancePresetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "skillPreset", skillPresetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "talentPreset", talentPresetHotkeyKeys);
            config.weaponPresets = weaponPresets;
            config.selectedWeaponPresets = selectedWeaponPresets;
            config.lockedItems = savedLocks;
            config.save();
        } catch (_:Dynamic) {}
    }
}
