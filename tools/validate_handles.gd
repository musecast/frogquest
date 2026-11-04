extends SceneTree
## Who may be called what (MuseSocial.handle_problem): nobody passes for Muse's team or the game, in any
## disguise (adm1n, the_admin, mod_bob, 0fficial, jasonmuse, frog_quest), while names that only have
## those letters in them stay free (badminton_pro, model_frog, devin, amused_frog, frogquestfan). Muse's
## own check (muse_social_handle_problem, in Muse Shelf's repo) should turn down the same.
##   Godot --headless --path . --script res://tools/validate_handles.gd

const RESERVED := [
	"admin", "Admin1", "@admin", "the_admin", "admin_bob", "adm1n", "4dm1n", "a_d_m_i_n", "sysadmin", "administrator",
	"moderator", "mod", "mod_bob", "bob_mod", "mod123", "m0d", "mods", "dev_jay", "devs", "official", "0fficial",
	"official_frog", "unofficial", "frogstaff", "staff", "frog_support", "support", "verified_frog", "developer",
	"team", "team_frog", "owner", "the_owner", "founder", "ceo_frog", "gm_frog", "muse", "muse_fan", "museum",
	"mus3", "m_u_s_e", "jasonmuse", "jason_muse", "the_muse", "realmuse", "frogquest", "frog_quest", "fr0g_qu3st",
	"frogquest2", "help", "api", "apple", "security", "root", "null", "everyone",
]
const FREE := [
	"froggy", "lil_froggy", "avery", "froggy_2009", "badminton_pro", "model_frog", "modern_art", "modest", "devin",
	"dev1n", "mod1fy", "amuse", "amused_frog", "bemused", "steamfrog", "teammate", "helpful", "james", "rapid_frog",
	"downer", "frogquestfan", "frog_quest_fan", "gamer", "leapking", "jump_jump", "x_x_x", "a1b",
]
const SHAPE := ["ab", "1234", "____", "frog-man", "frog man", "a_very_long_handle_123", ""]


func _initialize() -> void:
	var social: Node = root.get_node("MuseSocial")
	var failures: Array[String] = []
	for h in RESERVED:
		var said: String = social.handle_problem(h)
		if said != "That handle is reserved.":
			failures.append("\"%s\" should be reserved, got \"%s\"" % [h, said])
	for h in FREE:
		var said: String = social.handle_problem(h)
		if said != "":
			failures.append("\"%s\" should be free, got \"%s\"" % [h, said])
	for h in SHAPE:
		var said: String = social.handle_problem(h)
		if not said.begins_with("Use 3 to 20"):
			failures.append("\"%s\" should be turned down for its shape, got \"%s\"" % [h, said])
	if failures.is_empty():
		print("Handles test passed (%d reserved, %d free, %d misshapen)." % [RESERVED.size(), FREE.size(), SHAPE.size()])
	else:
		for f in failures:
			push_warning("FAIL: " + f)
		print("Handles test failed (%d)." % failures.size())
	quit(1 if not failures.is_empty() else 0)
