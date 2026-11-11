class_name ChrRipper
extends RefCounted
## Turns the raw graphics block (CHR ROM) into images.
##
## One tile = 8x8 pixels = 16 bytes. Bytes 0-7 hold the low bit of each pixel,
## bytes 8-15 hold the high bit. Two bits per pixel gives a colour number 0-3.
## The tile does not store real colours: the game picks a 4-colour palette at
## run time, so we always have to be told which palette to paint with.

const TILE_BYTES := 16
const TILES_PER_BANK := 256   # a 4 KB bank = 256 tiles = one 128x128 sheet
const SHEET_COLUMNS := 16

## Shades of grey used when we do not know the real palette yet.
const PREVIEW_PALETTE: Array[Color] = [
	Color(0, 0, 0, 0), Color(0.35, 0.35, 0.35), Color(0.7, 0.7, 0.7), Color(1, 1, 1),
]

var chr_rom: PackedByteArray

func _init(chr_data: PackedByteArray) -> void:
	chr_rom = chr_data

func tile_count() -> int:
	return chr_rom.size() / TILE_BYTES

func bank_count() -> int:
	return tile_count() / TILES_PER_BANK

## Returns 64 colour numbers (0-3), left to right, top to bottom.
func tile_pixels(index: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(64)
	var address := index * TILE_BYTES
	for y in 8:
		var low := chr_rom[address + y]
		var high := chr_rom[address + y + 8]
		for x in 8:
			var bit := 7 - x
			out[y * 8 + x] = ((low >> bit) & 1) | (((high >> bit) & 1) << 1)
	return out

## Paints one tile onto an image. `index` counts across the WHOLE graphics
## block (0 to 8191 for TMNT), not within a bank.
func draw_tile(image: Image, index: int, pos: Vector2i, palette: Array[Color] = PREVIEW_PALETTE,
		flip_h := false, flip_v := false, skip_transparent := false) -> void:
	if index < 0 or index >= tile_count():
		return
	var pixels := tile_pixels(index)
	var size := image.get_size()
	for y in 8:
		for x in 8:
			var sx := 7 - x if flip_h else x
			var sy := 7 - y if flip_v else y
			var dest := pos + Vector2i(x, y)
			var colour_number := pixels[sy * 8 + sx]
			if skip_transparent and colour_number == 0:
				continue  # leave whatever is already painted there (overlapping sprites)
			if dest.x >= 0 and dest.y >= 0 and dest.x < size.x and dest.y < size.y:
				image.set_pixelv(dest, palette[colour_number])

## One 4 KB bank as a 128x128 picture, 16 tiles across.
func bank_image(bank: int, palette: Array[Color] = PREVIEW_PALETTE) -> Image:
	var image := Image.create(SHEET_COLUMNS * 8, SHEET_COLUMNS * 8, false, Image.FORMAT_RGBA8)
	for i in TILES_PER_BANK:
		var cell := Vector2i(i % SHEET_COLUMNS, i / SHEET_COLUMNS) * 8
		draw_tile(image, bank * TILES_PER_BANK + i, cell, palette)
	return image

## Builds a sprite from a map, in the spirit of the reference project's JSON
## files. `sprite_map` looks like:
##   { "size": [16, 32],
##     "tiles": [ {"x": 0, "y": 0, "index": 1234, "flip_h": false, "flip_v": false}, ... ] }
func build_sprite(sprite_map: Dictionary, palette: Array[Color] = PREVIEW_PALETTE) -> Image:
	var size: Array = sprite_map.get("size", [16, 16])
	var image := Image.create(int(size[0]), int(size[1]), false, Image.FORMAT_RGBA8)
	for tile: Dictionary in sprite_map.get("tiles", []):
		draw_tile(image, int(tile.get("index", 0)), Vector2i(int(tile.get("x", 0)), int(tile.get("y", 0))),
			palette, bool(tile.get("flip_h", false)), bool(tile.get("flip_v", false)))
	return image

## Saves every bank as a PNG in `folder`. Returns how many files were written.
## These go in user://, never in the project, so they are never committed.
func export_bank_sheets(folder: String) -> int:
	DirAccess.make_dir_recursive_absolute(folder)
	var written := 0
	for bank in bank_count():
		if bank_image(bank).save_png(folder.path_join("chr_bank_%02d.png" % bank)) == OK:
			written += 1
	return written
