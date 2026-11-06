# Runs every Frog Quest validator (headless, but button_words needs a window), then checks the real saves
# didn't change, byte for byte.   tools/run_validators.ps1 [name ...]
# Godot: $env:GODOT, else the 4.7.1 build on the Desktop.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$only)
$godot = if ($env:GODOT) { $env:GODOT } else { Join-Path $env:USERPROFILE "Desktop\Godot_v4.7.1-stable_win64.exe" }
$game = Split-Path -Parent $PSScriptRoot
$ud = Join-Path $env:APPDATA "Godot\app_userdata\Frog Quest+"
function Snap {
  Get-ChildItem -LiteralPath $ud -Recurse -File |
    Where-Object { $_.FullName -notlike "*\logs\*" -and $_.FullName -notlike "*\shader_cache\*" -and $_.FullName -notlike "*\vulkan\*" } |
    ForEach-Object { "{0} {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.Substring(0, 12), $_.FullName.Substring($ud.Length) }
}
$before = @(Snap)
$names = "app_store_release", "release_load", "muse_account", "endless", "flies", "desktop_frog", "ads_manager_runtime", "party", "party_online", "froggy_jump", "level", "layout_fit", "button_words", "story", "keyboard", "handles", "story_party", "creator", "world_life", "difficulty", "race", "frenzy", "og_endless"
if ($only) { $names = $only }
$failed = @()
foreach ($n in $names) {
  $run = @("--path", $game, "--script", "res://tools/validate_$n.gd")
  if ($n -ne "button_words") { $run = @("--headless") + $run }
  $out = & $godot $run 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  $last = ($out | Where-Object { $_ -match "pass|fail|PASS|FAIL|error|ERROR" } | Select-Object -Last 1)
  "{0,-20} exit {1}  {2}" -f $n, $code, $last
  if ($code -ne 0) {
    $failed += $n
    $out | Where-Object { $_ -match "FAIL|ERROR|error|Parse|SCRIPT|BLOCKER" } | Select-Object -First 30 | ForEach-Object { "    $_" }
  }
}
$after = @(Snap)
$diff = Compare-Object $before $after
if ($diff) { "USER FILES CHANGED:"; $diff } else { "user files unchanged ($($after.Count) files, byte for byte)" }
if ($failed) { "FAILED: $($failed -join ', ')"; exit 1 } else { "ALL PASSED" }
