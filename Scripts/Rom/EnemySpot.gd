class_name EnemySpot
extends RefCounted
## One place where the original puts an enemy (or another moving object),
## as read from the ROM. See Research/enemy_placement.md.

var position := Vector2.ZERO   ## the object's own position value, in room pixels
var slot := 0                  ## which of the room's enemy kinds stands here (0 to 5)
var kinds := PackedInt32Array()  ## the kind number for each of the room's 4 enemy line-ups
var kind := -1                 ## the kind in the first line-up (the one a new game uses)
var hit_points := 1            ## that kind's starting hit points
var first_animation := 0       ## the animation number that kind starts with
var touch_damage := 0          ## energy the turtle loses on touching that kind (he has 128)
var half_size := Vector2i.ZERO  ## half the width and height of that kind's hit box, from the ROM

## The same place's enemy, somewhere else.
func moved_to(where: Vector2) -> EnemySpot:
	var copy := EnemySpot.new()
	copy.position = where
	copy.slot = slot
	copy.kinds = kinds
	copy.kind = kind
	copy.hit_points = hit_points
	copy.first_animation = first_animation
	copy.touch_damage = touch_damage
	copy.half_size = half_size
	return copy

func _to_string() -> String:
	return "Kind %02X at %s, %d hit points" % [kind, position, hit_points]
