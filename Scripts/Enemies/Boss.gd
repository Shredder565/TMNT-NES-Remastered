class_name Boss
extends Area2D
## What the bosses share: energy, hurting the turtle on touch, being hit
## by his weapon, and their pictures. Each boss adds its own `tick`.

signal defeated

const TICK_FRAMES := 2

var kind := 0
var room: RoomData
var target: Node2D
var direction := -1
var health := 1
var full_health := 1
var touch_damage := 0
var weapon_damage := 7
var weapon_damage_low := 10
var sprites: SpriteSet
var view_left := 0.0             ## left edge of the screen the fight is held on
var _frame := 0
var _ticks := 0
var _art := Node2D.new()
var _picture := Sprite2D.new()

func setup(at: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	position = at
	room = in_room
	target = turtle
	sprites = sprite_set
	_face_turtle()

func _ready() -> void:
	var touch := Rect2(-8, -44, 16, 44)      # guesses, as for the other enemies
	var reach := Rect2(-16, -52, 32, 56)
	if sprites != null:
		var picture := sprites.bounds("stand")
		touch = Rect2(-8, picture.position.y, 16, picture.size.y)
		reach = picture.grow(8)
	add_child(_box_shape(touch))
	var hurt := Area2D.new()
	hurt.name = "HurtBox"
	hurt.add_child(_box_shape(reach))
	hurt.area_entered.connect(_on_weapon_entered)
	add_child(hurt)
	add_child(_art)
	if sprites != null:
		_picture.centered = false
		_art.add_child(_picture)
	else:
		var block := ColorRect.new()
		block.position = Vector2(-10, -44)
		block.size = Vector2(20, 44)
		block.color = Color(0.5, 0.5, 0.2)
		_art.add_child(block)
	_show_frame()

func _box_shape(box: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	shape.position = box.get_center()
	return shape

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % TICK_FRAMES == 0:
		_ticks += 1
		if room != null:
			tick()
		_show_frame()
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.take_damage(touch_damage, global_position.x)

## One game update. Each boss writes its own.
func tick() -> void:
	pass

## The name of the animation to show now, and how far into it.
func _animation() -> String:
	return "stand"

func _animation_tick() -> int:
	return _ticks

func _face_turtle() -> float:
	var gap := _gap()
	if gap != 0.0:
		direction = 1 if gap > 0.0 else -1
	return gap

func _gap() -> float:
	return 0.0 if target == null else target.position.x - position.x

func _show_frame() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var frame := sprites.frame_at(_animation(), _animation_tick())
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func _on_weapon_entered(area: Area2D) -> void:
	if area.name == "WeaponHitbox":
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

func take_hit(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		Puff.leave(self)
		defeated.emit()
		queue_free()
