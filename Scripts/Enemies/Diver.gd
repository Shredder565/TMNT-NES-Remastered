class_name Diver
extends OriginalEnemy
## Enemy kind AA, by the original's rules (Research/enemy_AA.md, read from
## the code at bank 5, $A34F, $A357, $9CF8 and $A944).
##
## It hangs in the air, bobbing up and down. Once the turtle is less than
## 64 pixels away across it takes aim at him, once, and flies off that way
## at 2 pixels an update, still bobbing, until it leaves the screen.

const KINDS := { 0xAA: true }
const AIM_WITHIN := 64
const BOB_EVERY := 2              ## updates between changes of the bob's speed
## The bob's speed at each of its five steps (1/256 pixel an update).
const BOB_SPEEDS := [16, 64, 160, 384, 640]
## Eight directions from level (0) to straight down (7), a quarter turn in
## all: the speed across and the speed down for each. 2 pixels an update.
const AIM_SPEEDS := [
	Vector2i(510, 0), Vector2i(498, 114), Vector2i(460, 222), Vector2i(398, 318),
	Vector2i(318, 398), Vector2i(222, 460), Vector2i(114, 498), Vector2i(0, 510),
]
const FLAP := 0xCB
const ANIMATIONS := { FLAP: [4, [0x9A, 0x9B, 0x9C, 0x9D], LOOPS] }

var bob_timer := 0
var bob_step := 4                 ## which of BOB_SPEEDS
var bob_rising := false
var bob_way := -1                 ## the step goes down (-1) or up (1)
var aimed := false
var aim_direction := 0            ## 0 to 7
var aim_left := false
var aim_down := false

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0xAA

func _first_animation() -> int:
	return FLAP

func _stand_in_box() -> Rect2:
	return Rect2(-6, -12, 12, 10)

func _act() -> void:
	if not busy:
		busy = true
		bob_way = -1
		bob_timer = BOB_EVERY
		bob_step = 4
		bob_rising = false
		return
	_bob()
	if not aimed:
		if turtle_across() & 255 >= AIM_WITHIN:
			return
		_take_aim()
	var speeds: Vector2i = AIM_SPEEDS[aim_direction]
	speed_x = -speeds.x if aim_left else speeds.x
	speed_y += speeds.y if aim_down else -speeds.y

## The bob: its speed runs 640, 384, 160, 64, 16 downward, then the same
## upward from 16 to 640, and back, changing every second update.
func _bob() -> void:
	bob_timer -= 1
	if bob_timer == 0:
		bob_timer = BOB_EVERY
		bob_step += bob_way
		if bob_step == 0:
			bob_rising = not bob_rising
			bob_way = -bob_way
		elif bob_step == 4:
			bob_way = -bob_way
	speed_y = -BOB_SPEEDS[bob_step] if bob_rising else BOB_SPEEDS[bob_step]

## Picks one of 32 directions towards the turtle's middle from how far he
## is across and down, in 16-pixel steps. The original's table of angles
## is right, but its look-up takes each pair of neighbouring columns the
## wrong way round, so the aim is off by up to 16 pixels of his distance
## across. That is copied here.
func _take_aim() -> void:
	aimed = true
	aim_left = turtle_x() < whole_x()
	aim_down = turtle_y() >= whole_y()
	var across := (turtle_across() & 255) >> 4
	var down := (turtle_down() & 255) >> 4
	aim_direction = _angle_step(across ^ 1, down)

## The angle of (across, down) as a number from 0 (level) to 7 (straight
## down), rounded to the nearest.
static func _angle_step(across: int, down: int) -> int:
	if across == 0 and down == 0:
		return 4
	return floori(atan2(down, across) / (PI / 2.0) * 7.0 + 0.5)
