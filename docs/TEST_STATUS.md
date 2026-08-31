# Test Status

This file separates what has been seen working in live testing from what is only implemented in the newest experimental build. Human beings have a long tradition of calling code "done" immediately after it compiles; this project is attempting slightly higher standards.

| Component | Status | Notes |
|---|---|---|
| FTA bridge access | ✅ Verified | Reads active FTA state in game. |
| FTA map -> world coordinates | ✅ Verified | Travel reaches the intended route area. |
| WGG Navigation Server connection | ✅ Verified | Localhost navigation server connected successfully. |
| MMAP/VMAP path generation | ✅ Verified | Used during hybrid navigation tests. |
| Direct travel fallback | ✅ Verified | Original travel controller remains useful as fallback. |
| Mount / takeoff | ✅ Verified | Character can mount and enter flight. |
| Flight steering | ✅ Verified | Character follows long-distance destination direction. |
| Controlled landing | ✅ Verified | Character has landed at/near the intended quest NPC/area. |
| Native ground `MoveAlongPath` integration | 🟡 Working, still rough | Added to reduce building/bush/corner collisions; difficult geometry can still expose edge cases. |
| Object-manager scanning | ✅ Verified | Live NPCs/mobs/objects are discovered by Warden. |
| NPC/Object interaction | ✅ Verified | `ObjectInteract()` has opened quest interactions. |
| Quest acceptance | ✅ Verified | At least two quests were accepted during live testing. |
| FTA `SEQUENCE_CHAIN` task matching | ✅ Verified | Multi-objective Fairbreeze route state was read/matched. |
| Live quest objective progress | ✅ Verified | `/ftastate` reports current quest/objective progress. |
| Semantic action classification | ✅ Verified | `Help Citizens` correctly changed from incorrect KILL handling to INTERACT. |
| Kill objective target acquisition | ✅ Verified | Controller successfully found and attacked quest mobs. |
| External combat-rotation handoff | ✅ Verified | Selected quest mobs were killed by the active rotation. |
| Strict named kill filtering | 🟡 Partially verified | Intended to reject unrelated nearby hostiles; still needs broader route coverage. |
| Objective completion filtering | 🟡 Partially verified | Uses live progress + FTA satisfaction; more route testing needed. |
| Precise interaction-node latch | ✅ Verified enough to continue | Stops treating the exact FTA arrow pixel as a parking requirement. |
| Fairbreeze Mr. Fluff identification | ✅ Verified | Correct object found: Mr. Fluff, ObjectID 244042, very close to FTA marker. |
| Elevated-object staging/world click | 🧪 Experimental v0.7.6 | Implemented after ground path returned 0 for Mr. Fluff's elevated Z. Needs live validation. |
| Multi-quest turn-in handling | 🧪 Experimental v0.7.6 | Expanded route/gossip quest-ID matching. Needs live validation. |
| Extra-action quest mechanics | 🟡 Partial | Generic handling exists; route-specific behavior needs more testing. |
| Collect/use/click objectives | 🟡 Partial | Generic interaction framework exists, but bespoke mechanics remain. |
| Escort/follow/vehicle/puzzle quests | ❌ Not general | Require special handlers. |
| Full unattended 80–90 route | ❌ Not complete | End-to-end route is still under active development. |

## Current experimental version

```text
Controller: 0.7.6-elevated-turnin-fix
Bridge:     0.4.2-fta-satisfied
```

Latest package:

```text
latest/FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

## Current testing focus

The main development focus is now the objective/interaction layer rather than basic travel:

1. reliably interact with elevated/awkward quest objects,
2. turn in multiple completed quests at clustered NPCs,
3. continue reducing ground-navigation collisions around buildings and vegetation,
4. add quest-specific handlers only where generic route/object logic is insufficient,
5. keep validating that completed objectives are not repeated.
