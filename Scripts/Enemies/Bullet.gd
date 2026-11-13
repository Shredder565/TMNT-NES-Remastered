class_name Bullet
extends OriginalEnemy
## Object kind 19: what kind 71 fires (bank 5, $B3E2, then $8CFE). On its
## first update it sets off the way it faces at 5 pixels an update; after
## that it flies level until the place 4 above it is a wall, or it leaves
## the screen. One hit of the weapon destroys it.

const KIND := 0x19
const SPEED := 1280
const FLY := 0x4A
const ANIMATIONS := { FLY: [16, [0x8C], LOOPS] }

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return KIND

func _stand_in_box() -> Rect2:
	return Rect2(-3, -3, 6, 1)

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	super.setup_at(spot_kind, where, in_room, sprite_set, turtle)
	health = 1
	touch_damage = levels.touch_damage(KIND) if levels != null else 9
	set_animation(FLY)

func _act() -> void:
	if not busy:
		busy = true
		go_forward(SPEED)
	elif kind_at(0, -4) == RoomData.KIND_SOLID:
		remove()
