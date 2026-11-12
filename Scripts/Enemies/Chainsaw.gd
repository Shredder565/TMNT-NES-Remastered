class_name Chainsaw
extends OriginalEnemy
## Enemy kind 91, the one with the chainsaw, by the original's rules
## (Research/enemy_49_91.md, read from the code at bank 5, $91C6).
##
## It takes no notice of where the turtle is. It walks for 31 updates at
## 1.75 pixels an update, turning round at walls and at the screen's
## sides, then swings its saw, and so on. While it blinks from a hit it
## stands still.

const KINDS := { 0x91: true }
const WALK_SPEED := 448
const DROP_SPEED := 3 * 256       ## when the floor ends
const FALL_PULL := 36
const SWING_EVERY := 32           ## updates
const SIDE_MARGIN := 24           ## it turns in from this close to the screen's sides
const WALKING := 0x80
const FALLING := 0x81
const SWING_A := 0x82
const SWING_B := 0x83
const HURT := 0x84
const ANIMATIONS := {
	WALKING: [4, [0x80, 0x88, 0x81, 0x89], LOOPS],
	FALLING: [4, [0x81, 0x89], LOOPS],
	SWING_A: [4, [0x89, 0x82, 0x8B, 0x86, 0x8F, 0x8B, 0x82, 0x81], ENDS],
	SWING_B: [4, [0x81, 0x85, 0x8E, 0x83, 0x84, 0x8D, 0x84], ENDS],
	HURT: [4, [0x87, 0x8A], LOOPS],
}

enum Mode { SWING, DROP }

var mode := Mode.SWING
var timer := 0

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x91

func _first_animation() -> int:
	return FALLING

func _stand_in_box() -> Rect2:
	return Rect2(-4, -34, 8, 32)

func _act() -> void:
	if busy:
		if mode == Mode.SWING:
			if animation_ended():
				busy = false
				anim_step = 0
		else:
			speed_y += FALL_PULL
			if something_behind(12, 4):
				land()
		return
	if blinking:
		set_animation(HURT)   # afresh every update, so it holds the first picture
		stop()
		return
	if not something_behind(12, -1):
		if launch(DROP_SPEED):
			mode = Mode.DROP
			set_animation(FALLING)
		stop_across()
		return
	timer = (timer + 1) & 255
	if timer % SWING_EVERY == 0:
		stop_across()
		set_animation(SWING_A if counter() & 2 == 0 else SWING_B)
		mode = Mode.SWING
		busy = true
		return
	if animation != WALKING:
		# Starting to walk: away from the side of the screen if it is close to one.
		var across := (whole_x() - int(_corner().x)) & 255
		if not facing_left and across >= 256 - SIDE_MARGIN:
			facing_left = true
		elif facing_left and across < SIDE_MARGIN:
			facing_left = false
		set_off(WALK_SPEED)
		set_animation(WALKING)
	if wall_ahead(20, -36):
		turn_round()
