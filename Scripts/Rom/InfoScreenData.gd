class_name InfoScreenData
extends RefCounted
## Reads the Start screen (the original calls it INFORMATION) out of the
## player's ROM: its tile layout, its colours, the small area maps, the
## messages and the tables that say where each changing part goes.
## Nothing is copied into the project; see Research/start_screen.md for how
## the original builds the screen and what each table is.
##
## The screen is kept the way the console keeps it: 30 rows of 32 tile
## numbers, 64 colour bytes (one per 4 x 4 tiles, two bits per 2 x 2), and a
## list of 32 colour numbers. Places on it are console screen addresses:
## $2000 is the top-left tile, one row is 32 addresses, and the colour bytes
## begin at $23C0.

const COLS := 32
const ROWS := 30
const SCREEN_START := 0x2000
const COLOUR_BYTES_START := 0x23C0
const GRAPHICS_PAGE := 0x1B        ## the 4 KB page its background tiles come from
const PALETTE_ID := 3              ## its colour list in the ROM's palette table
const TURTLES := 4

## Tables in program bank 7
const T_LAYOUTS := 0xE3CE          ## screen layouts; the Start screen is entry 4 and lies in bank 3
const LAYOUT_ENTRY := 4
const T_STRINGS := 0xCAB7          ## short lists of tiles to put on the screen
const T_SELECT_STRINGS := 0xD1C1   ## per turtle: (string that lights his row, colour patch number)
const UNSELECT_STRING := 8         ## plus the turtle number: the string that dims his row again
const T_COLOUR_PATCHES := 0xFA36   ## colour patches: where in the colour list, then the colours, ends $FE
const T_PALETTES := 0xF796
const T_BANDANAS := 0xD675         ## per turtle: the colour of his bandana on his own sprites
## Tables in program bank 3
const T_BAR_PLACES := 0xADAD       ## per turtle: where his energy bar starts
const T_WEAPON_PLACES := 0xADB5    ## per turtle: where his special weapon's picture goes
const T_WEAPON_TILES := 0xADBD     ## per special weapon: its four tiles
const T_CAPTURED_TILES := 0xAC6E   ## the 3 x 3 tiles put over a captured turtle's face
const CAPTURED_PLACES := [0x2095, 0x2115, 0x2195, 0x2215]
const WORLD_NUMBER_PLACE := 0x2035
const T_HAS_MISSILES := 0xAD8B     ## per world: does this world use the first item box
const T_HAS_ROPES := 0xAD92        ## per world: and the second
const T_ITEM_PLACES := 0xADA1      ## six places (high byte first) used for the two item boxes
const T_ITEM_COLOURS := 0xAA10     ## four sets of three colour bytes for the item boxes
const ITEM_COLOURS_PLACE := 0x23ED
const MISSILE_TILES := [0x34, 0x36, 0x35, 0x37]
const T_MAP_STRIPS := 0xB641       ## per world: three strips of (rows, place high, place low, width)
const T_MAP_TILES := 0xB717        ## per world: the map's tiles, strip after strip
const T_MARKER := 0xB934           ## per world: across scale, across start, down scale, down start
const MARKER_TILE := 0xAE          ## a tall sprite: this tile over the next one
const T_MESSAGES := 0xB3D6         ## per world: four messages
const T_SPEAKER_FOR_FIRST := 0xAE55 ## per world: who says that world's first message
const T_SPECIAL_AREA := 0xB020     ## per world: the room that has its own message
const T_SPECIAL_MESSAGES := 0xB026 ## those messages, by world; entry 6 is for a held fight
const T_SPECIAL_SPEAKER := 0xAEC6
const T_CAUGHT_NAMES := 0xB47D     ## per turtle: his name, for "<name> GOT CAUGHT. WHO FIGHTS NEXT?"
const T_CAUGHT_WORDS := 0xB4AE     ## the rest of that message: for most names, and for the long one
const LONG_NAME_TURTLE := 2        ## Michelangelo's name fills the line, so the rest starts on the next
const T_PORTRAITS := 0xB43F        ## per speaker: the tiles of the face
const T_ENDINGS := 0xB412          ## per speaker: the closing words
const MESSAGE_START := 0x2223
const MESSAGE_LINE_2 := 0x63       ## low byte of the second line's start
const MESSAGE_LINE_3 := 0xA3
const ENDING_START := 0xE7
const BAR_FULL := 0x30
const BAR_HALF := 0x31
const BAR_EMPTY := 0x32
const DIGIT_ZERO := 0x0A           ## digits 1 to 9 are tiles 1 to 9; zero is tile 10
const BLANK_COUNT := 0x0F

var prg: PackedByteArray

func _init(prg_rom: PackedByteArray) -> void:
	prg = prg_rom

func byte_at(bank: int, address: int) -> int:
	return prg[bank * 0x4000 + (address & 0x3FFF)]

func word_at(bank: int, address: int) -> int:
	return byte_at(bank, address) | (byte_at(bank, address + 1) << 8)

## The screen as the ROM's layout has it, before anything is filled in:
## { "tiles": 960 tile numbers, "colours": 64 colour bytes }.
## The layout is a list of blocks. A block is a screen address (low byte
## first) and then runs: a count below $80 and one tile to repeat that many
## times, or $80 + a count and that many tiles. $7F starts another block
## and $FF ends the layout.
func layout() -> Dictionary:
	return screen_layout(3, LAYOUT_ENTRY)

## Any of the ROM's screen layouts: entry `entry` of the table at 7:$E3CE,
## whose data is in program bank `bank`. Cells the layout does not write
## are tile 0.
func screen_layout(bank: int, entry: int) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(0x400)
	var address := word_at(7, T_LAYOUTS + entry * 2)
	var at := word_at(bank, address)
	address += 2
	var guard := 0
	while guard < 4096:
		guard += 1
		var code := byte_at(bank, address)
		if code == 0xFF:
			break
		if code == 0x7F:
			at = word_at(bank, address + 1)
			address += 3
		elif code >= 0x80:
			for i in code & 0x7F:
				_put(cells, at, byte_at(bank, address + 1 + i))
				at += 1
			address += 1 + (code & 0x7F)
		else:
			for i in code:
				_put(cells, at, byte_at(bank, address + 1))
				at += 1
			address += 2
	return { "tiles": cells.slice(0, COLS * ROWS), "colours": cells.slice(COLS * ROWS, 0x400) }

## The screens before play (Research/title_screen.md): the notice, entry
## $13 with its data in bank 0, and the title, entry 1 with its data in
## bank 1. Both use graphics page $0F and colour patch $21.
const NOTICE_ENTRY := 0x13
const NOTICE_BANK := 0
const TITLE_ENTRY := 1
const TITLE_BANK := 1
const TITLE_PAGE := 0x0F
const TITLE_PATCH := 0x21
const PUSH_START_STRING := 0

## The 32 colour numbers of the title and the notice: all backdrop, with
## the patch's colours written in from its starting place, skipping every
## fourth place (which stays the backdrop).
func title_colours() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(32)
	out.fill(0x0F)
	var patch := colour_patch(TITLE_PATCH)
	var at := int(patch.at)
	for value: int in patch.values:
		if at % 4 == 0:
			at += 1
		if at >= 32:
			break
		out[at] = value
		at += 1
	return out

func _put(cells: PackedByteArray, at: int, value: int) -> void:
	var index := at - SCREEN_START
	if index >= 0 and index < cells.size():
		cells[index] = value

## The 32 colour numbers the screen starts with: the ROM's list number 3
## fills the first 24 (every fourth is the backdrop), and the last 8 are
## whatever the map underneath left there, passed in as two groups of four.
func colours(leftover_groups: Array = []) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(32)
	out.fill(0x0F)
	var address := word_at(7, T_PALETTES + PALETTE_ID * 2)
	var at := 0
	while at < 32:
		if at % 4 == 0:
			at += 1
			continue
		var value := byte_at(7, address)
		if value == 0xFE:
			break
		out[at] = value
		address += 1
		at += 1
	for g in mini(leftover_groups.size(), 2):
		for i in range(1, 4):
			out[24 + g * 4 + i] = int(leftover_groups[g][i])
	return out

## A colour patch: { "at": place in the colour list, "values": the colours }.
func colour_patch(number: int) -> Dictionary:
	var address := word_at(7, T_COLOUR_PATCHES + number * 2)
	var values := PackedByteArray()
	var read := 1
	while byte_at(7, address + read) != 0xFE and read < 33:
		values.append(byte_at(7, address + read))
		read += 1
	return { "at": byte_at(7, address), "values": values }

## The patch that gives the chosen turtle's row his own colour.
func select_patch(turtle: int) -> Dictionary:
	return colour_patch(byte_at(7, T_SELECT_STRINGS + turtle * 2 + 1))

## The colour number of a turtle's bandana on his own sprites.
func bandana(turtle: int) -> int:
	return byte_at(7, T_BANDANAS + turtle)

## One of the ROM's short tile lists, as writes to make: an array of
## [place, value]. A list is (count, place high, place low, tiles...); a
## count of $80 or more repeats the one tile that follows. $FE or $FF ends it.
func string_writes(number: int) -> Array:
	var address := word_at(7, T_STRINGS + number * 2)
	var bank := 7 if address >= 0xC000 else 3
	return _writes_at(bank, address, 0xFE)

func select_writes(turtle: int) -> Array:
	return string_writes(byte_at(7, T_SELECT_STRINGS + turtle * 2))

func unselect_writes(turtle: int) -> Array:
	return string_writes(UNSELECT_STRING + turtle)

func _writes_at(bank: int, address: int, end: int) -> Array:
	var writes: Array = []
	var guard := 0
	while guard < 32:
		guard += 1
		var count := byte_at(bank, address)
		if count == 0xFE or count == 0xFF or count == end:
			break
		var place := (byte_at(bank, address + 1) << 8) | byte_at(bank, address + 2)
		if count >= 0x80:
			for i in count & 0x7F:
				writes.append([place + i, byte_at(bank, address + 3)])
			address += 4
		else:
			for i in count:
				writes.append([place + i, byte_at(bank, address + 3 + i)])
			address += 3 + count
	return writes

## The four tiles of an energy bar. Energy runs 0 to 128; each tile is 32.
## The original halves the energy, takes one full tile per 16 and, of what
## is left over, 9 or more makes another full tile and 1 to 8 a half one.
static func bar_tiles(energy: int) -> PackedByteArray:
	var half := energy >> 1
	var full := half >> 4
	var rest := half & 15
	if rest >= 9:
		full += 1
		rest = 0
	var tiles := PackedByteArray()
	for i in 4:
		if full > 0:
			full -= 1
			tiles.append(BAR_FULL)
		elif rest != 0:
			rest = 0
			tiles.append(BAR_HALF)
		else:
			tiles.append(BAR_EMPTY)
	return tiles

## The two tiles of a count from 0 to 99, tens first (a zero digit is tile 10).
static func count_tiles(count: int) -> PackedByteArray:
	var tens := (count / 10) % 10
	var ones := count % 10
	return PackedByteArray([tens if tens != 0 else DIGIT_ZERO, ones if ones != 0 else DIGIT_ZERO])

## Everything about the four turtles: energy bars, how many of his special
## weapon each has, that weapon's picture, and the cover over a captured one.
## `energies`, `weapons` (0 none, 1 to 4) and `counts` each hold four numbers.
func turtle_writes(energies: Array, weapons: Array = [], counts: Array = []) -> Array:
	var writes: Array = []
	for t in TURTLES:
		var bar_place := word_at(3, T_BAR_PLACES + t * 2)
		var tiles := bar_tiles(int(energies[t]))
		var count := int(counts[t]) if t < counts.size() else 0
		tiles.append_array(count_tiles(count) if count != 0 else PackedByteArray([BLANK_COUNT, BLANK_COUNT]))
		for i in tiles.size():
			writes.append([bar_place + i, tiles[i]])
		var weapon := int(weapons[t]) if t < weapons.size() else 0
		var weapon_place := word_at(3, T_WEAPON_PLACES + t * 2)
		for i in 4:
			writes.append([weapon_place + (i % 2) + (i / 2) * COLS, byte_at(3, T_WEAPON_TILES + weapon * 4 + i)])
		if int(energies[t]) == 0:
			for i in 9:
				writes.append([int(CAPTURED_PLACES[t]) + (i / 3) * COLS + i % 3, byte_at(3, T_CAPTURED_TILES + i)])
	return writes

## The area number in the heading, and the two item boxes under the
## turtles. A world that does not use a box has it wiped; one that does
## shows the item and how many are held once there is at least one.
func heading_and_item_writes(world: int, missiles := 0, ropes := 0) -> Array:
	var writes: Array = [[WORLD_NUMBER_PLACE, world + 1]]
	var uses_missiles := byte_at(3, T_HAS_MISSILES + world) != 0
	var uses_ropes := byte_at(3, T_HAS_ROPES + world) != 0
	var set_number := 0
	if uses_missiles and missiles != 0:
		set_number += 1
	if uses_ropes and ropes != 0:
		set_number += 2
	for i in 3:
		writes.append([ITEM_COLOURS_PLACE + i, byte_at(3, T_ITEM_COLOURS + set_number * 3 + i)])
	var places: Array[int] = []
	for i in 6:
		places.append((byte_at(3, T_ITEM_PLACES + i * 2) << 8) | byte_at(3, T_ITEM_PLACES + i * 2 + 1))
	if not uses_missiles or missiles != 0:
		var picture: Array = MISSILE_TILES if uses_missiles else [0, 0, 0, 0]
		var digits := count_tiles(missiles) if uses_missiles else PackedByteArray([0, 0])
		writes.append_array([[places[0], picture[0]], [places[0] + 1, picture[1]],
			[places[1], picture[2]], [places[1] + 1, picture[3]],
			[places[2], digits[0]], [places[2] + 1, digits[1]]])
	if uses_ropes:
		if ropes != 0:
			var digits := count_tiles(ropes)
			writes.append_array([[places[3], digits[0]], [places[3] + 1, digits[1]]])
	else:
		for place: int in [places[3], places[4], places[5]]:
			writes.append_array([[place, 0], [place + 1, 0]])
	return writes

## The small map of the world, as writes. Worlds are numbered from 0.
func map_writes(world: int) -> Array:
	var writes: Array = []
	var strips := word_at(3, T_MAP_STRIPS + world * 2)
	var tiles := word_at(3, T_MAP_TILES + world * 2)
	var read := 0
	for strip in 3:
		var rows := byte_at(3, strips + strip * 4)
		var place := (byte_at(3, strips + strip * 4 + 1) << 8) | byte_at(3, strips + strip * 4 + 2)
		var width := byte_at(3, strips + strip * 4 + 3)
		for row in rows:
			for col in width:
				writes.append([place + row * COLS + col, byte_at(3, tiles + read)])
				read += 1
	return writes

## Where the blinking marker goes for a spot on the world's overworld, as
## the sprite's corner on the screen. The original multiplies each
## coordinate by a scale, keeps the high byte and adds a start.
func marker_place(world: int, spot: Vector2) -> Vector2i:
	var base := T_MARKER + world * 4
	var across := ((int(spot.x) * byte_at(3, base)) & 0xFFFF) >> 8
	var down := ((int(spot.y) * byte_at(3, base + 2)) & 0xFFFF) >> 8
	# A sprite is drawn one line below the height it is given.
	return Vector2i((byte_at(3, base + 1) + across) & 0xFF, ((byte_at(3, base + 3) + down) & 0xFF) + 1)

## Picks what is said. `pick` is 0 to 3 (the original takes it from its
## frame counter); 0 is only used when a turtle has been captured, else 1.
## Returns { "speaker": 0 or 1, "address": where the text begins }.
func choose_message(world: int, area: int, inside: bool, held_fight: bool, any_captured: bool, pick: int) -> Dictionary:
	if held_fight:
		return { "speaker": byte_at(3, T_SPECIAL_SPEAKER + world) / 2, "address": word_at(3, T_SPECIAL_MESSAGES + 6 * 2) }
	if inside and byte_at(3, T_SPECIAL_AREA + world) == area and world != 1:
		return { "speaker": byte_at(3, T_SPECIAL_SPEAKER + world) / 2, "address": word_at(3, T_SPECIAL_MESSAGES + world * 2) }
	pick &= 3
	if pick == 0 and not any_captured:
		pick = 1
	var address := word_at(3, word_at(3, T_MESSAGES + world * 2) + pick * 2)
	if pick == 0:
		return { "speaker": byte_at(3, T_SPEAKER_FOR_FIRST + world) / 2, "address": address }
	return { "speaker": byte_at(3, address), "address": address + 1 }

## The message after a capture: { "speaker", "address" } for the turtle
## who was caught. His name is followed by the mark $FB, which goes on to
## the shared words.
func caught_message(world: int, turtle: int) -> Dictionary:
	return { "speaker": byte_at(3, T_SPECIAL_SPEAKER + world) / 2, "address": word_at(3, T_CAUGHT_NAMES + turtle * 2) }

## Where the shared words after the name begin.
func caught_words_address(turtle: int) -> int:
	return word_at(3, T_CAUGHT_WORDS + (2 if turtle == LONG_NAME_TURTLE else 0))

## The speaker's face, as writes.
func portrait_writes(speaker: int) -> Array:
	return _writes_at(3, word_at(3, T_PORTRAITS + speaker * 2), 0xFF)

## Where a speaker's closing words begin.
func ending_address(speaker: int) -> int:
	return word_at(3, T_ENDINGS + speaker * 2)
