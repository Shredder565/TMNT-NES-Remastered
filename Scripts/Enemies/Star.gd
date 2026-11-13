class_name Star
extends OriginalEnemy
## Object kind 99: the star a foot soldier throws (Research/enemy_98.md,
## read from the code at bank 5, $8708).
##
## On its first update it turns towards the turtle and sets off at 3 pixels
## an update; after that it flies level until it meets a wall, leaves the
## screen, hits the turtle or is hit by his weapon.

const KIND := 0x99
const SPEED := 768
const SPIN := 0x99
const ANIMATIONS := { SPIN: [8, [0x92, 0x93], LOOPS] }

func _animations() -> Dictionary:
	return ANIMATIONS

func _stand_in_box() -> Rect2:
	return Rect2(-2, -2, 4, 1)

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	super.setup_at(spot_kind, where, in_room, sprite_set, turtle)
	health = 1
	touch_damage = levels.touch_damage(KIND) if levels != null else 9
	set_animation(SPIN)

func _act() -> void:
	if not busy:
		busy = true
		facing_left = turtle_x() < whole_x()
		go_forward(SPEED)
	elif kind_at(0, -4) == RoomData.KIND_SOLID:
		remove()

## A star that hits him is used up (the original's list at bank 6, $9910).
func _touch(turtle: Turtle) -> void:
	if turtle.touched_by(self, touch_damage):
		remove()
