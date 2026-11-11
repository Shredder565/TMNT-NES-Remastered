class_name Encounter
extends RefCounted
## One entry of the ROM's encounter table: something that appears when the
## camera reaches a certain place in a room. World 1's two bosses are
## entries of this table. See Research/encounters.md.

var row := 0                   ## the camera must be on this row of screens
var column := 0                ## 0: the camera must be at the room's left end.
                               ## Otherwise it must arrive at this screen from the left.
var position := Vector2.ZERO   ## where the object appears, in room pixels
var slot := 0                  ## the entry's slot byte, as stored
var is_boss := false           ## the entry names a line-up of its own (bosses do)
var kind := -1                 ## the object kind, where it could be worked out
var hit_points := 1
var touch_damage := 0

## The camera X the original waits for: 3 to 5 pixels short of the screen.
func camera_x() -> float:
	return 0.0 if column == 0 else column * 256.0 - 4.0

func _to_string() -> String:
	return "Kind %02X at %s when the camera reaches X %d" % [kind, position, camera_x()]
