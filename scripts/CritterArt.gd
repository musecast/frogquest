extends RefCounted
## Where each little thing is in assets/critters.png (drawn in code, a pixel at a time). Each of its
## pixels is drawn PIXEL px across: the tiles' own (Kenney's art is drawn two pixels a pixel, at the tile
## map's 1.2), so the flowers, the birds and the rest match the grass and the ground. The glow's the
## exception: a soft light, drawn any size.

const PIXEL := 2.4
const RECTS := {
	"bird_sit": Rect2(84, 0, 6, 5),
	"bird_peck": Rect2(91, 0, 6, 5),
	"bird_fly1": Rect2(98, 0, 6, 5),
	"bird_fly2": Rect2(105, 0, 6, 5),
	"butterfly0_open": Rect2(145, 0, 5, 3),
	"butterfly0_shut": Rect2(151, 0, 5, 3),
	"butterfly1_open": Rect2(157, 0, 5, 3),
	"butterfly1_shut": Rect2(163, 0, 5, 3),
	"butterfly2_open": Rect2(169, 0, 5, 3),
	"butterfly2_shut": Rect2(175, 0, 5, 3),
	"leaf0": Rect2(112, 0, 4, 5),
	"leaf1": Rect2(117, 0, 4, 5),
	"leaf_gold": Rect2(122, 0, 4, 5),
	"flower_red": Rect2(24, 0, 5, 7),
	"flower_yellow": Rect2(30, 0, 5, 7),
	"flower_blue": Rect2(36, 0, 5, 7),
	"flower_pink": Rect2(42, 0, 5, 7),
	"flower_bud": Rect2(127, 0, 4, 5),
	"pebble": Rect2(181, 0, 4, 3),
	"rock": Rect2(132, 0, 6, 4),
	"stone_flat": Rect2(186, 0, 6, 3),
	"stone_flat2": Rect2(193, 0, 5, 3),
	"clod": Rect2(230, 0, 2, 1),
	"clod2": Rect2(220, 0, 2, 2),
	"clod3": Rect2(199, 0, 2, 3),
	"dirt_stone": Rect2(202, 0, 5, 3),
	"bone": Rect2(208, 0, 6, 3),
	"fossil": Rect2(139, 0, 5, 4),
	"worm": Rect2(223, 0, 6, 2),
	"root": Rect2(48, 0, 3, 7),
	"root2": Rect2(52, 0, 4, 6),
	"root_long": Rect2(17, 0, 6, 9),
	"specks1": Rect2(57, 0, 8, 6),
	"specks2": Rect2(66, 0, 8, 6),
	"specks3": Rect2(75, 0, 8, 6),
	"clods": Rect2(215, 0, 4, 3),
	"glow": Rect2(0, 0, 16, 16),
}
