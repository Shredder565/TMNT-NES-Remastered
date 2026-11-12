class_name DummyEnemy
extends Area2D
## A stand-in enemy: paces left and right, hurts the turtle on touch, and
## loses hit points to each weapon swing. Not based on a real enemy yet.
## A room read from the ROM puts one of these, standing still, wherever the
## original puts an enemy, with that enemy's real hit points.

@export var max_health := 3
@export var speed := 25.0
@export var patrol_distance := 40.0   ## pixels each side of the start point
@export var touch_damage := 1
@export var weapon_damage := 1        ## hit points lost to one swing
@export var weapon_damage_low := 1    ## the same when the turtle is below half health

var health := 3
var direction := 1
var start_x := 0.0
var flash_timer := 0.0
var sprites: SpriteSet            ## the kind's real pictures, when a ROM map exists for it
var _picture: Sprite2D
var _frames := 0

@onready var art: ColorRect = $Art

func _ready() -> void:
	health = max_health
	start_x = position.x
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	if absf(position.x - start_x) >= patrol_distance:
		direction = -1 if position.x > start_x else 1
	if flash_timer > 0.0:
		flash_timer -= delta
		art.color = Color.WHITE if flash_timer > 0.0 else Color(0.75, 0.2, 0.6)
	if sprites != null:
		_frames += 1
		_show_picture()
	# Hurt any turtle we are touching. The turtle ignores this while blinking.
	if not monitoring:
		return   # on the overworld, where the small turtle cannot be hurt yet
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.touched_by(self, touch_damage)

func _on_area_entered(area: Area2D) -> void:
	# The turtle's weapon is the only Area2D named WeaponHitbox.
	if area.name == "WeaponHitbox" and Turtle.weapon_lands(self):
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

## Turns the pacing test enemy into a still marker centred on a spot from
## the ROM, labelled with the enemy kind's number.
func show_as_spot(spot: EnemySpot) -> void:
	position = spot.position
	start_x = position.x
	speed = 0.0
	max_health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	health = max_health
	var shape: CollisionShape2D = $CollisionShape2D
	shape.shape = shape.shape.duplicate()
	(shape.shape as RectangleShape2D).size = Vector2(14, 14)
	shape.position = Vector2.ZERO
	var box: ColorRect = $Art
	box.offset_top = -7.0
	box.offset_bottom = 7.0
	sprites = SpriteSet.cached("Kind%02X" % spot.kind) if spot.kind >= 0 else null
	if sprites != null and not sprites.bounds("walk").has_area():
		sprites = null
	if sprites != null:
		# The kind's real look, standing in place. Boxes follow the picture.
		var picture := sprites.bounds("walk")
		(shape.shape as RectangleShape2D).size = picture.size
		shape.position = picture.get_center()
		box.visible = false
		_picture = Sprite2D.new()
		_picture.centered = false
		add_child(_picture)
		_show_picture()
		return
	var label := Label.new()
	label.text = "%02X" % spot.kind if spot.kind >= 0 else "?"
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-6, -19)
	add_child(label)

func _show_picture() -> void:
	var frame := sprites.frame_at("walk", _frames / 2)   # one game update is 2 frames
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func take_hit(amount: int) -> void:
	health -= amount
	flash_timer = 0.1
	if health <= 0:
		Puff.leave(self)
		queue_free()
