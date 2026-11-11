extends Node
## Autoload ("singleton"). Godot creates one copy of this when the game starts
## and every other script can reach it by the name Game.
## It holds the things the whole project needs: file locations, the key
## and controller bindings, and whether a ROM has been supplied.

## user:// is a per-user folder Godot manages for us. On Windows it is
## %APPDATA%\Godot\app_userdata\TMNT Remake. Nothing in it is ever committed to Git.
## Shown on the ROM screen so we can tell which update is installed.
const BUILD := 26

const ROM_PATH := "user://baserom.nes"
const ROM_ASSETS_PATH := "user://rom_assets"

const SCENE_ROM_SELECT := "res://Scenes/UI/RomSelect.tscn"
## The playable map scene. With a ROM it opens on the first overworld.
const SCENE_TEST_ROOM := "res://Scenes/Levels/Area1Sewer.tscn"
## The grey-block practice room from the first builds (press F2 in the sewer).
const SCENE_PRACTICE_ROOM := "res://Scenes/Levels/TestRoom.tscn"
const SCENE_CHR_VIEWER := "res://Scenes/Tools/ChrViewer.tscn"

## Action name -> keys. Kept in code (as the reference project does in its
## SettingsManager) so they are easy to read and change in one place.
const DEFAULT_KEYS := {
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"jump": [KEY_Z, KEY_SPACE],
	"attack": [KEY_X],
	"pause": [KEY_ENTER],
	"open_chr_viewer": [KEY_F1],
	"switch_room": [KEY_F2],
	"previous_area": [KEY_F3],
	"next_area": [KEY_F4],
	"toggle_fly": [KEY_F6],
	"go_overworld": [KEY_F7],
	"toggle_enemies": [KEY_F8],
}

## Action name -> controller buttons, on from the start with no setup.
## The names are Godot's, which follow the Xbox layout: the d-pad moves,
## A jumps, X or B attacks (the NES pad's A and B), Start pauses. Any
## controller Godot recognises (Xbox, PlayStation, Switch) maps onto these.
const DEFAULT_PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X, JOY_BUTTON_B],
	"pause": [JOY_BUTTON_START],
}
## Action name -> [stick axis, direction]: the left stick moves too.
const DEFAULT_PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}
const STICK_DEADZONE := 0.5       ## how far the stick must be pushed to count
const ANY_CONTROLLER := -1        ## listen to every controller plugged in

func _ready() -> void:
	_register_input_actions()

func _register_input_actions() -> void:
	for action: String in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in DEFAULT_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
	for action: String in DEFAULT_PAD_BUTTONS:
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
		for button: int in DEFAULT_PAD_BUTTONS[action]:
			var press := InputEventJoypadButton.new()
			press.button_index = button
			press.device = ANY_CONTROLLER
			InputMap.action_add_event(action, press)
	for action: String in DEFAULT_PAD_AXES:
		var push := InputEventJoypadMotion.new()
		push.axis = DEFAULT_PAD_AXES[action][0]
		push.axis_value = DEFAULT_PAD_AXES[action][1]
		push.device = ANY_CONTROLLER
		InputMap.action_add_event(action, push)

## True when a ROM has been copied in and still passes the checks.
func has_rom() -> bool:
	if not FileAccess.file_exists(ROM_PATH):
		return false
	return RomInfo.inspect_file(ROM_PATH).accepted

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path)
