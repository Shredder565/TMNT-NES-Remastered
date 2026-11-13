class_name Bystander
extends OriginalEnemy
## Object kind 11: it stands on the ledge while kind 70 is fought (bank 5,
## $AAFF puts it there; its own routine at $82D0 does nothing). It hurts
## on touch like an enemy, and the weapon passes through it: its hit
## points are 255, which the original's hit code takes for "cannot be hit"
## (bank 6, $992E).

const KIND := 0x11
const STAND := 0x46
const ANIMATIONS := { STAND: [16, [0x8A], LOOPS] }

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return KIND

func _stand_in_box() -> Rect2:
	return Rect2(-8, -30, 16, 28)

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	super.setup_at(spot_kind, where, in_room, sprite_set, turtle)
	health = 255
	touch_damage = levels.touch_damage(KIND) if levels != null else 19
	moves = false
	set_animation(STAND)

func take_hit(_amount: int) -> void:
	pass
