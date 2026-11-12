class_name GameOverScreen
extends CanvasLayer
## What the original shows when the last turtle is captured (measured,
## Research/losing_a_turtle.md): GAME OVER alone on a black screen for
## about four and a half seconds, then CONTINUE and END with a marker.
## The marker moves between the two (Select in the original; here Up,
## Down or Select-like keys move it) and Start chooses. There are two
## continues; when they are used up the choice is not offered.
##
## With a ROM the words are written in the ROM's own letters (the tiles of
## the Start screen's page, which use the same letter numbers); without
## one, in plain text.

signal chosen(carry_on: bool)   ## true: CONTINUE, false: END (or no continues left)

const WORDS_FRAMES := 272       ## GAME OVER alone, before the choice appears
const LETTER_A := 0x10          ## the tile of the letter A; the others follow

enum Phase { SHUT, WORDS, CHOICE }

var phase := Phase.SHUT
var choice := 0                 ## 0 CONTINUE, 1 END
var offer_continue := true
var ripper: ChrRipper           ## null without a ROM
var _frames := 0
var _board := Control.new()

func _init() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_board.size = Vector2(256, 240)
	_board.draw.connect(_draw_board)
	add_child(_board)
	visible = false

func use_installed_rom() -> void:
	if ripper != null or not FileAccess.file_exists(Game.ROM_PATH):
		return
	var info := RomInfo.inspect_file(Game.ROM_PATH)
	if info.known_name != "":
		ripper = ChrRipper.new(info.chr_rom)

func is_open() -> bool:
	return phase != Phase.SHUT

## Shows GAME OVER. `continues_left` is how many continues remain after
## this one is counted; at 0 the game ends without asking.
func open(continues_left: int) -> void:
	offer_continue = continues_left > 0
	phase = Phase.WORDS
	choice = 0
	_frames = 0
	visible = true
	if is_inside_tree():
		get_tree().paused = true
	_board.queue_redraw()

func _physics_process(_delta: float) -> void:
	if phase == Phase.SHUT:
		return
	if phase == Phase.CHOICE:
		if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_up"):
			move_marker()
		elif Input.is_action_just_pressed("pause"):
			choose()
	tick()

## One frame.
func tick() -> void:
	if phase != Phase.WORDS:
		return
	_frames += 1
	if _frames >= WORDS_FRAMES:
		if offer_continue:
			phase = Phase.CHOICE
			_board.queue_redraw()
		else:
			_finish(false)

func move_marker() -> void:
	if phase == Phase.CHOICE:
		choice = 1 - choice
		_board.queue_redraw()

func choose() -> void:
	if phase == Phase.CHOICE:
		_finish(choice == 0)

func _finish(carry_on: bool) -> void:
	phase = Phase.SHUT
	visible = false
	if is_inside_tree():
		get_tree().paused = false
	chosen.emit(carry_on)

## Writes a word at a tile column and row of the original's screen.
func _write(word: String, col: int, row: int) -> void:
	if ripper == null:
		_board.draw_string(ThemeDB.fallback_font, Vector2(col * 8, row * 8 + 19), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		return
	var image := Image.create(word.length() * 8, 8, false, Image.FORMAT_RGBA8)
	var shades: Array[Color] = [Color.BLACK, Color.BLACK, Color.BLACK, NesPalette.color(0x30)]
	for i in word.length():
		var code := word.unicode_at(i)
		if code >= 65 and code <= 90:
			ripper.draw_tile(image, InfoScreenData.GRAPHICS_PAGE * ChrRipper.TILES_PER_BANK + LETTER_A + code - 65, Vector2i(i * 8, 0), shades)
	_board.draw_texture(ImageTexture.create_from_image(image), Vector2(col * 8, row * 8 + 12))

func _draw_board() -> void:
	_board.draw_rect(Rect2(0, 0, 256, 240), Color.BLACK)
	if phase == Phase.WORDS:
		_write("GAME OVER", 11, 13)
	elif phase == Phase.CHOICE:
		_write("CONTINUE", 13, 13)
		_write("END", 13, 16)
		_board.draw_rect(Rect2(96, (13 if choice == 0 else 16) * 8 + 13, 6, 6), Color(0.9, 0.3, 0.2))
