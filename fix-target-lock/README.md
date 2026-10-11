# Farever Fix Target Lock

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-fix-target-lock.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=fix-target-lock&expanded=true)

An unofficial HLX mod that restores Farever's non-functional **Lock Target** action.

Look at an enemy and press Farever's existing Lock Target binding to lock it. Press the same binding again to unlock. While locked, Farever routes single-target attacks to that enemy even if another enemy moves under the crosshair. Area-of-effect and point-targeted skills keep their normal targeting.

The mod uses Farever's existing `lockedTarget`, `SkillTarget`, and `hard-lock` HUD systems rather than implementing a separate combat targeting system.

The mod pins the locked enemy only while Farever resolves a skill's target. Native skill replacement and manual ground/point aiming continue normally; the crosshair target is restored when that skill-aim call ends.

Changing areas or replacing the controlled hero clears the target lock before Farever can automatically acquire another enemy. This also applies when **Auto-unlock when target dies** is off. Normal locks within the same area remain active.

## Installation

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

### Easy Installation

1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/8)

### Manual Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files) in the Farever game directory.
2. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) (required) to configure the mod in-game.
3. Download the latest build artifact ZIP. Install it with Vortex, or extract it directly into the Farever game directory; the archive already contains `hlx\mods\fix-target-lock\fix-target-lock.hl`.
4. Fully close and relaunch Farever.

## Usage

Open **Mod Settings** from Farever's Game Menu to configure the mod.

- **Enable** restores the target-lock feature. Disabling the mod clears the current lock and restores Farever's original feature flag.
- **Auto-unlock when target dies** clears the lock as soon as the locked enemy is defeated or despawns. It is enabled by default.
- **Press Lock Target to switch targets** changes the lock directly to Farever's current `autoTarget` when another enemy is aimed at. Pressing it without another valid target still unlocks normally. It is disabled by default.
- **Disable automatic camera movement** prevents Farever from pulling the camera's yaw and pitch toward the locked enemy, leaving camera rotation under manual control while preserving the normal locked-camera sensitivity. It is disabled by default.
- **Enable quick cast** lets you hold a ground-targeted skill's bound button to aim, then release it to cast. Uses the native ground indicator and cancellation controls. Quick taps still cast when the game queues the skill before opening its aiming indicator. Losing focus or blocking input requires a fresh hold and release to prevent an unintended cast. It works without a target lock and is disabled by default.
- Use Farever's normal **Lock Target** key or controller binding to toggle a target lock.
- Farever's native animated hard-lock indicator appears above the locked enemy.

Settings are saved to `Farever\hlx\config\fix-target-lock\config.json`.

## How it works

Farever contains a nearly complete target-lock implementation, but `PlayerController.updateInputs()` does not check the `LockTarget` input action. The mod adds that missing toggle behavior:

- unlocked + Lock Target: refreshes Farever's auto-target for the current view, then calls its `lockAutoTarget()`;
- locked + Lock Target: calls Farever's `leaveLock()`;
- enabled: keeps Farever's `Const.Camera.TargetLock` feature flag active.

Before the player controller updates, the mod checks whether its controller, hero or map changed. It clears the previous auto-target and uses native `leaveLock()` to reset lock state on a transition, including while input is blocked. Without this cleanup, Farever reuses the controller's `inLock` flag after replacing the hero and can acquire a new target before the existing dead-target check runs.

Farever already stores the target on `Hero.lockedTarget`, feeds target-based skills through `SkillTarget.Target`, leaves `SkillTarget.Point` behavior intact, and marks the corresponding enemy widget with the native `hard-lock` style.


## Building (for developers)

Requires Haxe 4.3.x and `hlx-runtime`.

```text
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd fix-target-lock
haxe compile.hxml
```

Output: `build/fix-target-lock/fix-target-lock.hl`

## Compatibility

Targets the September 30 Live client. Quick cast and camera controls live here; More Settings no longer hooks those systems.

This mod relies on Farever's internal HashLink layout. Game updates can require a rebuild or adjustment.

## Disclaimer

Unofficial community mod. Not affiliated with or endorsed by Farever's developers, HLX, Steam, or Valve.
