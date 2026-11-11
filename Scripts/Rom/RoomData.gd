class_name RoomData
extends RefCounted
## One room: which background tile sits in each 8x8 cell, its colour group,
## and what kind of cell it is (empty, solid, ladder...).
## Rooms are read from the player's ROM by RomLevels. Nothing is stored in
## the project. `from_text` makes a small hand-drawn room for tests and for
## playing without a ROM.

const TILE := 8

## Cell kinds, using the original game's own numbers where they are known.
const KIND_EMPTY := 0
const KIND_SOLID := 4
const KIND_LADDER := 9
const KIND_LADDER_TOP := 11
const KIND_DOOR := 2          ## a doorway or manhole
const KIND_WATER := 12        ## blocks the way on the overworld
const KIND_HURTS := 1         ## in rooms: hurts like an enemy's touch, and is not solid
const KIND_MOVING_FLOOR := 13 ## in rooms: a floor that carries the turtle along
const KIND_DEADLY := 15       ## in rooms: a floor that drains energy every update
const HURT_DAMAGE := 16       ## what kinds 1 and 15 take off each time
const MOVING_FLOOR_SPEED := 320  ## 1/256 pixel per update, to the right (one room measured)
## The original keeps the turtle's position at his middle; in a room his
## feet are 20 pixels below it (measured standing on two different floors).
const CENTRE_TO_FEET := 20

var name := ""
var cols := 0
var rows := 0
var chr_page := 0                      ## which 4 KB graphics page the tiles come from
var palettes: Array = []               ## groups of four NES colour numbers
var tiles := PackedInt32Array()        ## tile number per cell, -1 = nothing there
var attrs := PackedByteArray()         ## colour group (0-3) per cell
var kinds := PackedByteArray()         ## cell kind per cell
var start := Vector2(40, 96)           ## where the turtle's feet begin
var top_down := false                  ## true for an overworld map
var screens_wide := 1                  ## how many screens across the map is
var screen_size := Vector2i(256, 192)  ## one screen in pixels (256 x 256 on the overworld)
var doors: Array[Door] = []            ## the doorways in this map and where they lead
var enemy_spots: Array[EnemySpot] = [] ## where the original puts its enemies

## A room drawn with text: '#' solid, 'H' ladder, anything else empty.
static func from_text(lines: PackedStringArray, room_name := "Test room") -> RoomData:
	var room := RoomData.new()
	room.name = room_name
	room.rows = lines.size()
	room.cols = lines[0].length()
	room.resize_cells()
	for row in room.rows:
		for col in room.cols:
			var ch := lines[row][col]
			room.kinds[row * room.cols + col] = KIND_SOLID if ch == "#" else (KIND_LADDER if ch == "H" else KIND_EMPTY)
	return room

func resize_cells() -> void:
	tiles.resize(cols * rows)
	tiles.fill(-1)
	attrs.resize(cols * rows)
	kinds.resize(cols * rows)

func size_pixels() -> Vector2i:
	return Vector2i(cols, rows) * TILE

func kind_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return KIND_EMPTY
	return kinds[row * cols + col]

## Solid for the turtle and the enemies: walls and floors, and in rooms the
## moving floors and the deadly floors.
func is_solid_cell(col: int, row: int) -> bool:
	var kind := kind_at(col, row)
	if kind == KIND_SOLID:
		return true
	return not top_down and (kind == KIND_MOVING_FLOOR or kind == KIND_DEADLY)

func is_ladder_cell(col: int, row: int) -> bool:
	var kind := kind_at(col, row)
	return kind == KIND_LADDER or kind == KIND_LADDER_TOP

func kind_at_pixel(x: float, y: float) -> int:
	return kind_at(floori(x / TILE), floori(y / TILE))

## Overworld: can the turtle not walk here? Walls, water and the map's edge.
func blocks_walker(x: float, y: float) -> bool:
	if x < 0 or y < 0 or x >= cols * TILE or y >= rows * TILE:
		return true
	var kind := kind_at_pixel(x, y)
	return kind == KIND_SOLID or kind == KIND_WATER

## The door the original would pick for a turtle whose centre is here: one
## on the same screen, less than `reach` pixels away both across and down.
func door_at(centre: Vector2, reach := 32.0) -> Door:
	var screen := floori(centre.y / screen_size.y) * screens_wide + floori(centre.x / screen_size.x)
	for door in doors:
		if door.screen == screen and absf(door.position.x - centre.x) < reach and absf(door.position.y - centre.y) < reach:
			return door
	return null

## In a room: is a doorway within `reach` pixels to either side of the
## turtle's centre, at the height of his middle?
func door_cell_near(centre: Vector2, reach := 8.0) -> bool:
	var row := floori(centre.y / TILE)
	for col in range(floori((centre.x - reach) / TILE), floori((centre.x + reach) / TILE) + 1):
		if kind_at(col, row) == KIND_DOOR:
			return true
	return false

## The walkable spot closest to a point (used where the true starting spot
## is not known).
func nearest_walkable(point: Vector2) -> Vector2:
	var col := clampi(floori(point.x / TILE), 0, cols - 1)
	var row := clampi(floori(point.y / TILE), 0, rows - 1)
	if kind_at(col, row) == KIND_EMPTY:
		return point
	for ring in range(1, maxi(cols, rows)):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c := col + dx
				var r := row + dy
				if c >= 0 and r >= 0 and c < cols and r < rows and kinds[r * cols + c] == KIND_EMPTY:
					return Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)
	return point

func solid_at(x: float, y: float) -> bool:
	return is_solid_cell(floori(x / TILE), floori(y / TILE))

## If the point is on a ladder, returns the ladder's centre line (x).
## Otherwise returns NAN.
func ladder_center_at(x: float, y: float) -> float:
	var col := floori(x / TILE)
	var row := floori(y / TILE)
	if not is_ladder_cell(col, row):
		return NAN
	var first := col
	while is_ladder_cell(first - 1, row):
		first -= 1
	var last := col
	while is_ladder_cell(last + 1, row):
		last += 1
	return (first + last + 1) * TILE / 2.0

## Solid cells merged into as few rectangles as possible (in pixels), so the
## turtle does not catch on seams between neighbouring blocks.
func solid_rects() -> Array[Rect2i]:
	var open := {}   # "col,len" -> Rect2i still growing downwards
	var done: Array[Rect2i] = []
	for row in rows + 1:
		var runs := {}
		var col := 0
		while row < rows and col < cols:
			if is_solid_cell(col, row):
				var begin := col
				while col < cols and is_solid_cell(col, row):
					col += 1
				runs["%d,%d" % [begin, col - begin]] = Rect2i(begin, row, col - begin, 1)
			else:
				col += 1
		for key: String in open.keys():
			if runs.has(key):
				var grown: Rect2i = open[key]
				grown.size.y += 1
				open[key] = grown
				runs.erase(key)
			else:
				done.append(open[key])
				open.erase(key)
		for key: String in runs:
			open[key] = runs[key]
	var pixels: Array[Rect2i] = []
	for rect in done:
		pixels.append(Rect2i(rect.position * TILE, rect.size * TILE))
	return pixels

## Where a ladder comes up through a floor: a thin ledge the turtle can
## stand on but climb through. Returned as pixel rectangles.
func ladder_tops() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for row in rows:
		for col in cols:
			if is_ladder_cell(col, row) and not is_ladder_cell(col, row - 1) and not is_ladder_cell(col - 1, row):
				var last := col
				while is_ladder_cell(last + 1, row):
					last += 1
				if is_solid_cell(col - 1, row) or is_solid_cell(last + 1, row):
					out.append(Rect2i(col * TILE, row * TILE, (last - col + 1) * TILE, TILE))
	return out

## A sensible place to drop the turtle when the real entrance is not known:
## the first spot from the left with a floor and 6 empty cells above it.
func find_spawn() -> Vector2:
	for col in range(2, cols - 2):
		for row in range(6, rows):
			if is_solid_cell(col, row) and is_solid_cell(col + 1, row):
				var clear := true
				for up in range(1, 7):
					if kind_at(col, row - up) != KIND_EMPTY or kind_at(col + 1, row - up) != KIND_EMPTY:
						clear = false
						break
				if clear:
					return Vector2((col + 1) * TILE, row * TILE)
	return Vector2(cols * TILE / 2.0, 0)

## The whole room as one picture. With a ROM it is painted from the ROM's
## tiles; without one, blocks are grey and ladders cyan.
func build_image(ripper: ChrRipper) -> Image:
	var image := Image.create(cols * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	if ripper == null or palettes.is_empty():
		image.fill(Color(0.08, 0.09, 0.16))
		for row in rows:
			for col in cols:
				var cell := Rect2i(col * TILE, row * TILE, TILE, TILE)
				if is_solid_cell(col, row):
					image.fill_rect(cell, Color(0.36, 0.38, 0.45))
				elif is_ladder_cell(col, row):
					image.fill_rect(cell.grow_individual(0, -3, 0, -3), Color(0.3, 0.75, 0.85))
		return image
	var backdrop := NesPalette.color(int(palettes[0][0]))
	image.fill(Color.BLACK)
	var groups: Array = []
	for numbers: Array in palettes:
		var colours: Array[Color] = [backdrop]
		for i in range(1, 4):
			colours.append(NesPalette.color(int(numbers[i])))
		groups.append(colours)
	for row in rows:
		for col in cols:
			var i := row * cols + col
			if tiles[i] < 0:
				continue
			var group: Array[Color] = groups[attrs[i]]
			ripper.draw_tile(image, chr_page * ChrRipper.TILES_PER_BANK + tiles[i], Vector2i(col, row) * TILE, group)
	return image
