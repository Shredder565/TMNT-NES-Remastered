class_name StartScreen
extends CanvasLayer
## The screen the original shows when Start is pressed in play: the four
## turtles with their energy, the area's small map with a blinking marker
## where the turtle is, and a few words from Splinter or April. Up and Down
## pick which turtle carries on; Start goes back to the game, which stands
## still meanwhile. (Research/start_screen.md has the original's rules.)
##
## With a ROM the whole picture is put together from the ROM's own layout,
## tiles and tables (Scripts/Rom/InfoScreenData.gd). Without one it is plain
## boxes and text with the same choices.

signal turtle_chosen(turtle: int)   ## Start was pressed: this turtle carries on
signal closed                       ## the game is running again
signal event_finished               ## the message after an event has been typed out (see `event`)

const NAMES := ["LEO", "RAPH", "MIKE", "DON"]
const PLACEHOLDER_COLOURS := [Color(0.2, 0.45, 1.0), Color(0.9, 0.2, 0.2), Color(1.0, 0.6, 0.1), Color(0.65, 0.3, 0.9)]
const FULL_ENERGY := 128
## Measured in the original, in frames:
const BUILD_FRAMES := 10            ## Start to the finished screen
const TYPE_FRAMES := 4              ## one letter of the message
## After a world's last boss (Research/world_end.md, measured): the screen
## comes up by itself after 4 dark frames, types at half the speed, takes
## no buttons, has no marker, and ends a frame after the message does.
const EVENT_BUILD_FRAMES := 5
const EVENT_TYPE_FRAMES := 8
const LEAVE_FRAMES_OVERWORLD := 34  ## Start to the map being back on show
const LEAVE_FRAMES_ROOM := 26
const HOLD_FRAMES := 16             ## the game then stands still this long
## The original's picture starts 12 lines down the screen (measured: its
## scroll setting accounts for 8 of them, and the background sits 4 lines
## lower than that in play as well). Its left 8 pixels are not shown.
const TOP_LINE := 12

enum Phase { SHUT, BUILDING, SHOWN, LEAVING, HOLDING }

var data: InfoScreenData            ## null without a ROM
var ripper: ChrRipper
var phase := Phase.SHUT
var selected := 0
var energies: Array = [FULL_ENERGY, FULL_ENERGY, FULL_ENERGY, FULL_ENERGY]
var world := 0
var inside := false
var pause_game := true              ## stop the rest of the game while open
var tiles := PackedByteArray()      ## the screen's 960 tile numbers, as the console keeps them
var colour_bytes := PackedByteArray()
var colours := PackedByteArray()    ## its 32 colour numbers
var message_done := false
var marker_at := Vector2i.ZERO      ## the marker's corner on the screen
var _frames := 0                    ## frames in the current phase
var _clock := 0                     ## frames since it opened; the marker's colour steps with it
var _image: Image
var _picture := TextureRect.new()
var _marker := Sprite2D.new()
var _marker_looks: Array[ImageTexture] = []
var _plain := Control.new()         ## the no-ROM version
var _black := ColorRect.new()
var _edge := ColorRect.new()        ## the right 8 pixels, dark while an event's screen is up (the room's edge sprites are still there)
var _dirty := {}                    ## cells to repaint: row * 32 + column
var _speaker := 0
var _text_address := 0              ## where the message being typed is in the ROM
var _text_index := 0
var _text_place := 0
var _captured := 0
var caught := -1                    ## the turtle just captured, when the screen was forced open by that; else -1
var _event_over := false            ## the event's message has ended: one more frame on show
var event := false                  ## the screen was put up by the game to say something (a world's end), not by Start

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black.color = Color.BLACK
	_black.size = Vector2(256, 240)
	add_child(_black)
	_picture.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(_picture)
	_marker.centered = false
	add_child(_marker)
	_edge.color = Color.BLACK
	_edge.position = Vector2(248, 2)
	_edge.size = Vector2(8, 238)
	_edge.visible = false
	add_child(_edge)
	_plain.size = Vector2(256, 240)
	_plain.draw.connect(_draw_plain)
	add_child(_plain)
	visible = false

## Reads the ROM, if one is installed. Safe to call more than once.
func use_installed_rom() -> void:
	if data != null or not FileAccess.file_exists(Game.ROM_PATH):
		return
	var info := RomInfo.inspect_file(Game.ROM_PATH)
	if info.known_name != "":
		use_rom(info.prg_rom, info.chr_rom)

func use_rom(prg_rom: PackedByteArray, chr_rom: PackedByteArray) -> void:
	data = InfoScreenData.new(prg_rom)
	ripper = ChrRipper.new(chr_rom)

func is_open() -> bool:
	return phase != Phase.SHUT

## Opens the screen. `about` may hold: world, area, inside (in a room),
## held_fight, spot (where the turtle is on the overworld, or where he left
## it), energies (four numbers, 0 to 128), turtle (who is playing),
## weapons and counts (each turtle's special weapon and how many),
## missiles, ropes, sprite_colours (the map's last two sprite colour groups)
## and pick (which message, 0 to 3; left out, it is chosen at random);
## event (true: the world's "after the boss" message, with no buttons).
func open(about: Dictionary = {}) -> void:
	world = int(about.get("world", 0))
	event = bool(about.get("event", false))
	_event_over = false
	inside = bool(about.get("inside", false))
	caught = int(about.get("caught", -1))
	energies = (about.get("energies", energies) as Array).duplicate()
	selected = _first_fit(int(about.get("turtle", 0)), 1)
	_captured = 0
	for energy: int in energies:
		if energy == 0:
			_captured += 1
	phase = Phase.BUILDING
	_frames = 0
	_clock = 0
	message_done = false
	visible = true
	if pause_game and is_inside_tree():
		get_tree().paused = true
	if data != null:
		_build(about)
	_picture.visible = false
	_marker.visible = false
	_plain.visible = false
	_edge.visible = false
	_black.visible = true

## Puts the whole screen together in memory; it is shown BUILD_FRAMES later.
func _build(about: Dictionary) -> void:
	var start := data.layout()
	tiles = start.tiles
	colour_bytes = start.colours
	colours = data.colours(about.get("sprite_colours", []))
	_write(data.turtle_writes(energies, about.get("weapons", []), about.get("counts", [])))
	_write(data.heading_and_item_writes(world, int(about.get("missiles", 0)), int(about.get("ropes", 0))))
	_write(data.map_writes(world))
	_light_row(selected)
	marker_at = data.marker_place(world, about.get("spot", Vector2.ZERO)) if world < 5 else Vector2i(-16, -16)
	var pick: int = about.get("pick", randi_range(0, 3))
	var message := data.choose_message(world, int(about.get("area", 0)), inside, bool(about.get("held_fight", false)), _captured > 0, pick)
	if caught >= 0:
		message = data.caught_message(world, caught)
	if event:
		message = data.event_message(world)
	_speaker = message.speaker
	_text_address = message.address
	_text_index = 0
	_text_place = InfoScreenData.MESSAGE_START
	_image = Image.create(256, 240, false, Image.FORMAT_RGBA8)
	_image.fill(NesPalette.color(colours[0]))
	_paint_all()
	_picture.texture = ImageTexture.create_from_image(_image)
	_marker_looks.clear()
	for group in 4:
		var look := Image.create(8, 16, false, Image.FORMAT_RGBA8)
		var shades: Array[Color] = [Color(0, 0, 0, 0)]
		for i in range(1, 4):
			shades.append(NesPalette.color(colours[16 + group * 4 + i]))
		for half in 2:
			ripper.draw_tile(look, InfoScreenData.GRAPHICS_PAGE * ChrRipper.TILES_PER_BANK + InfoScreenData.MARKER_TILE + half,
				Vector2i(0, half * 8), shades)
		_marker_looks.append(ImageTexture.create_from_image(look))
	_marker.position = Vector2(marker_at)

## The first turtle, counting from `from` in steps of `step`, who still has
## energy. The original never lands on a captured turtle.
func _first_fit(from: int, step: int) -> int:
	var turtle := posmod(from, InfoScreenData.TURTLES)
	for i in InfoScreenData.TURTLES:
		if int(energies[turtle]) != 0:
			return turtle
		turtle = posmod(turtle + step, InfoScreenData.TURTLES)
	return posmod(from, InfoScreenData.TURTLES)

## Up (-1) or Down (+1): the next turtle that way who is not captured.
func move_selection(step: int) -> void:
	if phase != Phase.SHOWN or event:
		return
	var next := _first_fit(selected + step, step)
	if next == selected:
		return
	Sound.play(0x3C)   # the choice moves (3:$AA89)
	if data != null:
		_write(data.unselect_writes(selected))
		_light_row(next)
	selected = next
	_refresh()

## Lights a turtle's row and gives it his colour.
func _light_row(turtle: int) -> void:
	_write(data.select_writes(turtle))
	var patch := data.select_patch(turtle)
	for i in (patch.values as PackedByteArray).size():
		colours[int(patch.at) + i] = patch.values[i]
	# Every cell painted with that colour group has to be painted again.
	var group := int(patch.at) / 4
	if group < 4:
		for row in InfoScreenData.ROWS:
			for col in InfoScreenData.COLS:
				if _group_at(col, row) == group:
					_dirty[row * InfoScreenData.COLS + col] = true

## Start: go back to the game with the chosen turtle.
func request_close() -> void:
	if phase != Phase.SHOWN or event:
		return
	phase = Phase.LEAVING
	_frames = 0
	_picture.visible = false
	_marker.visible = false
	_plain.visible = false
	_black.visible = true
	turtle_chosen.emit(selected)

func _physics_process(_delta: float) -> void:
	if phase == Phase.SHUT:
		return
	if phase == Phase.SHOWN and not event:
		if Input.is_action_just_pressed("pause"):
			request_close()
		elif Input.is_action_just_pressed("move_down"):
			move_selection(1)
		elif Input.is_action_just_pressed("move_up"):
			move_selection(-1)
	tick()

## One frame of the screen.
func tick() -> void:
	_frames += 1
	_clock += 1
	match phase:
		Phase.BUILDING:
			if _frames >= (EVENT_BUILD_FRAMES if event else BUILD_FRAMES):
				phase = Phase.SHOWN
				_frames = 0
				_black.visible = data == null
				_picture.visible = data != null
				_marker.visible = data != null and world < 5 and not event
				_edge.visible = data != null and event
				_plain.visible = data == null
				if data != null:
					_write(data.portrait_writes(_speaker))
				else:
					message_done = true
				_refresh()
		Phase.SHOWN:
			if data != null:
				_marker.texture = _marker_looks[_clock & 3]
				if not message_done and _frames % (EVENT_TYPE_FRAMES if event else TYPE_FRAMES) == 0:
					_type_one()
					_refresh()
			if event and (message_done or data == null):
				if _event_over:
					_end_event()
				_event_over = true
		Phase.LEAVING:
			if _frames >= (LEAVE_FRAMES_ROOM if inside else LEAVE_FRAMES_OVERWORLD):
				phase = Phase.HOLDING
				_frames = 0
				visible = false
		Phase.HOLDING:
			if _frames >= HOLD_FRAMES:
				phase = Phase.SHUT
				if pause_game and is_inside_tree():
					get_tree().paused = false
				closed.emit()

## The event's message is done: the screen goes and the game takes over
## again at once (the original starts the next world on the next frame).
func _end_event() -> void:
	phase = Phase.SHUT
	visible = false
	event = false
	if pause_game and is_inside_tree():
		get_tree().paused = false
	event_finished.emit()

## Types the next letter of the message, or obeys the next mark in it.
## Marks: $F7 and $F8 start the second and third line, $FA adds an S when
## more than one turtle is captured, $FD goes on to the speaker's closing
## words, $FE moves to the place the next two bytes give, $FF ends.
func _type_one() -> void:
	var code := data.byte_at(3, _text_address + _text_index)
	_text_index += 1
	if code == 0:
		_text_place += 1
	elif code < 0xF7:
		Sound.play(0x36 if event else 0x39)   # a letter (3:$AF74)
		_write([[_text_place, code]])
		_text_place += 1
	elif code == 0xF7:
		_text_place = (_text_place & 0xFF00) | InfoScreenData.MESSAGE_LINE_2
	elif code == 0xF8:
		_text_place = (_text_place & 0xFF00) | InfoScreenData.MESSAGE_LINE_3
	elif code == 0xFA:
		if _captured > 1:
			_write([[_text_place, 0x22]])
			_text_place += 1
	elif code == 0xFD:
		_text_address = data.ending_address(_speaker)
		_text_index = 0
		_text_place = (_text_place & 0xFF00) | InfoScreenData.ENDING_START
	elif code == 0xFE:
		_text_place = (data.byte_at(3, _text_address + _text_index) << 8) | data.byte_at(3, _text_address + _text_index + 1)
		_text_index += 2
	elif code == 0xFB and caught >= 0:
		# After the caught turtle's name: on with the shared words, one
		# place on, or from the second line after the long name.
		_text_address = data.caught_words_address(caught)
		_text_index = 0
		_text_place += 1
		if caught == InfoScreenData.LONG_NAME_TURTLE:
			_text_place = (_text_place & 0xFF00) | InfoScreenData.MESSAGE_LINE_2
	elif code == 0xFF or code == 0xFB:
		message_done = true

## Finishes the message at once (used by tests).
func finish_message() -> void:
	var guard := 0
	while data != null and not message_done and guard < 400:
		_type_one()
		guard += 1
	_refresh()

## Changes tiles or colour bytes on the screen: a list of [place, value].
func _write(writes: Array) -> void:
	for entry: Array in writes:
		var place: int = entry[0]
		var value: int = entry[1]
		if place >= InfoScreenData.COLOUR_BYTES_START:
			var index := place - InfoScreenData.COLOUR_BYTES_START
			if index >= 64 or colour_bytes[index] == value:
				continue
			colour_bytes[index] = value
			for row in range((index / 8) * 4, mini((index / 8) * 4 + 4, InfoScreenData.ROWS)):
				for col in range((index % 8) * 4, (index % 8) * 4 + 4):
					_dirty[row * InfoScreenData.COLS + col] = true
		else:
			var index := place - InfoScreenData.SCREEN_START
			if index < 0 or index >= tiles.size() or tiles[index] == value:
				continue
			tiles[index] = value
			_dirty[index] = true

## Which of the four colour groups a cell is painted with.
func _group_at(col: int, row: int) -> int:
	var shift := ((row % 4) / 2) * 4 + ((col % 4) / 2) * 2
	return (colour_bytes[(row / 4) * 8 + col / 4] >> shift) & 3

func _paint_cell(index: int) -> void:
	var col := index % InfoScreenData.COLS
	var row := index / InfoScreenData.COLS
	var group := _group_at(col, row)
	var shades: Array[Color] = [NesPalette.color(colours[0])]
	for i in range(1, 4):
		shades.append(NesPalette.color(colours[group * 4 + i]))
	if col == 0:
		return   # the console hides the left 8 pixels
	ripper.draw_tile(_image, InfoScreenData.GRAPHICS_PAGE * ChrRipper.TILES_PER_BANK + tiles[index], Vector2i(col * 8, TOP_LINE + row * 8), shades)

func _paint_all() -> void:
	for index in tiles.size():
		_paint_cell(index)
	_dirty.clear()

## Shows what has changed since the last time.
func _refresh() -> void:
	if data == null:
		_plain.queue_redraw()
		return
	if _dirty.is_empty() or _image == null:
		return
	for index: int in _dirty:
		_paint_cell(index)
	_dirty.clear()
	(_picture.texture as ImageTexture).update(_image)

## The screen as a picture, marker included (used by tests and comparisons).
func snapshot() -> Image:
	if data == null or _image == null:
		return null
	for index: int in _dirty:
		_paint_cell(index)
	_dirty.clear()
	var copy: Image = _image.duplicate()
	if world < 5 and not event and not _marker_looks.is_empty():
		var look := _marker_looks[_clock & 3].get_image()
		copy.blend_rect(look, Rect2i(0, 0, 8, 16), marker_at)
	return copy

## The tile at a column and row of the layout (row 0 is the heading's row).
func tile_at(col: int, row: int) -> int:
	return tiles[row * InfoScreenData.COLS + col] if not tiles.is_empty() else -1

## Without a ROM: plain boxes and text.
func _draw_plain() -> void:
	var font := ThemeDB.fallback_font
	_plain.draw_rect(Rect2(0, 0, 256, 240), Color(0.05, 0.05, 0.1))
	_plain.draw_string(font, Vector2(24, 24), "INFORMATION   AREA %d" % (world + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	_plain.draw_rect(Rect2(32, 32, 96, 88), Color(0.1, 0.15, 0.45))
	_plain.draw_string(font, Vector2(40, 80), "MAP (needs a ROM)", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 0.7))
	for t in InfoScreenData.TURTLES:
		var top := 40.0 + t * 32.0
		var lit := t == selected
		_plain.draw_rect(Rect2(168, top, 24, 24), PLACEHOLDER_COLOURS[t] if lit else Color(0.35, 0.35, 0.35))
		_plain.draw_string(font, Vector2(196, top + 10), NAMES[t], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE if lit else Color(0.6, 0.6, 0.6))
		var bar := InfoScreenData.bar_tiles(int(energies[t]))
		for i in 4:
			var shade := Color(0.25, 0.25, 0.3)
			if bar[i] == InfoScreenData.BAR_FULL:
				shade = Color(0.9, 0.25, 0.2)
			elif bar[i] == InfoScreenData.BAR_HALF:
				shade = Color(0.6, 0.2, 0.2)
			_plain.draw_rect(Rect2(196 + i * 8, top + 14, 7, 6), shade)
		if int(energies[t]) == 0:
			_plain.draw_line(Vector2(168, top), Vector2(192, top + 24), Color.WHITE)
			_plain.draw_line(Vector2(192, top), Vector2(168, top + 24), Color.WHITE)
	_plain.draw_rect(Rect2(8, 136, 152, 88), Color(0.1, 0.15, 0.45))
	_plain.draw_string(font, Vector2(16, 160), "UP / DOWN  CHOOSE A TURTLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	_plain.draw_string(font, Vector2(16, 180), "START  BACK TO THE GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
