# Welcome to FROG QUEST

This is the biggest game project I've worked on. I learned a lot making the last two game jam games I made, and wanted to go for a bigger scope. I hope you're ready to embark on the FROG QUEST !

## Newcomer quick tour

### What this project is
Frog Quest is a Godot 4.2 2D platformer where you launch a frog upward with mouse-drag jumps, meet NPC frogs, collect a lantern/key, and eventually reach a finale sequence near the top of the climb.

### Directory structure at a glance
- `project.godot`: engine/project config (main scene, input map, autoloads, display settings).
- `scenes/`: `.tscn` scene files and a few scene-specific scripts.
- `scripts/`: gameplay scripts attached to scene nodes.
- `assets/`: sprites, audio, tile textures, fonts, and import metadata.
- `Main.tres` / `Shadow.tres`: tile sets used by tilemaps.

### Core gameplay architecture
- **Main world scene**: `scenes/Main.tscn` is the root scene and uses `scripts/Main.gd`.
- **Player subscene**: `scenes/player.tscn` is instanced inside `Main.tscn` and uses `scripts/player.gd`.
- **Jump mechanic**: `scripts/Trajectory.gd` calculates velocity from mouse drag and writes to player velocity on release.
- **Global state**: `scripts/MusicManager.gd` is autoloaded to persist small cross-reload state (music playback position / crown unlock).

### Important systems to understand first
1. **Input map and controls**
   - Mouse launch (`ui_mouse`), lantern toggle (`ui_light` / F), pause, fullscreen, mute, fast-forward debug input are all in `project.godot`.
2. **Player loop** (`scripts/player.gd`)
   - Handles gravity/movement, score/time HUD, darkness+lantern behavior, key/keyhole interactions, title/pause/winscreen UI flow, and endgame camera sequence.
3. **World event script** (`scripts/Main.gd`)
   - Handles NPC dialogs and triggers, collectible spawns, blocked path changes, finale progression, and some global toggles (pause/fullscreen).

### Conventions and practical tips
- A lot of behavior is node-path based (`$"../..."`), so scene hierarchy changes can break scripts quickly.
- Most interactions are signal-driven from `Area2D` overlaps into `_on_*` handlers.
- There is intentionally playful/rapid-prototype code in places (repeated handlers, inline strings, comments marked for cleanup).

### Suggested learning path
1. Open `project.godot` to understand startup scene and inputs.
2. Open `scenes/Main.tscn` and inspect the high-level node tree.
3. Open `scenes/player.tscn` to see UI + camera + trajectory wiring.
4. Read `scripts/Trajectory.gd`, then `scripts/player.gd`, then `scripts/Main.gd`.
5. If you plan refactors, start by reducing repeated trigger handlers and centralizing dialogue data.
