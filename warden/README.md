# WardenGG controller

The original `_FTA_DirectMove_v0.4.lua` file in this repository is a **legacy milestone**, not the current controller.

Current experimental build:

```text
0.7.6-elevated-turnin-fix
```

The complete current controller and matching FTA bridge are packaged here:

```text
../latest/FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

Extract:

```text
WardenGG/_FTA_HybridNav_v0.7.6_ElevatedTurninFix.lua
```

into the WardenGG script directory used by your setup.

Do not load multiple old `_FTA_DirectMove*` / `_FTA_HybridNav*` controllers at the same time. Each script can independently steer the character, which produces exactly the sort of behavior one would expect from several robots fighting over the same steering wheel.

Current commands:

```text
/ftahybrid
/ftastate
/ftacandidates
```

See the repository root README and `docs/TEST_STATUS.md` for current verified/experimental status.
