class_name Swooper
extends OriginalEnemy
## Enemy kind 85: it flies level and, when the turtle is at the right
## slant from it, dives (or climbs) at him and keeps going. Read from the
## code at bank 5, $94A5 and $9726 (Research/enemy_85.md).
##
## - Setting off, on its first update: to the right if the screen is
##   scrolling left, else to the left, at 1.375 pixels an update.
## - Each update after, while it flies level: how far the turtle is across
##   and down is measured. The distance down picks a band (128 and more,
##   112, 96, 80, 64, 48, 32; nearer than 32 it does nothing) and the
##   band a slice of 8 pixels across (56 to 63 for the first band, down to
##   8 to 15 for the last). With the turtle in that slice it goes: 5.5
##   pixels an update downward if he is below, 6.5 upward if he is above,
##   and 1.75 across the way it faces.
## - Once it has a whole pixel of speed up or down it does nothing more.

const KINDS := { 0x85: true }
const SPEED := 352
const DOWN_BANDS := [0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20]
const ACROSS_EDGES := [0x40, 0x38, 0x30, 0x28, 0x20, 0x18, 0x10, 0x08]
const DIVE_DOWN := 0x0580
const DIVE_UP := -0x0680
const DIVE_ACROSS := 0x01C0
const FLY := 0x0D
const CLIMBING := 0x0E
const DIVING := 0x0F
const ANIMATIONS := {
	FLY: [4, [0x8C, 0x8D], LOOPS],
	CLIMBING: [8, [0x8F], LOOPS],
	DIVING: [8, [0x8E], LOOPS],
}

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x85

func _first_animation() -> int:
	return FLY

func _stand_in_box() -> Rect2:
	return Rect2(-10, -16, 20, 14)

func _act() -> void:
	if not busy:
		busy = true
		facing_left = scroll_step >= 0
		go_forward(SPEED)
		return
	if (speed_y >> 8) != 0:
		return
	var across := turtle_across() & 255
	var down := turtle_down() & 255
	for band in DOWN_BANDS.size():
		if down >= DOWN_BANDS[band]:
			if across < ACROSS_EDGES[band] and across >= ACROSS_EDGES[band + 1]:
				var above := turtle_is_above()
				speed_y = DIVE_UP if above else DIVE_DOWN
				set_animation(CLIMBING if above else DIVING)
				go_forward(DIVE_ACROSS)
			return
