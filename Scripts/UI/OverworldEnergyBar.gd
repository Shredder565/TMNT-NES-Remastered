class_name OverworldEnergyBar
extends TextureRect
## All the original shows over the overworld's map (Research/hud.md): the
## playing turtle's energy as eight sprites in a row near the bottom of
## the screen. Each sprite is 8 by 16 and stands for 16 energy, by the
## same rule as the strip in a room. The tiles are on the sprites' own
## graphics page and take the sprites' fourth colour group.

const AT := Vector2(96, 209)       ## first sprite's corner on the screen (measured)
const SPRITES := 8
const ENERGY_PER_SPRITE := 16
const TILE_FULL := 0xAA            ## each is this tile with the next one under it
const TILE_HALF := 0xAC
const TILE_EMPTY := 0xAE
const SPRITE_PAGE := 16
const COLOURS: Array[int] = [0x0F, 0x0F, 0x16, 0x37]   ## measured in world 1

var ripper: ChrRipper
var energy := -1

func _init() -> void:
	position = AT
	stretch_mode = TextureRect.STRETCH_KEEP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func use(new_ripper: ChrRipper) -> void:
	ripper = new_ripper
	var shown := energy
	energy = -1
	show_energy(maxi(shown, 0))

## The eight sprites' tiles for an energy from 0 to 128.
static func sprite_tiles(amount: int) -> PackedByteArray:
	var tiles := PackedByteArray()
	for tile: int in HudStrip.bar_tiles(amount):
		tiles.append(TILE_FULL if tile == HudStrip.BAR_FULL else (TILE_HALF if tile == HudStrip.BAR_HALF else TILE_EMPTY))
	return tiles

func show_energy(amount: int) -> void:
	if amount == energy:
		return
	energy = amount
	texture = ImageTexture.create_from_image(picture())

## The row as a picture, 64 by 16, clear where the sprites are.
func picture() -> Image:
	var image := Image.create(SPRITES * 8, 16, false, Image.FORMAT_RGBA8)
	if ripper == null:
		return image
	var shades: Array[Color] = []
	for number in COLOURS:
		shades.append(NesPalette.color(number))
	var tiles := sprite_tiles(maxi(energy, 0))
	for i in SPRITES:
		for half in 2:
			ripper.draw_tile(image, SPRITE_PAGE * ChrRipper.TILES_PER_BANK + tiles[i] + half, Vector2i(i * 8, half * 8), shades, false, false, true)
	return image
