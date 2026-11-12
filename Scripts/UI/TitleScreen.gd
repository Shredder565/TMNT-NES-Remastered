extends Node
## The screens the original shows before play (Research/title_screen.md):
## the notice about names and rights for 256 frames (Start or Select skips
## it), then the title with PUSH START. Start there makes PUSH START blink
## for 128 frames and the game begins. With a ROM both pictures are put
## together from the ROM's own layouts, tiles and colours; without one, a
## plain title.
##
## The original also starts a demonstration of play when the title has
## been up for 256 frames. The remake does not: the title stays.

const NOTICE_FRAMES := 256
const BLINK_FRAMES := 128
const BLINK_EVERY := 8            ## PUSH START goes off and on every 8 frames
const TOP_LINE := 4               ## the original's background sits 4 lines down (see Research/start_screen.md)

enum Phase { NOTICE, TITLE, BLINK }

var data: InfoScreenData          ## null without a ROM
var ripper: ChrRipper
var phase := Phase.NOTICE
var next_scene := Game.SCENE_TEST_ROOM
var leave_when_done := true       ## false: stay put at the end (tests)
var finished := false
var push_start_shown := true
var _frames := 0
var _tiles := PackedByteArray()
var _colour_bytes := PackedByteArray()
var _colours := PackedByteArray()
var _title_tiles := PackedByteArray()
var _picture := TextureRect.new()
var _plain := Control.new()

func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.size = Vector2(256, 240)
	add_child(back)
	add_child(_picture)
	_plain.size = Vector2(256, 240)
	_plain.draw.connect(_draw_plain)
	add_child(_plain)
	if FileAccess.file_exists(Game.ROM_PATH):
		var info := RomInfo.inspect_file(Game.ROM_PATH)
		if info.accepted:
			use_rom(info.prg_rom, info.chr_rom)
	show_phase(Phase.NOTICE if data != null else Phase.TITLE)

func use_rom(prg_rom: PackedByteArray, chr_rom: PackedByteArray) -> void:
	data = InfoScreenData.new(prg_rom)
	ripper = ChrRipper.new(chr_rom)
	_colours = data.title_colours()

## Puts a phase's picture up.
func show_phase(new_phase: Phase) -> void:
	phase = new_phase
	_frames = 0
	push_start_shown = true
	_plain.visible = data == null
	_picture.visible = data != null
	if data == null:
		_plain.queue_redraw()
		return
	if phase == Phase.NOTICE:
		var notice := data.screen_layout(InfoScreenData.NOTICE_BANK, InfoScreenData.NOTICE_ENTRY)
		_tiles = notice.tiles
		_colour_bytes = notice.colours
	elif phase == Phase.TITLE:
		var title := data.screen_layout(InfoScreenData.TITLE_BANK, InfoScreenData.TITLE_ENTRY)
		_tiles = title.tiles
		_colour_bytes = title.colours
		_title_tiles = _tiles.duplicate()
		_write_push_start(true)
	_paint()

## Writes PUSH START (the ROM's tile list number 0), or blanks it.
func _write_push_start(on: bool) -> void:
	push_start_shown = on
	for entry: Array in data.string_writes(InfoScreenData.PUSH_START_STRING):
		var index: int = entry[0] - InfoScreenData.SCREEN_START
		if index >= 0 and index < _tiles.size():
			_tiles[index] = entry[1] if on else _title_tiles[index]

func _paint() -> void:
	_picture.texture = ImageTexture.create_from_image(picture())

## The screen as a picture (also used by tests and comparisons).
func picture() -> Image:
	var image := Image.create(256, 240, false, Image.FORMAT_RGBA8)
	image.fill(NesPalette.color(_colours[0]) if not _colours.is_empty() else Color.BLACK)
	if data == null:
		return image
	for index in _tiles.size():
		var col := index % InfoScreenData.COLS
		var row := index / InfoScreenData.COLS
		if col == 0:
			continue   # the console hides the left 8 pixels
		var shift := ((row % 4) / 2) * 4 + ((col % 4) / 2) * 2
		var group := (_colour_bytes[(row / 4) * 8 + col / 4] >> shift) & 3
		var shades: Array[Color] = [NesPalette.color(_colours[0])]
		for i in range(1, 4):
			shades.append(NesPalette.color(_colours[group * 4 + i]))
		ripper.draw_tile(image, InfoScreenData.TITLE_PAGE * ChrRipper.TILES_PER_BANK + _tiles[index], Vector2i(col * 8, TOP_LINE + row * 8), shades)
	# Above the picture the console shows the last four lines of the
	# screen's memory, which hold colour choices, not tiles: the second
	# half of the colour table read as a row of tiles.
	for col in range(1, InfoScreenData.COLS):
		var shift := 4 + ((col % 4) / 2) * 2
		var group := (_colour_bytes[56 + col / 4] >> shift) & 3
		var shades: Array[Color] = [NesPalette.color(_colours[0])]
		for i in range(1, 4):
			shades.append(NesPalette.color(_colours[group * 4 + i]))
		ripper.draw_tile(image, InfoScreenData.TITLE_PAGE * ChrRipper.TILES_PER_BANK + _colour_bytes[32 + col], Vector2i(col * 8, TOP_LINE - 8), shades)
	return image

func tile_at(col: int, row: int) -> int:
	return _tiles[row * InfoScreenData.COLS + col] if not _tiles.is_empty() else -1

func _physics_process(_delta: float) -> void:
	if finished:
		return
	if Input.is_action_just_pressed("pause"):
		press_start()
	tick()

## Start (the original also takes Select on the notice).
func press_start() -> void:
	if phase == Phase.NOTICE:
		show_phase(Phase.TITLE)
	elif phase == Phase.TITLE:
		phase = Phase.BLINK
		_frames = 0

## One frame.
func tick() -> void:
	_frames += 1
	if phase == Phase.NOTICE and _frames >= NOTICE_FRAMES:
		show_phase(Phase.TITLE)
	elif phase == Phase.BLINK:
		if _frames >= BLINK_FRAMES:
			finished = true
			if leave_when_done:
				Game.go_to(next_scene)
			return
		var on := (_frames / BLINK_EVERY) % 2 == 1
		if on != push_start_shown:
			push_start_shown = on
			if data != null:
				_write_push_start(on)
				_paint()
			else:
				_plain.queue_redraw()

func _draw_plain() -> void:
	var font := ThemeDB.fallback_font
	_plain.draw_string(font, Vector2(0, 100), "TMNT REMAKE", HORIZONTAL_ALIGNMENT_CENTER, 256, 16)
	if push_start_shown:
		_plain.draw_string(font, Vector2(0, 180), "PUSH START", HORIZONTAL_ALIGNMENT_CENTER, 256, 8)
