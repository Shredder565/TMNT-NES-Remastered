# Leonardo's sprites in the original (USA ROM)

Worked out on 11 November 2026 by recording the console's sprite table
(256 bytes at PPU OAM) on every frame in MesenCE while Leonardo climbed,
walked, attacked, crouched and jumped in the first sewer.

- The game uses tall sprites: each is 8 pixels wide and 16 high (two tiles).
- With tall sprites, an even tile number comes from the graphics page in
  $0027 and an odd one from the page in $0028. In the sewer those were pages
  0 and 21. All of Leonardo's and his sword's tiles are in page 0, so their
  whole-ROM tile numbers are 0 to 255.
- Leonardo is 16 wide and 48 tall standing: two columns of three sprites,
  five or six sprites a frame. The sword is one or two extra sprites.
- Body colours are sprite palette 0 (NES colours 09, 12, 2A); the sword uses
  sprite palette 1 (02, 16, 31).
- The sprite table is written 3 frames after the position values change, so
  positions were matched against X/Y from 3 frames earlier.
- His feet are 24 pixels below the Y value in $0460; $0480 is his centre line.
  Facing left mirrors every sprite about that line.

## Animations (one update = 2 frames)

| Animation | Frames | Updates per frame |
| --- | --- | --- |
| Walk | walk1, stand, walk2, stand | 6 |
| Attack (B) | 3 | 2 |
| Attack upward (Up+B) | 4 | 2 |
| Crouch attack (Down+B) | 4 | 2 |
| Ladder climb | 2, mirrored alternately | about 4 |
| Jump | 1 (also used for a jump attack's end) | - |

Not captured yet: the hurt and defeated frames, swimming, the overworld
sprite, and the other three turtles (expected to share these tiles with a
different bandana colour, untested).

The map itself is `Resources/AssetRipper/Sprites/Leonardo.json`.
