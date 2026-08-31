# FTA + WardenGG 80–90 Auto-Quest Prototype

Experimental World of Warcraft Retail/Midnight leveling automation built around **Follow The Arrow (FTA)** and **WardenGG Extended Lua Unlocker**.

This is a personal hobby project. I started it because I was bored and wanted to see how far FTA + WardenGG could be pushed toward reliable alt-leveling automation. I am building it primarily for my own use and experimentation, but I am happy to share the code with anyone who wants to test it, learn from it, improve it, or build on the ideas here.

No software license has been selected yet.

## Current versions

Latest experimental package:

```text
latest/FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

The package contains:

```text
WardenGG/_FTA_HybridNav_v0.7.6_ElevatedTurninFix.lua
FollowTheArrow/Core/WGGBridge.lua
```

Current bridge version:

```text
0.4.2-fta-satisfied
```

The old `warden/_FTA_DirectMove_v0.4.lua` file is a legacy milestone and should not be used with the current hybrid controller.

## What is working in live testing

The project has progressed well beyond the original v0.4 travel prototype. The following pieces have been demonstrated in game during development:

- FTA route, module, step and segment state can be read through the bridge.
- FTA map coordinates are converted into WoW world coordinates.
- The bridge reads quest IDs, objective indexes and live WoW objective progress.
- FTA `SEQUENCE_CHAIN` state can be matched to the routed objective rather than blindly using the first unfinished segment.
- WardenGG Navigation Server connects successfully on localhost.
- MMAP/VMAP-backed path generation is being used for hybrid navigation.
- Ground travel can use WardenGG `FindPath` + `MoveAlongPath`.
- Flying/skyriding travel, steering, obstacle recovery, descent and controlled landing work.
- Direct movement remains available as a fallback when navigation fails.
- The controller can mount, take off and attempt controlled `Surge Forward` use during long flights.
- Live WardenGG object-manager scanning can find nearby units and objects.
- Quest NPCs can be approached and interacted with.
- Quest acceptance has worked in live testing.
- Multi-objective FTA route handling is working well enough to select and execute kill objectives.
- Kill objectives can select a matching hostile and hand the target to an external Warden combat rotation.
- Strict kill-name matching prevents the objective controller from intentionally farming arbitrary nearby mobs.
- Semantic objective classification distinguishes actions such as `KILL`, `INTERACT`, `EXTRA_ACTION`, `PICKUP` and `TURNIN`.
- The Fairbreeze `Help Citizens` objective is correctly classified as interaction work even though WoW reports its objective type as `monster`.
- The live object scanner correctly identified **Mr. Fluff** as the intended Fairbreeze interaction object during testing.

## Latest experimental work: v0.7.6

v0.7.6 contains two newer changes that still need broader live validation:

### Elevated interaction objects

Some quest objects are physically above the ground navmesh. Mr. Fluff on the Fairbreeze statue exposed this problem: the correct object was found, but asking ground navigation to path directly to the object's elevated Z coordinate returned no path.

v0.7.6 adds an elevated-object flow:

```text
identify elevated quest object
        ↓
choose a reachable ground staging point
        ↓
move near the object
        ↓
face + pitch toward it
        ↓
world-space WGG.MouseClick()
        ↓
WGG.ObjectInteract() fallback
```

### Multiple quest turn-ins

The quest-event layer now collects currently actionable pickup/turn-in quest IDs from the routed FTA state instead of only looking at the root active segment. This is intended to support clusters where several completed quests are available at the same time.

These newest v0.7.6 changes are experimental until they receive more live testing.

## Architecture

```text
Follow The Arrow
      |
      | route / step / SEQUENCE_CHAIN / quest objective state
      v
FTA WGG Bridge v0.4.2
      |
      v
Route-task planner
      |
      +-- exact routed quest/objective
      +-- live objective progress
      +-- FTA IsSegmentSatisfied()
      |
      v
Hybrid navigation
      |
      +-- ground: FindPath + MoveAlongPath
      +-- flight: nav-generated nodes + custom flight controller
      +-- direct fallback
      +-- obstacle recovery / landing
      |
      v
Objective dispatcher
      |
      +-- PICKUP / TURNIN -> quest gossip/event controller
      +-- KILL -> strict mob selection -> external combat rotation
      +-- INTERACT -> precise route-node scan -> object interaction
      +-- EXTRA_ACTION -> target + extra action button
      |
      v
FTA progress advances -> next routed task
```

See `docs/ARCHITECTURE.md` for more detail.

## Navigation Server

The current hybrid build expects a WardenGG Navigation Server when MMAP/VMAP navigation is being used.

Default script address:

```text
127.0.0.1:47110
```

Example navigation-server data layout used during development:

```text
C:\WGG\NavData\mmaps\
C:\WGG\NavData\vmaps\
```

The server configuration, not the Lua controller, points to the MMAP/VMAP directories.

## Follow The Arrow bridge installation

This repository intentionally does **not** redistribute the full Follow The Arrow addon.

Copy:

```text
fta_bridge/WGGBridge.lua
```

to:

```text
World of Warcraft/_retail_/Interface/AddOns/FollowTheArrow/Core/WGGBridge.lua
```

Then make sure this line exists in `FollowTheArrow.toc` after the appropriate core files:

```text
Core\WGGBridge.lua
```

Bridge diagnostic:

```text
/ftawgg
```

## WardenGG installation

The current complete controller is included in the latest ZIP package:

```text
latest/FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

Extract:

```text
WardenGG/_FTA_HybridNav_v0.7.6_ElevatedTurninFix.lua
```

into the WardenGG script directory used by your setup.

Do not leave several old `_FTA_DirectMove*` or `_FTA_HybridNav*` controllers loading at the same time. They are independent scripts and can fight over movement.

Useful commands:

```text
/ftahybrid       toggle the current hybrid controller
/ftastate        dump current FTA/route/objective state
/ftacandidates   inspect interaction candidates
/ftawgg          dump FTA bridge state
```

## Combat

The objective controller is responsible for finding the routed hostile, targeting it, approaching it and deciding when the objective is complete.

It is **not** intended to be a universal class/spec rotation. Actual ability casting is expected to come from a separate compatible Warden rotation.

## Known limitations

This remains an active prototype. Current limitations include:

- Some bespoke quest mechanics still require quest-specific handlers.
- Difficult city, indoor, bush and building geometry can still expose navigation edge cases.
- Quest-specific NPC/ObjectID mappings are incomplete.
- Some collect/use/click/follow/escort mechanics are still generic or unimplemented.
- Reward-choice handling is simplistic in the experimental quest controller.
- The newest elevated-world-click and multi-turn-in changes in v0.7.6 still need live validation.
- A full unattended 80–90 run has not yet been completed end-to-end.

## Primary route

Current development target:

```text
Midnight Alt 80–90
```

## Third-party projects

This repository contains only integration/prototype work created for this project. It does not include or claim ownership of:

- Follow The Arrow
- WardenGG
- TrinityCore
- Arctium navigation data

Their respective code, data, names and licenses belong to their owners/authors.

## Status

**Prototype / active development.**

The strongest recent milestone is no longer just travel. The current system can read FTA's multi-objective route state, use MMAP/VMAP-backed hybrid movement, land at quest areas, select routed kill objectives and successfully hand matching mobs to a combat rotation. Interaction and turn-in automation are now the main area being hardened.
