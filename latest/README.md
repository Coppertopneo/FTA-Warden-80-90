# Latest experimental package

Current experimental controller:

```text
0.7.6-elevated-turnin-fix
```

Current FTA bridge:

```text
0.4.2-fta-satisfied
```

The ZIP is stored as four Base64 text parts because this repository update path does not reliably accept the binary archive directly. Rebuild it on Windows with:

```powershell
powershell -ExecutionPolicy Bypass -File .\latest\rebuild_latest.ps1
```

That creates:

```text
latest\FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip
```

The rebuild script verifies the decoded archive is exactly **29,314 bytes** before accepting it.

The resulting ZIP contains:

```text
README_FIRST.txt
WardenGG/_FTA_HybridNav_v0.7.6_ElevatedTurninFix.lua
FollowTheArrow/Core/WGGBridge.lua
```

The Base64 parts under `latest/parts/` are source data for the reconstruction script and normally do not need to be opened by hand, unless staring at Base64 is how you choose to spend an evening.
