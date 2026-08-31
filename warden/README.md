# WardenGG controller

The original `_FTA_DirectMove_v0.4.lua` in this directory is a **legacy milestone**, not the current controller.

Current experimental build:

```text
0.7.6-elevated-turnin-fix
```

The current complete controller is stored in the reconstructed package under `latest/`.

From the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\latest\rebuild_latest.ps1
```

That creates:

```text
latest\FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

Extract:

```text
WardenGG/_FTA_HybridNav_v0.7.6_ElevatedTurninFix.lua
```

into the WardenGG script directory used by your setup.

Do not load multiple old `_FTA_DirectMove*` / `_FTA_HybridNav*` controllers at the same time. Each script can independently steer the character, which is a charming way to discover what happens when several robots share one steering wheel.

Current commands:

```text
/ftahybrid
/ftastate
/ftacandidates
```

See the repository root README and `docs/TEST_STATUS.md` for current verified/experimental status.
