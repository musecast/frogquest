# Publishes an update for a store build of Frog Quest, over the air (scripts/Updater.gd): everything in the game
# changed since that build, as a patch pack (only the changed files, each as just its changes), put in
# ota/manifest.json and signed with the update key (kept on this PC, outside the repo). Then commit and push
# ota/: phones on that build get it the next time the game opens, and it's in from the time after.
#   tools/ota/publish_update.ps1 -Build 33             a new update for build 33
#   tools/ota/publish_update.ps1 -Build 33 -TakeBack   none for build 33: its phones go back to the build's own
# The build's own pack comes from its GitHub release (build-33, made by the TestFlight workflow), kept in
# %LOCALAPPDATA%\FrogQuestOTA. Run every validator first. An update can't change scripts/Updater.gd, the
# engine, the plugins, the icon, name or settings, or the privacy manifest: those need a build.
param([Parameter(Mandatory = $true)][int]$Build, [switch]$TakeBack)
$ErrorActionPreference = "Stop"
$godot = if ($env:GODOT) { $env:GODOT } else { Join-Path $env:USERPROFILE "Desktop\Godot_v4.7.1-stable_win64.exe" }
$game = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$key = Join-Path $env:USERPROFILE ".frogquest-ota\signing_key.pem"
$cache = Join-Path $env:LOCALAPPDATA "FrogQuestOTA"
if (-not (Test-Path $key)) { throw "No update key at $key (it's made once, and kept there)" }
if (Test-Path (Join-Path $game "build_info.cfg")) { throw "build_info.cfg is in the game folder: it's only ever a build's own (the workflow writes it). Delete it first." }
New-Item -ItemType Directory -Force $cache | Out-Null

function Run-Godot([string[]]$a) {
  $out = & $godot @a 2>&1 | ForEach-Object { "$_" }
  return @{ code = $LASTEXITCODE; out = $out }
}

if ($TakeBack) {
  $r = Run-Godot @("--headless", "--path", $game, "--script", "res://tools/ota/make_update.gd", "--", "$Build", "take-back", $key)
} else {
  $base = Join-Path $cache "base-$Build.pck"
  if (-not (Test-Path $base)) {
    $from = "https://github.com/musecast/frogquest/releases/download/build-$Build/base.pck"
    "Getting build $Build's own pack: $from"
    Invoke-WebRequest -Uri $from -OutFile "$base.part" -UseBasicParsing
    Move-Item -Force "$base.part" $base
  }
  "Build $Build's own pack: {0:N1} MB" -f ((Get-Item $base).Length / 1MB)
  $patch = Join-Path $cache "update-$Build.pck"
  Remove-Item -Force -ErrorAction SilentlyContinue $patch
  $r = Run-Godot @("--headless", "--path", $game, "--export-patch", "iOS", $patch, "--patches", $base)
  if ($r.out -match "No files or changes to export") { "Nothing's changed in the game since build $Build: no update."; exit 0 }
  if ($r.code -ne 0 -or -not (Test-Path $patch)) { $r.out | Select-Object -Last 30; throw "The update couldn't be made" }
  $r.out | Where-Object { $_ -match "Storing File" } | ForEach-Object { "  " + ($_ -replace '\x1b\[[0-9;]*m', '' -replace '^.*Storing File: ', '') }
  $r = Run-Godot @("--headless", "--path", $game, "--script", "res://tools/ota/make_update.gd", "--", "$Build", $patch, $key)
}
$r.out | Where-Object { $_ -match "^Build |^List signed|couldn't|doesn't match|usage" }
if ($r.code -ne 0) { throw "The list couldn't be made" }
"Now commit and push ota/ (git add ota)."
