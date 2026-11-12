class_name OriginalEnemy
extends Area2D
## What every ordinary enemy of the original has in common, written from
## Research/enemy_routines.md (how the original runs its objects) so that an
## enemy script only has to say what its own kind decides.
##
## Positions and speeds are whole numbers of 1/256 pixel, as in the
## original, so nothing drifts. One update does, in this order:
##   1. the kind's own rules (`_act`),
##   2. the blink that follows a hit runs down,
##   3. the enemy is moved by its speeds,
##   4. it is removed if it has left the screen,
##   5. its animation steps.
## The original updates its enemies on the frames its turtle does not move.

const TICK_FRAMES := 2
const SAFE_TICKS := 24            ## updates it blinks, and cannot be hit again, after a hit
## The map is felt in 16-pixel cells; a cell is what its top-left tile is.
const CELL := 16
const SCREEN_ROWS_PIXELS := 192    ## the room's part of the screen
const KIND_LEFT_OVER := 0x0C       ## what lies above and below a one-screen room (see kind_at)
const WALLS := [4, 0x0C, 0x0D]    ## what stops an enemy: walls and both moving floors
## An animation list ends by stopping (the enemy's rules see that it ended)
## or by starting again.
const ENDS := 0
const LOOPS := 1
const GOES_ON := 0x100             ## plus the number of the animation it goes on to
const THROWN_AT_ONCE := 4          ## the original's places for things enemies throw
const LAND_LIFT := 31             ## the most a landing raises it
const ENDED := 255                ## the step number of an animation that has stopped
## How things fly and fall. One line per number the original's kinds use:
## pull (added to the fall speed each update), then the places felt:
## `front` ahead at `high` up while rising; `side` ahead at foot height
## while falling; `side` ahead at `middle` up always; straight up at `head`.
const FLIGHTS := [
	{ "pull": 36, "front": 8, "high": -32, "middle": -16, "side": 12, "head": -35 },
	{ "pull": 48, "front": 14, "high": -42, "middle": -24, "side": 14, "head": -42 },
	{ "pull": 28, "front": 14, "high": -34, "middle": -16, "side": 14, "head": -36 },
	{ "pull": 28, "front": 12, "high": -40, "middle": -24, "side": 14, "head": -40 },
	{ "pull": 28, "front": 16, "high": -20, "middle": -8, "side": 18, "head": -20 },
	{ "pull": 40, "front": 14, "high": -28, "middle": -12, "side": 14, "head": -28 },
	{ "pull": 78, "front": 20, "high": -42, "middle": -18, "side": 20, "head": -42 },
]

## The original's frame counter (RAM $1E), which several kinds use where
## one would expect a random number. In play it is the game's own frame
## count; a test or a side-by-side run sets `frame_counter` itself.
static var frame_counter := -1
static var counter_offset := 0
## Set by the room scene when a ROM is installed: used to give an enemy
## the hit box the ROM has for the animation it is showing.
static var levels: RomLevels
## The original's one unpredictable number (RAM $45, stirred by an idle
## loop for as long as each frame has time to spare). In play the remake
## rolls its own; a side-by-side run sets `chance_byte` from the recording.
static var chance_byte := -1
static var _first_column := -1    ## the first of the sixteen map columns to hand; -1 = not tracked
static var _screen_left := 0
## How far the screen scrolled in the turtle's last update (the original's
## RAM $40): some kinds pick the way they set off from its sign.
static var scroll_step := 0
static var _step_frame := 0

var kind := 0
var room: RoomData
var target: Node2D                ## the turtle
var sprites: SpriteSet
var view_corner := Callable()     ## gives the top-left corner of the screen in the room; unset = no screen
var health := 1
var touch_damage := 0
var weapon_damage := 7
var weapon_damage_low := 10
var sub_x := 0                    ## position in 1/256 pixel
var sub_y := 0
var speed_x := 0                  ## 1/256 pixel per update
var speed_y := 0
var facing_left := false
var blinking := false             ## true for SAFE_TICKS updates after a hit
var safe_ticks := 0
var moves := true                 ## false: its speeds are not applied
var busy := false                 ## true while one of the kind's longer actions runs
var animation := 0
var anim_step := 0
var anim_ticks := 0
var picture := 0                  ## the original's picture number, shown as frame "f<number>"
var ticks := 0                    ## updates lived
var gone := false
var is_thrown := false            ## true for something an enemy threw
var _frame := 0
var _placed := Vector2.INF
var _art := Node2D.new()
var _picture := Sprite2D.new()
var _block: ColorRect
var _shapes: Array[CollisionShape2D] = []

## 1 facing right, -1 facing left.
var direction: int:
	get:
		return -1 if facing_left else 1

## The animations of this kind: number -> [updates per picture, pictures, ENDS or LOOPS].
func _animations() -> Dictionary:
	return {}

## The kind's own rules, once an update.
func _act() -> void:
	pass

## The size of the placeholder block and of the hit box when no ROM is there.
func _stand_in_box() -> Rect2:
	return Rect2(-6, -32, 12, 30)

## The kind an object of this script is when the place does not say.
func _default_kind() -> int:
	return 0

## The animation a new object of this kind starts with (the ROM's table,
## for when no ROM is there to ask).
func _first_animation() -> int:
	return 0

## The script that runs a kind by the original's rules, or null if that
## kind has not been written from the original's code yet.
static func for_kind(spot_kind: int) -> OriginalEnemy:
	if Soldier.KINDS.has(spot_kind):
		return Soldier.new()
	if Flier.KINDS.has(spot_kind):
		return Flier.new()
	if LedgeWalker.KINDS.has(spot_kind):
		return LedgeWalker.new()
	if CeilingCrawler.KINDS.has(spot_kind):
		return CeilingCrawler.new()
	if Lurker.KINDS.has(spot_kind):
		return Lurker.new()
	if Chainsaw.KINDS.has(spot_kind):
		return Chainsaw.new()
	if Pouncer.KINDS.has(spot_kind):
		return Pouncer.new()
	if Gunner.KINDS.has(spot_kind):
		return Gunner.new()
	return null

## Makes it the enemy of one of the ROM's enemy places. Set `view_corner`
## first if there is a screen.
func setup(spot: EnemySpot, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	setup_at(spot.kind if spot.kind >= 0 else _default_kind(), spot.position, in_room, sprite_set, turtle)
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	# A new object faces left when it appears on the right half of the screen.
	facing_left = whole_x() - int(_corner().x) >= 128
	set_animation(_first_animation())

func setup_at(spot_kind: int, where: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	kind = spot_kind
	room = in_room
	target = turtle
	sprites = sprite_set
	place(where)

## Puts it somewhere, with no fraction of a pixel.
func place(where: Vector2) -> void:
	sub_x = roundi(where.x * 256.0)
	sub_y = roundi(where.y * 256.0)
	position = Vector2(sub_x / 256.0, sub_y / 256.0)
	_placed = position

func whole_x() -> int:
	return sub_x >> 8

func whole_y() -> int:
	return sub_y >> 8

func _ready() -> void:
	var box := _stand_in_box()
	var touch := CollisionShape2D.new()
	add_child(touch)
	_shapes.append(touch)
	var hurt := Area2D.new()
	hurt.name = "HurtBox"
	var reach := CollisionShape2D.new()
	hurt.add_child(reach)
	_shapes.append(reach)
	hurt.area_entered.connect(_on_weapon_entered)
	add_child(hurt)
	_set_box(box)
	add_child(_art)
	if sprites != null:
		_picture.centered = false
		_art.add_child(_picture)
	else:
		_block = ColorRect.new()
		_block.position = box.position
		_block.size = box.size
		_block.color = Color(0.5, 0.25, 0.7)
		_art.add_child(_block)
	_fit_box_to_animation()
	_show()

func _set_box(box: Rect2) -> void:
	for shape in _shapes:
		var rectangle := RectangleShape2D.new()
		rectangle.size = box.size
		shape.shape = rectangle
		shape.position = box.get_center()

## The original's box depends on the animation on show: as wide as the
## ROM's pair says to each side, and from its half height above the
## position down to 2 above it (Research/hit_boxes.md).
func _fit_box_to_animation() -> void:
	if levels == null or animation == 0 or _shapes.is_empty():
		return
	var half := levels.box_half_size(kind, animation)
	if half == Vector2i.ZERO:
		return
	_set_box(Rect2(-half.x, -half.y, half.x * 2, maxi(half.y - 2, 1)))

## The original's frame counter as an enemy's rules see it.
static func counter() -> int:
	if frame_counter >= 0:
		return frame_counter & 255
	return (Engine.get_physics_frames() + counter_offset) & 255

## A number from 0 to 255 that nothing can foresee.
static func chance() -> int:
	return chance_byte & 255 if chance_byte >= 0 else randi() & 255

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _is_update_frame():
		tick()
	if gone:
		return
	for body in get_overlapping_bodies():
		if body is Turtle:
			_touch(body)

## Enemies are updated on the frames the turtle is not.
func _is_update_frame() -> bool:
	if frame_counter >= 0:
		return frame_counter % TICK_FRAMES == 0
	if is_instance_valid(target) and target is Turtle:
		return target._frame % TICK_FRAMES != 0
	return _frame % TICK_FRAMES == 0

func _touch(turtle: Turtle) -> void:
	turtle.touched_by(self, touch_damage)

## One game update.
func tick() -> void:
	if gone:
		return
	if position != _placed:
		place(position)   # something else moved it
	ticks += 1
	_act()
	if gone:
		return
	if blinking:
		safe_ticks = (safe_ticks - 1) & 255
		if safe_ticks == 0:
			blinking = false
	if moves:
		sub_x += speed_x
		sub_y += speed_y
	position = Vector2(sub_x / 256.0, sub_y / 256.0)
	_placed = position
	if _off_screen():
		remove()
		return
	_animate()
	_show()

func remove() -> void:
	gone = true
	queue_free()

## --- the screen -----------------------------------------------------------

func _corner() -> Vector2:
	return view_corner.call() if view_corner.is_valid() else Vector2.ZERO

## Gone once it is within 4 pixels of the screen's sides or top, or below
## the room's part of the screen.
func _off_screen() -> bool:
	if not view_corner.is_valid():
		return room != null and sub_y > (room.size_pixels().y + 64) * 256
	var corner := _corner()
	var across := whole_x() - int(corner.x)
	var down := whole_y() - int(corner.y)
	return across < 4 or across >= 252 or down < 4 or down >= 192

## --- the map --------------------------------------------------------------

## The kind of map cell `across`, `down` pixels from its position.
##
## The original keeps only sixteen 16-pixel columns of the map to hand,
## one screen's worth, and looks a place up by its column counted round
## that ring. So a place past the screen's side is answered with the
## column sixteen along, and so is the half-shown column at one edge of
## the screen (which edge depends on how the screen last scrolled: see
## `screen_moved_to`).
func kind_at(across: int, down: int) -> int:
	if room == null:
		return RoomData.KIND_EMPTY
	var x := whole_x() + across
	var y := whole_y() + down
	var column := x >> 4
	if view_corner.is_valid():
		var corner := _corner()
		var first := _first_column if _first_column >= 0 else (int(corner.x) + 8) >> 4
		column = first + posmod(column - first, 16)
		if room.rows * RoomData.TILE <= SCREEN_ROWS_PIXELS:
			# A room one screen tall. Heights wrap at 256, and outside the
			# room's own rows the original finds whatever the last map left
			# in memory there. Measured in world 1 (entered by its first
			# manhole): solid from 16 below the room's bottom round to its
			# top, nothing in the 16 pixels just below the room.
			y &= 255
			if y >= SCREEN_ROWS_PIXELS:
				return RoomData.KIND_EMPTY if y < SCREEN_ROWS_PIXELS + CELL else KIND_LEFT_OVER
	return room.kind_at(column * 2, (y >> 4) * 2)

## Keeps track of which sixteen map columns the original would have to
## hand. Scrolling right, the column coming in on the right replaces the
## one going out on the left once the screen is 8 pixels into it;
## scrolling left, the column coming in on the left is only taken up once
## the screen has gone past it and the next one starts to show (or the
## screen has reached the room's left end). The room scene calls this every frame.
static func screen_moved_to(left_edge: int) -> void:
	if _first_column < 0 or absi(left_edge - _screen_left) > 32:
		_first_column = (left_edge + 8) >> 4
	elif left_edge > _screen_left:
		_first_column = maxi(_first_column, (left_edge + 8) >> 4)
	elif left_edge < _screen_left:
		_first_column = mini(_first_column, (left_edge + 16) >> 4) if left_edge > 0 else 0
	var now := Engine.get_physics_frames()
	if left_edge != _screen_left:
		scroll_step = left_edge - _screen_left if absi(left_edge - _screen_left) <= 32 else 0
		_step_frame = now
	elif now - _step_frame >= TICK_FRAMES:
		scroll_step = 0
	_screen_left = left_edge

func wall_at(across: int, down: int) -> bool:
	return WALLS.has(kind_at(across, down))

## Is there anything at all `back` pixels behind it, `down` pixels below
## its position? (Behind is away from the way it faces.)
func something_behind(back: int, down: int) -> bool:
	return kind_at(back if facing_left else -back, down) != RoomData.KIND_EMPTY

## A wall `reach` pixels ahead in the way it is moving (to the right when
## it is not moving), at `high` above it, or at 14 or 6 above. The whole
## pixels of its speed are added to the reach.
func wall_ahead(reach: int, high: int) -> bool:
	var across := (-reach if speed_x < 0 else reach) + (speed_x >> 8)
	return wall_at(across, high) or wall_at(across, -14) or wall_at(across, -6)

## --- the turtle -----------------------------------------------------------

func turtle_x() -> int:
	return floori(target.position.x) if is_instance_valid(target) else whole_x()

## The turtle's position value is his middle, 20 above his feet.
func turtle_y() -> int:
	return floori(target.position.y) - RoomData.CENTRE_TO_FEET if is_instance_valid(target) else whole_y()

func turtle_across() -> int:
	return absi(turtle_x() - whole_x())

func turtle_down() -> int:
	return absi(turtle_y() - whole_y())

func turtle_is_above() -> bool:
	return turtle_y() < whole_y()

## Turns to face the turtle unless he is less than 8 pixels away across;
## returns how far away across he is.
func face_turtle() -> int:
	var across := turtle_across()
	if across >= 8:
		facing_left = turtle_x() < whole_x()
	return across

## --- moving ---------------------------------------------------------------

func stop_across() -> void:
	speed_x = 0

func stop_down() -> void:
	speed_y = 0

func stop() -> void:
	speed_x = 0
	speed_y = 0

## Sets the whole pixels of the downward speed and leaves its fraction,
## as the original does in several places.
func set_fall_pixels(pixels: int) -> void:
	speed_y = pixels * 256 + (speed_y & 255)

## Sets the sideways speed, in the way it faces.
func go_forward(speed: int) -> void:
	speed_x = -speed if facing_left else speed

func turn_round() -> void:
	facing_left = not facing_left
	speed_x = -speed_x

## Sets off forward, unless a wall is 10 pixels ahead (at 16, 14 or 6 up).
func set_off(speed: int) -> void:
	go_forward(speed)
	if wall_ahead(10, -16):
		stop_across()

## One update in the air: the pull, then the map. A wall ahead stops the
## sideways speed (and a rise); a ceiling stops a rise.
func fly(flight: int) -> void:
	var how: Dictionary = FLIGHTS[flight]
	speed_y += how.pull
	var way := -1 if speed_x < 0 else 1
	var step := speed_x >> 8
	var rising := speed_y < 0
	var blocked: bool
	if rising:
		blocked = wall_at(way * int(how.front) + step, how.high)
	else:
		blocked = wall_at(way * int(how.side), 0)
	if not blocked:
		blocked = wall_at(way * int(how.side) + step, how.middle)
	if blocked:
		if rising:
			stop_down()
		stop_across()
	elif rising and wall_at(0, how.head):
		stop_down()

## Has it come down into a floor? Then it is raised a pixel at a time until
## the place `up` above it is clear, and stands. Returns true if so.
func land(up := -4) -> bool:
	if not wall_at(0, up):
		return false
	for i in LAND_LIFT:
		sub_y -= 256
		if not wall_at(0, up):
			break
	busy = false
	stop()
	return true

## The start of a drop or a leap: sets the downward speed (negative is
## up) and marks it busy, unless a wall is 14 pixels ahead of it (at 4 up
## when dropping or 36 up when leaping, or at 12 up), in which case it
## just stands with no speed. Returns true if it is away.
func launch(fall_speed: int) -> bool:
	busy = true
	var reach := -14 if facing_left else 14
	speed_y = fall_speed
	if wall_at(reach, -36 if speed_y < 0 else -4) or wall_at(reach, -12):
		busy = false
		stop()
		return false
	return true

## Makes something this enemy throws, `across` pixels ahead of it and
## `down` from its position, facing the way it faces. The original has
## four places for thrown things, shared by every enemy on the screen,
## and does not make one that would start in a wall (8 above its own
## position). Returns null if none was made. The caller sets it up and
## then gives it its first update with `tick()`, which the original does
## in the same round as the throw.
func throw_object(thrown: OriginalEnemy, thrown_kind: int, across: int, down: int) -> OriginalEnemy:
	var parent := get_parent()
	var flying := 0
	if parent != null:
		for other in parent.get_children():
			if other is OriginalEnemy and other.is_thrown and not other.gone:
				flying += 1
	if parent == null or flying >= THROWN_AT_ONCE:
		thrown.free()
		return null
	thrown.is_thrown = true
	thrown.view_corner = view_corner
	thrown.setup_at(thrown_kind, Vector2(whole_x() + (-across if facing_left else across), whole_y() + down), room, SpriteSet.cached("Kind%02X" % thrown_kind), target)
	thrown.facing_left = facing_left
	thrown.weapon_damage = weapon_damage
	thrown.weapon_damage_low = weapon_damage_low
	if thrown.kind_at(0, -8) == RoomData.KIND_SOLID:
		thrown.free()
		return null
	parent.add_child(thrown)
	return thrown

## --- animation ------------------------------------------------------------

func set_animation(number: int) -> void:
	animation = number
	anim_step = 0
	var entry: Array = _animations().get(number, [1, [], LOOPS])
	anim_ticks = entry[0]
	_fit_box_to_animation()

func animation_ended() -> bool:
	return anim_step == ENDED

func _animate() -> void:
	if animation == 0:
		return
	var entry: Array = _animations().get(animation, [1, [], LOOPS])
	anim_ticks = (anim_ticks - 1) & 255
	if anim_ticks == 0:
		anim_ticks = entry[0]
		anim_step = (anim_step + 1) & 255
	if anim_step >= 128:
		anim_step = 0
	var pictures: Array = entry[1]
	if anim_step < pictures.size():
		picture = pictures[anim_step]
	elif entry[2] == ENDS:
		anim_step = ENDED
	elif entry[2] >= GOES_ON:
		animation = entry[2] - GOES_ON
		anim_ticks = _animations().get(animation, [1, [], LOOPS])[0]
		anim_step = 0
		_fit_box_to_animation()
	else:
		anim_step = 0

func _show() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var frame := _frame_name()
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

## The sprite map's name for the picture on show.
func _frame_name() -> String:
	return "f%d" % picture

## --- being hit ------------------------------------------------------------

func _on_weapon_entered(area: Area2D) -> void:
	if area.name == "WeaponHitbox" and not blinking and Turtle.weapon_lands(self):
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

## A hit that has landed: it blinks and cannot be hit again for 24 updates.
## What else it does about it is up to the kind's rules, which see
## `blinking`.
func take_hit(amount: int) -> void:
	blinking = true
	safe_ticks = SAFE_TICKS
	health -= amount
	if health <= 0:
		Puff.leave(self)
		remove()
