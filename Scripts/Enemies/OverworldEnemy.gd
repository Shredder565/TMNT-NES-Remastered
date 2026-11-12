class_name OverworldEnemy
extends Node2D
## The enemies that move about the overworld map: kinds 9A and 9B (the
## rollers, which drive along the streets and turn at walls) and kind 40
## (the soldier, who walks at the turtle). Their rules are the original's,
## read from its code in bank 5 at $877E, $87C0 and $8907; see
## Research/overworld.md. Positions are the original's own position values,
## speeds are in 1/256 pixel per update, and an update is two frames.
##
## Touching one hurts the turtle and his weapon hurts them; the map scene
## (RoomScene) tests the boxes, since it knows both sides.

const KINDS := [0x9A, 0x9B, 0x40]
const TICK_FRAMES := 2
## The rollers' speeds, and the faster ones they use while the turtle drives the van.
const ROLLER_ACROSS := 0x0220
const ROLLER_ACROSS_VAN := 0x0260
const ROLLER_UP := 0x0240
const ROLLER_UP_VAN := 0x0280
const SOLDIER_SPEED := 0x0220
const SAFE_UPDATES := 24           ## after a hit that does not finish it, nothing can hit it for this long
const SOLDIER_NEAR := 10           ## closer than this on one axis, the soldier does not walk along it
const FACE_FROM := 8               ## further than this across, he turns to face the turtle
## The points the original tests before moving, from the enemy's position:
## a wall or water at any of them stops that move.
const ROLLER_PROBES := {
	"right": [Vector2i(16, -24), Vector2i(16, -4)],
	"left": [Vector2i(-16, -24), Vector2i(-16, -4)],
	"up": [Vector2i(8, -28), Vector2i(-8, -28)],
	"down": [Vector2i(8, 2), Vector2i(-8, 2)],
}
const SOLDIER_PROBES := {
	"right": [Vector2i(12, -6)],
	"left": [Vector2i(-12, -6)],
	"up": [Vector2i(0, -19)],
	"down": [Vector2i(0, 1)],
}
## How long each of an animation's two pictures stays, in updates, when
## the sprite map does not say (its "updates" entry; measured).
const PICTURE_UPDATES := [7, 9]

var kind := 0x9A
var room: RoomData
var target: Node2D                 ## the overworld turtle
var driving_van := false           ## the rollers speed up while he drives
var self_driven := true            ## false: something else calls tick() on the right frames
var screen_corner := Vector2.ZERO  ## the corner of the original's screen, kept up to date by the map scene
var speed := Vector2i.ZERO         ## 1/256 pixel per update
var facing_left := false
var animation := ""                ## "up", "down" or "across"
var health := 1
var half_size := Vector2i(8, 16)   ## half its box, from the ROM's table for its kind
var safe_updates := 0              ## updates left in which it cannot be hit
var touch_damage := 0
var weapon_damage := 1
var weapon_damage_low := 1
var sprites: SpriteSet             ## null without a ROM map: a labelled block is drawn
var picture_name := ""
var _fraction := Vector2i.ZERO     ## the part of a pixel not yet moved, in 1/256
var _frame := 0
var _animation_updates := 0
var _picture := Sprite2D.new()

func _init() -> void:
	_picture.centered = false
	add_child(_picture)

func setup(spot: EnemySpot, map: RoomData, pictures: SpriteSet, turtle: Node2D) -> void:
	kind = spot.kind
	position = spot.position
	room = map
	sprites = pictures
	target = turtle
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	if spot.half_size != Vector2i.ZERO:
		half_size = spot.half_size
	animation = "up"   # the ROM starts all three on their "up" animation
	# It comes in facing the turtle (measured for the soldier; the rollers
	# were only ever seen coming in with the turtle to their right).
	facing_left = turtle != null and int(turtle.position.x) < int(position.x)
	_show_picture()

func _physics_process(_delta: float) -> void:
	if not self_driven:
		return
	_frame += 1
	if _frame % TICK_FRAMES == 0:
		tick()

## One update: decide, then move, as the original orders them.
func tick() -> void:
	if room == null:
		return
	match kind:
		0x9A:
			_roller(true)
		0x9B:
			_roller(false)
		_:
			_soldier()
	_move()
	_animation_updates += 1
	if safe_updates > 0:
		safe_updates -= 1
	_show_picture()

## Its box on the map, as the original places an enemy's: as wide as the
## half width to each side, and from the half height above its position
## down to 2 above it (Research/hit_boxes.md).
func box() -> Rect2:
	var at := position.floor()
	return Rect2(at.x - half_size.x, at.y - half_size.y, half_size.x * 2.0, maxf(half_size.y - 2.0, 1.0))

## The turtle's weapon lands. Returns true if that finished it.
func take_hit(amount: int) -> bool:
	if safe_updates > 0 or is_queued_for_deletion():
		return false
	health -= amount
	if health <= 0:
		Puff.leave(self)
		queue_free()
		return true
	safe_updates = SAFE_UPDATES
	return false

## A roller keeps going the way it is going until a wall or water is in
## the way, then tries the next way round: kind 9A goes right, up, left,
## down; kind 9B right, down, left, up. When the last choice is blocked
## too it stands for an update, facing the other way, and starts over.
func _roller(first_kind: bool) -> void:
	if speed.y == 0:
		if not facing_left:
			if _roll("right"):
				return
			if first_kind:
				_roller_up(true)
			else:
				_roller_down(false)
		else:
			if _roll("left"):
				return
			if first_kind:
				_roller_down(true)
			else:
				_roller_up(false)
	elif speed.y < 0:
		_roller_up(first_kind)
	else:
		_roller_down(first_kind)

func _roller_up(first_kind: bool) -> void:
	if _roll("up"):
		return
	facing_left = first_kind   # 9A will try left next, 9B right
	speed = Vector2i.ZERO

func _roller_down(first_kind: bool) -> void:
	if _roll("down"):
		return
	if first_kind:
		facing_left = false
		if not _roll("right"):
			_roller_up(true)
	elif not _roll("left"):
		_roller_up(false)

func _roll(way: String) -> bool:
	if _blocked(ROLLER_PROBES[way]):
		return false
	var across := ROLLER_ACROSS_VAN if driving_van else ROLLER_ACROSS
	var up := ROLLER_UP_VAN if driving_van else ROLLER_UP
	match way:
		"right":
			speed = Vector2i(across, 0)
			facing_left = false
			_animate("across")
		"left":
			speed = Vector2i(-across, 0)
			facing_left = true
			_animate("across")
		"up":
			speed = Vector2i(0, -up)
			_animate("up")
		"down":
			speed = Vector2i(0, up)
			_animate("down")
	return true

## The soldier walks at the turtle: across first while he is 10 or more
## pixels away that way, otherwise (or when a wall stops that) up or down
## while he is 10 or more away that way. Within 10 both ways he stands.
func _soldier() -> void:
	if target == null:
		return
	var across := absi(int(target.position.x) - int(position.x))
	var down := absi(int(target.position.y) - int(position.y))
	var above := int(target.position.y) < int(position.y)
	if across >= FACE_FROM:
		facing_left = int(target.position.x) < int(position.x)
	if across >= SOLDIER_NEAR:
		if _walk("left" if facing_left else "right"):
			return
		if down >= SOLDIER_NEAR and _walk("up" if above else "down"):
			return
		speed = Vector2i.ZERO
		return
	if down < SOLDIER_NEAR:
		speed = Vector2i.ZERO
		return
	if _walk("up" if above else "down"):
		return
	if _walk("left" if facing_left else "right"):
		return
	speed = Vector2i.ZERO

func _walk(way: String) -> bool:
	if _blocked(SOLDIER_PROBES[way]):
		return false
	match way:
		"right":
			speed.x = SOLDIER_SPEED
			if _animate("across"):
				speed.y = 0
		"left":
			speed.x = -SOLDIER_SPEED
			if _animate("across"):
				speed.y = 0
		"up":
			speed.y = -SOLDIER_SPEED
			if _animate("up"):
				speed.x = 0
		"down":
			speed.y = SOLDIER_SPEED
			if _animate("down"):
				speed.x = 0
	return true

## Is a wall (cell kind 4) or water (kind 12) at any of these points?
## The original works the point out on the screen in one byte, so a point
## above the screen's top is looked up 256 pixels lower, and one left of
## its left edge 256 to the right. That is kept, since it decides which
## way an enemy turns near the screen's edge.
func _blocked(probes: Array) -> bool:
	for probe: Vector2i in probes:
		var on_screen := position.floor() - screen_corner + Vector2(probe)
		var point := screen_corner + Vector2(posmod(int(on_screen.x), 256), posmod(int(on_screen.y), 256))
		var kind_there := room.kind_at_pixel(point.x, point.y)
		if kind_there == RoomData.KIND_SOLID or kind_there == RoomData.KIND_WATER:
			return true
	return false

## Changes the animation; true when it was a different one.
func _animate(wanted: String) -> bool:
	if animation == wanted:
		return false
	animation = wanted
	_animation_updates = -1   # this update still shows the old picture's turn; the new one starts next
	return true

## Adds the speed, keeping the part of a pixel left over, as the original does.
func _move() -> void:
	var total := _fraction + speed
	var whole := Vector2i(total.x >> 8, total.y >> 8)
	_fraction = Vector2i(total.x & 255, total.y & 255)
	position += Vector2(whole)

func _show_picture() -> void:
	_picture.visible = sprites != null and (safe_updates == 0 or safe_updates % 2 == 0)   # it blinks after a hit
	queue_redraw()
	if sprites == null:
		return
	var frames: Array = sprites.animations.get(animation, {}).get("frames", [])
	if frames.is_empty():
		return
	var updates: Array = sprites.animations[animation].get("updates", PICTURE_UPDATES)
	var cycle := int(updates[0]) + int(updates[1])
	var index := 0 if posmod(_animation_updates, cycle) < int(updates[0]) else 1
	var frame: String = frames[mini(index, frames.size() - 1)]
	picture_name = frame
	if not sprites.textures.has(frame):
		return
	_picture.texture = sprites.textures[frame]
	var offset: Vector2 = sprites.offsets[frame]
	_picture.flip_h = facing_left
	if facing_left:
		offset.x = -offset.x - _picture.texture.get_width()
	_picture.position = offset

func _draw() -> void:
	if sprites != null:
		return
	draw_rect(Rect2(-8, -16, 16, 16), Color(0.75, 0.2, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(-6, -4), "%02X" % kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
