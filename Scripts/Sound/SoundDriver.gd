class_name SoundDriver
extends RefCounted
## Plays the original's sound effects and music from the data in the
## player's ROM, the way the original's sound program does
## (Research/sound.md). It does not make sound itself: once a frame it
## works out what to tell the console's sound chip and passes each value
## to `chip` (a SoundChip, or anything with write(register, value)).
##
## How to use it: play(number) to start a sound, step() once every frame.
##
## Six voices ("slots"): 0 and 1 are the music's two square waves, 2 its
## triangle wave (the bass), 3 its drum track, 4 is the first square wave
## again for sound effects, 5 the noise for effects and drums.

const SLOTS := 6
const SLOT_TRIANGLE := 2
const SLOT_DRUMS := 3
const SLOT_EFFECT_SQUARE := 4
const SLOT_NOISE := 5
## Which of the chip's registers each slot's channel starts at.
const CHANNEL_START := [0x4000, 0x4004, 0x4008, 0x400C, 0x4000, 0x400C]

const SILENT := 0x30              ## "loudness 0, steady" for a square wave or the noise
const NO_SWEEP := 0x7F            ## the sweep register's "off"
const STEADY_LOUDNESS := 0x10     ## the bit of a tone byte that says the chip does no fading of its own
const HIGH_NEVER_SENT := 0xF8     ## no pitch has this high byte, so the first note always sends its own
const WOBBLE_ENDED := 0xFF        ## a wobble table has run out: no pitches are sent until the next note
const ECHO_OFF := 0x80
const DRUM_REST := 12

## Numbers the original treats specially.
const TUNE_LOCKED := 0x83         ## while this is in the drum slot no other tune starts and nothing silences it
const TUNE_OVER_A := 0x83         ## when one of these two ends, `tune_over` becomes true
const TUNE_OVER_B := 0x7F
const TUNE_ON_TOP_A := 0x77       ## these two start without silencing what is playing
const TUNE_ON_TOP_B := 0x7F
const EFFECT_NO_RESTART := 0x16   ## not started again while it is already sounding
const BLOCKED_FROM := 0x07        ## effects from here ...
const BLOCKED_TO := 0x3E          ## ... up to here are not started while TUNE_ON_TOP_A is in slot 1
const FADE_START := 7             ## what the game writes to start a fade-out
const FADE_STEP_FRAMES := 0x2F    ## frames for each step quieter
const FADE_DRUMS_STOP_AT := 0x20  ## in the last step, the frame the drums stop on

## The stages of a square-wave note's loudness.
enum { STAGE_TABLE, STAGE_SIMPLE, STAGE_HOLD, STAGE_TAIL }

## Everything remembered for one voice.
class Voice:
	var number := 0               ## the sound playing here (0 = free)
	var address := 0              ## where its data is being read
	var frames_left := 0          ## of the note or rest being played
	var tempo := 0                ## frames in one length unit
	var effect_format := false    ## its data is written in the effects' format
	var resting := false
	var has_sweep := false        ## (effects) the chip is sliding the pitch
	# repeats and called pieces
	var repeat_count := 0
	var repeat_mark := 0
	var in_call := false
	var return_address := 0
	# what was last sent, and the instrument
	var last_high := 0
	var last_low := 0
	var loudness := 0             ## loudness now, before quieting and fading
	var instrument_loudness := 0
	var tone := 0                 ## the high bits of the channel's first register
	var octave := 0
	var transpose := 0
	var quieting := 0             ## taken off every loudness sent
	var pitch := 0                ## the note's own pitch number
	# loudness shape
	var stage := STAGE_TABLE
	var shape := 0                ## shape number; $80 and up is the simple shape
	var shape_count := 0          ## frames until the next step
	var shape_place := 0
	var shape_mark := 0
	var shape_repeat := 0
	# tail of the note
	var tail_length := 0          ## the tail begins when fewer frames than this are left
	var tail_sixteenths := 0
	var fall_time := 0
	var fall_count := 0
	# second tone
	var second_tone := 0
	var second_tone_now := false
	# wobble
	var wobble_on := false
	var wobble_delay := 0
	var wobble_count := 0
	var wobble_depth := 0
	var wobble_table := 0
	var wobble_place := 0
	var wobble_mark := 0
	var wobble_repeat := 0
	# echo
	var echo := 0x80
	var echo_first := false       ## the next pitch remembered fills the whole memory
	var echo_twice_unit := false  ## remember every second tempo unit
	var echo_back := 0            ## how many notes back the tail plays
	var echo_next := 0
	var echo_memory := [0, 0, 0, 0]

var data: SoundData
var chip                          ## gets write(register, value); may be null
var voices: Array[Voice] = []
var requested := 0                ## the last number asked for
var tune_over := false            ## set when tune $83 or $7F has played to its end
var fade_stage := 0               ## 0 = no fade-out going on
var fade_counter := 0
var fade_amount := 0              ## taken off the music's loudness
var triangle_length := 0          ## the triangle instrument's note-length setting
var last_drum := 0
## Every value sent to the chip since this was last emptied, as
## register * 256 + value. Only kept while `keep_log` is true (for tests).
var keep_log := false
var log: PackedInt32Array = PackedInt32Array()
## Counts things in the data this program does not expect (for tests).
var oddities := 0

var _work := 0                    ## the pitch number being worked on

func _init(sound_data: SoundData, sound_chip = null) -> void:
	data = sound_data
	chip = sound_chip
	for i in SLOTS:
		voices.append(Voice.new())

# ---------------------------------------------------------------- starting

## Start sound `number` (what the original does at 0:$9057).
func play(number: int) -> void:
	requested = number
	if number <= 0 or number > 0xFF:
		return
	if number >= SoundData.FIRST_SAMPLE:
		_start_sample(number - SoundData.FIRST_SAMPLE)
		return
	if number >= SoundData.FIRST_TUNE:
		if voices[SLOT_DRUMS].number == TUNE_LOCKED:
			return
		voices[0].wobble_count = 0
		voices[1].wobble_count = 0
		if number != TUNE_ON_TOP_A and number != TUNE_ON_TOP_B:
			stop_all()
		if number == TUNE_OVER_A or number == TUNE_OVER_B:
			tune_over = false
	else:
		if number == EFFECT_NO_RESTART and voices[SLOT_NOISE].number == number:
			return
		if voices[1].number == TUNE_ON_TOP_A and number >= BLOCKED_FROM and number < BLOCKED_TO:
			return
	for entry: Array in data.voices(number):
		var slot: int = entry[0]
		if slot >= SLOTS:
			continue
		# A voice is only taken by a number that is not lower than the
		# one playing there.
		if number < voices[slot].number:
			continue
		_take_voice(slot, number, entry[1])

func _take_voice(slot: int, number: int, address: int) -> void:
	var voice := voices[slot]
	voice.address = address
	voice.last_high = HIGH_NEVER_SENT
	voice.frames_left = 1
	voice.repeat_count = 0
	# Only this much is cleared; the rest of the instrument stays as the
	# last sound in this slot left it, until the new data sets it.
	if slot < SLOT_TRIANGLE:
		voice.quieting = 0
		voice.second_tone = 0
		voice.echo = ECHO_OFF
	if slot <= SLOT_TRIANGLE:
		voice.transpose = 0
	voice.stage = STAGE_TABLE
	voice.in_call = false
	voice.wobble_on = false
	voice.second_tone_now = false
	voice.resting = false
	voice.has_sweep = false
	voice.effect_format = data.is_effect_format(address)
	if not voice.effect_format:
		fade_counter = 0
		fade_amount = 0
	voice.number = number
	# Quieten the channel; the first square wave only if no effect has it.
	if slot == 0 and voices[SLOT_EFFECT_SQUARE].number != 0:
		return
	var start: int = CHANNEL_START[slot]
	_to_chip(start, 0 if slot == SLOT_TRIANGLE else SILENT)
	_to_chip(start + 1, NO_SWEEP)

## Silence everything (0:$9016). Does nothing while the locked tune plays.
func stop_all() -> void:
	if voices[SLOT_DRUMS].number == TUNE_LOCKED:
		return
	for voice in voices:
		voice.number = 0
	voices[0].wobble_count = 0
	voices[1].wobble_count = 0
	fade_counter = 0
	fade_stage = 0
	fade_amount = 0
	_silence_triangle()
	_to_chip(0x4000, SILENT)
	_to_chip(0x4004, SILENT)
	_to_chip(0x400C, SILENT)
	_to_chip(0x4001, NO_SWEEP)
	_to_chip(0x4005, NO_SWEEP)

## Begin a fade-out of the music (the game does this by writing 7 to $0199).
func fade_out() -> void:
	fade_stage = FADE_START

## True while any voice is sounding.
func busy() -> bool:
	for voice in voices:
		if voice.number != 0:
			return true
	return false

## The number playing in a slot (0 = none).
func playing(slot: int) -> int:
	return voices[slot].number

func _start_sample(sample: int) -> void:
	var values := data.sample_values(sample)
	_to_chip(0x4015, 0x0F)
	for i in 4:
		_to_chip(0x4010 + i, values[i])
	_to_chip(0x4015, 0x1F)

# ------------------------------------------------------------- each frame

## One frame (0:$8644).
func step() -> void:
	_fade_step()
	for slot in SLOTS:
		if voices[slot].number != 0:
			_step_voice(slot)

func _fade_step() -> void:
	if fade_stage == 0:
		return
	if fade_stage == 1:
		stop_all()
		return
	if fade_stage == 2 and fade_counter == FADE_DRUMS_STOP_AT:
		voices[SLOT_DRUMS].number = 0
	fade_counter += 1
	if fade_counter == FADE_STEP_FRAMES:
		fade_counter = 0
		fade_amount += 1
		fade_stage -= 1

func _step_voice(slot: int) -> void:
	var voice := voices[slot]
	voice.frames_left = (voice.frames_left - 1) & 0xFF
	if voice.frames_left == 0:
		if voice.effect_format:
			_read_effect(slot)
		else:
			_read_music(slot)
		return
	# Between notes only the music's square waves have anything to do.
	if slot >= SLOT_TRIANGLE or voice.effect_format or voice.resting:
		return
	var wobble_now := true
	if voice.echo != ECHO_OFF:
		var unit := voice.tempo
		if voice.echo_twice_unit:
			unit = (unit * 2) & 0xFF
		if unit != 0 and voice.frames_left % unit == 0:
			_work = voice.pitch
			_remember_pitch(voice)
		wobble_now = voice.stage != STAGE_TAIL
	if wobble_now and voice.wobble_on:
		voice.wobble_count = (voice.wobble_count - 1) & 0xFF
		if voice.wobble_count == 0:
			voice.wobble_count = 1
			_wobble_step(voice)
			_send_pitch(slot)
	voice.shape_count = (voice.shape_count - 1) & 0xFF
	if voice.shape_count != 0:
		return
	voice.shape_count = 1
	_tail_check(slot)
	match voice.stage:
		STAGE_TABLE:
			_shape_step(slot)
		STAGE_SIMPLE:
			_simple_step(slot)
		STAGE_TAIL:
			_tail_step(slot)

# -------------------------------------------------------- loudness shapes

## Has the note reached its tail?
func _tail_check(slot: int) -> void:
	var voice := voices[slot]
	if voice.stage == STAGE_TAIL or voice.frames_left >= voice.tail_length:
		return
	voice.stage = STAGE_TAIL
	if voice.second_tone & 2:
		voice.second_tone_now = true
	var tail_loudness := (voice.second_tone & 0x0C) >> 2
	if tail_loudness != 0:
		_send_loudness(slot, tail_loudness)

## The next byte of the loudness table.
func _shape_step(slot: int) -> void:
	var voice := voices[slot]
	var table := data.shape_table(voice.shape)
	for guard in 256:
		var value := data.byte(table + voice.shape_place)
		if value == 0xFF:
			voice.stage = STAGE_HOLD
			return
		if value == 0xFE:
			voice.shape_repeat = (voice.shape_repeat + 1) & 0xFF
			if data.byte(table + voice.shape_place + 1) == voice.shape_repeat:
				voice.shape_repeat = 0
				voice.shape_mark = 0
				voice.shape_place = (voice.shape_place + 2) & 0xFF
			else:
				voice.shape_place = voice.shape_mark
			continue
		if value >= 0xFB:
			voice.shape_place = (voice.shape_place + 1) & 0xFF
			voice.shape_mark = voice.shape_place
			continue
		if value >= 0x10:
			voice.shape_count = value >> 4
		voice.shape_place = (voice.shape_place + 1) & 0xFF
		_send_loudness(slot, value & 0x0F)
		return

## The simple shape: one quieter each frame for a set number of frames.
func _simple_step(slot: int) -> void:
	var voice := voices[slot]
	voice.shape_place = (voice.shape_place - 1) & 0xFF
	if voice.shape_place & 0x80:
		voice.stage = STAGE_HOLD
		return
	if voice.loudness > 0:
		_send_loudness(slot, voice.loudness - 1)

## The tail of a note: the echo's pitch, and the loudness falling to 1.
func _tail_step(slot: int) -> void:
	var voice := voices[slot]
	if voice.echo != ECHO_OFF:
		_work = voice.echo_memory[(voice.echo_next - 1 - voice.echo_back) & 3]
		_send_pitch_if_changed(slot)
	if voice.second_tone & 0x0C:
		return
	voice.fall_count = (voice.fall_count - 1) & 0xFF
	if voice.fall_count != 0:
		return
	voice.fall_count = maxi(voice.fall_time, 1)
	if voice.loudness >= 2:
		_send_loudness(slot, voice.loudness - 1)

func _send_loudness(slot: int, value: int) -> void:
	var voice := voices[slot]
	voice.loudness = value
	var out := value
	if value != 0:
		out = value - voice.quieting
		if out > 0:
			out -= fade_amount
		if out <= 0:
			out = 1
	var tone := voice.tone
	if voice.second_tone_now:
		tone = voice.second_tone & 0xF0
	_write(slot, 0, out | tone)

# ------------------------------------------------------------------ pitch

func _send_pitch(slot: int) -> void:
	if slot == SLOT_TRIANGLE or slot == SLOT_NOISE:
		_send_high(slot)
		_send_low(slot)
		return
	if slot < SLOT_TRIANGLE and voices[slot].wobble_count == WOBBLE_ENDED:
		return
	_send_pitch_if_changed(slot)

## The high byte restarts the wave, which clicks, so for a steady tone
## without a sweep it is only sent when it has changed.
func _send_pitch_if_changed(slot: int) -> void:
	var voice := voices[slot]
	if (_work >> 8) != voice.last_high or voice.has_sweep or (voice.tone & STEADY_LOUDNESS) == 0:
		_send_high(slot)
	_send_low(slot)

func _send_high(slot: int) -> void:
	var high := (_work >> 8) & 0xFF
	voices[slot].last_high = high
	_write(slot, 3, high | 0x08)

func _send_low(slot: int) -> void:
	var low := _work & 0xFF
	if slot < SLOT_TRIANGLE:
		voices[slot].last_low = low
	_write(slot, 2, low)

## Put the pitch being worked on into the echo memory.
func _remember_pitch(voice: Voice) -> void:
	if voice.echo_first:
		voice.echo_first = false
		for i in 4:
			voice.echo_memory[i] = _work
	else:
		voice.echo_memory[voice.echo_next] = _work
	voice.echo_next = (voice.echo_next + 1) & 3

## The next step of the wobble table moves the pitch being worked on away
## from the note's own pitch.
func _wobble_step(voice: Voice) -> void:
	var table := data.wobble_table(voice.wobble_table)
	for guard in 256:
		var value := data.byte(table + voice.wobble_place)
		if value == 0xFF:
			voice.wobble_count = WOBBLE_ENDED
			return
		if value == 0xFE:
			voice.wobble_repeat = (voice.wobble_repeat + 1) & 0xFF
			if data.byte(table + voice.wobble_place + 1) == voice.wobble_repeat:
				voice.wobble_repeat = 0
				voice.wobble_mark = 0
				voice.wobble_place = (voice.wobble_place + 2) & 0xFF
			else:
				voice.wobble_place = voice.wobble_mark
			continue
		if value >= 0xFB:
			voice.wobble_place = (voice.wobble_place + 1) & 0xFF
			voice.wobble_mark = voice.wobble_place
			continue
		if value >= 0x10:
			voice.wobble_count = value >> 4
		voice.wobble_place = (voice.wobble_place + 1) & 0xFF
		var move := value & 0x0F
		if move < 8:
			_work = (voice.pitch + ((move * voice.wobble_depth) & 0xFF)) & 0xFFFF
		else:
			_work = (voice.pitch - (((16 - move) * voice.wobble_depth) & 0xFF)) & 0xFFFF
		return

# ------------------------------------------------------- the music format

func _read_music(slot: int) -> void:
	var voice := voices[slot]
	for guard in 4096:
		var value := data.byte(voice.address)
		var high := value & 0xF0
		var low := value & 0x0F
		if slot == SLOT_DRUMS:
			if high == 0xF0:
				if _control(slot, low):
					return
			elif high == 0xD0:
				voice.tempo = low
				voice.address += 1
			else:
				_set_length(slot, low)
				voice.address += 1
				_drum(value >> 4)
				return
			continue
		if high < 0xC0:
			_note(slot, value)
			return
		match high:
			0xC0:
				_set_length(slot, low)
				if slot == SLOT_TRIANGLE:
					_silence_triangle()
				else:
					_write(slot, 0, SILENT)
				voice.resting = true
				voice.address += 1
				return
			0xD0:
				voice.tempo = low
				if slot == SLOT_TRIANGLE:
					triangle_length = data.byte(voice.address + 1)
					voice.address += 2
				else:
					var sound := data.byte(voice.address + 1)
					voice.tone = sound & 0xF0
					voice.instrument_loudness = sound & 0x0F
					voice.shape = data.byte(voice.address + 2)
					# With a table shape the "loudness" is the quieting.
					voice.quieting = 0 if voice.shape & 0x80 else voice.instrument_loudness
					_set_tail(voice, data.byte(voice.address + 3))
					voice.address += 4
			0xE0:
				_setting(slot, low)
			0xF0:
				if _control(slot, low):
					return
	push_warning("SoundDriver: sound %d never reaches a note" % voice.number)
	voice.number = 0

## The E commands.
func _setting(slot: int, which: int) -> void:
	var voice := voices[slot]
	var value := data.byte(voice.address + 1)
	if which < 6:
		voice.octave = which
		voice.address += 1
		return
	if which > 6 and slot >= SLOT_TRIANGLE and which != 0x0A:
		oddities += 1
	voice.address += 2
	match which:
		6:
			voice.tempo = value
		7:
			voice.shape = value
		8:
			_set_tail(voice, value)
		9:
			if value == 0:
				voice.second_tone_now = false
			elif (value & 0x0F) == 0:
				voice.tone = value
			else:
				voice.second_tone = value
				voice.second_tone_now = true
		0x0A:
			voice.transpose = (value * 2) & 0xFF
			if value & 0x80:
				voice.transpose |= 0x80
		0x0B:
			if value == 0:
				voice.wobble_on = false
			else:
				var units := value >> 4
				voice.wobble_delay = (voice.tempo * units) & 0xFF
				voice.wobble_depth = value & 0x0F
				voice.wobble_table = data.byte(voice.address)
				voice.wobble_on = true
				voice.address += 1
		0x0C:
			if value == 0:
				voice.echo = ECHO_OFF
			else:
				voice.echo = value
				voice.echo_first = true
				voice.echo_twice_unit = value >= 4
				voice.echo_back = (value if value < 4 else value - 3) & 0x0F
			voice.echo_next = 0
		_:
			# The original has no such command.
			oddities += 1
			push_warning("SoundDriver: unknown command E%X in sound %d" % [which, voice.number])
			voice.number = 0

func _set_tail(voice: Voice, value: int) -> void:
	voice.tail_sixteenths = value & 0x0F
	voice.fall_time = value >> 4
	voice.fall_count = maxi(voice.fall_time, 1)

## The F commands, shared by both formats. True if the voice has ended.
func _control(slot: int, which: int) -> bool:
	var voice := voices[slot]
	match which:
		0x0B:   # mark the start of a repeat
			voice.address += 1
			voice.repeat_mark = voice.address
		0x0D:   # play a piece somewhere else, then come back
			voice.return_address = voice.address + 3
			voice.in_call = true
			voice.address = data.word(voice.address + 1)
		0x0E:   # repeat, or jump
			voice.repeat_count = (voice.repeat_count + 1) & 0xFF
			var times := data.byte(voice.address + 1)
			if voice.repeat_count == times:
				voice.repeat_count = 0
				voice.address += 2
			elif (voice.repeat_count - times) & 0x80:
				voice.address = voice.repeat_mark
			else:
				voice.repeat_count -= 1
				voice.address = data.word(voice.address + 2)
		0x0F:   # the end of a called piece, or of the voice
			if voice.in_call:
				voice.in_call = false
				voice.address = voice.return_address
			else:
				_end_voice(slot)
				return true
		_:
			if slot >= SLOT_TRIANGLE:
				oddities += 1
			voice.quieting = which
			voice.address += 1
	return false

## A note's or a rest's length: (count + 1) tempo units.
func _set_length(slot: int, count: int) -> void:
	var voice := voices[slot]
	voice.frames_left = (voice.tempo * (count + 1)) & 0xFF
	if slot >= SLOT_TRIANGLE:
		return
	if voice.wobble_on:
		voice.wobble_count = (voice.wobble_delay + 1) & 0xFF
		voice.wobble_place = 0
		voice.wobble_mark = 0
		voice.wobble_repeat = 0
	voice.tail_length = ((voice.frames_left * voice.tail_sixteenths) >> 4) & 0xFF

func _note(slot: int, value: int) -> void:
	var voice := voices[slot]
	var count := value & 0x0F
	_set_length(slot, count)
	if slot == SLOT_TRIANGLE:
		_triangle_note_length(count)
	else:
		voice.second_tone_now = (voice.second_tone & 1) != 0
		voice.shape_count = 1
		if voice.shape & 0x80:
			_send_loudness(slot, voice.instrument_loudness)
			voice.shape_place = voice.shape & 0x0F
			voice.stage = STAGE_SIMPLE
		else:
			voice.shape_place = 0
			voice.shape_mark = 0
			voice.shape_repeat = 0
			_shape_step(slot)
			voice.stage = STAGE_TABLE
		voice.second_tone_now = false
		voice.resting = false
	# The pitch: the table's entry, moved by the transpose, halved for
	# each octave above the table's own.
	var place := (value >> 4) * 2
	var moved := voice.transpose
	var pitch := 0
	if moved == 0:
		pitch = data.word(SoundData.T_PITCHES + place)
	elif moved & 0x80:
		place -= moved & 0x7F
		if place >= 0:
			pitch = data.word(SoundData.T_PITCHES + place)
		else:
			pitch = data.word(SoundData.T_LOW_PITCHES + ((place + 24) & 0xFF))
	else:
		pitch = data.word(SoundData.T_PITCHES + place + moved)
	pitch >>= mini((5 - voice.octave) & 0xFF, 16)
	_work = pitch
	if slot != SLOT_TRIANGLE:
		if voice.echo != ECHO_OFF:
			_remember_pitch(voice)
		voice.pitch = pitch
		if voice.wobble_on and voice.wobble_delay == 0:
			_wobble_step(voice)
	_send_pitch(slot)
	voice.address += 1

## The triangle has no loudness: how long a note sounds is set through
## the chip's own counter.
func _triangle_note_length(count: int) -> void:
	var value := 0x90             # sound for the whole note
	if triangle_length >= 0x80:
		value = triangle_length - 0x80
	elif triangle_length != 0:
		var frames := (triangle_length + 1) * (count + 1)
		if frames < 0x80:
			value = frames
	_to_chip(0x4008, value)

## A note of the drum track starts an effect or the sample.
func _drum(drum: int) -> void:
	if drum == DRUM_REST:
		return
	last_drum = drum
	if drum > DRUM_REST:
		oddities += 1
		return
	play(data.drum_sound(drum))

# ----------------------------------------------------- the effects' format

func _read_effect(slot: int) -> void:
	var voice := voices[slot]
	for guard in 4096:
		var value := data.byte(voice.address)
		if value >= 0xFB:
			if value == 0xFC:
				# Not a command of this format: the original takes it as
				# a quieting and carries on reading as music.
				oddities += 1
				_control(slot, 0x0C)
				_read_music(slot)
				return
			if _control(slot, value & 0x0F):
				return
			continue
		if slot != SLOT_NOISE and value >= 0xF8:
			var setting := data.byte(voice.address + 1)
			voice.address += 2
			match value:
				0xF8:
					voice.tempo = setting
				0xF9:
					voice.tone = setting
				0xFA:
					_write(slot, 1, setting)
			continue
		if value != 0 and value < 0x10:
			# Frames for each note, then how the channel is set up.
			voice.tempo = value
			var setup := data.byte(voice.address + 1)
			if slot == SLOT_TRIANGLE:
				_to_chip(0x4008, setup)
				voice.address += 2
			elif slot == SLOT_NOISE:
				voice.tone = SILENT       # steady loudness; nothing more to read
				voice.address += 1
			else:
				voice.tone = setup
				var sweep := data.byte(voice.address + 2)
				voice.has_sweep = sweep != 0x88
				_write(slot, 1, sweep if voice.has_sweep else NO_SWEEP)
				voice.address += 3
			continue
		# A note: one length unit long.
		voice.frames_left = voice.tempo
		if slot != SLOT_TRIANGLE:
			voice.instrument_loudness = value >> 4
			if voice.tone & STEADY_LOUDNESS:
				_write(slot, 0, voice.tone | voice.instrument_loudness)
			else:
				_write(slot, 0, voice.tone)   # the chip's own fading does the loudness
		if slot == SLOT_NOISE:
			_work = (_work & 0xFF00) | (value & 0x0F)
			voice.address += 1
		else:
			_work = ((value & 0x0F) << 8) | data.byte(voice.address + 1)
			voice.address += 2
		_send_pitch(slot)
		return
	push_warning("SoundDriver: sound %d never reaches a note" % voice.number)
	voice.number = 0

# --------------------------------------------------------- ending, writing

func _end_voice(slot: int) -> void:
	var voice := voices[slot]
	var number := voice.number
	voice.number = 0
	match slot:
		SLOT_TRIANGLE:
			_silence_triangle()
		SLOT_DRUMS:
			_to_chip(0x400C, SILENT)
			if number == TUNE_OVER_A or number == TUNE_OVER_B:
				tune_over = true
		SLOT_EFFECT_SQUARE:
			_to_chip(0x4000, SILENT)
			_to_chip(0x4001, NO_SWEEP)
			# Give the first square wave back to the music, as the note
			# it is in the middle of would sound now.
			var music := voices[0]
			if music.number != 0:
				if music.effect_format or music.resting:
					_to_chip(0x4000, SILENT)
				else:
					_send_loudness(0, music.loudness)
				_to_chip(0x4002, music.last_low)
				_to_chip(0x4003, music.last_high)
		_:
			_write(slot, 0, SILENT)

func _silence_triangle() -> void:
	_to_chip(0x4015, 0x0B)
	_to_chip(0x4008, 0x00)
	_to_chip(0x4015, 0x0F)

## Send a value to register `register` (0-3) of the slot's channel. The
## music's first square wave is not heard while an effect has its channel.
func _write(slot: int, register: int, value: int) -> void:
	if slot == 0 and voices[SLOT_EFFECT_SQUARE].number != 0:
		return
	_to_chip(CHANNEL_START[slot] + register, value)

func _to_chip(register: int, value: int) -> void:
	if keep_log:
		log.append(register * 256 + (value & 0xFF))
	if chip != null:
		chip.write(register, value & 0xFF)
