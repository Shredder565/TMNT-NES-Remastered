class_name Bebop
extends Boss
## Object kind 70, the boss of world 1's second room (it looks like
## Bebop). Written from the original's routine at bank 5, $AADB
## (Research/encounters.md), state by state:
##   0  puts kind 11 on the ledge (see Bystander) and goes on;
##   1  turns to the turtle and sets off at 2 pixels an update;
##   2  walking. Under 16 pixels from the turtle (across only): state 5.
##      Under 36: a jump, but only while bits 4 and 5 of the frame counter
##      are both 0. Else, after 48 updates: a jump if the turtle is in the
##      air, otherwise state 1 again;
##   3  the jump: 5 pixels an update upward;
##   4  in the air; landing, state 7;
##   5, 6  stops and plays its stopped animation through, then state 9;
##   7  turns away from the turtle and sets off;
##   9  stands. When bits 1 to 4 of the frame counter are all 0: state 1
##      if bit 6 is set, state 7 if not.

const KIND := 0x70
const WALK_SPEED := 512
const JUMP_SPEED := -1280
const CLOSE := 16
const JUMP_WITHIN := 36
const WALK_UPDATES := 48
const WALK := 0x40
const STAND := 0x41
const STOPPED := 0x42
const JUMP := 0x43
const ANIMATIONS := {
	WALK: [4, [0x80, 0x81, 0x82], LOOPS],
	STAND: [4, [0x83], LOOPS],
	STOPPED: [4, [0x83, 0x84, 0x83], ENDS],
	JUMP: [4, [0x85], LOOPS],
}
const COMPANY_KIND := 0x11
const COMPANY_AT := Vector2(196, 83)   ## on the screen
const CAPTIVE_AT := Vector2(168, 83)

var company: OriginalEnemy            ## who stands by on the ledge
var captive: Sprite2D                 ## the second figure there, only a picture

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return KIND

func _first_animation() -> int:
	return STAND

func _run_state() -> void:
	match state:
		0:
			state = 1
			_bring_company()
		1, 7:
			face(state == 7)
			set_off(WALK_SPEED)
			set_animation(WALK)
			go(2)
		2:
			stop_at_wall()
			state_ticks += 1
			turn_at_edge()
			var far := gap()
			if far < CLOSE:
				go(5)
			elif far < JUMP_WITHIN:
				if counter() & 0x30 == 0:
					go(3)
			elif state_ticks >= WALK_UPDATES:
				go(3 if turtle_in_air() else 1)
		3:
			speed_y = JUMP_SPEED
			state = 4
			set_animation(JUMP)
		4:
			fly(FLIGHT)
			if land(LAND_UP):
				state = 7
		5:
			set_animation(STOPPED)
			state = 6
			stop_across()
		6:
			if animation_ended():
				state = 9
				set_animation(STAND)
		_:
			set_animation(STAND)
			stop()
			if (counter() >> 1) & 0x0F == 0:
				state = 1 if counter() & 0x40 != 0 else 7

func _bring_company() -> void:
	if get_parent() == null:
		return
	company = Bystander.new()
	company.view_corner = view_corner
	company.setup_at(COMPANY_KIND, _corner() + COMPANY_AT, room, SpriteSet.cached("Kind%02X" % COMPANY_KIND), target)
	company.facing_left = true
	get_parent().add_child(company)
	# The second figure (slot 8 in the original: a picture with no object
	# behind it, at (168, 83) on the screen, not mirrored).
	var pictures := SpriteSet.cached("Kind%02X" % COMPANY_KIND)
	if pictures != null and pictures.textures.has("f143"):
		captive = Sprite2D.new()
		captive.centered = false
		captive.texture = pictures.textures["f143"]
		captive.position = _corner() + CAPTIVE_AT + pictures.offsets["f143"] - Vector2(0, sprite_lift)
		get_parent().add_child(captive)

## The one on the ledge stops being an object the moment the boss is
## beaten (bank 6, $99F1): he hurts no more, but his picture stays until
## the scene after the fight (RoomScene._step_ledge_scene).
func _beaten() -> void:
	if is_instance_valid(company):
		company.gone = true
		company.set_physics_process(false)
