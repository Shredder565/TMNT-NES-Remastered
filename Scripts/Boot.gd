extends Node
## First scene to run. Sends the player to the ROM screen the first time,
## and straight into the test room after that.

func _ready() -> void:
	if Game.has_rom():
		Game.go_to(Game.SCENE_TEST_ROOM)
	else:
		Game.go_to(Game.SCENE_ROM_SELECT)
