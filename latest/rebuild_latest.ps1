$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$partsDir = Join-Path $root "parts"
$out = Join-Path $root "FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip"

$parts = Get-ChildItem $partsDir -Filter "FTA_HybridNav_v0.7.6_ElevatedTurninFix.zip.b64.*" | Sort-Object Name
if ($parts.Count -ne 4) {
    throw "Expected 4 package parts in $partsDir, found $($parts.Count)."
}

$b64 = ($parts | ForEach-Object { (Get-Content $_.FullName -Raw).Trim() }) -join ""
$bytes = [Convert]::FromBase64String($b64)

if ($bytes.Length -ne 29314) {
    throw "Unexpected decoded package size: $($bytes.Length) bytes. Expected 29314."
}

[IO.File]::WriteAllBytes($out, $bytes)
Write-Host "Built $out ($($bytes.Length) bytes)"
