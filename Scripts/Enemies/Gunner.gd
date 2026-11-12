class_name Gunner
extends OriginalEnemy
## Enemy kind 94, by the original's rules (Research/enemy_92_94.md, read
## from the code at bank 5, $9983).
##
## It walks the way it faces at 1.375 pixels an update, turning round at
## walls, and never turns to the turtle. While he is less than 32 pixels
## above or below it, and for 32 frames in every 64, it stands and fires
## kind 95 the way it faces, one an update, as long as there is room for
## another.

const KINDS := { 0x94: true }
const WALK_SPEED := 352
const DROP_SPEED := 2 * 256
const FALL_PULL := 24
const FIRE_WITHIN := 32           ## the turtle this close in height
const FIRE_BIT := 0x20            ## it fires while this bit of the frame counter is clear
const FIRED_KIND := 0x95
const FIRED_UP := 17
const LAND_UP := -5
const WALKING := 0x1E
const FIRING := 0x1F
const ANIMATIONS := {
	WALKING: [4, [0x97, 0x98, 0x99], LOOPS],
	FIRING: [4, [0x97, 0x9A], ENDS],
}

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x94

func _first_animation() -> int:
	return WALKING

func _stand_in_box() -> Rect2:
	return Rect2(-4, -32, 8, 30)

func _act() -> void:
	if busy:
		# Dropping off a ledge.
		speed_y += FALL_PULL
		land(LAND_UP)
		return
	if not something_behind(12, -1):
		if launch(DROP_SPEED):
			set_animation(WALKING)
		return
	if turtle_down() & 255 < FIRE_WITHIN and counter() & FIRE_BIT == 0:
		set_animation(FIRING)   # afresh every update
		stop()
		var shot := throw_object(Missile.new(), FIRED_KIND, 0, -FIRED_UP)
		if shot != null:
			shot.tick()
		return
	set_off(WALK_SPEED)
	if animation != WALKING:
		set_animation(WALKING)
	if wall_ahead(12, -12):
		turn_round()
