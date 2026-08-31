# FTA + WardenGG 80–90 Auto-Quest Prototype

Experimental World of Warcraft Retail/Midnight leveling automation prototype.

The project uses **Follow The Arrow (FTA)** as the high-level leveling route/quest-step source and **WardenGG Extended Lua Unlocker** for movement, flying, landing, live object discovery, and NPC interaction.

The goal is a fast and reliable **80–90 alt leveling flow** using FTA's optimized route.

## Project intent

This is a personal hobby project I started because I was bored and wanted to see how far I could push FTA + WardenGG toward reliable alt-leveling automation.

I'm building it primarily for my own use and experimentation, but I'm happy to share the code with anyone who finds it useful, wants to learn from it, test it, improve it, or build on the ideas here. I'm not looking for payment or compensation for the work.

This is still an experimental project under active development, so expect unfinished pieces, occasional questionable behavior, and the usual consequences of teaching a game character to make decisions on its own.

No software license has been selected yet.

## Current verified state

The following behavior has been tested in-game:

- Reads FTA's active route step and destination through the bridge.
- Converts FTA map coordinates to WoW world coordinates.
- Direct ground movement toward FTA destinations works.
- Continuous heading correction works after overshooting a destination.
- Mount/flying travel works.
- Flight controller can reach the destination and perform a controlled landing.
- The character has successfully landed directly in front of the target NPC.
- Live WardenGG object-manager scanning can identify a nearby NPC/object.
- The character can approach the live NPC coordinates.
- `WGG.ObjectInteract()` successfully opened the NPC/quest dialog.

### Current known limitation

**v0.4 opens the NPC/quest dialog, but does not yet accept/start the quest.**

The next quest-controller step is explicit handling of quest UI actions such as accepting, completing, and selecting rewards after interaction.

## Current components

### `warden/_FTA_DirectMove_v0.4.lua`

Current WardenGG travel/interact prototype.

Implemented:

- FTA target consumption
- direct ground steering
- mount attempts
- flying/skyriding
- obstacle raycasts
- obstacle recovery
- controlled descent and landing
- live object enumeration
- `ObjectName`, `ObjectID`, `ObjectGUID`, and `ObjectPos` inspection
- pickup/turn-in candidate selection
- live NPC approach
- `WGG.ObjectInteract()`
- controlled long-distance `Surge Forward` attempts

Surge Forward is implemented in v0.4, but has not yet been independently validated as thoroughly as the travel/landing/NPC interaction path.

### `fta_bridge/WGGBridge.lua`

Small bridge loaded inside Follow The Arrow.

It exposes the currently resolved FTA step through:

```lua
_G.FTA_WGG_Bridge.GetCurrent()
```

Example returned information includes:

```lua
{
    routeId = "...",
    moduleId = "...",
    stepIndex = 1,
    segmentIndex = 1,
    kind = "pickup",
    questIDs = { ... },
    objectiveIndex = 1,
    text = "...",
    target = {
        mapID = 1234,
        x = 50.0,
        y = 50.0,
        x01 = 0.5,
        y01 = 0.5,
        radius = 6
    }
}
```

The bridge also adds:

```text
/ftawgg
```

for diagnostics.

## Follow The Arrow installation

This repository intentionally does **not** redistribute the full Follow The Arrow addon.

Copy:

```text
fta_bridge/WGGBridge.lua
```

to:

```text
World of Warcraft/_retail_/Interface/AddOns/FollowTheArrow/Core/WGGBridge.lua
```

Then add:

```text
Core\WGGBridge.lua
```

to `FollowTheArrow.toc` after `Core\GuideArrow.lua`.

Confirm the bridge with:

```text
/ftawgg
```

## WardenGG installation

Copy:

```text
warden/_FTA_DirectMove_v0.4.lua
```

into the WardenGG script directory being loaded by the user's WGG setup.

Disable older movement prototypes while testing v0.4.

In game, use the clickable panel or:

```text
/ftadirect4
```

## Current architecture

```text
Follow The Arrow
      |
      | active route step + target
      v
FTA WGG Bridge
      |
      v
WardenGG Travel Controller
      |
      +-- direct ground movement
      +-- mount / takeoff
      +-- flight steering
      +-- obstacle recovery
      +-- Surge Forward
      +-- descent / landing
      |
      v
Near FTA destination
      |
      v
Live WardenGG Object Manager
      |
      +-- ObjectName
      +-- ObjectID
      +-- ObjectGUID
      +-- ObjectPos
      |
      v
Approach candidate
      |
      v
WGG.ObjectInteract()
      |
      v
Quest dialog opens
      |
      v
[ NEXT: accept / complete / reward handling ]
```

## Navigation-server work

A WardenGG Navigation Server integration is being investigated separately.

Current plan:

- use MMAP/VMAP-backed navigation when available
- use server-generated ground paths for obstacle-aware travel
- periodically generate/update flying path nodes
- retain the already-working direct movement controller as a fallback
- keep the current live-NPC approach/landing logic near the destination

The current v0.4 code does **not** require the navigation server.

## Why keep the direct controller?

The direct controller has already been proven in-game to:

1. reach an FTA destination,
2. correct after overshooting,
3. fly,
4. descend,
5. land at the NPC,
6. identify the live NPC,
7. interact with the NPC.

Even after MMAP/VMAP navigation is added, this makes a useful fallback and near-target controller.

## Current test target

Primary route:

```text
Midnight Alt 80–90
```

The project is intended to automate that route as reliably and quickly as practical.

## Known work remaining

- Explicit quest accept handling.
- Explicit quest completion / reward selection.
- Better deterministic questID -> expected NPC/ObjectID mapping.
- Objective/Kill/Collect/Use quest handlers.
- Combat integration.
- Special quest mechanic handlers.
- MMAP/VMAP navigation-server integration.
- More robust skyriding boost logic.
- Recovery around difficult city/indoor geometry.
- Additional route testing.

## Third-party projects

This repository contains only the integration/prototype code created for this project. It does not include or claim ownership of:

- Follow The Arrow
- WardenGG
- TrinityCore
- Arctium navigation data

Their respective code, data, names, and licenses belong to their owners/authors.

## Sharing and contributions

The code is being developed openly as a hobby project. Anyone interested in testing, discussing, improving, or adapting the ideas is welcome to follow the project and contribute where appropriate.

## Status

**Prototype / active development.**

The strongest verified milestone as of v0.4 is:

> FTA route target -> fly -> land in front of NPC -> live object scan -> approach NPC -> open quest dialog.
