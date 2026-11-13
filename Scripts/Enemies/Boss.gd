class_name Boss
extends OriginalEnemy
## What the original's bosses (object kinds 70 to 7F) have in common,
## written from Research/encounters.md. They are objects like any other:
## the same update, the same touch and weapon tests, a box that follows
## the animation. On top of that (bank 5, $AA96):
## - the kind's routine goes by a state number;
## - after it, in a room, the boss is put back between 24 and 232 across
##   the screen and no higher than 32 down it;
## - a hit only makes it blink; at no hit points left it becomes a puff.
## `defeated` tells the room scene, which runs what comes after.

signal defeated

const KEPT_LEFT := 0x18
const KEPT_RIGHT := 0xE8
const KEPT_TOP := 0x20
const TURN_LEFT := 0x19           ## walking: it turns round left of this across the screen
const TURN_RIGHT := 0xE8          ## ...or at this or more
const WALL_LOOK := 12             ## a wall this far ahead, 37 up, stops it
const WALL_UP := -37
const FLIGHT := 6                 ## the numbers its jumps fall by (OriginalEnemy.FLIGHTS)
const LAND_UP := -5

var full_health := 1
var state := 0
var state_ticks := 0              ## the original's timer, set to 0 by most changes of state

func _stand_in_box() -> Rect2:
	return Rect2(-8, -30, 16, 28)

## The kind's routine for the state it is in.
func _run_state() -> void:
	pass

func _act() -> void:
	_run_state()
	if not view_corner.is_valid():
		return
	var corner := _corner()
	var across := whole_x() - int(corner.x)
	if across < KEPT_LEFT:
		sub_x += (KEPT_LEFT - across) * 256
	elif across >= KEPT_RIGHT:
		sub_x -= (across - KEPT_RIGHT) * 256
	var down := whole_y() - int(corner.y)
	if down < KEPT_TOP:
		sub_y += (KEPT_TOP - down) * 256

## Changes state and starts the timer again.
func go(next: int) -> void:
	state = next
	state_ticks = 0

## Its place across the screen, and the turtle's, as the original compares them.
func screen_x() -> int:
	return (whole_x() - int(_corner().x)) & 255

func turtle_screen_x() -> int:
	return (turtle_x() - int(_corner().x)) & 255

## How far the turtle is across, whichever side.
func gap() -> int:
	return absi(screen_x() - turtle_screen_x())

## Turns to the turtle (or away from him); level with him counts as his
## being to the left.
func face(away := false) -> void:
	facing_left = (screen_x() >= turtle_screen_x()) != away

## Anything at all 12 ahead (the way it moves) and 37 up stops it.
func stop_at_wall() -> void:
	if kind_at(-WALL_LOOK if speed_x < 0 else WALL_LOOK, WALL_UP) != RoomData.KIND_EMPTY:
		stop_across()

## Near either side of the screen it turns round.
func turn_at_edge() -> void:
	var across := screen_x()
	if across < TURN_LEFT or across >= TURN_RIGHT:
		turn_round()

## Is the turtle off the ground? (Bit 4 of his flags in the original.)
func turtle_in_air() -> bool:
	var turtle := target as Turtle
	return turtle != null and not turtle.on_floor() and turtle.state != Turtle.State.CLIMB

func take_hit(amount: int) -> void:
	var was_alive := health > 0
	super.take_hit(amount)
	if was_alive and health <= 0:
		_beaten()
		defeated.emit()

## What goes with it when it is beaten.
func _beaten() -> void:
	pass
