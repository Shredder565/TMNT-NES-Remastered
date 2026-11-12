extends Control
## Asks the player for their own ROM, checks it, copies it into user:// and
## rips the tile sheets. The screen is built in code so there is one small
## scene file and everything is readable here.

var status: Label
var file_dialog: FileDialog
var ready_to_continue := false

func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var title := Label.new()
	title.text = "TMNT REMAKE  (build %d)" % Game.BUILD
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	status = Label.new()
	status.text = "Drop your own TMNT .nes file on this window, or press Select ROM."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 8)
	status.custom_minimum_size = Vector2(240, 120)
	box.add_child(status)

	var select := Button.new()
	select.text = "Select ROM"
	select.pressed.connect(open_picker)
	box.add_child(select)

	var skip := Button.new()
	skip.text = "Play with placeholder art"
	skip.pressed.connect(func() -> void: Game.go_to(Game.SCENE_TEST_ROOM))
	box.add_child(skip)

	# Fallback picker, only used if the PC cannot show its own file picker.
	# project.godot turns off "embed subwindows", so it opens as a separate
	# normal-sized window instead of inside the tiny game screen.
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.nes ; NES ROM"])
	file_dialog.size = Vector2i(800, 500)
	file_dialog.file_selected.connect(handle_rom)
	add_child(file_dialog)

	get_window().files_dropped.connect(func(files: PackedStringArray) -> void:
		if files.size() > 0:
			handle_rom(files[0]))

func open_picker() -> void:
	# Ask Windows for its own file picker directly.
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Select your TMNT ROM", "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.nes;NES ROM"]), _on_native_picked)
	else:
		file_dialog.popup_centered()

func _on_native_picked(picked: bool, paths: PackedStringArray, _filter_index: int) -> void:
	if picked and paths.size() > 0:
		handle_rom.call_deferred(paths[0])

func handle_rom(path: String) -> void:
	if path.get_extension().to_lower() in ["zip", "7z", "rar"]:
		status.text = "That is a compressed file. Unzip it first and use the .nes file inside."
		return
	var info := RomInfo.inspect_file(path)
	var details := ""
	if info.ok_header:
		details = "\nFingerprint (SHA-1): %s" % info.sha1
	if not info.accepted:
		status.text = info.message + details
		return
	DirAccess.copy_absolute(path, ProjectSettings.globalize_path(Game.ROM_PATH))
	var sheets := ChrRipper.new(info.chr_rom).export_bank_sheets(Game.ROM_ASSETS_PATH)
	status.text = "%s%s\nRipped %d tile sheets.\nPress Enter to continue." % [info.message, details, sheets]
	print(status.text)
	# Also saved to a text file so the fingerprint can be copied.
	var note := FileAccess.open("user://rom_check.txt", FileAccess.WRITE)
	if note:
		note.store_string(status.text)
		note.close()
	ready_to_continue = true

func _unhandled_input(event: InputEvent) -> void:
	if ready_to_continue and (event.is_action_pressed("pause") or event.is_action_pressed("ui_accept")):
		Game.go_to(Game.SCENE_TITLE)
