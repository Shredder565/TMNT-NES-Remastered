# TMNT Remake (starter project)

A from-scratch Godot 4.6 remake project. It ships no game graphics or code
from the original. The player supplies their own ROM and the game builds its
graphics from that file on their machine.

## Setting up on another PC

Run `setup_tmnt_project.bat` on the new PC. It can be run from anywhere,
for example straight from a download. It installs Git if the PC has none,
gets this project into `%USERPROFILE%\TMNT-NES-Remastered` (or updates it),
downloads Godot 4.6.1 into the project's `Tools` folder, and writes
`godot_path.txt` so the other `.bat` files can find Godot. Run it again
later to get the latest version.

Then, in the project folder:

1. Run `play.bat` once and give the game your ROM on the ROM screen. The
   ROM and everything made from it stay in that PC's Godot user folder and
   are never synced, so this is needed once per PC.
2. Run `run_tests.bat`. It should end with RESULT: PASS.

`godot_path.txt` holds the full path of that PC's Godot `.exe` on one line.
It is not synced. Without it the `.bat` files look in
`C:\Users\Neil\MarioProject\Godot\`.

## Run it

- `open_in_godot.bat` opens the project in the Godot editor. Press F5 to play.
- `play.bat` runs the game without the editor.
- `run_tests.bat` runs the self-tests and prints PASS or FAIL.

Controls: arrow keys to move and climb ladders, Down to crouch, Z or Space to jump, X to attack,
F1 to open the tile viewer (needs a ROM). F3/F4 step through the 46 areas,
F7 shows the current world's overworld map, F8 switches the stand-in enemies
on and off, F6 toggles flying through walls, F2 opens the practice room.

With a ROM the game opens on the first overworld map, as the original does.
Walk onto a manhole or into a doorway to go in. Inside, climb a ladder out of
the top of the screen, or press Up in front of a doorway, to come back out.

Enemies stand where the original puts them, with its hit points and its
damage on touch. 24 of the 29 kinds are drawn from their own sprites, and 18
of those move: walkers and fliers that keep a steady speed, the foot-soldier
kind that hops, walks up and attacks, and kinds that leap, hop, charge or
ride up and down. Their speeds and timings are measured. For the kinds that
react to the turtle, the rules for when they act are a simple pattern fitted
to a few recordings, not the original's. The rest stand still for now.

Five kinds throw or fire things, with the original's speeds and damage. In
a room, enemies are made as the screen reaches their places and removed when
they leave it, so going away and coming back brings them back. A beaten
enemy leaves a puff. Three more kinds of floor act as in the original: one
hurts, one carries the turtle along, one drains his energy. Purple blocks, labelled with the kind
number, are the 5 kinds not recorded yet. See `Research/enemy_kinds.md`.

## Where things are

| Folder | What is in it |
| --- | --- |
| `Scenes/` | Scene files: the boot scene, ROM screen, test room, turtle, tile viewer |
| `Scripts/Singletons/Game.gd` | Shared settings: file paths and key bindings |
| `Scripts/Rom/RomInfo.gd` | Checks that a file is the right game |
| `Scripts/Rom/ChrRipper.gd` | Turns the ROM's tile data into images |
| `Scripts/Player/Turtle.gd` | Movement, jump and attack for one turtle |
| `Scripts/Rom/RomLevels.gd` | Reads every room, every overworld map and the doors between them from the ROM |
| `Scripts/Rom/Door.gd` | One door: where it is and where it leads |
| `Scripts/Rom/EnemySpot.gd` | One place where the original puts an enemy |
| `Scripts/Enemies/Crawler.gd` | The enemy kinds that walk or fly at a steady speed |
| `Scripts/Enemies/Soldier.gd` | Enemy kinds 98 (the foot-soldier-looking one) and 49, which walk up to the turtle |
| `Scripts/Enemies/Leaper.gd` | Enemy kinds 92, 9D and 9E, which leap, hop and jump |
| `Scripts/Enemies/Charger.gd` | Enemy kind A0, which charges |
| `Scripts/Enemies/PathEnemy.gd` | Enemy kind 88, which rides up and down |
| `Scripts/Enemies/Shot.gd` | The things enemies throw and fire |
| `Scripts/Enemies/Puff.gd` | The puff a beaten enemy leaves |
| `Scripts/Player/OverworldTurtle.gd` | The small turtle that walks the overworld map |
| `Scripts/Levels/RoomScene.gd` | Shows a room or a map and takes the turtle through doors |
| `Resources/AssetRipper/Sprites/` | Sprite maps (which tiles make which sprite) |
| `Research/` | Notes on how the original works, and the emulator scripts used |
| `Tests/` | Self-tests that use a fake ROM built in memory |

## Sprite map format

A sprite map is a small JSON file that says which tiles to paste where.
It contains tile numbers only, never pixels, so it is safe to commit.

```json
{
  "size": [16, 32],
  "palette": "Leonardo",
  "tiles": [
    { "x": 0, "y": 0, "index": 0, "flip_h": false, "flip_v": false }
  ]
}
```

`index` counts tiles across the whole 128 KB graphics block, 0 to 8191.
The tile viewer (F1) shows the index of the tile under the mouse.

## Rules for this repository

- Never commit a ROM, or any image ripped from one. `.gitignore` blocks `*.nes`.
- Ripped images are written to Godot's user folder, outside the project:
  `%APPDATA%\Godot\app_userdata\TMNT Remake\rom_assets`.
