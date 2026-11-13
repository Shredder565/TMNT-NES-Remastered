class_name Puff
extends Node2D
## The puff a beaten enemy leaves (object kind 15 in the original): it sits
## where the enemy was for 9 updates and is gone.

const LIFE_TICKS := 9
const TICK_FRAMES := 2

var _frame := 0
var _ticks := 0
var _sprites: SpriteSet
var _picture := Sprite2D.new()

## Leaves a puff where `enemy` is. Does nothing if the enemy is in no scene.
static func leave(enemy: Node2D) -> void:
	if enemy.get_parent() == null:
		return
	var puff := Puff.new()
	puff.position = enemy.position
	enemy.get_parent().add_child(puff)

func _ready() -> void:
	_sprites = SpriteSet.cached("Kind15")
	if _sprites == null:
		return
	_picture.centered = false
	add_child(_picture)
	_show()

func _show() -> void:
	if _sprites == null:
		return
	var frame := _sprites.frame_at("walk", _ticks)
	if _sprites.textures.has(frame):
		_picture.texture = _sprites.textures[frame]
		_picture.position = _sprites.offsets[frame] - Vector2(0, OriginalEnemy.sprite_lift)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % TICK_FRAMES != 0:
		return
	_ticks += 1
	if _ticks >= LIFE_TICKS:
		queue_free()
	else:
		_show()

func _draw() -> void:
	if _sprites == null:
		draw_circle(Vector2(0, -8), 8.0, Color(1, 1, 1, 0.7))
