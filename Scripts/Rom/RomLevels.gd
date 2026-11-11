class_name RomLevels
extends RefCounted
## Reads the side-scrolling rooms, the overworld maps and the doors between
## them straight out of the player's ROM.
##
## How the original stores a map (worked out from its code, see
## Research/level_format.md and Research/doors.md):
## - A world has several areas (rooms) and, in worlds 1 to 5, one overworld.
## - A map is a grid of SCREENS. A room's screen is 8 x 6 BLOCKS
##   (256 x 192 pixels); an overworld screen is 8 x 8 (256 x 256).
## - A block is 4 x 4 TILES (32 x 32 pixels), plus one byte giving the colour
##   group of each of its four quarters.
## - A small table per graphics page says what kind of thing each tile is
##   (empty, solid, ladder, door...).
## - Doors are 11-byte records: where the door is, then where it leads.
##
## All the addresses below are for the USA ROM. They are locations of
## tables, not game data; the data stays in the ROM.

const WORLDS := 6
const OVERWORLDS := 5           ## the sixth world (the Technodrome) has none
const SCREEN_BLOCKS := Vector2i(8, 6)
const OVERWORLD_SCREEN_BLOCKS := Vector2i(8, 8)
const BLOCK_TILES := 4

## Tables in program bank 1 (addresses as the console sees them)
const T_BLOCKS := 0x8015        ## per world: where the block shapes are (bank 3)
const T_BLOCK_COLOURS := 0x8033 ## per world: where the block colour bytes are (bank 3)
const T_SCREENS := 0x805D       ## per world: where the screens are (bank 1)
const T_OW_BLOCKS := 0x8001        ## the same three for the overworld;
const T_OW_BLOCK_COLOURS := 0x800B ## its blocks are in bank 4
const T_OW_SCREENS := 0x8051
## Tables in program bank 7
const T_ROOM_MAPS := 0xF49E     ## per world -> per area: width, height, screen numbers
const T_OVERWORLD_MAPS := 0xF4AA ## per world: width, height, screen numbers
const T_GRAPHICS_PAGES := 0xD5CE ## per world -> per area: background page, sprite set
const T_PALETTE_IDS := 0xD63B   ## per world -> per area: palette number
const T_OW_GRAPHICS_PAGES := 0xD5C8 ## per world: the overworld's background page
const T_OW_PALETTE_IDS := 0xD636    ## per world: the overworld's palette number
const T_OW_START := 0xD679      ## per world: camera position when the world begins
const T_PALETTES := 0xF796      ## per palette number: colour list ending in $FE
const T_TILE_KINDS := 0xFC93    ## per graphics page (minus 13): (last tile, kind) pairs
const T_DOORS := 0xE84F         ## 7 pointers: each world's rooms, then the overworlds
const DOORS_END := 0xEEBB       ## first byte after the last door list
const DOOR_BYTES := 11
const DOOR_LISTS_OVERWORLD := 6 ## index of the overworld entry in T_DOORS
## Tables in program bank 6: where enemies stand (Research/enemy_placement.md)
const T_ENEMY_SPOTS := 0x8681     ## per world -> per area -> per screen: list of (x, y, slot), ends $FF
const T_OW_ENEMY_SPOTS := 0xAC8F  ## per world -> per screen: the same for the overworld
const T_ENEMY_LINEUPS := 0x82EB   ## per world -> per area: 4 line-up numbers
const T_ENEMY_KINDS := 0x86E9     ## per line-up: the enemy kind in each slot
const T_KIND_INFO_HIGH := 0x883D  ## kinds $80 and up: hit points, first animation
const T_KIND_INFO_LOW := 0x8749   ## kinds below $80: hit points, first animation
const T_WEAPON_DAMAGE := 0x9BCB   ## per turtle: damage of a hit, then when below half energy
const T_TOUCH_DAMAGE := 0x8B05    ## per kind: energy the turtle loses on touching it
const ENEMY_LINEUPS := 18
const OVERWORLD_LINEUP := 16      ## every overworld uses this one
const ENEMY_SPOT_BYTES := 3

var prg: PackedByteArray
var _door_bounds := PackedInt32Array()

func _init(prg_rom: PackedByteArray) -> void:
	prg = prg_rom

## Returns null unless a verified USA ROM is installed.
static func open_installed() -> RomLevels:
	if not FileAccess.file_exists(Game.ROM_PATH):
		return null
	var info := RomInfo.inspect_file(Game.ROM_PATH)
	if info.known_name == "":
		return null
	return RomLevels.new(info.prg_rom)

func _byte(bank: int, address: int) -> int:
	return prg[bank * 0x4000 + (address & 0x3FFF)]

func _word(bank: int, address: int) -> int:
	return _byte(bank, address) | (_byte(bank, address + 1) << 8)

func area_count(world: int) -> int:
	var table := _word(7, T_ROOM_MAPS + world * 2)
	var next_table := _word(7, T_OVERWORLD_MAPS) if world == WORLDS - 1 else _word(7, T_ROOM_MAPS + (world + 1) * 2)
	return (next_table - table) / 2

func has_overworld(world: int) -> bool:
	return world >= 0 and world < OVERWORLDS

## The original picks block tables by world, with three exceptions.
func _block_table_index(world: int, area: int) -> int:
	if world == 4:
		return 6 + area
	if world == 3 and area == 0:
		return 0
	if world == 3 and area == 0x11:
		return 0x0C
	return world

## Colour numbers for a palette: 8 groups of 4 (4 background, 4 sprite).
func palette(palette_id: int, backdrop := 0x0F) -> Array:
	var address := _word(7, T_PALETTES + palette_id * 2)
	var flat: Array[int] = []
	var read := 0
	while flat.size() < 32:
		if flat.size() % 4 == 0:
			flat.append(backdrop)
			continue
		var value := _byte(7, address + read)
		if value == 0xFE:
			break
		flat.append(value)
		read += 1
	while flat.size() < 32:
		flat.append(backdrop)
	var groups: Array = []
	for g in 8:
		groups.append(flat.slice(g * 4, g * 4 + 4))
	return groups

## What kind of cell a tile is, for a given graphics page.
func _tile_kinds(chr_page: int) -> PackedByteArray:
	var kinds := PackedByteArray()
	kinds.resize(256)
	var index := chr_page - 13
	if index < 0 or index > 15:
		return kinds
	var address := _word(7, T_TILE_KINDS + index * 2)
	if address == 0:
		return kinds
	var tile := 0
	var entry := 0
	while tile < 256:
		var last := _byte(7, address + entry * 2)
		var kind := _byte(7, address + entry * 2 + 1)
		while tile <= last:
			kinds[tile] = kind
			tile += 1
		if last == 0xFF:
			break
		entry += 1
	return kinds

## One side-scrolling room, with the doors that lead out of it.
func room(world: int, area: int) -> RoomData:
	var map := _word(7, _word(7, T_ROOM_MAPS + world * 2) + area * 2)
	var table_index := _block_table_index(world, area)
	var pages := _word(7, T_GRAPHICS_PAGES + world * 2)
	var data := RoomData.new()
	data.name = "World %d, area %d" % [world + 1, area]
	data.chr_page = _byte(7, pages + area * 2)
	data.palettes = palette(_byte(7, _word(7, T_PALETTE_IDS + world * 2) + area))
	_fill(data, map, _word(1, T_SCREENS + world * 2), SCREEN_BLOCKS,
		3, _word(1, T_BLOCKS + table_index * 2), _word(1, T_BLOCK_COLOURS + table_index * 2))
	data.doors = _door_list(_word(7, T_DOORS + world * 2), area, data)
	var lineups := PackedInt32Array()
	var lineup_address := _word(6, _word(6, T_ENEMY_LINEUPS + world * 2) + area * 2)
	for i in 4:
		lineups.append(_byte(6, lineup_address + i))
	data.enemy_spots = _enemy_spots(_word(6, _word(6, T_ENEMY_SPOTS + world * 2) + area * 2), data, lineups)
	data.start = data.find_spawn()
	return data

## A world's top-down map, with the doors (manholes, buildings) on it.
## Returns null for the sixth world, which has none.
func overworld(world: int) -> RoomData:
	if not has_overworld(world):
		return null
	var data := RoomData.new()
	data.name = "World %d, overworld" % (world + 1)
	data.top_down = true
	data.chr_page = _byte(7, T_OW_GRAPHICS_PAGES + world)
	data.palettes = palette(_byte(7, T_OW_PALETTE_IDS + world))
	_fill(data, _word(7, T_OVERWORLD_MAPS + world * 2), _word(1, T_OW_SCREENS + world * 2), OVERWORLD_SCREEN_BLOCKS,
		4, _word(1, T_OW_BLOCKS + world * 2), _word(1, T_OW_BLOCK_COLOURS + world * 2))
	data.doors = _door_list(_word(7, T_DOORS + DOOR_LISTS_OVERWORLD * 2), world, data)
	data.enemy_spots = _enemy_spots(_word(6, T_OW_ENEMY_SPOTS + world * 2), data,
		PackedInt32Array([OVERWORLD_LINEUP, OVERWORLD_LINEUP, OVERWORLD_LINEUP, OVERWORLD_LINEUP]))
	# The table holds the camera's corner; the turtle stands mid-screen.
	var camera := Vector2(_word(7, T_OW_START + world * 4), _word(7, T_OW_START + world * 4 + 2))
	data.start = data.nearest_walkable(camera + Vector2(128, 120))
	return data

## Lays a map's screens, blocks and tiles out into the room's cells.
func _fill(data: RoomData, map: int, screens: int, screen_blocks: Vector2i, block_bank: int, blocks: int, block_colours: int) -> void:
	var width := _byte(7, map)
	var height := _byte(7, map + 1)
	data.screens_wide = width
	data.screen_size = screen_blocks * BLOCK_TILES * RoomData.TILE
	data.cols = width * screen_blocks.x * BLOCK_TILES
	data.rows = height * screen_blocks.y * BLOCK_TILES
	data.resize_cells()
	var kinds := _tile_kinds(data.chr_page)
	for screen_y in height:
		for screen_x in width:
			var screen := _byte(7, map + 2 + screen_y * width + screen_x)
			if screen == 0xFF:
				continue  # no screen here
			var screen_address := screens + screen * screen_blocks.x * screen_blocks.y
			for block_y in screen_blocks.y:
				for block_x in screen_blocks.x:
					var block := _byte(1, screen_address + block_y * screen_blocks.x + block_x)
					var colours := _byte(block_bank, block_colours + block)
					for ty in BLOCK_TILES:
						for tx in BLOCK_TILES:
							var tile := _byte(block_bank, blocks + block * 16 + ty * BLOCK_TILES + tx)
							var col := (screen_x * screen_blocks.x + block_x) * BLOCK_TILES + tx
							var row := (screen_y * screen_blocks.y + block_y) * BLOCK_TILES + ty
							var cell := row * data.cols + col
							data.tiles[cell] = tile
							data.attrs[cell] = (colours >> (((ty / 2) * 2 + tx / 2) * 2)) & 3
							data.kinds[cell] = kinds[tile]

## Every address where a door table or a door list begins. One list in the
## ROM has no end marker and runs into the next table, so a list is also
## stopped where the next one starts.
func _all_door_bounds() -> PackedInt32Array:
	if _door_bounds.is_empty():
		var seen := {DOORS_END: true}
		for i in DOOR_LISTS_OVERWORLD + 1:
			var table := _word(7, T_DOORS + i * 2)
			seen[table] = true
			for k in _door_list_count(table):
				seen[_word(7, table + k * 2)] = true
		for address: int in seen:
			_door_bounds.append(address)
		_door_bounds.sort()
	return _door_bounds

## A door table is a row of pointers followed directly by its first list.
func _door_list_count(table: int) -> int:
	return clampi((_word(7, table) - table) / 2, 0, 32)

func _door_list(table: int, index: int, data: RoomData) -> Array[Door]:
	var doors: Array[Door] = []
	if index >= _door_list_count(table):
		return doors  # this room has no doors (a boss room, the underwater level)
	var address := _word(7, table + index * 2)
	var end := DOORS_END
	for bound in _all_door_bounds():
		if bound > address:
			end = mini(end, bound)
			break
	while address + DOOR_BYTES <= end and _byte(7, address) != 0xFF:
		var door := Door.new()
		door.screen = _byte(7, address)
		door.position = Vector2(
			(door.screen % data.screens_wide) * data.screen_size.x + _byte(7, address + 1),
			(door.screen / data.screens_wide) * data.screen_size.y + _byte(7, address + 2))
		door.to_room = _byte(7, address + 3) != 0
		door.to_area = _byte(7, address + 4)
		# Turtle's place on the screen, then the camera's corner (high byte first).
		door.arrive = Vector2(
			_byte(7, address + 5) + (_byte(7, address + 7) << 8 | _byte(7, address + 8)),
			_byte(7, address + 6) + (_byte(7, address + 9) << 8 | _byte(7, address + 10)))
		doors.append(door)
		address += DOOR_BYTES
	return doors

## Reads a map's enemy places. `screen_table` holds one pointer per screen;
## each points at a list of 3-byte entries ending in $FF. `lineups` are the
## map's 4 enemy line-up numbers.
func _enemy_spots(screen_table: int, data: RoomData, lineups: PackedInt32Array) -> Array[EnemySpot]:
	var spots: Array[EnemySpot] = []
	var size := data.size_pixels()
	var screens := (size.x / data.screen_size.x) * (size.y / data.screen_size.y)
	for screen in screens:
		var address := _word(6, screen_table + screen * 2)
		var corner := Vector2((screen % data.screens_wide) * data.screen_size.x, (screen / data.screens_wide) * data.screen_size.y)
		var read := 0
		while _byte(6, address) != 0xFF and read < 64:
			var spot := EnemySpot.new()
			spot.position = corner + Vector2(_byte(6, address), _byte(6, address + 1))
			var third := _byte(6, address + 2)
			if third < 0x10:
				# A kind number given directly, with no line-up (unused in this ROM).
				spot.kinds = PackedInt32Array([third, third, third, third])
			else:
				spot.slot = third & 7
				for lineup in lineups:
					spot.kinds.append(_kind_in_slot(lineup, spot.slot))
			spot.kind = spot.kinds[0]
			if spot.kind >= 0:
				var info := (T_KIND_INFO_HIGH + (spot.kind & 0x7F) * 2) if spot.kind >= 0x80 else (T_KIND_INFO_LOW + spot.kind * 2)
				spot.hit_points = _byte(6, info)
				spot.first_animation = _byte(6, info + 1)
				spot.touch_damage = _byte(6, T_TOUCH_DAMAGE + spot.kind)
			spots.append(spot)
			address += ENEMY_SPOT_BYTES
			read += 1
	return spots

func _kind_in_slot(lineup: int, slot: int) -> int:
	if lineup < 0 or lineup >= ENEMY_LINEUPS:
		return -1
	return _byte(6, _word(6, T_ENEMY_KINDS + lineup * 2) + slot)

## An object kind's starting hit points.
func hit_points(kind: int) -> int:
	return _byte(6, (T_KIND_INFO_HIGH + (kind & 0x7F) * 2) if kind >= 0x80 else (T_KIND_INFO_LOW + kind * 2))

## The energy the turtle loses on touching an object of this kind.
func touch_damage(kind: int) -> int:
	return _byte(6, T_TOUCH_DAMAGE + kind)

## What one weapon hit takes off an enemy: [normally, when the turtle is
## below half energy]. Turtles are numbered 0 Leonardo, 1 Raphael,
## 2 Michelangelo, 3 Donatello.
func weapon_damage(turtle_index: int) -> Vector2i:
	return Vector2i(_byte(6, T_WEAPON_DAMAGE + turtle_index * 2), _byte(6, T_WEAPON_DAMAGE + turtle_index * 2 + 1))
