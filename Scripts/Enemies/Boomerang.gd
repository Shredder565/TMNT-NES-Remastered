class_name Boomerang
extends OriginalEnemy
## Object kind 93, thrown by kind 92 (Research/enemy_92_94.md, read from
## the code at bank 5, $92F3).
##
## It sets off at 4 pixels an update and is pulled back by 16/256 of a
## pixel each update, so it slows, turns and comes back. After its first
## 6 updates it is gone as soon as it is within 4 pixels (across) of the
## one that threw it. It is also gone when it hits the turtle.

const KIND := 0x93
const PULL := 16
const CATCH_WITHIN := 4
const SPIN := 0x89
const ANIMATIONS := { SPIN: [2, [0x91, 0x92, 0x93, 0x94], LOOPS] }

var thrower: OriginalEnemy
var grace := 0

func _animations() -> Dictionary:
	return ANIMATIONS

func _stand_in_box() -> Rect2:
	return Rect2(-3, -14, 6, 12)

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	super.setup_at(spot_kind, where, in_room, sprite_set, turtle)
	health = levels.hit_points(kind) if levels != null else 7
	touch_damage = levels.touch_damage(KIND) if levels != null else 6
	set_animation(SPIN)

func _act() -> void:
	speed_x += PULL if facing_left else -PULL
	if grace > 0:
		grace -= 1
	elif is_instance_valid(thrower) and not thrower.gone and absi(thrower.whole_x() - whole_x()) < CATCH_WITHIN:
		remove()

func _touch(turtle: Turtle) -> void:
	if turtle.touched_by(self, touch_damage):
		remove()
