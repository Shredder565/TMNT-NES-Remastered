class_name Missile
extends OriginalEnemy
## Things enemies throw or fire that simply fly level until they leave the
## screen: kind 4A (thrown by 49) and kind 95 (fired by 94). Read from
## the code at bank 5, $927C and $99D9. Walls do not stop them. They hurt
## on touch and fly on; the turtle's weapon can destroy them.

const KINDS := {
	0x4A: { "speed": 832, "first": 0x37 },   # 3.25 pixels an update
	0x95: { "speed": 640, "first": 0x20 },   # 2.5 pixels an update
}
const ANIMATIONS := {
	0x37: [8, [0x96], LOOPS],
	0x20: [8, [0x9B], LOOPS],
}

func _animations() -> Dictionary:
	return ANIMATIONS

func _stand_in_box() -> Rect2:
	return Rect2(-3, -14, 6, 12)

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	super.setup_at(spot_kind, where, in_room, sprite_set, turtle)
	health = levels.hit_points(kind) if levels != null else (9 if kind == 0x4A else 24)
	touch_damage = levels.touch_damage(kind) if levels != null else 1
	set_animation(KINDS[kind].first)

func _act() -> void:
	if not busy:
		busy = true
		go_forward(KINDS[kind].speed)

func _touch(turtle: Turtle) -> void:
	turtle.touched_by(self, touch_damage)
