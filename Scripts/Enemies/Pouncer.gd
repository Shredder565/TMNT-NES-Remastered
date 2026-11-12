class_name Pouncer
extends OriginalEnemy
## Enemy kind 92, by the original's rules (Research/enemy_92_94.md, read
## from the code at bank 5, $9288).
##
## It walks at the turtle at 1.75 pixels an update. From less than 40
## pixels away it leaps. Further away it now and then (one update in 64,
## by the original's one unpredictable number) throws kind 93, which comes
## back to it.

const KINDS := { 0x92: true }
const WALK_SPEED := 448
const LEAP_WITHIN := 40
const LEAP_SPEED := -3 * 256
const DROP_SPEED := 3 * 256
const FALL_PULL := 36
const THROW_ODDS := 64
const THROWN_KIND := 0x93
const THROWN_UP := 34
const THROWN_SPEED := 1024        ## 4 pixels an update
const THROWN_GRACE := 6           ## updates before it can be caught again
const WALKING := 0x85
const THROWING := 0x86
const ARM_OUT := 0x8A
const IN_AIR := 0x88
const ANIMATIONS := {
	WALKING: [4, [0x8B, 0x8C, 0x8D], LOOPS],
	THROWING: [4, [0x8C, 0x8E, 0x8F], GOES_ON + ARM_OUT],
	ARM_OUT: [4, [0x8F], LOOPS],
	IN_AIR: [12, [0x90], ENDS],
}

enum Mode { LEAP, DROP }

var mode := Mode.LEAP

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x92

func _first_animation() -> int:
	return WALKING

func _stand_in_box() -> Rect2:
	return Rect2(-4, -34, 8, 32)

func _act() -> void:
	if busy:
		if mode == Mode.LEAP:
			fly(1)
			if land():
				anim_step = 0
		else:
			speed_y += FALL_PULL
			if something_behind(12, 4):
				land()
		return
	if not something_behind(0, -1):
		if launch(DROP_SPEED):
			mode = Mode.DROP
			set_animation(IN_AIR)
		stop_across()
		return
	if face_turtle() < LEAP_WITHIN:
		# The leap keeps whatever sideways speed it had.
		if launch(LEAP_SPEED):
			mode = Mode.LEAP
			set_animation(IN_AIR)
		return
	if chance() % THROW_ODDS == 0:
		set_animation(THROWING)
		stop()
		var thrown := throw_object(Boomerang.new(), THROWN_KIND, 0, -THROWN_UP) as Boomerang
		if thrown != null:
			thrown.thrower = self
			thrown.go_forward(THROWN_SPEED)
			thrown.grace = THROWN_GRACE
			thrown.tick()
			return
	set_off(WALK_SPEED)
	if animation != WALKING:
		set_animation(WALKING)
	if wall_ahead(20, -36):
		stop_across()
