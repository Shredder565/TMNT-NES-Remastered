class_name SpriteSet
extends RefCounted
## Builds a character's pictures from the player's ROM using a sprite map
## (a JSON file in Resources/AssetRipper/Sprites). The map only says which
## tile goes where; the pixels come from the ROM on the player's machine.

const MAPS_FOLDER := "res://Resources/AssetRipper/Sprites/"

var textures := {}     ## frame name -> ImageTexture
var offsets := {}      ## frame name -> Vector2, where the picture's corner sits
var animations := {}   ## animation name -> { "frames": [...], "ticks": int, "loop": bool }

static var _cache := {}   ## character -> SpriteSet or null, built once per run

## Like load_for, but builds each character's pictures only once.
static func cached(character: String) -> SpriteSet:
	if not _cache.has(character):
		_cache[character] = load_for(character)
	return _cache[character]

## The box (in pixels from the character's own position) that holds every
## frame of an animation.
func bounds(animation: String) -> Rect2:
	var box := Rect2()
	var first := true
	for frame: String in animations.get(animation, {}).get("frames", []):
		if not textures.has(frame):
			continue
		var rect := Rect2(offsets[frame], (textures[frame] as Texture2D).get_size())
		box = rect if first else box.merge(rect)
		first = false
	return box

## Returns null when no ROM has been supplied or the map is missing, so the
## caller can fall back to placeholder art.
static func load_for(character: String) -> SpriteSet:
	var map_path := MAPS_FOLDER + character + ".json"
	if not FileAccess.file_exists(Game.ROM_PATH) or not FileAccess.file_exists(map_path):
		return null
	var info := RomInfo.inspect_file(Game.ROM_PATH)
	if not info.accepted:
		return null
	var map: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	if typeof(map) != TYPE_DICTIONARY:
		return null
	return build(map, ChrRipper.new(info.chr_rom))

static func build(map: Dictionary, ripper: ChrRipper) -> SpriteSet:
	var sprite_set := SpriteSet.new()
	var tile_height := int(map.get("tile_height", 8))
	var palettes := {}
	for key: String in map.get("palettes", {}):
		palettes[int(key)] = NesPalette.sprite_palette(map["palettes"][key])
	var frames: Dictionary = map.get("frames", {})
	for frame_name: String in frames:
		var tiles: Array = frames[frame_name]
		if tiles.is_empty():
			continue
		# Find the smallest box that holds every tile of this frame.
		var box := Rect2i(int(tiles[0].x), int(tiles[0].y), 8, tile_height)
		for tile: Dictionary in tiles:
			box = box.merge(Rect2i(int(tile.x), int(tile.y), 8, tile_height))
		var image := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		# Earlier entries are drawn on top, as on the console, so paint last first.
		for i in range(tiles.size() - 1, -1, -1):
			var tile: Dictionary = tiles[i]
			var palette: Array[Color] = palettes.get(int(tile.get("palette", 0)), ChrRipper.PREVIEW_PALETTE)
			var flip_h := bool(tile.get("flip_h", false))
			var flip_v := bool(tile.get("flip_v", false))
			var pos := Vector2i(int(tile.x), int(tile.y)) - box.position
			# A tall (8x16) sprite is two tiles stacked; flipping it upside down swaps them.
			for part in tile_height / 8:
				var source := (tile_height / 8 - 1 - part) if flip_v else part
				ripper.draw_tile(image, int(tile.index) + source, pos + Vector2i(0, part * 8), palette, flip_h, flip_v, true)
		sprite_set.textures[frame_name] = ImageTexture.create_from_image(image)
		sprite_set.offsets[frame_name] = Vector2(box.position)
	sprite_set.animations = map.get("animations", {})
	return sprite_set

## The frame name to show `tick` updates into an animation.
func frame_at(animation: String, tick: int) -> String:
	var anim: Dictionary = animations.get(animation, {})
	var frames: Array = anim.get("frames", [])
	if frames.is_empty():
		return ""
	var step := tick / maxi(int(anim.get("ticks", 1)), 1)
	if bool(anim.get("loop", true)):
		return frames[step % frames.size()]
	return frames[mini(step, frames.size() - 1)]

## How many updates a non-looping animation lasts.
func length(animation: String) -> int:
	var anim: Dictionary = animations.get(animation, {})
	return int(anim.get("frames", []).size()) * maxi(int(anim.get("ticks", 1)), 1)
