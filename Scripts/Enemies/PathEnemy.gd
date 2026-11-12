class_name PathEnemy
extends Area2D
## Enemies that repeat a fixed up-and-down path, whatever the turtle does.
## So far only kind 88, which lowers itself and climbs back in steps.
##
## Each step is [updates, speed down in 1/256 pixel per update]. The steps
## are read off one recording of the USA ROM (Research/enemy_49_88_A0.md).

const KINDS := {
	# Lowered 96 pixels, then: up 64, up 6, up 14 with short stops, down 84.
	0x88: {
		"first": [[48, 512]],
		"loop": [[2, 0], [32, -512], [5, 0], [3, -512], [6, 0], [7, -512], [3, 0], [42, 512]],
	},
}
const TICK_FRAMES := 2

var kind := 0x88
var first: Array = []
var loop: Array = []
var step := 0
var step_ticks := 0
var in_first := true
var health := 9
var touch_damage := 15
var weapon_damage := 7
var weapon_damage_low := 10
var sprites: SpriteSet
var _frame := 0
var _ticks := 0
var _picture := Sprite2D.new()

func setup(spot: EnemySpot, sprite_set: SpriteSet) -> void:
	kind = spot.kind if KINDS.has(spot.kind) else 0x88
	first = KINDS[kind].first
	loop = KINDS[kind].loop
	position = spot.position
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	sprites = sprite_set

func _ready() -> void:
	var box := Rect2(-8, -29, 16, 32)        # guess when there is no picture
	if sprites != null:
		box = sprites.bounds("walk")
		_picture.centered = false
		add_child(_picture)
	else:
		var block := ColorRect.new()
		block.position = box.position
		block.size = box.size
		block.color = Color(0.3, 0.7, 0.8)
		add_child(block)
	add_child(_box_shape(box))
	var hurt := Area2D.new()
	hurt.name = "HurtBox"
	hurt.add_child(_box_shape(box.grow(8)))
	hurt.area_entered.connect(_on_weapon_entered)
	add_child(hurt)
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
		tick()
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.touched_by(self, touch_damage)

## One game update: carry on with the current step of the path.
func tick() -> void:
	_ticks += 1
	var steps := first if in_first else loop
	if steps.is_empty():
		return
	position.y += steps[step][1] / 256.0
	step_ticks += 1
	if step_ticks >= int(steps[step][0]):
		step_ticks = 0
		step += 1
		if step >= steps.size():
			step = 0
			in_first = false
	_show_frame()

func _show_frame() -> void:
	if sprites == null:
		return
	var frame := sprites.frame_at("walk", _ticks)
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func _on_weapon_entered(area: Area2D) -> void:
	if area.name == "WeaponHitbox" and Turtle.weapon_lands(self):
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		Puff.leave(self)
		queue_free()
