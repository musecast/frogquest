extends RefCounted
## How hard the climb is: how much of the jump the aim line shows (AimLine.gd). Normal, the default, shows
## the jump past its peak; Easy all of it, to where he'll land; Hard just its start. Beat the game on Hard
## (the whole climb on Hard or OG, from its first jump to the top) and OG mode's yours: the very first Frog
## Quest's aim line. The choice is kept with the wardrobe (MusicManager.difficulty); each climb remembers
## the easiest it was played on (player.gd: easiest_rank).

const MODES := ["easy", "normal", "hard", "og"]  # (easiest first)
const DEFAULT := "normal"
const NAMES := {"easy": "Easy", "normal": "Normal", "hard": "Hard", "og": "OG"}
const ABOUT := {
	"easy": "The whole jump shown, right to where you'll land.",
	"normal": "The jump shown past its peak.",
	"hard": "Just the start of the jump.",
	"og": "The very first Frog Quest's aim line. Good luck.",
}
const OG_TITLE := "OG Mode Unlocked!"
const OG_BLURB := ("This is the aim line from the very first Frog Quest, back in 2024: one thin pink line. "
	+ "It shows which way you're pulling... and that's about it. People really climbed the whole World Tree "
	+ "with this. We believe in you. Mostly.")
const HARD_FROM_START := "(Hard counts from the start of a climb)"


static func rank(mode: String) -> int:
	var i := MODES.find(mode)
	return i if i >= 0 else MODES.find(DEFAULT)


## The one chosen now (OG only once it's unlocked).
static func current() -> String:
	var mode := str(MusicManager.difficulty)
	if mode == "og" and not MusicManager.og_unlocked:
		return DEFAULT
	return mode if mode in MODES else DEFAULT


## The ones to choose from.
static func choices() -> Array:
	return MODES if MusicManager.og_unlocked else MODES.slice(0, 3)
