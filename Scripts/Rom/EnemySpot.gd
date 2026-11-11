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

func _to_string() -> String:
	return "Kind %02X at %s, %d hit points" % [kind, position, hit_points]
