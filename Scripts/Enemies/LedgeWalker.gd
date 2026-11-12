class_name LedgeWalker
extends OriginalEnemy
## Enemy kinds 8D and 84: they walk the way they face, turn round at walls
## and walk straight off ledges. Read from the code at bank 5, $978E,
## $9977, $9851 and $9870 (Research/enemy_81_8D_86.md). They take no
## notice of the turtle.

const KINDS := {
	0x8D: { "speed": 352, "first": 0x01 },   # 1.375 pixels an update
	0x84: { "speed": 768, "first": 0x1C },   # 3 pixels an update
}
const DROP_SPEED := 2             ## whole pixels an update when the floor ends
const FALL_PULL := 24             ## added each update while it falls
const WALL_REACH := 12            ## a wall this far ahead (at 12, 14 or 6 up) turns it round
const LAND_UP := -5               ## it lands when the place 5 above it is in a floor
const ANIMATIONS := {
	0x01: [3, [0x9D, 0x9E], LOOPS],
	0x1C: [2, [0x90, 0x91], LOOPS],
}

var falling := false

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x8D

func _first_animation() -> int:
	return KINDS.get(kind, KINDS[0x8D]).first

func _stand_in_box() -> Rect2:
	return Rect2(-7, -13, 14, 11)

## Kind 8D's sprite map names its two pictures by hand.
func _frame_name() -> String:
	if kind == 0x8D:
		return "walk1" if picture == 0x9D else "walk2"
	return super._frame_name()

func _act() -> void:
	if not busy:
		# Setting off, at the start and again after every landing.
		busy = true
		falling = false
		go_forward(KINDS.get(kind, KINDS[0x8D]).speed)
	elif falling:
		speed_y += FALL_PULL
		land(LAND_UP)
	elif not something_behind(12, -1):
		falling = true
		set_fall_pixels(DROP_SPEED)
		stop_across()
	elif wall_ahead(WALL_REACH, -12):
		turn_round()
