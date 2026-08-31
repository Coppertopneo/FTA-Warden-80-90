# Architecture Notes

## High-level responsibilities

### Follow The Arrow

FTA is treated as the route brain.

The bridge reads the active resolved step and target rather than duplicating FTA's route database.

### WardenGG

WardenGG is currently responsible for:

- protected calls
- movement
- player/world position
- facing
- pitch
- raycasts
- live object enumeration
- live object position
- NPC/object interaction

## Current direct-travel design

The prototype deliberately started without MMAP/VMAP navigation.

That established whether FTA coordinates could drive real movement before adding a separate pathfinding service.

Live testing confirmed this works.

## Proposed hybrid navigation design

```text
FTA destination
      |
      v
Navigation manager
      |
      +-- Nav Server path available
      |       |
      |       +-- Ground: generated path
      |       +-- Flight: generated/recalculated nodes
      |
      +-- Nav Server unavailable / path failure
              |
              +-- direct movement fallback
      |
      v
Near destination
      |
      v
existing direct landing controller
      |
      v
live object scan
      |
      v
exact NPC/object position
      |
      v
interaction
```

The existing direct controller should remain even after nav-server integration because it has already proven useful for final approach, overshoot correction, and fallback behavior.

## Quest interaction status

The current interaction system can open the NPC dialog.

It does not yet explicitly call the quest accept/complete/reward APIs.

That is the immediate functional gap between the current prototype and an unattended pickup/turn-in cycle.
