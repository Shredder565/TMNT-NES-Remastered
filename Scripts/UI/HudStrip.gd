class_name HudStrip
extends TextureRect
## The strip under a room's picture, as the original draws it
## (Research/hud.md): "Pts." and the score, the playing turtle's energy as
## eight tiles, his weapon's box, the box for his special weapon with how
## many he has under it, and "HI" with the best score; a boss's energy goes
## under the turtle's. The boxes are read from the original's code (bank 0,
## $82E8) and measured for all four turtles (Research/score.md).
## It is made of tiles from the room's own graphics page in the room's
## first colour group, so it needs the ROM; without one RoomScene keeps
## its plain bar and text.
##
## The original has no strip on the overworld.

const COLS := 32
const FIRST_LINE := 195        ## the strip's first screen line (measured)
const LINES := 45              ## down to the last line of the screen
const ROW_HEADROOM := 6        ## lines of an empty row showing above the first row of tiles
const LEFT_HIDDEN := 8         ## the console hides the left 8 pixels
const RIGHT_HIDDEN_FROM := 248 ## and the original covers the right 8 with sprites

## Tile numbers (measured; the same in every room's page).
const WORD_PTS: Array[int] = [0x1F, 0x2F, 0x0B]
const WORD_HI: Array[int] = [0x17, 0x18]
const DIGIT_ZERO := 0x0A       ## the digits are tiles 1 to 9, and 10 for nought
const BAR_FULL := 0x30
const BAR_HALF := 0x31
const BAR_EMPTY := 0x32
const WEAPON_BOX := 0x40       ## four tiles per turtle from here: left column top, bottom, then right column
const EMPTY_BOX := 0x3C        ## the same order
const SPECIAL_BOX := 0x4C      ## plus 4 for each special weapon number (1 to 4): its four tiles, the same order
const THIRD_ITEM_BOX := 0x34   ## the four tiles of the third box's item, when any is held
const BAR_TILES := 8
const ENERGY_PER_TILE := 16
const SCORE_DIGITS := 7

## Where things go, as column and row of the strip (row 0 is the first row of tiles).
const PTS_AT := Vector2i(1, 0)
const SCORE_AT := Vector2i(4, 0)
const BAR_AT := Vector2i(12, 0)
const WEAPON_AT := Vector2i(21, 0)
const SPECIAL_AT := Vector2i(24, 0)
const THIRD_AT := Vector2i(27, 0)
const HI_AT := Vector2i(1, 2)
const HI_SCORE_AT := Vector2i(4, 2)
const SPECIAL_COUNT_AT := Vector2i(24, 2)   ## two digits under the special weapon's box
const THIRD_COUNT_AT := Vector2i(27, 2)
const BOSS_BAR_AT := Vector2i(12, 2)
const ROWS := 5                ## rows of tiles the strip reaches (the last ones are empty)

var ripper: ChrRipper
var page := 0
var colours: Array = [0x0F, 0x01, 0x16, 0x20]
var turtle := 0
var energy := 128
var score := 0
var high_score := 0
var boss_energy := -1          ## under 0: no boss, no second bar
var third_box := false         ## worlds 3 and 4 show one more box (code: the table at bank 0, $8402)
var special := 0               ## the playing turtle's special weapon number, 0 for none
var special_count := 0         ## how many of it he has (shown as two digits when not 0)
var special_blanked := false   ## while the special weapon is the one in use its box blinks: true on the frames it is blank
var third_count := 0           ## how many of the third box's item are held

func _init() -> void:
	position = Vector2(0, FIRST_LINE)
	stretch_mode = TextureRect.STRETCH_KEEP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## The tiles come from this page in these four colours (a room's first group).
func use(new_ripper: ChrRipper, new_page: int, new_colours: Array) -> void:
	ripper = new_ripper
	page = new_page
	if new_colours.size() >= 4:
		colours = new_colours
	refresh()

func show_turtle(index: int, new_energy: int) -> void:
	if index == turtle and new_energy == energy:
		return
	turtle = index
	energy = new_energy
	refresh()

func show_boss(new_energy: int) -> void:
	if new_energy == boss_energy:
		return
	boss_energy = new_energy
	refresh()

## The special weapon's box: which weapon (0 for none), how many, and
## whether the box is blanked just now (it blinks while that weapon is the
## one in use: blank for 8 frames in every 16).
func show_special(number: int, count: int, blanked := false) -> void:
	if number == special and count == special_count and blanked == special_blanked:
		return
	special = number
	special_count = count
	special_blanked = blanked
	refresh()

func show_third(count: int) -> void:
	if count == third_count:
		return
	third_count = count
	refresh()

## A count as the original writes it: two digits, nought being tile 10.
static func count_tiles(count: int) -> PackedByteArray:
	var value := clampi(count, 0, 99)
	var tens := value / 10
	var units := value % 10
	return PackedByteArray([tens if tens != 0 else DIGIT_ZERO, units if units != 0 else DIGIT_ZERO])

func show_scores(new_score: int, new_high: int) -> void:
	if new_score == score and new_high == high_score:
		return
	score = new_score
	high_score = new_high
	refresh()

## The eight tiles of an energy bar: one full tile for each 16; of what is
## left over, 8 or more is another full tile and 1 to 7 a half one.
static func bar_tiles(amount: int) -> PackedByteArray:
	var value := clampi(amount, 0, BAR_TILES * ENERGY_PER_TILE)
	var full := value / ENERGY_PER_TILE
	var rest := value % ENERGY_PER_TILE
	var tiles := PackedByteArray()
	for i in BAR_TILES:
		if i < full:
			tiles.append(BAR_FULL)
		elif i == full and rest >= 8:
			tiles.append(BAR_FULL)
		elif i == full and rest > 0:
			tiles.append(BAR_HALF)
		else:
			tiles.append(BAR_EMPTY)
	return tiles

static func digit_tiles(number: int) -> PackedByteArray:
	var tiles := PackedByteArray()
	var value := clampi(number, 0, 9999999)
	for i in SCORE_DIGITS:
		var digit := value % 10
		tiles.insert(0, digit if digit != 0 else DIGIT_ZERO)
		value /= 10
	return tiles

## The strip's tiles, ROWS rows of 32.
func tiles() -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(COLS * ROWS)
	_put(cells, PTS_AT, WORD_PTS)
	_put(cells, SCORE_AT, digit_tiles(score))
	_put(cells, BAR_AT, bar_tiles(energy))
	_put_box(cells, WEAPON_AT, WEAPON_BOX + 4 * clampi(turtle, 0, 3))
	if special == 0:
		_put_box(cells, SPECIAL_AT, EMPTY_BOX)
	elif not special_blanked:
		_put_box(cells, SPECIAL_AT, SPECIAL_BOX + 4 * special)
	if special_count > 0:
		_put(cells, SPECIAL_COUNT_AT, count_tiles(special_count))
	if third_box:
		_put_box(cells, THIRD_AT, THIRD_ITEM_BOX if third_count > 0 else EMPTY_BOX)
		if third_count > 0:
			_put(cells, THIRD_COUNT_AT, count_tiles(third_count))
	_put(cells, HI_AT, WORD_HI)
	_put(cells, HI_SCORE_AT, digit_tiles(high_score))
	if boss_energy >= 0:
		_put(cells, BOSS_BAR_AT, bar_tiles(boss_energy))
	return cells

func tile_at(col: int, row: int) -> int:
	return tiles()[row * COLS + col]

func _put(cells: PackedByteArray, at: Vector2i, values: Variant) -> void:
	for i in values.size():
		cells[at.y * COLS + at.x + i] = values[i]

func _put_box(cells: PackedByteArray, at: Vector2i, first: int) -> void:
	for i in 4:
		cells[(at.y + i % 2) * COLS + at.x + i / 2] = first + i

## The strip as a picture, 256 by 45.
func picture() -> Image:
	var image := Image.create(256, LINES, false, Image.FORMAT_RGBA8)
	image.fill(NesPalette.color(colours[0]))
	if ripper == null:
		return image
	var shades: Array[Color] = []
	for number: int in colours.slice(0, 4):
		shades.append(NesPalette.color(number))
	var cells := tiles()
	for index in cells.size():
		var col := index % COLS
		if cells[index] == 0 or col * 8 < LEFT_HIDDEN or col * 8 >= RIGHT_HIDDEN_FROM:
			continue
		ripper.draw_tile(image, page * ChrRipper.TILES_PER_BANK + cells[index], Vector2i(col * 8, ROW_HEADROOM + (index / COLS) * 8), shades)
	return image

func refresh() -> void:
	texture = ImageTexture.create_from_image(picture())
