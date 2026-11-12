class_name Door
extends RefCounted
## One doorway, as the original stores it: where it is and where it leads.
## Manholes, building doors and the ladders that climb out of a sewer are all
## "doors" to the game. See Research/doors.md.

var screen := 0               ## which screen of its room the doorway is on
var position := Vector2.ZERO  ## the doorway's own spot, in room pixels
var to_room := false          ## true: into a side-scrolling room. false: out to the overworld
var to_area := 0              ## the room's number (for the overworld: the world's number)
var arrive := Vector2.ZERO    ## where the turtle's centre appears on the other side
var arrive_camera := Vector2.ZERO  ## the corner of the screen there (the record keeps it apart from his place on the screen)

func _to_string() -> String:
	return "Door at %s -> %s %d at %s" % [position, "room" if to_room else "overworld", to_area, arrive]
