# Architecture

## 1. Follow The Arrow as route authority

Follow The Arrow remains the high-level route source. The controller does not invent a leveling route. It consumes the currently resolved FTA state and attempts to execute it.

The bridge exports information including:

- route ID and module ID
- step and segment indexes
- segment kind
- quest name and quest IDs
- active quest ID
- objective index
- live WoW objective text/type/progress
- current FTA target coordinates
- `SEQUENCE_CHAIN` index and current route requirement
- visible unfinished actionable segments
- recommended routed segment
- FTA `IsSegmentSatisfied()` result

This distinction matters on multi-objective steps because FTA's first unfinished segment is not necessarily the same objective as the current optimized arrow/sequence node.

## 2. Route-task planner

The Warden controller selects a current task from the bridge's routed state.

Conceptually:

```text
FTA step
  +-- current sequence-chain node
  +-- route gate / required quest objective
  +-- unfinished segments
              |
              v
       recommended routed task
```

Completion is checked against both live WoW objective progress and FTA's own `IsSegmentSatisfied()` logic.

## 3. Hybrid navigation

FTA still supplies the destination coordinates. MMAP/VMAP data changes how the character travels to those coordinates.

### Ground

Primary ground flow:

```text
FTA destination
      ↓
map -> world coordinates
      ↓
WGG FindPath
      ↓
WGG MoveAlongPath
      ↓
progress watchdog / repath
```

The custom direct-ground controller remains a fallback for short approaches and navigation failures.

### Flight

Flight uses nav-generated waypoint information with the custom flight controller for:

- mounting
- takeoff
- heading/pitch control
- controlled `Surge Forward` attempts
- obstacle raycasts
- recovery/detours
- descent
- final landing

Near the destination the controller intentionally transitions from long-distance travel into objective-specific logic.

## 4. Objective dispatcher

After the current routed task is known, the controller classifies it into an action.

### PICKUP / TURNIN

- scans near the routed quest marker
- opens NPC gossip
- matches currently actionable quest IDs
- selects available or active quests
- handles quest detail/progress/complete events
- accepts/completes/rewards where supported

v0.7.6 extends this to consider multiple currently actionable pickup/turn-in quest IDs rather than only the root active segment.

### KILL

- scans loaded hostile units
- uses strict matching against the current routed objective instead of accepting every hostile nearby
- targets the chosen live object
- approaches it
- hands the valid target to an external combat rotation
- clears attack/target state when the objective changes or completes

### INTERACT

- semantic classification gives route/live objective text priority over raw WoW objective type
- precise FTA route nodes can create an interaction-area latch
- loaded objects are scored by marker distance and objective semantics
- known quest mechanics can add quest-specific matching
- normal interaction uses Warden object/world interaction APIs

### Elevated interaction objects

Ground nav cannot path directly to objects located on top of statues, ledges, etc.

v0.7.6 introduces:

```text
elevated object ObjectPos
      ↓
reachable ground staging point
      ↓
face object
      ↓
pitch toward object
      ↓
world-space MouseClick
      ↓
ObjectInteract fallback
```

This was added after the controller correctly identified Mr. Fluff in Fairbreeze but received no ground path to his elevated Z coordinate.

### EXTRA_ACTION

The controller can identify certain route tasks requiring an extra-action button, approach a matching object/unit and attempt the extra action.

## 5. Recovery and fallbacks

The project deliberately retains several layers rather than trusting one navigation method blindly:

```text
native WGG ground path
       ↓ fail/stall
repath / short direct recovery

flight nav nodes
       ↓ fail
custom direct flight controller
       ↓
raycast obstacle recovery
```

## 6. Diagnostics

Current commands:

```text
/ftawgg          bridge state
/ftahybrid       controller toggle
/ftastate        route/task/objective dump
/ftacandidates   current interaction candidates
```

These diagnostics are intentionally verbose while the route executor is still being developed.

## 7. External combat rotation

Travel/quest logic and class combat logic are intentionally separated.

The FTA/Warden controller chooses the correct routed hostile and gets into a usable combat position. A separate Warden-compatible combat rotation is expected to cast the class/spec abilities.

This avoids turning the quest/navigation controller into a giant class-specific rotation framework.
