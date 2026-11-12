class_name Flier
extends OriginalEnemy
## Enemy kinds 81 and 96 (and 8E and 8F, which the original sends to the
## same routine): they fly level and turn round at walls. Read from the
## code at bank 5, $97D7, $99E5 and $9833 (Research/enemy_81_8D_86.md).
##
## On its first update it picks its way from the screen: to the right if
## the screen is scrolling left just then, otherwise to the left.

const KINDS := {
	0x81: { "first": 0x02 },
	0x8E: { "first": 0x00 },
	0x8F: { "first": 0x08 },
	0x96: { "first": 0x21 },
}
const SPEED := 640                ## 2.5 pixels an update
const WALL_REACH := 10            ## a wall this far ahead (at 10, 14 or 6 up) turns it round
const ANIMATIONS := {
	0x02: [4, [0x9F, 0xA0], LOOPS],
	0x00: [8, [0x00], LOOPS],
	0x08: [3, [0x8C, 0x8D, 0x8E, 0x8F], LOOPS],
	0x21: [4, [0x95, 0x96], LOOPS],
}

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x81

func _first_animation() -> int:
	return KINDS.get(kind, KINDS[0x81]).first

func _stand_in_box() -> Rect2:
	return Rect2(-6, -10, 12, 8)

func _act() -> void:
	if not busy:
		busy = true
		facing_left = scroll_step >= 0
		go_forward(SPEED)
	elif wall_ahead(WALL_REACH, -10):
		turn_round()
