package itemutilities;

import modinput.NativeHotkey;

import haxe.Json;
import haxe.ds.ObjectMap;
import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;
import itemutilities.CharacterResetStore.CharacterResetKind;
import itemutilities.InspectAccess as G;
import itemutilities.JunkSaleQueue.JunkSaleItem;

typedef ItemUtilitiesConfig = {
    var enabled:Bool;
    var holdInteractToQuickLoot:Bool;
    var showDepositMaterials:Bool;
    var showLockVisuals:Bool;
    var sortingIgnoresLockedItems:Bool;
    var instantMoteConversion:Bool;
    var preset1Hotkey:Dynamic;
    var preset2Hotkey:Dynamic;
    var preset3Hotkey:Dynamic;
    var preset4Hotkey:Dynamic;
    var preset5Hotkey:Dynamic;
    var appearancePreset1Hotkey:Dynamic;
    var appearancePreset2Hotkey:Dynamic;
    var appearancePreset3Hotkey:Dynamic;
    var appearancePreset4Hotkey:Dynamic;
    var appearancePreset5Hotkey:Dynamic;
    var appearancePresets:Array<Dynamic>;
    var selectedAppearancePresets:Array<Dynamic>;
    var skillPreset1Hotkey:Dynamic;
    var skillPreset2Hotkey:Dynamic;
    var skillPreset3Hotkey:Dynamic;
    var skillPreset4Hotkey:Dynamic;
    var skillPreset5Hotkey:Dynamic;
    var skillPresets:Array<Dynamic>;
    var selectedSkillPresets:Array<Dynamic>;
    var talentPreset1Hotkey:Dynamic;
    var talentPreset2Hotkey:Dynamic;
    var talentPreset3Hotkey:Dynamic;
    var talentPreset4Hotkey:Dynamic;
    var talentPreset5Hotkey:Dynamic;
    var talentPresets:Array<Dynamic>;
    var selectedTalentPresets:Array<Dynamic>;
    // Retain the original preset storage keys for existing configurations.
    // Each preset's `weapons` array now also stores armor and accessories.
    var weaponPresets:Array<Dynamic>;
    var selectedWeaponPresets:Array<Dynamic>;
    var lockedItems:Array<Dynamic>;
    var junkRules:Array<Dynamic>;
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
        lockedItems: [],
        junkRules: []
    };
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";
    static inline var CRAFTING_COMPONENT_TYPE = "CraftingComponent";

    static var enabled:Bool = true;
    static var showDepositMaterials:Bool = true;
    static var showLockVisuals:Bool = true;
    static var sortingIgnoresLockedItems:Bool = false;
    static var presetHotkeyKeys:Array<Dynamic> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var skillPresetHotkeyKeys:Array<Dynamic> = [for (_ in 0...PresetSlots.COUNT) 0];
    static var selectedSkillPreset:Int = 0;
    static var selectedSkillPresetCharacterId:String;
    static var skillPresetTransfer = new SkillPresetTransfer();
    static var skillPresetHero:Dynamic;
    static var skillPresetHost:Dynamic;
    static var skillPresetSpecialization:Dynamic;
    static var skillPresetCharacterId:String;
    static var nextSkillPresetCheck:Float = 0;
    static var skillPresetStatus:String = "";
    static var appearancePresetHotkeyKeys:Array<Dynamic> = [for (_ in 0...PresetSlots.COUNT) 0];
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
    static var talentPresetHotkeyKeys:Array<Dynamic> = [for (_ in 0...PresetSlots.COUNT) 0];
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
    static var gameAppType:hl.Bytes;
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
    static var lockEditMode:Bool = false;
    static var junkEditMode:Bool = false;
    static var junkState = new ItemJunkState();
    static var junkBadgeCache = new ObjectMap<Dynamic, Bool>();
    static var nextJunkBadgeCheck = 0.;
    static var activeMerchant:Dynamic;
    static var merchantGoldCounter:Dynamic;
    static var junkSale = new JunkSaleQueue();
    static var junkSaleHero:Dynamic;
    static var junkSaleHost:Dynamic;
    static var junkSaleInventory:Dynamic;
    static var junkSaleLoadout:Dynamic;
    static var junkSaleMerchant:Dynamic;
    static var junkSaleCharacter:String;
    static var nextJunkSaleCheck = 0.;
    static var junkItemReason:Dynamic;
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
        PlayerInspect.initialize(() -> enabled);
    }

    @:hlx.postfix(GameApp.finishedLoading)
    static function restoreLocksAfterLoading(instance:Dynamic, result:Void):Void {
        if (enabled) reconcileItemLocks();
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function prepareQuickLoot(instance:Dynamic, dt:Float, result:Void):Void {
        // PlayerController.update only reaches updateInputs when gameplay
        // input is unblocked. Its next input query is the normal Interact press.
        quickLootState.prepare(instance, enabled && config.holdInteractToQuickLoot);
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
        if (!enabled || !config.holdInteractToQuickLoot) {
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

            // Wait for a genuine native press before repeating. The native input API may buffer
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
        if (result == null || !enabled || !config.holdInteractToQuickLoot)
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
        InspectTooltips.forget(instance);
        unregisterSlot(instance);
        if (instance == activeGearAppearance) activeGearAppearance = null;
        if (instance == activeTalentView) {
            activeTalentView = null;
            activeTalentRoot = null;
        }
    }

    @:hlx.prefix(ui.TipItem.init)
    static function beforeInspectItemTip(instance:Dynamic):HlxPrefixResult<Void> {
        InspectTooltips.begin(instance);
        return Continue;
    }

    @:hlx.postfix(ui.TipItem.init)
    static function afterInspectItemTip(instance:Dynamic, result:Void):Void InspectTooltips.end();

    @:hlx.prefix(st.Equipment.isEquipped)
    static function inspectItemEquipped(instance:Dynamic, item:Dynamic):HlxPrefixResult<Bool> {
        return InspectTooltips.equippedSlot(item) == null ? Continue : SkipWith(true);
    }

    @:hlx.prefix(st.Equipment.getEquipSlot)
    static function inspectItemSlot(instance:Dynamic, item:Dynamic):HlxPrefixResult<String> {
        var slot = InspectTooltips.equippedSlot(item);
        return slot == null ? Continue : SkipWith(slot);
    }

    @:hlx.prefix(ui.win.InfusionSkillDesc.getSkillRank)
    static function inspectInfusionRank(instance:Dynamic):HlxPrefixResult<Int> {
        var rank = InspectTooltips.infusionRank(instance);
        return rank == null ? Continue : SkipWith(rank);
    }

    @:hlx.prefix(ui.BaseUI.setTip)
    static function suppressLockEditItemTooltip(instance:Dynamic, element:Dynamic,
        anchor:Dynamic, position:Dynamic, nesting:Dynamic):HlxPrefixResult<Dynamic> {
        if (!enabled || (!(showLockVisuals && lockEditMode) && !junkEditMode))
            return Continue;
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!(junkEditMode ? isActiveInventoryGridSlot(entry, slot) : isActiveLockSlot(entry, slot)))
                continue;
            if (isAncestorOf(slot, element) || isAncestorOf(slot, anchor)) {
                return SkipWith(null);
            }
        }
        return Continue;
    }

    @:hlx.prefix(App.render)
    static function updateNativeControls(instance:Dynamic, engine:Dynamic):HlxPrefixResult<Void> {
        // Update after game/UI input and before the owning windows render.
        try draw() catch (error:Dynamic) logLockError("native controls", error);
        try NativeUtilityUi.endFrame() catch (error:Dynamic) logLockError("native control cleanup", error);
        return Continue;
    }

    @:hlx.postfix(hxd.SceneEvents.emitEvent)
    static function dismissPresetDropdowns(instance:Dynamic, event:Dynamic, result:Void):Void {
        try NativeUtilityUi.onPointerEvent(event) catch (error:Dynamic) logLockError("preset dropdown", error);
    }

    @:hlx.postfix(ui.BaseUI.displayWindow)
    static function closeCoveredPresetDropdowns(instance:Dynamic, window:Dynamic, root:Dynamic, result:Void):Void {
        try NativeUtilityUi.onWindowDisplayed(window) catch (error:Dynamic) logLockError("preset dropdown", error);
    }

    @:hlx.prefix(st.Loadout.requestCompleteItem)
    static function completeMoteInstantly(instance:Dynamic, item:Dynamic):HlxPrefixResult<Dynamic> {
        if (!enabled || !config.instantMoteConversion)
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
        unknown:Null<Int>):HlxPrefixResult<Bool> {
        var item = itemAt(instance, index);
        return isItemLocked(item) ? SkipWith(false) : Continue;
    }

    // InventorySlot's discard actions call requestDropIndex directly.
    @:hlx.prefix(st.Inventory.requestDropIndex)
    static function preventLockedDropRequest(instance:Dynamic, index:Int, count:Bool,
        unknown:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
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
        return transferRestriction(item, destination) != null
            || transferRestriction(itemAt(destination, destinationIndex), instance) != null
            ? SkipWith(false)
            : Continue;
    }

    @:hlx.prefix(st.Inventory.requestTransfer)
    static function preventLockedTransferRequest(instance:Dynamic, index:Int,
        destination:Dynamic, destinationIndex:Int, force:hl.Ref<Bool>,
        count:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(instance, index);
        var reason = transferRestriction(item, destination);
        if (reason == null) reason = transferRestriction(itemAt(destination, destinationIndex), instance);
        if (reason == null) return Continue;
        rejectActionCallback(callback);
        return SkipWith(reason);
    }

    @:hlx.prefix(st.Loadout.checkRequestTransfer)
    static function preventLockedRightClickTransferCheck(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        var reason = transferRestriction(item, destination);
        return reason == null ? Continue : SkipWith(reason);
    }

    @:hlx.prefix(st.Loadout.requestTransfer)
    static function preventLockedRightClickTransferRequest(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        var reason = transferRestriction(item, destination);
        if (reason == null) return Continue;
        rejectActionCallback(callback);
        return SkipWith(reason);
    }

    static function isProtectedTransferDestination(inventory:Dynamic):Bool {
        return isBankInventory(inventory) || isScrapInventory(inventory);
    }

    static function transferRestriction(item:Dynamic, destination:Dynamic):Dynamic {
        if (item == null || destination == null) return null;
        if (isItemLocked(item) && isProtectedTransferDestination(destination)) return getLockedItemReason();
        if (isItemJunk(item) && (isBankInventory(destination)
            || G.isA(destination, "st.Equipment"))) return getJunkItemReason();
        return null;
    }

    @:hlx.prefix(st.Loadout.canEquipOnSlot)
    static function preventJunkEquipCheck(instance:Dynamic, item:Dynamic, slot:String,
        force:hl.Ref<Bool>, equipment:Dynamic, excluded:Dynamic):HlxPrefixResult<Bool> {
        return isItemJunk(item) ? SkipWith(false) : Continue;
    }

    @:hlx.prefix(st.Loadout.checkEquipOnSlot)
    static function preventJunkEquipReason(instance:Dynamic, item:Dynamic, slot:String,
        force:hl.Ref<Bool>, equipment:Dynamic, excluded:Dynamic):HlxPrefixResult<Dynamic> {
        return isItemJunk(item) ? SkipWith(getJunkItemReason()) : Continue;
    }

    @:hlx.prefix(st.Loadout.equipOnSlot)
    static function preventJunkEquipRequest(instance:Dynamic, item:Dynamic, slot:String,
        force:hl.Ref<Bool>, equipment:Dynamic, excluded:Dynamic, callback:Dynamic):HlxPrefixResult<Dynamic> {
        if (!isItemJunk(item)) return Continue;
        rejectActionCallback(callback);
        return SkipWith(getJunkItemReason());
    }

    static function getJunkItemReason():Dynamic {
        if (junkItemReason == null) {
            if (eReasonType == null) eReasonType = HlxRuntime.resolveType("EReason");
            junkItemReason = HlxRuntime.constructEnum(eReasonType, "Custom", ["Unmark this item as junk first"]);
        }
        return junkItemReason;
    }

    @:hlx.postfix(ui.win.MerchantUI.init)
    static function afterMerchantInit(instance:Dynamic, result:Void):Void {
        if (activeMerchant != instance) junkSale.cancel();
        activeMerchant = instance;
        merchantGoldCounter = null;
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
        if (loadout == null) return false;
        if (inventory == fieldOrNull(loadout, "bank")) return true;
        for (bank in G.array(fieldOrNull(loadout, "banks"), true)) if (bank == inventory) return true;
        return false;
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
        if (!sortingIgnoresLockedItems || instance != sourceInventory || indexes == null)
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
        var kept:Array<{ window:Dynamic, inventory:Dynamic }> = [];
        for (entry in openInventoryWindows)
            if (entry.window != instance) kept.push(entry);
        openInventoryWindows = kept;

        if (instance == activeInventoryWindow) {
            lockEditMode = false;
            junkEditMode = false;
            cancelLockedSort(false);
            activeInventoryWindow = null;
            sourceInventory = null;
            playerInventoryComp = null;
        }
        if (instance == activeInventoryUI) {
            lockEditMode = false;
            junkEditMode = false;
            cancelLockedSort(false);
            activeInventoryUI = null;
            playerInventoryComp = null;
        }
        if (instance == activeCharacterUI) {
            activeCharacterUI = null;
            cancelPresetTransfer();
        }
        if (instance == activeMerchant) {
            activeMerchant = null;
            merchantGoldCounter = null;
            junkSale.cancel();
        }
        if (instance == activeBankWindow) {
            cancelDeposit();
            activeBankWindow = null;
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
        NativeUiLayout.beginFrame();
        NativeUtilityUi.beginFrame();
        PlayerInspect.update();
        // Badges may trail a replicated upgrade by at most 200ms. Requests and
        // clicks always check live identity; no fingerprint scans when UI is closed.
        var badgeTime = haxe.Timer.stamp();
        if (badgeTime >= nextJunkBadgeCheck) {
            junkBadgeCache.clear();
            nextJunkBadgeCheck = badgeTime + LOCK_RECONCILE_INTERVAL;
        }
        refreshActiveHero();
        updateJunkSale();
        updateTalentPreset();
        updateSkillPreset();
        updateAppearancePreset();

        if (lockedSortActive && !lockedSortWaiting)
            transferNextLockedSortItem();

        if (activeBankWindow != null && enabled && showDepositMaterials)
            drawBankHeaderButton();
        if (activeScrapWindow != null && enabled && showDepositMaterials)
            drawRecyclerHeaderButton();

        if (enabled) {
            if (activeInventoryUI == null || !isUiVisible(activeInventoryUI)) {
                lockEditMode = false;
                junkEditMode = false;
            }
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
            drawJunkControls();
            if (showLockVisuals) {
                drawLockHeaderButton();
                if (lockEditMode)
                    drawLockSlotOverlays();
                drawLockedItemBadges();
            }
        }
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
        NativeUtilityUi.button(fieldOrNull(sortButton, "parent"), "recycler-deposit", rect, "all", "Deposit all", () -> {
            if (enabled && showDepositMaterials && !recyclerDepositing) beginRecyclerDeposit();
        });
    }

    static function drawBankDepositButton(sortButton:Dynamic, rect:OverlayRect,
        mode:Int, suffix:String, tooltip:String):Void {
        NativeUtilityUi.button(fieldOrNull(sortButton, "parent"), "bank-deposit-" + suffix, rect, suffix,
            StringTools.trim(tooltip), () -> {
                if (enabled && showDepositMaterials && !depositing) beginDepositMode(mode);
            });
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
        drawPresetButtons(rect, fieldOrNull(appearanceButton, "parent"), Equipment);
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
        drawPresetButtons(rect, view, Talent);
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
        var equippedBounds:OverlayRect = null;
        var footerChildren = fieldOrNull(footer, "children");
        for (i in 0...arrayLength(footerChildren)) {
            var child = arrayGet(footerChildren, i);
            if (InspectAccess.isA(child, "ui.win.HeroSkillSlots")) {
                equippedBounds = uiElementRect(child);
                break;
            }
        }
        var rect = SkillPresetLayout.place(uiElementRect(footer), textBounds,
            NativeUiLayout.rect(view, 0, 0, PresetSlots.CONTROLS_WIDTH, 36),
            uiElementRect(view), equippedBounds);
        drawPresetButtons(rect, footer, Skill);
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
        drawPresetButtons(rect, fieldOrNull(button, "parent"), Appearance);
    }

    static function uiElementRect(element:Dynamic):OverlayRect {
        var width = fieldOrNull(element, "calculatedWidth");
        var height = fieldOrNull(element, "calculatedHeight");
        if (width == null || height == null) return null;
        return NativeUiLayout.rect(element, 0, 0, cast width, cast height);
    }

    static function drawPresetButtons(rect:OverlayRect, parent:Dynamic, kind:PresetKind):Void {
        var busy = switch kind {
            case Equipment: presetTransferActive;
            case Talent: talentPresetTransfer.active;
            case Skill: skillPresetTransfer.active;
            case Appearance: appearancePresetTransfer.active;
        };
        var selected = switch kind {
            case Equipment: selectedWeaponPreset;
            case Talent: selectedTalentPreset;
            case Skill: selectedSkillPreset;
            case Appearance: selectedAppearancePreset;
        };
        NativeUtilityUi.presets(parent, "presets-" + cast(kind, Int), rect, busy, selected,
            preset -> {
                if (!enabled) return;
                switch kind {
                    case Equipment: selectEquipmentPreset(preset); activateEquipmentPreset(preset);
                    case Talent: selectTalentPreset(preset); activateTalentPreset(preset);
                    case Skill: selectSkillPreset(preset); activateSkillPreset(preset);
                    case Appearance: selectAppearancePreset(preset); activateAppearancePreset(preset);
                }
            }, () -> {
                if (!enabled) return;
                switch kind {
                    case Equipment: saveCurrentEquipmentToPreset(selectedWeaponPreset);
                    case Talent: saveCurrentTalentsToPreset(selectedTalentPreset);
                    case Skill: saveCurrentSkillsToPreset(selectedSkillPreset);
                    case Appearance: saveCurrentAppearancesToPreset(selectedAppearancePreset);
                }
            });
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
        if (!enabled || talentPresetTransfer.active || !PresetSlots.valid(preset)) return;
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
        if (!enabled || talentPresetTransfer.active || !PresetSlots.valid(preset)) return;
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
            if (!enabled || hero != talentPresetHero
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
        if (!enabled || appearancePresetTransfer.active || !PresetSlots.valid(preset)) return;
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
        if (!enabled || appearancePresetTransfer.active || !PresetSlots.valid(preset)) return;
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
            if (!enabled || hero != appearancePresetHero
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
        if (!enabled || skillPresetTransfer.active || !PresetSlots.valid(preset)) return;
        try {
            var hero = resolveHero();
            var characterId = heroPersistentId(hero);
            if (characterId == null || !talentsReady(hero)) return;
            var specialization = fieldOrNull(hero, "specialization");
            var current = NativeSkills.current(specialization);
            NativeSkills.ensureSynchronized(hero, current);
            var owners = NativeSkills.runeSkills(current.runes);
            var rules = NativeSkills.rules(hero);
            var saved = SkillPresetPlan.saved(current, owners);
            var signatures = SkillPresetPlan.savedSignatures(current, owners, rules);
            SkillPresetPlan.validate(saved, rules, signatures);
            var existing = findSkillPreset(characterId, preset);
            if (existing == null) {
                existing = {characterId: characterId, preset: preset};
                config.skillPresets.push(existing);
            }
            Reflect.setField(existing, "classId", Std.string(fieldOrNull(fieldOrNull(hero, "inf"), "id")));
            Reflect.setField(existing, "skills", saved);
            Reflect.setField(existing, "signatureSkills", signatures);
            if (NativeSkills.mage(hero) != null)
                Reflect.setField(existing, "conduits", SkillPresetPlan.savedConduits(current));
            else Reflect.deleteField(existing, "conduits");
            saveConfig();
            skillPresetStatus = "Skill preset " + (preset + 1) + " saved.";
        } catch (error:Dynamic) {
            skillPresetStatus = Std.string(error);
            logLockError("save skill preset", error);
        }
    }

    static function activateSkillPreset(preset:Int):Void {
        if (!enabled || skillPresetTransfer.active || !PresetSlots.valid(preset)) return;
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
            // Older presets did not record signature runes; leave those choices
            // alone until the player presses Set to capture them explicitly.
            var signatures = Reflect.hasField(saved, "signatureSkills")
                ? SkillPresetPlan.decodeSignatures(Reflect.field(saved, "signatureSkills")) : [];
            NativeSkills.ensureCanApply(hero);
            var conduits = Reflect.hasField(saved, "conduits")
                ? SkillPresetPlan.decodeConduits(Reflect.field(saved, "conduits"), current.conduits.length) : null;
            if (conduits != null) NativeSkills.validateConduits(hero, conduits);
            var changes = SkillPresetPlan.build(current, target, NativeSkills.rules(hero),
                NativeSkills.runeSkills(current.runes), signatures, conduits);
            if (changes.length == 0) {
                skillPresetStatus = "This skill preset is already active.";
                refreshSkillPresetView(hero);
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
            if (!enabled || hero != skillPresetHero
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
        var hero = skillPresetHero;
        skillPresetHero = null;
        skillPresetHost = null;
        skillPresetSpecialization = null;
        skillPresetCharacterId = null;
        // Completion waits for both the rune reply and replicated state.
        // Also reflect any applied changes when a later request was rejected.
        refreshSkillPresetView(hero);
    }

    static function refreshSkillPresetView(hero:Dynamic):Void {
        try {
            var view = activeCharacterUI;
            if (hero == null || hero != resolveHero() || view == null || !isUiVisible(view)) return;
            var descriptor = fieldOrNull(view, "skillDesc");
            if (descriptor == null || !isUiVisible(descriptor)) return;
            NativeSkills.refreshView(view, hero);
        } catch (error:Dynamic) {
            logLockError("refresh skill preset selection", error);
        }
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
        if (activeInventoryUI == null || !isUiVisible(activeInventoryUI) || playerInventoryComp == null) return;
        var sortButton = fieldOrNull(playerInventoryComp, "sortButton");
        if (sortButton == null || !isUiVisible(sortButton)) return;
        var rect = NativeUiLayout.rect(sortButton, -38, 0, 32, 30);
        NativeUtilityUi.button(fieldOrNull(sortButton, "parent"), "edit-locks", rect, "lock",
            null, () -> {
                if (enabled && showLockVisuals) {
                    lockEditMode = !lockEditMode;
                    junkEditMode = false;
                }
            }, lockEditMode);
    }

    static function isItemJunk(item:Dynamic):Bool {
        if (!enabled || item == null) return false;
        var hero = resolveHero();
        var character = heroPersistentId(hero);
        var kind = G.text(fieldOrNull(item, "kind"));
        if (!junkState.hasKind(character, kind) || isItemLocked(item)) return false;
        if (!NativeJunk.isInBag(fieldOrNull(hero, "loadout"), item)) return false;
        return junkState.matches(character, kind, NativeJunk.fingerprint(item));
    }

    static function toggleItemJunk(item:Dynamic):Void {
        if (!enabled || !isLockLoadoutReady()) return;
        reconcileItemLocks();
        if (isItemLocked(item)) return;
        var hero = resolveHero();
        if (!NativeJunk.isInBag(fieldOrNull(hero, "loadout"), item)) return;
        var character = heroPersistentId(hero);
        var kind = G.text(fieldOrNull(item, "kind"));
        var fingerprint = NativeJunk.fingerprint(item);
        if (character == null || fingerprint == null) return;
        junkSale.cancel();
        junkState.set(character, kind, fingerprint, !junkState.matches(character, kind, fingerprint));
        junkBadgeCache.clear();
        saveConfig();
    }

    static function drawJunkControls():Void {
        var sort = fieldOrNull(playerInventoryComp, "sortButton");
        if (activeInventoryUI != null && isUiVisible(activeInventoryUI) && isUiVisible(sort)) {
            NativeUtilityUi.button(fieldOrNull(sort, "parent"), "edit-junk",
                NativeUiLayout.rect(sort, showLockVisuals ? -76 : -38, 0, 32, 30),
                "junk", null, () -> {
                    if (!enabled) return;
                    junkEditMode = !junkEditMode;
                    lockEditMode = false;
                }, junkEditMode);
        }
        for (entry in visibleSlots) {
            var slot = entry.slot;
            if (!isActiveInventoryGridSlot(entry, slot)) continue;
            var item = authoritativeSlotItem(entry, slot);
            if (item == null) continue;
            if (!junkBadgeCache.exists(item)) junkBadgeCache.set(item, isItemJunk(item));
            if (junkBadgeCache.get(item) && !isItemLocked(item)) NativeUtilityUi.badge(slot, "junk-badge");
            if (junkEditMode) NativeUtilityUi.lockInput(slot, () -> {
                if (!enabled || !junkEditMode || !isActiveInventoryGridSlot(entry, slot)) return;
                var item = authoritativeSlotItem(entry, slot);
                if (item != null) toggleItemJunk(item);
            });
        }
        if (activeMerchant != null && isUiVisible(activeMerchant) && NativeJunk.isGuildMerchant(activeMerchant)) {
            var footer = fieldOrNull(activeMerchant, "currencyList");
            if (!isUiVisible(footer)) return;
            if (!isUiVisible(merchantGoldCounter) || !isAncestorOf(footer, merchantGoldCounter))
                merchantGoldCounter = findMerchantGoldCounter(footer);
            if (merchantGoldCounter == null) return;
            // Measure only the native counter. The utility is its sibling in
            // the window, so it cannot enlarge its own positioning anchor.
            var gold = NativeUiLayout.localRect(merchantGoldCounter,
                NativeUiLayout.objectBounds(merchantGoldCounter, 0));
            if (gold == null || !gold.valid()) return;
            NativeUtilityUi.button(fieldOrNull(footer, "parent"), "sell-junk",
                NativeUiLayout.rect(merchantGoldCounter, gold.left - 40,
                    gold.top + (gold.height - 30) / 2, 32, 30), "sell-junk",
                junkSale.active ? "Selling junk..." : "Sell all junk", beginJunkSale, junkSale.active);
        }
    }

    static function findMerchantGoldCounter(object:Dynamic):Dynamic {
        if (!isUiVisible(object)) return null;
        if (G.isA(object, "ui.comp.CurrencyCounter") && G.text(fieldOrNull(object, "itemKind")) == "Gold")
            return object;
        // Search only the small footer, once when created or rebuilt. Shop
        // item prices and currency counters elsewhere are not valid anchors.
        for (child in InspectUi.children(object)) {
            var counter = findMerchantGoldCounter(child);
            if (counter != null) return counter;
        }
        return null;
    }

    static function beginJunkSale():Void {
        if (!enabled || junkSale.active || !isUiVisible(activeMerchant)
            || !NativeJunk.isGuildMerchant(activeMerchant) || !isLockLoadoutReady()) return;
        reconcileItemLocks();
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        var inventory = fieldOrNull(loadout, "inventory");
        var items:Array<JunkSaleItem> = [];
        var content = getContent(inventory);
        for (index in 0...arrayLength(content)) {
            var item = itemAt(inventory, index);
            if (!isItemJunk(item) || G.call("st.Loadout", "canSellItem", loadout, [item]) != true) continue;
            var stack = G.call("st.Inventory", "getItemStack", inventory, [item]);
            var count = G.integer(fieldOrNull(stack, "count"));
            var uid = itemUid(item);
            if (count > 0 && uid != null) items.push({item:item, uid:uid, count:count, fingerprint:NativeJunk.fingerprint(item)});
        }
        if (!junkSale.start(activeMerchant, items)) return;
        cancelDeposit(); cancelRecyclerDeposit(); cancelPresetTransfer(); cancelLockedSort(false);
        junkSaleHero = hero;
        junkSaleHost = fieldOrNull(currentGameApp(), "host");
        junkSaleCharacter = heroPersistentId(hero);
        junkSaleInventory = inventory;
        junkSaleLoadout = loadout;
        junkSaleMerchant = activeMerchant;
        nextJunkSaleCheck = 0;
    }

    static function updateJunkSale():Void {
        try {
            if (junkSale.active) {
                var hero = resolveHero();
                if (!enabled || hero != junkSaleHero || heroPersistentId(hero) != junkSaleCharacter
                    || fieldOrNull(currentGameApp(), "host") != junkSaleHost
                    || fieldOrNull(fieldOrNull(hero, "loadout"), "inventory") != junkSaleInventory
                    || !isLockLoadoutReady() || activeMerchant != junkSaleMerchant
                    || !isUiVisible(activeMerchant) || !NativeJunk.isGuildMerchant(activeMerchant)) {
                    junkSale.cancel();
                } else {
                    var now = haxe.Timer.stamp();
                    if (now < nextJunkSaleCheck) return;
                    nextJunkSaleCheck = now + 0.05;
                    reconcileItemLocks();
                    var next = junkSale.next(activeMerchant, now,
                        candidate -> G.call("st.Inventory", "getItemStack", junkSaleInventory, [candidate.item]) != null,
                        candidate -> {
                            var stack = G.call("st.Inventory", "getItemStack", junkSaleInventory, [candidate.item]);
                            return stack != null && fieldOrNull(stack, "item") == candidate.item
                                && itemUid(candidate.item) == candidate.uid
                                && G.integer(fieldOrNull(stack, "count")) == candidate.count
                                && isItemJunk(candidate.item)
                                && NativeJunk.fingerprint(candidate.item) == candidate.fingerprint
                                && G.call("st.Loadout", "canSellItem", junkSaleLoadout, [candidate.item]) == true;
                        });
                    if (next != null) {
                        var id = junkSale.requestId;
                        G.call("st.Loadout", "sellItem", junkSaleLoadout, [next.item,
                            (success:Bool) -> junkSale.acknowledge(id, success)]);
                    }
                }
            }
        } catch (error:Dynamic) {
            junkSale.cancel("Selling junk stopped: " + Std.string(error));
            logLockError("sell junk", error);
        }
        if (!junkSale.active && junkSaleHero != null) {
            if (junkSaleMerchant == activeMerchant && isUiVisible(activeMerchant)) {
                try G.call("ui.win.MerchantUI", "rebuildBuyback", activeMerchant) catch (_:Dynamic) {}
            }
            if (junkSale.error != "") try {
                var ui = G.current("ui.BaseUI", "current");
                if (G.isA(ui, "ui.GameUI")) {
                    var chat = G.call("ui.GameUI", "get_chat", ui);
                    if (chat != null) G.call("ui.hud.ChatBox", "chatError", chat, [InspectUi.escape(junkSale.error)]);
                }
            } catch (_:Dynamic) {}
            junkSaleHero = null; junkSaleHost = null; junkSaleInventory = null;
            junkSaleLoadout = null; junkSaleMerchant = null; junkSaleCharacter = null;
        }
    }

    static function drawLockSlotOverlays():Void {
        for (entry in visibleSlots) {
            var slot = entry.slot;
            if (!isActiveLockSlot(entry, slot) || authoritativeSlotItem(entry, slot) == null) continue;
            NativeUtilityUi.lockInput(slot, () -> {
                // Resolve at click time: sorting/transfers can replace a slot's item.
                if (!enabled || !showLockVisuals || !lockEditMode || !isActiveLockSlot(entry, slot)) return;
                var item = authoritativeSlotItem(entry, slot);
                if (item != null) toggleItemLock(item);
            });
        }
    }

    static function drawLockedItemBadges():Void {
        for (entry in visibleSlots) {
            var slot = entry.slot;
            if (isActiveLockSlot(entry, slot) && isItemLocked(authoritativeSlotItem(entry, slot)))
                NativeUtilityUi.badge(slot);
        }
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
        return isItemType(item, CRAFTING_COMPONENT_TYPE)
            || isItemType(item, "UpgradeComponent");
    }

    static function matchesDepositMode(item:Dynamic):Bool {
        if (item == null || isItemLocked(item) || isItemJunk(item))
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
        entry = {
            inventory: inventory,
            index: index,
            slot: slot,
            listIndex: visibleSlots.length
        };
        slotsByObject.set(slot, entry);
        visibleSlots.push(entry);
    }

    static function unregisterSlot(slot:Dynamic):Void {
        var entry = slotsByObject.get(slot);
        if (entry == null)
            return;
        NativeUtilityUi.forget(slot);
        slotsByObject.remove(slot);
        // Fill the gap with the last entry, avoiding another list search or shift.
        var last = visibleSlots.pop();
        if (entry.listIndex < visibleSlots.length) {
            visibleSlots[entry.listIndex] = last;
            last.listIndex = entry.listIndex;
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

    static function toggleItemLock(item:Dynamic):Void {
        if (isItemJunk(item)) return;
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
        if (ItemLockState.setLocked(lockRecords, current, tracked, locked)) {
            junkBadgeCache.clear();
            saveConfig();
        }
    }

    static function isItemLocked(item:Dynamic):Bool {
        if (!enabled || item == null)
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
            junkSale.cancel();
            junkEditMode = false;
            lockEditMode = false;
            junkBadgeCache.clear();
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
            // Normalize absent and empty infusions to the same uninfused identity.
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
            if (NativeHotkey.isPressed(key)) {
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
            if (NativeHotkey.isPressed(key)) {
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
            if (NativeHotkey.isPressed(key)) {
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
            if (NativeHotkey.isPressed(key)) {
                selectSkillPreset(preset);
                activateSkillPreset(preset);
                return;
            }
        }
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        try {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            var data:Dynamic = config;
            var wasEnabled = enabled;
            if (Reflect.hasField(data, "enabled"))
                enabled = Reflect.field(data, "enabled");
            if (Reflect.hasField(data, "showDepositMaterials"))
                showDepositMaterials = Reflect.field(data, "showDepositMaterials");
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals = Reflect.field(data, "showLockVisuals");
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems = Reflect.field(data, "sortingIgnoresLockedItems");
            loadPresetHotkeyConfig(data);
            junkState.load(Reflect.field(data, "junkRules"));
            if ((!enabled && wasEnabled) || !showDepositMaterials) {
                cancelDeposit();
                cancelRecyclerDeposit();
            }
            if (!enabled || !showLockVisuals)
                lockEditMode = false;
            if (!enabled) { junkEditMode = false; junkSale.cancel(); }
            if (!enabled || !sortingIgnoresLockedItems)
                cancelLockedSort(false);
        } catch (_:Dynamic) {}
    }

    static function loadConfig():Void {
        try {
            var data:Dynamic = config;
            if (Reflect.hasField(data, "enabled")) enabled = Reflect.field(data, "enabled");
            if (Reflect.hasField(data, "showDepositMaterials")) showDepositMaterials = Reflect.field(data, "showDepositMaterials");
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals = Reflect.field(data, "showLockVisuals");
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems = Reflect.field(data, "sortingIgnoresLockedItems");
            loadPresetHotkeyConfig(data);
            junkState.load(Reflect.field(data, "junkRules"));
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
            config.enabled = enabled;
            config.showDepositMaterials = showDepositMaterials;
            config.showLockVisuals = showLockVisuals;
            config.sortingIgnoresLockedItems = sortingIgnoresLockedItems;
            PresetSlots.saveHotkeys(config, "preset", presetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "appearancePreset", appearancePresetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "skillPreset", skillPresetHotkeyKeys);
            PresetSlots.saveHotkeys(config, "talentPreset", talentPresetHotkeyKeys);
            config.weaponPresets = weaponPresets;
            config.selectedWeaponPresets = selectedWeaponPresets;
            config.lockedItems = savedLocks;
            config.junkRules = junkState.saved();
            config.save();
        } catch (_:Dynamic) {}
    }
}
