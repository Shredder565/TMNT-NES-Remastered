class_name NesPalette
extends RefCounted
## The NES could show 64 fixed colours, numbered 0 to 63. Games store colour
## NUMBERS; this table turns a number into a colour for the screen.
## It is a general approximation of the console's output, not game data.

const RGB: PackedInt32Array = [
	0x545454, 0x001E74, 0x081090, 0x300088, 0x440064, 0x5C0030, 0x540400, 0x3C1800, 0x202A00, 0x083A00, 0x004000, 0x003C00, 0x00323C, 0x000000, 0x000000, 0x000000,
	0x989698, 0x084CC4, 0x3032EC, 0x5C1EE4, 0x8814B0, 0xA01464, 0x982220, 0x783C00, 0x545A00, 0x287200, 0x087C00, 0x007628, 0x006678, 0x000000, 0x000000, 0x000000,
	0xECEEEC, 0x4C9AEC, 0x787CEC, 0xB062EC, 0xE454EC, 0xEC58B4, 0xEC6A64, 0xD48820, 0xA0AA00, 0x74C400, 0x4CD020, 0x38CC6C, 0x38B4CC, 0x3C3C3C, 0x000000, 0x000000,
	0xECEEEC, 0xA8CCEC, 0xBCBCEC, 0xD4B2EC, 0xECAEEC, 0xECAED4, 0xECB4B0, 0xE4C490, 0xCCD278, 0xB4DE78, 0xA8E290, 0x98E2B4, 0xA0D6E4, 0xA0A2A0, 0x000000, 0x000000,
]

static func color(number: int) -> Color:
	var rgb := RGB[number & 63]
	return Color8((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255)

## Four colours for the ripper from four NES colour numbers.
## Entry 0 is always see-through for sprites.
static func sprite_palette(numbers: Array) -> Array[Color]:
	var out: Array[Color] = [Color(0, 0, 0, 0)]
	for i in range(1, 4):
		out.append(color(int(numbers[i])))
	return out
