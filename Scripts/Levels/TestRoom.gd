extends Node2D
## The milestone room: a floor, a few ledges, one turtle and one test enemy.

const START := Vector2(40, 208)

@onready var turtle: Turtle = $Turtle
@onready var hud: Label = $HUD/Label
@onready var health_bar: Control = $HUD/HealthBar

func _ready() -> void:
	turtle.health_changed.connect(health_bar.set_health)
	turtle.died.connect(_on_turtle_died)
	health_bar.set_health(turtle.health, turtle.max_health)
	hud.text = "%s\nArrows move  Down crouch  Z jump  X attack  F1 tiles  F2 sewer  build %d" % [turtle.turtle_name, Game.BUILD]

func _process(_delta: float) -> void:
	# Fell out of the room: put the turtle back at the start.
	if turtle.position.y > 400.0:
		turtle.position = START
		turtle.speed = Vector2i.ZERO

func _on_turtle_died() -> void:
	# Placeholder for the real "switch turtle / game over" flow.
	await get_tree().create_timer(1.5).timeout
	turtle.position = START
	turtle.revive()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chr_viewer"):
		Game.go_to(Game.SCENE_CHR_VIEWER)
	elif event.is_action_pressed("switch_room"):
		Game.go_to(Game.SCENE_TEST_ROOM)
