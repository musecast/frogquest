extends RefCounted
## Where each little thing is in assets/critters.png (drawn in code, a pixel at a time). Each of its
## pixels is drawn PIXEL px across: the tiles' own (Kenney's art is drawn two pixels a pixel, at the tile
## map's 1.2), so the flowers, the birds and the rest match the grass and the ground. The glow's the
## exception: a soft light, drawn any size.

const PIXEL := 2.4
const RECTS := {
	"bird_sit": Rect2(41, 0, 6, 5),
	"bird_peck": Rect2(48, 0, 6, 5),
	"bird_fly1": Rect2(55, 0, 6, 5),
	"bird_fly2": Rect2(62, 0, 6, 5),
	"butterfly0_open": Rect2(96, 0, 5, 3),
	"butterfly0_shut": Rect2(102, 0, 5, 3),
	"butterfly1_open": Rect2(108, 0, 5, 3),
	"butterfly1_shut": Rect2(114, 0, 5, 3),
	"butterfly2_open": Rect2(120, 0, 5, 3),
	"butterfly2_shut": Rect2(126, 0, 5, 3),
	"leaf0": Rect2(69, 0, 4, 5),
	"leaf1": Rect2(74, 0, 4, 5),
	"leaf_gold": Rect2(79, 0, 4, 5),
	"flower_red": Rect2(17, 0, 5, 7),
	"flower_yellow": Rect2(23, 0, 5, 7),
	"flower_blue": Rect2(29, 0, 5, 7),
	"flower_pink": Rect2(35, 0, 5, 7),
	"flower_bud": Rect2(84, 0, 4, 5),
	"pebble": Rect2(132, 0, 4, 3),
	"rock": Rect2(89, 0, 6, 4),
	"stone_flat": Rect2(137, 0, 6, 3),
	"stone_flat2": Rect2(144, 0, 5, 3),
	"glow": Rect2(0, 0, 16, 16),
}
