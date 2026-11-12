class_name Soldier
extends OriginalEnemy
## Enemy kind 98, the foot soldier, by the original's own rules
## (Research/enemy_98.md, read from the code at bank 5, $864B).
##
## Standing on a floor it looks how far away the turtle is across:
##   96 pixels or more  - it jumps towards him;
##   64 to 95           - it throws a star (kind 99), three times in four;
##   24 to 63           - it walks at him, turning round at walls;
##   under 24           - it punches or kicks.
## Hit, it stands stunned for 16 updates and then jumps.

const KIND := 0x98
const KINDS := { 0x98: true }
const WALK_SPEED := 320           ## 1.25 pixels an update
const JUMP_SPEED := -1536         ## 6 pixels an update, upward
const DROP_SPEED := 2             ## whole pixels an update when the floor ends
const FALL_PULL := 36             ## added each update while it drops off a ledge
const JUMP_FROM := 96             ## jumps from this far or further
const THROW_FROM := 64            ## throws from this far, up to JUMP_FROM
const ATTACK_WITHIN := 24         ## punches and kicks nearer than this
const STUN_TICKS := 16
const THROW_UNTIL := 0xC0         ## it throws while the frame counter is below this, else walks
const PUNCH_FROM := 0x60          ## frame counter at or above this: the long punch, else the short one
const STAR_KIND := 0x99
const STAR_UP := 36               ## a star starts this far above the soldier's position

const WALK := 0x90
const KICK_HIGH := 0x91           ## the four attacks; the first two only with a special weapon chosen
const KICK_LOW := 0x92
const PUNCH_LONG := 0x93
const PUNCH_SHORT := 0x94
const THROW := 0x95
const THROW_SPECIAL := 0x96
const SPIN := 0x97
const STUNNED := 0x98
const RISE := 0xAB
## number -> [updates per picture, pictures, what happens at the end]
const ANIMATIONS := {
	WALK: [3, [0x80, 0x81, 0x82, 0x81], ENDS],
	KICK_HIGH: [16, [0x8A], ENDS],
	KICK_LOW: [6, [0x8A, 0x8B, 0x8C, 0x8A], ENDS],
	PUNCH_LONG: [6, [0x82, 0x86, 0x87, 0x82], ENDS],
	PUNCH_SHORT: [6, [0x82, 0x83, 0x82], ENDS],
	THROW: [4, [0x82, 0x84, 0x85], ENDS],
	THROW_SPECIAL: [4, [0x8A, 0x88, 0x89], ENDS],
	SPIN: [1, [0x8D, 0x8E, 0x90, 0x8F], LOOPS],
	STUNNED: [8, [0x91], LOOPS],
	RISE: [8, [0x80], LOOPS],
}

enum Mode { GROUND, JUMP, DROP, POSE }

var mode := Mode.GROUND
var stun_ticks := 0
## True while the turtle has a special weapon chosen (the original's RAM
## $5B). The remake has no special weapons yet, so this stays false.
var special_weapon_chosen := false

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return KIND

func _first_animation() -> int:
	return WALK

func _act() -> void:
	if busy:
		match mode:
			Mode.JUMP:
				_jumping()
			Mode.DROP:
				_dropping()
			Mode.POSE:
				# A throw, punch or kick: nothing more until its animation ends.
				if animation_ended():
					busy = false
					anim_step = 0
		return
	if blinking:
		_stunned()
		return
	if not something_behind(12, -1):
		# No floor under its back foot: it drops.
		set_fall_pixels(DROP_SPEED)
		stop_across()
		_begin(Mode.DROP)
		return
	var across := face_turtle()
	if across >= JUMP_FROM:
		_jump()
	elif across >= THROW_FROM and counter() < THROW_UNTIL:
		set_animation(THROW_SPECIAL if special_weapon_chosen else THROW)
		_begin(Mode.POSE)   # it is not stopped: if it was walking it slides on
		_throw_star()
	elif across < ATTACK_WITHIN:
		if special_weapon_chosen:
			set_animation(KICK_HIGH if counter() & 8 != 0 else KICK_LOW)
		else:
			set_animation(PUNCH_LONG if counter() >= PUNCH_FROM else PUNCH_SHORT)
		_begin(Mode.POSE)
		stop()
	else:
		# Walking. The speed is only set when the walking animation starts,
		# so a soldier already showing it (after a jump, say) walks on the spot.
		if animation != WALK:
			set_animation(WALK)
			set_off(WALK_SPEED)
		if wall_ahead(24, -16):
			turn_round()

func _begin(new_mode: Mode) -> void:
	mode = new_mode
	busy = true

## Hit: it stands in its stunned pose for 16 updates, then jumps.
func _stunned() -> void:
	if animation != STUNNED:
		stun_ticks = STUN_TICKS
		set_animation(STUNNED)
		stop()
		return
	stun_ticks = (stun_ticks - 1) & 255
	if stun_ticks == 0:
		_jump()

func _jump() -> void:
	_begin(Mode.JUMP)
	speed_y = JUMP_SPEED
	set_off(WALK_SPEED)
	if wall_ahead(24, -16):
		turn_round()

func _jumping() -> void:
	fly(0)
	if speed_y < 0:
		# Rising: the spin for the last three pixels a second of rise. The
		# original sets the animation afresh every update, so it stays on
		# its first picture until the rise is over.
		set_animation(SPIN if (speed_y >> 8) >= -3 else RISE)
		return
	if (speed_y >> 8) >= 2:
		set_animation(WALK)
	land()

func _dropping() -> void:
	speed_y += FALL_PULL
	if something_behind(12, 6):
		land()

## A star starts 36 above the soldier, if one of the four places for
## thrown things is free and it would not start inside a wall.
func _throw_star() -> void:
	var star := throw_object(Star.new(), STAR_KIND, 0, -STAR_UP)
	if star != null:
		star.tick()
