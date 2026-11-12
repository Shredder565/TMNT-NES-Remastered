class_name CeilingCrawler
extends OriginalEnemy
## Enemy kind 86: it crawls along ceilings and swoops at the turtle. Read
## from the code at bank 5, $982B, $987C, $98D7 and $9908
## (Research/enemy_81_8D_86.md).
##
## - Crawling: 1.375 pixels an update, turning at walls. Where the ceiling
##   ends behind it, it rises until it finds one.
## - With the turtle less than 40 pixels away across it swoops: down at 6
##   pixels an update, slowing by 45 each update, so it turns and climbs
##   back to the ceiling, still moving sideways. A floor stops the dive; a
##   wall ahead sends it straight back up.

const KINDS := { 0x86: true }
const SPEED := 352
const RISE_SPEED := -3            ## whole pixels an update, looking for a ceiling
const RISE_PULL := 24             ## it rises faster by this each update
const SWOOP_WITHIN := 40
const SWOOP_SPEED := 6            ## whole pixels an update, downward
const SWOOP_PULL := 45
const CEILING_UP := -24           ## it hangs with the ceiling this far above its position
const HANG := 0x06
const DIVE := 0x07
const ANIMATIONS := {
	HANG: [8, [0x97, 0x98], LOOPS],
	DIVE: [16, [0x99], LOOPS],
}

enum Mode { CRAWL, RISE, SWOOP }

var mode := Mode.CRAWL

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x86

func _first_animation() -> int:
	return HANG

func _stand_in_box() -> Rect2:
	return Rect2(-12, -12, 24, 10)

func _act() -> void:
	if not busy:
		# Setting off, at the start and whenever it has found a ceiling:
		# to the right if the screen is scrolling left, else to the left.
		busy = true
		mode = Mode.CRAWL
		facing_left = scroll_step >= 0
		go_forward(SPEED)
		return
	match mode:
		Mode.CRAWL:
			_crawl()
		Mode.RISE:
			_rise()
		Mode.SWOOP:
			_swoop()

func _crawl() -> void:
	var ahead := -12 if facing_left else 12
	if kind_at(-ahead, -34) == RoomData.KIND_EMPTY:
		_start_rise()   # the ceiling has ended behind it
	elif wall_at(ahead, -13):
		facing_left = not facing_left
		go_forward(SPEED)
	elif turtle_across() < SWOOP_WITHIN:
		set_animation(DIVE)
		mode = Mode.SWOOP
		set_fall_pixels(SWOOP_SPEED)

func _start_rise() -> void:
	mode = Mode.RISE
	set_fall_pixels(RISE_SPEED)
	stop_across()

func _rise() -> void:
	speed_y -= RISE_PULL
	if not wall_at(0, CEILING_UP):
		return
	for i in 23:
		sub_y += 256
		if not wall_at(0, CEILING_UP):
			break
	busy = false
	stop_down()

func _swoop() -> void:
	speed_y -= SWOOP_PULL
	if wall_at(-10 if facing_left else 10, -16):
		set_animation(HANG)
		_start_rise()
	elif speed_y >= 0:
		if wall_at(0, 0):
			stop_down()   # the floor
	elif wall_at(0, CEILING_UP):
		# Back at the ceiling.
		for i in 64:
			sub_y += 256
			if not wall_at(0, CEILING_UP):
				break
		set_animation(HANG)
		mode = Mode.CRAWL
		stop_down()
