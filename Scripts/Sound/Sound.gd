extends Node
## Autoload: the game's sound. Any script can call
##
##     Sound.play(0x21)      start sound effect or tune number $21
##     Sound.stop_all()      silence everything
##     Sound.fade_out()      let the music die away
##     Sound.tune_over       true when tune $83 or $7F has played to its end
##
## The numbers are the original's own (Research/sound.md lists them), and
## what they sound like comes from the player's ROM: SoundData finds the
## data, SoundDriver steps it once a frame as the original's sound program
## does, SoundChip turns the result into samples, and this node hands the
## samples to Godot. Without a ROM every call does nothing. In a headless
## run (the tests) the driver still steps but no samples are made.

const ACTION_TOGGLE := "toggle_sound"
const MIX_RATE := 44100.0
const FRAMES_PER_SECOND := 60
const BUFFER_SECONDS := 0.15          ## how much sound Godot may hold waiting to be heard
const CUSHION_FRAMES := 3              ## silence put in first, so a late frame does not leave a gap
const REQUESTS_KEPT := 64

var data: SoundData
var driver: SoundDriver
var chip: SoundChip
## Master switch (key M). Off: the driver keeps stepping, so anything
## waiting for a tune to end still gets its turn, but nothing is heard.
var enabled := true
## The last numbers asked for, oldest first, as [frame, number] (for tests
## and for comparing with the original).
var requests: Array = []
var frame := 0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _buffer_room := 0                  ## what Godot's buffer holds when empty
var _looked_for_rom := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_rom()

## Look for the player's ROM and get ready to play from it. Safe to call
## again (after the ROM screen has copied a ROM in, say).
func load_rom(path: String = Game.ROM_PATH) -> void:
	_looked_for_rom = true
	driver = null
	if not FileAccess.file_exists(path):
		return
	use_program(SoundData.prg_of_file(FileAccess.get_file_as_bytes(path)))

## Play from these program bytes (tests pass a made-up ROM here).
func use_program(prg: PackedByteArray) -> void:
	driver = null
	data = SoundData.new(prg)
	if not data.usable():
		return
	chip = SoundChip.new(data, MIX_RATE)
	driver = SoundDriver.new(data, chip)
	if DisplayServer.get_name() != "headless":
		open_audio()

## Make the Godot player the samples are handed to. Not done in a headless
## run, where there is nobody to hear it.
func open_audio() -> void:
	if _player != null:
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_SECONDS
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_buffer_room = _playback.get_frames_available()

## True when sounds can be played (a ROM was found).
func ready_to_play() -> bool:
	return driver != null

func play(number: int) -> void:
	requests.append([frame, number])
	if requests.size() > REQUESTS_KEPT:
		requests.pop_front()
	if driver == null and not _looked_for_rom:
		load_rom()
	if driver != null:
		driver.play(number)

func stop_all() -> void:
	if driver != null:
		driver.stop_all()

func fade_out() -> void:
	if driver != null:
		driver.fade_out()

## True when tune $83 or $7F has played to its end since it was started.
var tune_over: bool:
	get:
		return driver != null and driver.tune_over

## The tune (or other sound) in music slot 0, or 0.
func tune_playing() -> int:
	return driver.playing(0) if driver != null else 0

func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(ACTION_TOGGLE) and event.is_action_pressed(ACTION_TOGGLE):
		enabled = not enabled

## Once a game frame, as the original's picture interrupt does.
func _physics_process(_delta: float) -> void:
	frame += 1
	if driver == null:
		return
	driver.step()
	if _playback == null:
		return
	var count := int(MIX_RATE / FRAMES_PER_SECOND)
	var room := _playback.get_frames_available()
	if room >= _buffer_room:
		# Nothing is waiting to be heard (the start, or a frame came
		# late): begin again a little ahead.
		var cushion := PackedVector2Array()
		cushion.resize(count * CUSHION_FRAMES)
		_playback.push_buffer(cushion)
		room -= cushion.size()
	if room < count:
		return                        # Godot has plenty waiting already
	var samples := chip.render_frame(count)   # also keeps the chip's clock going
	if not enabled:
		samples.fill(Vector2.ZERO)
	_playback.push_buffer(samples)
