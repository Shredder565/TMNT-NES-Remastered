class_name Lake
extends Node2D
## World 2's lake: its clock, its currents and its bombs (Research/lake.md).
## Written from the original's own routines: the clock in the swimming
## routine (bank 4, $A94E), the things at fixed places (bank 4, $AB94 and
## $B554: which are in hand, the currents at $B813, the bombs at $B7BC),
## the bomb as an item (bank 6, $96B5) and the scenes for a disarming and
## for the clock running out (bank 6, $A167 and $A110).
## The room scene makes one of these when the underwater room is shown and
## calls `frame()` once a frame.

signal all_disarmed            ## the eighth bomb has been seen to
signal time_up                 ## the clock ran out and the flashing is over

const CLOCK_SECONDS := 140     ## what the clock is set to on diving in (measured)
const CLOCK_UPDATES := 30      ## his updates to a second
const IN_HAND_LEFT := 10       ## a thing is in hand while its span across meets the screen from here
const IN_HAND_RIGHT := 246     ## ...to here, on the row of screens on show
const KIND_BOMB_FIRST := 0x17  ## the table's kinds for the eight bombs
const KIND_BOMB_LAST := 0x1E
const KIND_BOMB_OBJECT := 0x09 ## the object kind a bomb is made as (an item), and
const BOMB_ANIMATION := 0x38   ## its animation: the ROM's box table is asked with these
const CURRENTS := { 0x20: 0x10, 0x24: 0x11, 0x21: 0x20, 0x25: 0x21, 0x22: 0x40, 0x26: 0x41, 0x23: 0x80, 0x27: 0x81 }   ## table kind -> what the turtle's routine is told
const BOMB_BOX := Vector2i(4, 46)       ## the bomb's box: 4 each side, 46 up from its place (stand-in when the ROM's table is not to hand)
const BOMB_ABOVE := 25         ## he is brought to this far above the bomb's place,
const BOMB_CALLS := 64         ## and works on it for this many calls of the scene (one every second frame)
const BOMB_PICTURES := [0x8A, 0x8B]   ## his two pictures at a bomb, 4 calls each
const TIME_UP_CALLS := 50      ## the flashing when the clock has run out
const FLASH_COLOUR := Color(0.85, 0.2, 0.5)   ## stands in for the original's all-one-colour palette ($15)

var scene: Node                ## the room scene
var turtle: Turtle
var things: Array = []         ## the room's fixed things: [kind, place, number, far corner, flags]
var seconds := CLOCK_SECONDS
var count := CLOCK_UPDATES
var disarmed := 0              ## one bit for each bomb seen to (the original's $7D)
var owner_number := 0          ## the number of the current he is in (the original's $8B)
var bombs := {}                ## table kind -> its picture
var disarming := -1            ## the table kind of the bomb being disarmed, -1 when none
var _calls := 0                ## calls left of the work on it, -1 while he is being brought to it
var _frame := 0
var _time_up_calls := -1
var _live: SpriteSet
var _off: SpriteSet
var bomb_half := BOMB_BOX

func setup(room_scene: Node, the_turtle: Turtle, fixed_things: Array, done: int) -> void:
	scene = room_scene
	turtle = the_turtle
	things = fixed_things
	disarmed = done
	_live = SpriteSet.cached("LakeBomb")
	_off = SpriteSet.load_for("LakeBomb", {"2": {2: 0x00, 3: 0x12}})   # the colours the game changes to (measured)
	for thing: Array in things:
		if int(thing[0]) >= KIND_BOMB_FIRST and int(thing[0]) <= KIND_BOMB_LAST:
			var picture := Sprite2D.new()
			picture.centered = false
			add_child(picture)
			bombs[int(thing[0])] = picture
	turtle.swim_clock = clock_update
	_show_bombs()

static func bomb_bit(kind: int) -> int:
	return 1 << (kind - KIND_BOMB_FIRST)

func bomb_place(kind: int) -> Vector2:
	for thing: Array in things:
		if int(thing[0]) == kind:
			return Vector2((thing[3] as Vector2).x, (thing[1] as Vector2).y)   # its right end across, its top down
	return Vector2.ZERO

func _show_bombs() -> void:
	for kind: int in bombs:
		var picture: Sprite2D = bombs[kind]
		var done := disarmed & bomb_bit(kind) != 0 and kind != disarming
		var set_of := _off if done else _live
		if set_of == null:
			picture.visible = false
			continue
		var frame := "off" if done else ("f140" if (_frame / 8) % 2 == 0 else "f141")
		picture.texture = set_of.textures[frame]
		picture.position = bomb_place(kind) + set_of.offsets[frame]

## The clock, called by the turtle's swimming routine on each of its
## updates. False when the time is up: his routine then does nothing.
func clock_update() -> bool:
	if seconds == 0:
		if _time_up_calls < 0:
			_time_up_calls = TIME_UP_CALLS
			turtle.set_physics_process(false)
		return false
	count -= 1
	if count == 0:
		count = CLOCK_UPDATES
		seconds -= 1
	return true

## Is a fixed thing in hand: on the row of screens on show, its span across
## meeting the screen (bank 4, $AC05 and $B60E).
func in_hand(thing: Array, corner: Vector2) -> bool:
	var from: Vector2 = thing[1]
	var to: Vector2 = thing[3]
	if floori(from.y / 192.0) != floori(corner.y / 192.0):
		return false
	return to.x >= corner.x + IN_HAND_LEFT and from.x <= corner.x + IN_HAND_RIGHT

## The current he is in, as the original works it out once an update
## (bank 4, $B813): each current in hand in turn; one that is not the one
## he is in is passed over while he is in another; he is in it while he is
## right of its left end and not right of its right end, both taken as
## places on the screen in single bytes.
func current_for(corner: Vector2, across: int) -> int:
	var value := turtle.swim_current
	for thing: Array in things:
		if not CURRENTS.has(int(thing[0])) or not in_hand(thing, corner):
			continue
		if owner_number != 0 and owner_number != int(thing[2]):
			continue
		var left := (int((thing[1] as Vector2).x) - int(corner.x)) & 255
		var right := (int((thing[3] as Vector2).x) - int(corner.x)) & 255
		if left < across and right >= across:
			owner_number = int(thing[2])
			value = CURRENTS[int(thing[0])]
		else:
			owner_number = 0
			value = 0
	return value

## The bomb his box touches, by the original's box test (bank 6, $9AD3),
## or -1. A bomb already seen to does nothing.
func bomb_touched() -> int:
	var his := turtle.touch_box()
	for kind: int in bombs:
		if disarmed & bomb_bit(kind) != 0:
			continue
		var at := bomb_place(kind)
		var x := int(at.x)
		var y := int(at.y)
		var across := x + bomb_half.x >= his[0] - his[2] if x < his[0] else x - bomb_half.x < his[0] + his[2]
		if not across:
			continue
		if (y - 2 >= his[1] - his[3]) if y < his[1] else (y - bomb_half.y < his[1] + his[3]):
			return kind
	return -1

## One frame. True while one of the lake's scenes holds the game.
func frame(enemies_frame: bool, corner: Vector2) -> bool:
	_frame += 1
	_show_bombs()
	if _time_up_calls >= 0:
		_step_time_up()
		return true
	if disarming >= 0:
		_step_disarming()
		return true
	if not enemies_frame or turtle.state != Turtle.State.SWIM:
		return false
	turtle.swim_current = current_for(corner, floori(turtle.screen_x))
	var kind := bomb_touched()
	if kind >= 0 and turtle.health > 0:
		disarmed |= bomb_bit(kind)
		disarming = kind
		_calls = -1
		_frame = 0
		turtle.invulnerable_timer = 0.0   # his blinking is ended
		turtle.set_physics_process(false)
		turtle.swim_hide_bubble()
		return true
	return false

## A disarming (bank 6, $A167 and $A19F), one call every second frame: he
## is moved a pixel a call until he is 25 above the bomb's place, then put
## at the bomb's place across; 64 calls with his two pictures; the bomb
## then shows as seen to and play goes on (or, with all eight, the world
## ends).
func _step_disarming() -> void:
	if _frame % 2 == 0:
		return   # (his own animation stands still meanwhile: measured)
	var at := bomb_place(disarming)
	var middle := floori(turtle.position.y) - int(Turtle.CENTRE_ABOVE_FEET)
	var target := int(at.y) - BOMB_ABOVE
	if _calls < 0:
		if middle != target:
			turtle.position.y += 1.0 if middle < target else -1.0
			return
		turtle.place_across(at.x + turtle.position.x - floorf(turtle.position.x))
		_calls = BOMB_CALLS
		return
	_calls -= 1
	if _calls > 0:
		turtle.swim_pose(BOMB_PICTURES[1] if _calls & 4 != 0 else BOMB_PICTURES[0])
		return
	disarming = -1
	turtle.speed = Vector2i.ZERO
	_show_bombs()
	if disarmed == 0xFF:
		all_disarmed.emit()
	else:
		turtle.set_physics_process(true)

## The clock has run out (bank 6, $A110): 50 calls of flashing, then every
## turtle's energy is gone.
func _step_time_up() -> void:
	if _frame % 2 == 0:
		return
	_time_up_calls -= 1
	scene.background.modulate = FLASH_COLOUR if _time_up_calls & 4 == 0 else Color.WHITE
	if _time_up_calls == 0:
		_time_up_calls = -1
		scene.background.modulate = Color.WHITE
		time_up.emit()
