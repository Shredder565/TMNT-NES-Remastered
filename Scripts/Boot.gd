extends Node
## First scene to run. Sends the player to the ROM screen the first time,
## and to the title after that.

func _ready() -> void:
	if Game.has_rom():
		Game.go_to(Game.SCENE_TITLE)
	else:
		Game.go_to(Game.SCENE_ROM_SELECT)
