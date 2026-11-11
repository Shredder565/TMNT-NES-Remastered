class_name Shot
extends Area2D
## Something an enemy throws or fires: it flies level, in a straight line.
##
## Speeds, starting points and lifetimes are read from recordings of the USA
## ROM (Research/shots_spawning_tiles.md). Each kind's damage comes from the
## ROM's own table and is put in `damage_of` by the room scene.

## `speed` is in 1/256 pixel per update. `offset` is where it starts,
## measured from the enemy's position when the enemy faces right.
## `move` (if given) is how many updates it flies before it stops and
## hangs; `life` is how many updates it lasts in all.
const KINDS := {
	0x4A: { "speed": 832, "offset": Vector2(4, -16) },             # thrown by kind 49
	0x4C: { "speed": 832, "offset": Vector2(4, -20), "move": 15, "life": 39 },  # from kind 4B: flies 45 pixels, then hangs
	0x95: { "speed": 640, "offset": Vector2(2, -17) },             # fired by kind 94
	0x9F: { "speed": 832, "offset": Vector2(4, -12) },             # fired by kind 9E
	0x99: { "speed": 768, "offset": Vector2(3, -36) },             # thrown by kind 98
}
const TICK_FRAMES := 2
const GIVE_UP_DISTANCE := 200.0   ## guess: gone once this far from the turtle (off the screen)

static var damage_of := {}        ## kind -> energy lost on touch; 1 when not filled in

var kind := 0x99
var room: RoomData
var target: Node2D
var direction := 1
var speed := 768
var move_ticks := 0
var life_ticks := 0
var damage := 1
var ticks := 0
var sprites: SpriteSet
var _frame := 0
var _picture := Sprite2D.new()

## Makes a shot beside the enemy `from` and adds it next to that enemy.
static func fire(from: Node2D, shot_kind: int, toward: int, in_room: RoomData, turtle: Node2D) -> Shot:
	var shot := Shot.new()
	var how: Dictionary = KINDS[shot_kind]
	shot.kind = shot_kind
	shot.room = in_room
	shot.target = turtle
	shot.direction = toward
	shot.speed = how.speed
	shot.move_ticks = how.get("move", 0)
	shot.life_ticks = how.get("life", 0)
	shot.damage = damage_of.get(shot_kind, 1)
	shot.sprites = SpriteSet.cached("Kind%02X" % shot_kind)
	var offset: Vector2 = how.offset
	shot.position = from.position + Vector2(offset.x * toward, offset.y)
	if from.get_parent() != null:
		from.get_parent().add_child(shot)
	return shot

func _ready() -> void:
	var box := Rect2(-4, -8, 8, 8)
	if sprites != null:
		box = sprites.bounds("walk")
		_picture.centered = false
		add_child(_picture)
		var frame := sprites.frame_at("walk", 0)
		if sprites.textures.has(frame):
			_picture.texture = sprites.textures[frame]
			_picture.position = sprites.offsets[frame]
		scale.x = direction
	else:
		var block := ColorRect.new()
		block.position = box.position
		block.size = box.size
		block.color = Color(1.0, 0.9, 0.4)
		add_child(block)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	shape.position = box.get_center()
	add_child(shape)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % TICK_FRAMES == 0:
		tick()
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.take_damage(damage, global_position.x)
			if life_ticks == 0:
				queue_free()   # guess: a flying shot is used up by a hit
				return

## One game update.
func tick() -> void:
	if move_ticks == 0 or ticks < move_ticks:
		position.x += direction * speed / 256.0
	ticks += 1
	if sprites != null:
		var frame := sprites.frame_at("walk", ticks)
		if sprites.textures.has(frame):
			_picture.texture = sprites.textures[frame]
			_picture.position = sprites.offsets[frame]
	var gone := life_ticks > 0 and ticks >= life_ticks
	if room != null:
		gone = gone or position.x < 0.0 or position.x >= room.size_pixels().x
	if target != null:
		gone = gone or absf(position.x - target.position.x) > GIVE_UP_DISTANCE
	if gone:
		queue_free()
