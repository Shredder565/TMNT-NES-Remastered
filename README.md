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

Controls: arrow keys to move and climb ladders, Down to crouch, Z or Space to jump, X to attack
(hold Up or Down to swing upward or downward),
C or Backspace is the NES pad's Select (in a room it changes between the
turtle's own weapon and his special weapon; Back on a controller),
F1 to open the tile viewer (needs a ROM). F3/F4 step through the 46 areas,
F7 shows the current world's overworld map, F8 switches the stand-in enemies
on and off, F6 toggles flying through walls, F2 opens the practice room.

A controller works as soon as it is plugged in, with no setup (Xbox layout;
PlayStation and Switch pads map onto it): d-pad or left stick to move, climb
and crouch, A to jump, X or B to attack. Start (Enter on the keyboard) opens the original's
information screen, built from your ROM: Up and Down choose a turtle, Start
goes back to play.

With a ROM the game opens on the first overworld map, as the original does.
Walk onto a manhole or into a doorway to go in. Inside, climb a ladder out of
the top of the screen, or press Up in front of a doorway, to come back out.

Enemies stand where the original puts them, with its hit points and its
damage on touch. 26 of the 29 kinds are drawn from their own sprites, and 18
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
| `Scripts/Singletons/Game.gd` | Shared settings: file paths, key and controller bindings |
| `Scripts/Rom/RomInfo.gd` | Checks that a file is the right game |
| `Scripts/Rom/ChrRipper.gd` | Turns the ROM's tile data into images |
| `Scripts/Player/Turtle.gd` | Movement, jump and attack for one turtle |
| `Scripts/Rom/RomLevels.gd` | Reads every room, every overworld map and the doors between them from the ROM |
| `Scripts/Rom/Door.gd` | One door: where it is and where it leads |
| `Scripts/Rom/EnemySpot.gd` | One place where the original puts an enemy |
| `Scripts/Enemies/OriginalEnemy.gd` | What every enemy written from the original's own code shares (`Research/enemy_routines.md`) |
| `Scripts/Enemies/Soldier.gd`, `Star.gd` | Enemy kind 98, the foot soldier, and its star (99), by the original's rules |
| `Scripts/Enemies/Flier.gd` | Kinds 81 and 96 (and 8E, 8F): level fliers, by the original's rules |
| `Scripts/Enemies/LedgeWalker.gd` | Kinds 8D and 84: walkers that drop off ledges, by the original's rules |
| `Scripts/Enemies/CeilingCrawler.gd` | Kind 86: along the ceiling, and a swoop, by the original's rules |
| `Scripts/Enemies/Lurker.gd` | Kind 49: waits, comes out, throws, goes back in, by the original's rules |
| `Scripts/Enemies/Chainsaw.gd` | Kind 91, by the original's rules |
| `Scripts/Enemies/Pouncer.gd`, `Boomerang.gd` | Kind 92 and what it throws (93), by the original's rules |
| `Scripts/Enemies/Gunner.gd` | Kind 94, by the original's rules |
| `Scripts/Enemies/Diver.gd` | Kind AA: bobs in the air, then flies at the turtle, by the original's rules |
| `Scripts/Enemies/Missile.gd` | Kinds 4A and 95: thrown and fired things that fly level, by the original's rules |
| `Scripts/Enemies/Crawler.gd` | Fitted to measurements: the kinds not yet read from the code that walk or fly at a steady speed |
| `Scripts/Enemies/LegacyWalker.gd` | The old fitted pattern for kind 49 (no longer used by the room scene) |
| `Scripts/Enemies/Leaper.gd` | Fitted to measurements: kinds 9D and 9E, which hop and jump (and the old pattern for 92) |
| `Scripts/Enemies/Shot.gd` | Fitted to measurements: the things the other enemies throw and fire |
| `Scripts/Enemies/Charger.gd` | Enemy kind A0, which charges |
| `Scripts/Enemies/PathEnemy.gd` | Enemy kind 88, which rides up and down |
| `Scripts/Enemies/Puff.gd` | The puff a beaten enemy leaves |
| `Scripts/Enemies/Boss.gd` | What the bosses share |
| `Scripts/Enemies/Bebop.gd` | World 1's first boss, in the second sewer |
| `Scripts/Enemies/Rocksteady.gd` | World 1's last boss |
| `Scripts/Levels/Item.gd` | Pizzas and other things to pick up |
| `Scripts/Player/OverworldTurtle.gd` | The small turtle that walks the overworld map |
| `Scripts/Levels/RoomScene.gd` | Shows a room or a map and takes the turtle through doors |
| `Resources/AssetRipper/Sprites/` | Sprite maps (which tiles make which sprite) |
| `Research/` | Notes on how the original works, and the emulator scripts used |
| `Tests/` | Self-tests that use a fake ROM built in memory |

## Sound

With a ROM installed the game plays the original's sound effects and the
title tune through its own sound driver and synthesizer, from the ROM's
music data (`Research/sound.md`). M turns sound on and off. Music in play
is not wired in yet.

## World 1

With a ROM installed the game opens on the original's notice and title
screen, built from the ROM's own layout (`Research/title_screen.md`); Start
begins play.

World 1 can be played from its overworld to its end: the six rooms, their
enemies, three pizzas and one other item, the first boss at the end of the
second sewer and the last boss in the last room. The bosses come in where
the ROM's own table says, the screen holds still while one is fought, and
its energy shows under the turtle's. Three more places stop the screen
until the enemies there are beaten. Beating the last boss plays the
original's ending of the world (the turtle walks to April, she speaks on
the Start screen: `Research/world_end.md`) and opens world 2's overworld.
The score is kept as the original keeps it (`Research/score.md`).

How the turtle meets walls, ledges and ceilings, and how the screen
scrolls, follow the original's own rules, read from its code. In eighteen
scripted runs through world 1's rooms the turtle's path now matches the
original's exactly, to the fraction of a pixel
(`Research/turtle_collision.md`, `Research/scrolling.md`). Items, the
enemies' safe time after a hit and hurting tiles are in
`Research/items_and_hits.md`.

What is still missing from world 1 is listed at the end of
`Research/world1.md`.

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
- The same goes for the game's program code. `Research/tools/disassemble_rom.py`
  turns your own ROM into a readable listing in `rom_listing/`, which
  `.gitignore` blocks. We read the listing, write down in `Research/` what
  the original does in our own words, and write our own code from that.
  The listing itself, or code translated line for line from it, is never
  committed.
