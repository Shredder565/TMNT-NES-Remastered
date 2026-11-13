class_name SoundChip
extends RefCounted
## A small stand-in for the console's sound chip. The SoundDriver tells it
## what the original's sound program would tell the real chip, by register
## number and value (write), and it turns that into sound samples
## (render_frame). It knows five kinds of channel:
##
##   two square waves   $4000-$4003 and $4004-$4007
##   a triangle wave    $4008-$400B
##   noise              $400C-$400F
##   a sample player    $4010-$4013
##   and $4015, which switches channels on and off.
##
## It is kept simple. What it does carefully is what the game's sound data
## leans on: exact pitches, the chip's own fading ("envelope"), its pitch
## slides ("sweep"), and its counters that cut a note off after a time.
## Those run off a clock the chip ticks four times a frame, so a frame is
## rendered in four quarters. What it does not do: the real chip's slightly
## curved mixing of channels, or its filters beyond removing the offset.

const CPU_HZ := 1789773.0         ## the NTSC console's clock; every pitch comes from it

## The "length" code in the top five bits of a channel's fourth register:
## how many half-frame ticks the note may sound.
const LENGTHS: Array[int] = [10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
		12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30]
## Clock ticks between steps of the noise, for each of its 16 pitches (NTSC).
const NOISE_PERIODS: Array[int] = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
## Clock ticks for each bit of a sample, for each of the 16 rates (NTSC).
const SAMPLE_PERIODS: Array[int] = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54]
## The share of each cycle a square wave is high, for its four tones.
const DUTY: Array[float] = [0.125, 0.25, 0.5, 0.75]
## The triangle wave's 32 steps.
const TRIANGLE_STEPS: Array[int] = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const NOISE_LONG := 32767         ## steps before the usual noise repeats
const NOISE_SHORT := 93           ## steps before the "metallic" noise repeats

## How loud each kind of channel is in the mix, per unit of its level
## (the usual straight-line stand-in for the chip's mixer).
const MIX_SQUARE := 0.00752
const MIX_TRIANGLE := 0.00851
const MIX_NOISE := 0.00494
const MIX_SAMPLE := 0.00335
const GAIN := 1.6                 ## overall loudness (a judgement, not measured)
const OFFSET_FOLLOW := 0.004      ## how quickly the steady offset is taken out

class SquareChannel:
	var first := false            ## the first square wave slides down one step further
	var on := true
	var tone := 0                 ## 0-3: which DUTY
	var hold := false             ## no cutting off; the fade starts over when it ends
	var steady := false           ## loudness is `setting`; otherwise the fade's level
	var setting := 0              ## loudness, or the fade's speed
	var fade_start := false
	var fade_divider := 0
	var fade_level := 0
	var sweep_on := false
	var sweep_period := 0
	var sweep_down := false
	var sweep_shift := 0
	var sweep_reload := false
	var sweep_divider := 0
	var period := 0               ## the pitch number (11 bits)
	var length := 0               ## half-frame ticks left
	var phase := 0.0              ## where in its cycle, 0 to 1

class NoiseChannel:
	var on := true
	var hold := false
	var steady := false
	var setting := 0
	var fade_start := false
	var fade_divider := 0
	var fade_level := 0
	var short_mode := false
	var period := 4
	var length := 0
	var place := 0.0              ## where in the noise's sequence

var memory: SoundData             ## where sample bytes are read from (may be null)
var mix_rate := 44100.0

var squares: Array[SquareChannel] = [SquareChannel.new(), SquareChannel.new()]
var noise := NoiseChannel.new()
# triangle
var triangle_on := true
var triangle_control := false
var triangle_reload_value := 0
var triangle_reload := false
var triangle_linear := 0          ## quarter-frame ticks left
var triangle_length := 0
var triangle_period := 0
var triangle_phase := 0.0         ## 0 to 32
# sample player
var sample_rate_index := 0
var sample_loop := false
var sample_level := 0             ## 0-127
var sample_start := 0xC000
var sample_size := 1
var sample_address := 0
var sample_bytes_left := 0
var sample_bits_left := 0
var sample_byte := 0
var sample_clock := 0.0

var _noise_long_sums: PackedInt32Array      ## running count of "on" steps
var _noise_short_sums: PackedInt32Array
var _mix: PackedFloat32Array = PackedFloat32Array()
var _offset := 0.0

func _init(sample_memory: SoundData = null, rate: float = 44100.0) -> void:
	memory = sample_memory
	mix_rate = rate
	squares[0].first = true
	_noise_long_sums = _noise_sums(false, NOISE_LONG)
	_noise_short_sums = _noise_sums(true, NOISE_SHORT)

## The noise comes from a 15-bit shift register: each step, two of its
## bits are compared and the result is fed in at the top. The channel is
## "on" in a step when the bottom bit is 0. The whole sequence is worked
## out once; entry i is how many of the first i steps are "on".
static func _noise_sums(short_mode: bool, steps: int) -> PackedInt32Array:
	var sums := PackedInt32Array()
	sums.resize(steps + 1)
	var register := 1
	var total := 0
	for i in steps:
		sums[i] = total
		if register & 1 == 0:
			total += 1
		var other := (register >> 6) if short_mode else (register >> 1)
		var fed := (register ^ other) & 1
		register = (register >> 1) | (fed << 14)
	sums[steps] = total
	return sums

# -------------------------------------------------------------- registers

func write(register: int, value: int) -> void:
	match register:
		0x4000, 0x4004:
			var square := squares[(register >> 2) & 1]
			square.tone = value >> 6
			square.hold = value & 0x20 != 0
			square.steady = value & 0x10 != 0
			square.setting = value & 0x0F
		0x4001, 0x4005:
			var square := squares[(register >> 2) & 1]
			square.sweep_on = value & 0x80 != 0
			square.sweep_period = (value >> 4) & 7
			square.sweep_down = value & 0x08 != 0
			square.sweep_shift = value & 7
			square.sweep_reload = true
		0x4002, 0x4006:
			var square := squares[(register >> 2) & 1]
			square.period = (square.period & 0x700) | value
		0x4003, 0x4007:
			var square := squares[(register >> 2) & 1]
			square.period = (square.period & 0xFF) | ((value & 7) << 8)
			if square.on:
				square.length = LENGTHS[value >> 3]
			square.fade_start = true
			square.phase = 0.0        # the wave starts over
		0x4008:
			triangle_control = value & 0x80 != 0
			triangle_reload_value = value & 0x7F
		0x400A:
			triangle_period = (triangle_period & 0x700) | value
		0x400B:
			triangle_period = (triangle_period & 0xFF) | ((value & 7) << 8)
			if triangle_on:
				triangle_length = LENGTHS[value >> 3]
			triangle_reload = true
		0x400C:
			noise.hold = value & 0x20 != 0
			noise.steady = value & 0x10 != 0
			noise.setting = value & 0x0F
		0x400E:
			noise.short_mode = value & 0x80 != 0
			noise.period = NOISE_PERIODS[value & 0x0F]
		0x400F:
			if noise.on:
				noise.length = LENGTHS[value >> 3]
			noise.fade_start = true
		0x4010:
			sample_rate_index = value & 0x0F
			sample_loop = value & 0x40 != 0
		0x4011:
			sample_level = value & 0x7F
		0x4012:
			sample_start = 0xC000 + value * 64
		0x4013:
			sample_size = value * 16 + 1
		0x4015:
			squares[0].on = value & 1 != 0
			squares[1].on = value & 2 != 0
			triangle_on = value & 4 != 0
			noise.on = value & 8 != 0
			if not squares[0].on:
				squares[0].length = 0
			if not squares[1].on:
				squares[1].length = 0
			if not triangle_on:
				triangle_length = 0
			if not noise.on:
				noise.length = 0
			if value & 0x10 == 0:
				sample_bytes_left = 0
				sample_bits_left = 0
			elif sample_bytes_left == 0 and sample_bits_left == 0:
				sample_address = sample_start
				sample_bytes_left = sample_size

## True when no channel can be making any sound (so rendering can be skipped).
func silent() -> bool:
	if sample_bytes_left > 0 or sample_bits_left > 0:
		return false
	for square in squares:
		if square.length > 0 and _square_level(square) > 0:
			return false
	if noise.length > 0 and (noise.setting if noise.steady else noise.fade_level) > 0:
		return false
	return triangle_length == 0 or triangle_linear == 0

# ----------------------------------------------------- the chip's own clock

## Four times a frame: the fades and the triangle's counter.
func _quarter_tick() -> void:
	for square in squares:
		if square.fade_start:
			square.fade_start = false
			square.fade_level = 15
			square.fade_divider = square.setting
		elif square.fade_divider == 0:
			square.fade_divider = square.setting
			if square.fade_level > 0:
				square.fade_level -= 1
			elif square.hold:
				square.fade_level = 15
		else:
			square.fade_divider -= 1
	if noise.fade_start:
		noise.fade_start = false
		noise.fade_level = 15
		noise.fade_divider = noise.setting
	elif noise.fade_divider == 0:
		noise.fade_divider = noise.setting
		if noise.fade_level > 0:
			noise.fade_level -= 1
		elif noise.hold:
			noise.fade_level = 15
	else:
		noise.fade_divider -= 1
	if triangle_reload:
		triangle_linear = triangle_reload_value
	elif triangle_linear > 0:
		triangle_linear -= 1
	if not triangle_control:
		triangle_reload = false

## Twice a frame: the counters that cut notes off, and the pitch slides.
func _half_tick() -> void:
	for square in squares:
		if not square.hold and square.length > 0:
			square.length -= 1
		if square.sweep_divider == 0 and square.sweep_on and square.sweep_shift > 0 \
				and square.period >= 8 and _sweep_target(square) <= 0x7FF:
			square.period = _sweep_target(square)
		if square.sweep_divider == 0 or square.sweep_reload:
			square.sweep_divider = square.sweep_period
			square.sweep_reload = false
		else:
			square.sweep_divider -= 1
	if not noise.hold and noise.length > 0:
		noise.length -= 1
	if not triangle_control and triangle_length > 0:
		triangle_length -= 1

## Where a slide would take the pitch number next.
func _sweep_target(square: SquareChannel) -> int:
	var change := square.period >> square.sweep_shift
	if not square.sweep_down:
		return square.period + change
	return maxi(square.period - change - (1 if square.first else 0), 0)

func _square_level(square: SquareChannel) -> int:
	return square.setting if square.steady else square.fade_level

# ---------------------------------------------------------------- samples

## One frame's worth of sound: `count` stereo samples. The chip's clock
## ticks at the start of each quarter of the frame.
func render_frame(count: int) -> PackedVector2Array:
	_mix.resize(count)
	_mix.fill(0.0)
	var from := 0
	for quarter in 4:
		_quarter_tick()
		if quarter & 1 == 1:
			_half_tick()
		var to := count * (quarter + 1) / 4
		var samples := to - from
		_add_square(squares[0], from, samples)
		_add_square(squares[1], from, samples)
		_add_triangle(from, samples)
		_add_noise(from, samples)
		_add_sample(from, samples)
		from = to
	# Take out the steady offset (the channels only ever push one way),
	# and hand the same signal to both ears.
	var out := PackedVector2Array()
	out.resize(count)
	var offset := _offset
	for i in count:
		var value := _mix[i]
		offset += (value - offset) * OFFSET_FOLLOW
		var heard := (value - offset) * GAIN
		out[i] = Vector2(heard, heard)
	_offset = offset
	return out

func _add_square(square: SquareChannel, from: int, count: int) -> void:
	# No sound when its counter has run out, the pitch is too high for
	# the chip, or a slide upwards would take it off the bottom.
	if square.length == 0 or square.period < 8 or _sweep_target(square) > 0x7FF:
		return
	var level := _square_level(square)
	if level == 0:
		return
	# The chip makes one cycle every 16 x (pitch number + 1) clock ticks.
	var step := CPU_HZ / (16.0 * (square.period + 1)) / mix_rate
	var high_share: float = DUTY[square.tone]
	var loud := level * MIX_SQUARE
	var phase := square.phase
	for i in count:
		# The share of this sample's time the wave spends high (which
		# smooths the edges a little compared with just looking once).
		var end := phase + step
		var whole := floorf(end)
		var high := whole * high_share + minf(end - whole, high_share) - minf(phase, high_share)
		_mix[from + i] += high / step * loud
		phase = end - whole
	square.phase = phase

func _add_triangle(from: int, count: int) -> void:
	var moving := triangle_length > 0 and triangle_linear > 0 and triangle_period >= 2
	# One step every (pitch number + 1) clock ticks, 32 steps to a cycle:
	# an octave below a square wave with the same number.
	var step := CPU_HZ / (triangle_period + 1.0) / mix_rate if moving else 0.0
	var phase := triangle_phase
	if not moving:
		# A stopped triangle stays where it is (the offset is removed later).
		var held: float = TRIANGLE_STEPS[int(phase)] * MIX_TRIANGLE
		for i in count:
			_mix[from + i] += held
		return
	for i in count:
		_mix[from + i] += TRIANGLE_STEPS[int(phase)] * MIX_TRIANGLE
		phase += step
		if phase >= 32.0:
			phase -= 32.0
	triangle_phase = phase

func _add_noise(from: int, count: int) -> void:
	if noise.length == 0:
		return
	var level := noise.setting if noise.steady else noise.fade_level
	if level == 0:
		return
	var steps := NOISE_SHORT if noise.short_mode else NOISE_LONG
	var sums := _noise_short_sums if noise.short_mode else _noise_long_sums
	var step := CPU_HZ / noise.period / mix_rate      # sequence steps per sample
	var loud := level * MIX_NOISE
	var place := fmod(noise.place, steps)
	for i in count:
		var end := place + step
		var a := int(place)
		var b := int(end)
		var on_share := 0.0
		if b == a:
			on_share = sums[a + 1] - sums[a]
		elif b <= steps:
			on_share = float(sums[b] - sums[a]) / (b - a)
		else:
			on_share = float(sums[steps] - sums[a] + sums[b - steps]) / (b - a)
		_mix[from + i] += on_share * loud
		place = end
		if place >= steps:
			place -= steps
	noise.place = place

## Samples are stored one bit per step: 1 = two up, 0 = two down.
func _add_sample(from: int, count: int) -> void:
	if sample_bytes_left == 0 and sample_bits_left == 0:
		var held := sample_level * MIX_SAMPLE
		if held != 0.0:
			for i in count:
				_mix[from + i] += held
		return
	var step: float = CPU_HZ / SAMPLE_PERIODS[sample_rate_index] / mix_rate   # bits per sample
	for i in count:
		sample_clock += step
		while sample_clock >= 1.0:
			sample_clock -= 1.0
			_next_sample_bit()
		_mix[from + i] += sample_level * MIX_SAMPLE

func _next_sample_bit() -> void:
	if sample_bits_left == 0:
		if sample_bytes_left == 0:
			if not sample_loop:
				return
			sample_address = sample_start
			sample_bytes_left = sample_size
		sample_byte = memory.byte(sample_address) if memory != null else 0x55
		sample_address += 1
		if sample_address > 0xFFFF:
			sample_address = 0x8000
		sample_bytes_left -= 1
		sample_bits_left = 8
	if sample_byte & 1:
		if sample_level <= 125:
			sample_level += 2
	elif sample_level >= 2:
		sample_level -= 2
	sample_byte >>= 1
	sample_bits_left -= 1
