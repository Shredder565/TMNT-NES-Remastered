class_name Item
extends Area2D
## Something lying in a room for the turtle to pick up.
##
## What each kind gives was found by touching it in the emulator
## (Research/world1.md): a slice of pizza gives 32 energy, a whole pizza
## fills it. Kind 0B was picked up without any change I could see.

const SLICE := 0x03
const WHOLE_PIZZA := 0x01
const UNKNOWN_0B := 0x0B
const SLICE_ENERGY := 32

var kind := SLICE
var sprites: SpriteSet

func setup(item_kind: int, at: Vector2, sprite_set: SpriteSet) -> void:
	kind = item_kind
	position = at
	sprites = sprite_set

func _ready() -> void:
	var box := Rect2(-8, -16, 16, 16)
	if sprites != null and sprites.bounds("walk").has_area():
		box = sprites.bounds("walk")
		var picture := Sprite2D.new()
		picture.centered = false
		var frame := sprites.frame_at("walk", 0)
		picture.texture = sprites.textures[frame]
		picture.position = sprites.offsets[frame]
		add_child(picture)
	else:
		var block := ColorRect.new()
		block.position = box.position
		block.size = box.size
		block.color = Color(0.95, 0.75, 0.2)
		add_child(block)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	shape.position = box.get_center()
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Turtle:
		pick_up(body)

## Gives the turtle what this item gives, and removes it.
func pick_up(turtle: Turtle) -> void:
	if kind == SLICE:
		turtle.heal(SLICE_ENERGY)
	elif kind == WHOLE_PIZZA:
		turtle.heal(turtle.max_health)
	queue_free()
