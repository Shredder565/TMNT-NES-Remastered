class_name Bebop
extends Boss
## Object kind 70: the boss met in world 1's second room. It looks like
## Bebop.
##
## This follows the original's own routine for it (bank 5, $AADB; see
## Research/encounters.md), step for step, and was checked against
## emulator recordings:
## - It walks at 2 pixels an update. Every 48 updates of walking it turns
##   to face the turtle again. At 25 pixels from the screen's left edge or
##   24 from its right it turns round; a wall just ahead stops it.
## - Closer than 16 pixels to the turtle (sideways only) it stops for 12
##   updates, then stands.
## - 16 to 35 pixels away it jumps, but only during 16 frames of every 64.
## - Standing, it waits for the game's frame counter to come round (every
##   32 frames) and then walks at the turtle or away from him, by turns:
##   64 frames of "at him", 64 of "away".
## - A jump ends in a walk away from him.
##
## One rule is left out: walking 48 updates while further than 35 pixels
## away, the original jumps instead of turning if one bit of the turtle's
## state is set, and what that bit means is not known.

const KIND := 0x70
const WALK_SPEED := 512          ## 2 px per update
const GRAVITY := 78              ## added to the fall speed every update
const JUMP_SPEED := -1280        ## upward speed at the start of a jump
const SINK := 4.0                ## rides 4 pixels below the floor's top edge
const BUMP_DISTANCE := 16.0
const JUMP_DISTANCE := 36.0
const BUMP_TICKS := 12
const REFACE_TICKS := 48
const EDGE_LEFT := 25.0          ## screen X below this turns it round
const EDGE_RIGHT := 232.0        ## and this or more
const WALL_LOOK := 12.0
const WALL_HEIGHT := 37.0

enum State { FACE, AWAY, WALK, BUMP, STAND, JUMP }

var state := State.FACE
var state_ticks := 0
var speed_x := 0
var fall_speed := 0
var clock := 0x10                ## stands in for the game's frame counter

func _init() -> void:
	kind = KIND
	health = 72
	full_health = 72
	touch_damage = 19

func _wall_ahead() -> bool:
	var ahead := position.x + (WALL_LOOK if speed_x >= 0 else -WALL_LOOK)
	return ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - WALL_HEIGHT)

func tick() -> void:
	clock += TICK_FRAMES
	state_ticks += 1
	match state:
		State.FACE, State.AWAY:
			var gap := _gap()
			direction = 1 if gap > 0.0 else -1
			if state == State.AWAY:
				direction = -direction
			speed_x = direction * WALK_SPEED
			_go(State.WALK)
		State.WALK:
			if _wall_ahead():
				speed_x = 0
			var across := position.x - view_left
			if across < EDGE_LEFT or across >= EDGE_RIGHT:
				direction = -direction
				speed_x = -speed_x
			var distance := absf(_gap())
			if distance < BUMP_DISTANCE:
				_go(State.BUMP)
			elif distance < JUMP_DISTANCE:
				if clock & 0x30 == 0:
					fall_speed = JUMP_SPEED
					_go(State.JUMP)
			elif state_ticks >= REFACE_TICKS:
				_go(State.FACE)
		State.BUMP:
			speed_x = 0
			if state_ticks >= BUMP_TICKS:
				_go(State.STAND)
		State.STAND:
			speed_x = 0
			if (clock >> 1) & 0x0F == 0:
				_go(State.FACE if clock & 0x40 != 0 else State.AWAY)
		State.JUMP:
			fall_speed += GRAVITY
			if _wall_ahead():
				speed_x = 0
	position.x += speed_x / 256.0
	if state == State.JUMP:
		position.y += fall_speed / 256.0
		if fall_speed > 0 and room.solid_at(position.x, position.y - SINK - 1.0):
			position.y = floorf((position.y - SINK) / RoomData.TILE) * RoomData.TILE + SINK
			fall_speed = 0
			speed_x = 0
			_go(State.AWAY)

func _go(next: State) -> void:
	state = next
	state_ticks = 0

func _animation() -> String:
	match state:
		State.FACE, State.AWAY, State.WALK:
			return "walk"
		State.BUMP:
			return "bump"
		State.JUMP:
			return "jump"
	return "stand"

func _animation_tick() -> int:
	return state_ticks if state == State.BUMP else _ticks
