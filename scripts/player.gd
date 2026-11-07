@tool
extends CharacterBody2D

@export_tool_button("Test Hat Notification", "Notification") var _dbg_hat_notif: Callable
@export_tool_button("Test Skin Notification", "Notification") var _dbg_skin_notif: Callable

func _init() -> void:
	_dbg_hat_notif = Callable(self, &"_test_hat_notif")
	_dbg_skin_notif = Callable(self, &"_test_skin_notif")

@export var debug_unlock_crown: bool = false
@export var debug_unlock_golden_skin: bool = false
@export var debug_unlock_grayscale_skin: bool = false
@export var debug_unlock_negative_skin: bool = false
@export var debug_unlock_blackcrown: bool = false
@export var debug_unlock_wizhat: bool = false
@export var debug_unlock_cakehat: bool = false
@export var debug_beat_game: bool = false

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
## Where the ending's camera comes to rest under the win screen (from where he's held up top, in his own
## scale: 1.2): his bedroom, framed as the game frames him when he wakes up there again after "Thanks for
## playing!". The ending's last keyframe (the "end" animation) is the same.
const END_IN_BEDROOM := Vector2(-1260.67, 7204)
var bestRun = 1
var jumpCount = 0
## The climb's time, as played: the game's own steps, counted only while he's climbing (not on the title,
## waking, paused, won, or while the game's away: then its steps don't run). Never the clock, which goes on
## while the game's put away. hours, minutes and seconds are split off it (_split_play_time).
var play_secs := 0.0
var _safe_spot := Vector2.INF  # (the last place saved below the finale: a save up in it puts him back there)
var _going_home := false  # ("Thanks for playing!" pressed: the curtain on its way down)
const WIN_FADE := 1.4  # (each of the win screen's lines easing in)
const WIN_STAGGER := 0.6  # (one after another)
const HOME_FADE := 0.9  # ("Thanks for playing!": the screen easing to black, and the title easing up out of it)
var tempVelocityx = 0.0
var minutes = 0
var seconds = 0
@export var max_y_position: float = 500.0 # The Y position at which the opacity should be 100%
var fade_duration = 1.0 # Duration for fading in seconds
var bangersCount = 0
var songTrigger = 70
@export var has_lantern = false
@export var has_key = false
var music_bus = AudioServer.get_bus_index("Master")
var SpeedrunMode = false
var easiest_rank := -1  # the easiest difficulty this climb's been played on (Difficulty.gd's MODES)
var finalTime
var finalTimeBool = 0
var finalbuttonBool = 0
var hours = 0
var lanternbool = 0

var save_path = "user://save_game.save"
var was_airborne = false
var key_node = null
var key_trail_pos = Vector2.ZERO
var key_last_dir = -1.0
var _resize_timer: SceneTreeTimer = null
var _just_loaded: bool = false
var _end_triggered: bool = false
var _active_wardrobe: CanvasLayer = null
var _wiz_tween: Tween = null
var _wiz_sprite_base_y: float = 0.0
var _zoom_tween: Tween = null
var _froggy_head: Script = null  # (scripts/FroggyHead.gd, loaded when his hat's first placed)
var _crt_normal_volume: float = -20.0
## Tracks bottom banner suppressed while paused in horizontal mode (restore on unpause).
var _banner_hidden_for_landscape_pause: bool = false
var _title_glide: Tween = null  # (the title moving to where it now goes: _place_title)
var _title_laid_out_for := Vector2.ZERO  # (the screen size the title was last laid out for)
## Waking up at home (Main.wake_up): asleep in his beanbag, then up as the TV has its say. While he's
## waking there's no jumping (Trajectory) and the clock's held, till the tutorial's up.
var waking := false
var asleep := false
var _from_the_dark := false  # (the frog god's intro has just cut to black: the game fades in on him)
var _zzz: Node2D = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var highScore
var currentHeight
var _fall_top := 0.0  # (the highest he's been since he last stood: a fall's how far below that he lands)
const GHOST_FALL := 150.0  # (a fall this big, in currentHeight: the Ghost skin)
const LONG_FALL := 45.0  # (a fall this big, in currentHeight, a tenth of a pixel: he lands hard, with a "!". A mushroom throws him ~33)
const SLEEPY := 45.0  # (seconds left alone, standing still, before he nods off)
const DUST := Color(0.93, 0.89, 0.80)  # (the dust he kicks up, jumping and landing)
## Landed hard: seconds left of him stuck there shivering (no jumping till it's done), and the shiver's
## own clock.
var stunned := 0.0
var _shiver_t := 0.0
var _idle_s := 0.0
var _fall_air: AudioStreamPlayer = null  # (the rush of air as he falls a long way)
var _napping := false  # (nodded off from being left alone: a touch wakes him)

func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])


func _ready():
	if Engine.is_editor_hint():
		return  # (a tool script for the test buttons above: the game itself only starts in the game)
	_trace("Player ready start")

	get_tree().root.content_scale_size = Vector2i(480, 270)
	$Sprite2D.frame_changed.connect(_place_hats)
	$Sprite2D.animation_changed.connect(_place_hats)

	currentHeight = (-position.y - 472) /10
	highScore = currentHeight

	load_game()
	if easiest_rank < 0:  # (a new climb: the difficulty chosen now)
		var difficulty: GDScript = load("res://scripts/Difficulty.gd")
		easiest_rank = difficulty.rank(difficulty.current())
	_just_loaded = true
	_trace("Player ready after load_game")
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func(): _just_loaded = false)

	# Debug unlocks — toggle in the Godot Inspector
	if debug_unlock_crown:
		MusicManager.froggyCrown = 1
		MusicManager.save_wardrobe()
	if debug_unlock_golden_skin:
		if "golden_skin" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("golden_skin")
		MusicManager.save_wardrobe()
	if debug_unlock_grayscale_skin:
		if "grayscale_skin" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("grayscale_skin")
		MusicManager.save_wardrobe()
	if debug_unlock_negative_skin:
		if "negative_skin" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("negative_skin")
		MusicManager.save_wardrobe()
	if debug_unlock_blackcrown:
		if "blackcrown" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("blackcrown")
		MusicManager.save_wardrobe()
	if debug_unlock_wizhat:
		if "wizhat" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("wizhat")
		MusicManager.save_wardrobe()
	if debug_unlock_cakehat:
		if "cakehat" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("cakehat")
		MusicManager.save_wardrobe()
	if debug_beat_game:
		MusicManager.game_beaten = true
		MusicManager.save_wardrobe()

	_apply_equipped_cosmetics()
	_restore_world_pickups()
	var wiz_area := get_node_or_null("../WizArea2D")
	if wiz_area and not wiz_area.body_exited.is_connected(_on_wiz_area_2d_body_exited):
		wiz_area.body_exited.connect(_on_wiz_area_2d_body_exited)

	_build_title_menu()
	_show_logo()

	get_viewport().size_changed.connect(_on_viewport_resized)
	$PauseScreen.visibility_changed.connect(_on_pause_screen_visibility_changed)
	AdsManager.connect("ads_removed_changed", _apply_ui_layout)
	MuseAccount.changed.connect(_on_muse_account_changed)

	_setup_crt_state()
	if MusicManager.game_beaten:
		_activate_beaten_crt()
	add_to_group("banner_reserve_ui")
	# (notifications come down to just under these: MusicManager's toasts)
	$CanvasLayer/TouchScreenButtonPause/ColorRect.add_to_group("corner_hud")
	$CanvasLayer/MarginContainer/VBoxContainer.add_to_group("corner_hud")
	# Hide title screen immediately so buttons never appear at their .tscn default sizes.
	# _initial_title_layout() fires before the first rendered frame and shows the
	# title screen only after layout is already correct.
	$titlescreen.visible = false
	call_deferred("_initial_title_layout")
	$Camera2D/AnimationPlayer.last_keyframe_reached.connect(_on_end_animation_finished)

	await get_tree().create_timer(0.5, true, false, true).timeout
	_apply_ui_layout()
	_trace("Player ready end")


func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	# Hold backspace to run end credits at 8x speed.
	if ($Camera2D/AnimationPlayer.current_animation == "end" or finalbuttonBool == 1) \
			and not $PauseScreen.visible:
		var _spd := 16.0 if Input.is_key_pressed(KEY_BACKSPACE) else 1.0
		Engine.time_scale = _spd
		$winscreen/goodbyefroggy.pitch_scale = _spd

	if Input.is_action_just_pressed("mute_music"):
		pass
		#$sadTimer.stop()
		#$"../Environmental Audio/Classical Bangers".stop()
		#$"../Environmental Audio/Classical Bangers2".stop()
		#$"../Environmental Audio/Classical Bangers3".stop()
		#$"../finale/Control/froggod".stop()
		#$winscreen/goodbyefroggy.stop()
	
	
	currentHeight = (-position.y - 472) /10
	
	if Engine.time_scale == 1.0 and $Trajectory.endGame == 0 and not waking:
		play_secs += delta
	_split_play_time()
		
	
	if $Trajectory.endGame == 0:
		$CanvasLayer/TouchScreenButtonPause.visible = true
	
		
	if currentHeight > highScore:
		highScore = currentHeight
		bestRun = 1
	
	
	if currentHeight > 779:
		$CanvasLayer.visible = false

			
	elif currentHeight >= 0:
		#if $Trajectory.endGame == 0:
			#$"CanvasLayer/current height".visible = true
		$"../World Sprites/tutorial".visible = false
		$"../World Sprites/tutorial2".visible = false
		$"../World Sprites/tutorial3".visible = false
		$"../World Sprites/tutorial4".visible = false
		
	if currentHeight > 787:
		$Trajectory.endGame = 1
		position.y = -8382
		position.x = 2804
		reset_physics_interpolation()
		velocity = Vector2(0,0)
		$"../finale/finale walls/toshow".visible = false
		$"../Blackfaderect".visible = false
		$"../World Sprites/tutorial".visible = false
		$"../World Sprites/tutorial2".visible = false
		$"../World Sprites/tutorial3".visible = false
		$"../World Sprites/tutorial4".visible = false
		if not _end_triggered:
			_end_triggered = true
			await get_tree().create_timer(1.0).timeout
			$Camera2D/AnimationPlayer.play("end")
			if finalTimeBool == 0:
				# THIS HAPPENS ONCE WHEN GAME ENDS
				finalTime = play_time_text()
				finalTimeBool =1
				MusicManager.unlock("shadow")  # (he's beaten it: the frog god's own shadow is his to wear)
				if int(hours) == 0:
					MusicManager.unlock("halo")  # (and in under an hour: the Halo)

				$"../frogNPC1".position = Vector2(3038, -1236)
				$"../frogNPC1/Jonathan-dodd-hut-wo-details".visible = false

				$"../frogNPC2".position = Vector2(2541, -1750)
				$"../frogNPC2/wiztheme".queue_free()

				$"../frogNPC5".position = Vector2(3096, -4573)
				$"../frogNPC5/wiztheme2".queue_free()

				await get_tree().create_timer(3.0).timeout
				$winscreen/goodbyefroggy.play()

		
	if ($Camera2D/AnimationPlayer.is_playing and $Camera2D/AnimationPlayer.current_animation) \
			or finalbuttonBool == 1:
		position.y = -8382
		position.x = 2804
		reset_physics_interpolation()
	

		
	_nap(delta)
	_fall_sound(delta)
	_shivering(delta)

	# Add the gravity.
	if not is_on_floor():
		if not was_airborne:
			_fall_top = currentHeight
		_fall_top = maxf(_fall_top, currentHeight)  # (the highest he's been this time in the air)
		was_airborne = true
		velocity.y += gravity * delta
		$Sprite2D.play("airborne")
		$Shadow.play("airborne")
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, 0.0, 10.0 * delta)
		$Shadow.rotation = $Sprite2D.rotation

		if is_on_wall():
			velocity.x = -tempVelocityx


	if is_on_floor():
		if was_airborne:
			was_airborne = false
			var fell: float = _fall_top - currentHeight
			if fell >= GHOST_FALL:
				MusicManager.unlock("ghost")  # (a really big fall: the Ghost skin)
			if fell >= LONG_FALL:
				_exclaim()  # (that was a long way down)
				_land_hard(fell)
			save_game()
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, get_floor_normal().angle() + PI / 2, 25.0 * delta)
		$Shadow.rotation = $Sprite2D.rotation

		if $Trajectory.mousePath.length() > 200:
			$Sprite2D.play("prejump")
		else:	
			if currentHeight < highScore - songTrigger and bestRun == 1 and not _just_loaded:
				songTrigger += 15
				$sadTimer.start()
				bestRun = 0
				save_game()  # persist bestRun=0 now so a reset mid-song won't retrigger
				AdsManager.on_story_break()  # (a big fall: a natural break for a full-screen ad, now and then)
			
			if $sadTimer.is_stopped():
				$Sprite2D.play("default")
				$Shadow.play("default")
			else:
				$Sprite2D.play("sad")
				if not $"../finale/Control/froggod".playing:
					if not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount  == 0:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers".play(0.0)
						bangersCount = 1
						save_game()
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount == 1:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers2".play(0.0)
						bangersCount = 2
						save_game()
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount == 2:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers3".play(0.0)
						bangersCount = 0
						save_game()
					
				

				
		
		
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		
	if has_lantern and Input.is_action_just_pressed("ui_light"):
		if $FrogLantern.visible:
			$FrogLantern.visible = false
			$FrogLantern/lanternout.play()
			fade_lantern(0.0)
		else:
			$FrogLantern.visible = true
			$FrogLantern/lanternignite.play()
			fade_lantern(1.0)
			
			
	
	tempVelocityx = velocity.x/2.5
	
	# Scale the current height from 0-779 to 0-1000
	var scaledHeight = int((currentHeight / 779.0) * 1000)
	
	$"CanvasLayer/MarginContainer/VBoxContainer/current height".text = ("height: " + str(int(scaledHeight)) + "mm")
	$"CanvasLayer/high score".text = str(int(highScore))
	$CanvasLayer/MarginContainer/VBoxContainer/jumpcount.text = ("jumps: " + str(int(jumpCount)))
	
	if Engine.time_scale != 0.05:
		$CanvasLayer/MarginContainer/VBoxContainer/time.text = "time: " + play_time_text()
	
	
	fade_darkness()

	if has_key and key_node and is_instance_valid(key_node):
		if velocity.x != 0:
			key_last_dir = sign(velocity.x)
		var trail_offset = Vector2(-key_last_dir * 30, 0)
		key_trail_pos = lerp(key_trail_pos, position + trail_offset, delta * 5.0)
		key_node.position = key_trail_pos

	_place_hats()

	move_and_slide()


func _on_area_2d_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	if body != self:
		return
	velocity = Vector2(-500, -400)
	$"../frogNPC3/campfire/Area2D/burnSound".play()
	
	
	

func fade_lantern(target_alpha):
	var t := create_tween()
	t.tween_property($FrogLantern, "modulate:a", target_alpha, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func fade_darkness():
	if finalTimeBool == 1:
		$"../Blackfaderect".visible = false
		return
	var heightCheck = currentHeight - 142
	var darknessHeight = (clamp(heightCheck, 0, 100)/100) * 2
	
	if darknessHeight > 1:
		darknessHeight = 1
	


	if currentHeight > 313:
		$"../Darkness".visible = false
		$"../Blackfaderect".visible = true
		$FrogLantern.visible = false
	elif currentHeight > 148:
		$"../Blackfaderect".visible = false
		$"../Darkness".visible = true
		#RGB VALUES ARE FROM 0 TO 1 DUHHHHHH
		$"../Darkness".color.r = 1 - darknessHeight
		$"../Darkness".color.g = 1 - darknessHeight
		$"../Darkness".color.b = 1 - darknessHeight
		#print($"../Darkness".color.r)
	else:
		$FrogLantern.visible = false
		$"../Darkness".visible = false
		$"../Blackfaderect".visible = false

	#AUTO LANTERN
	if has_lantern == true and currentHeight > 174 and currentHeight < 313:
		if $FrogLantern.visible == false:
			$FrogLantern/lanternignite.play()
			$FrogLantern.visible = true
			lanternbool = 1
	else:
		if lanternbool == 1:
			$FrogLantern.visible = false
			$FrogLantern/lanternout.play()
			lanternbool = 0
		else:
			$FrogLantern.visible = false


func _on_area_2_dkeyhole_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("keyhole attempt")
	if has_key == true:
		print("keyhole success")
		$"..".gateDestroyed = 1
		$".".has_key = false
		if key_node and is_instance_valid(key_node):
			key_node.queue_free()
		key_node = null
		$"../World Sprites/Keyhole/Area2Dkeyholeblocker".queue_free()
		$"../World Sprites/Keyhole".visible = false
		$"../World Sprites/Keyhole/havekey".play()
		$"../frogNPC6/pathopen".play()
		MusicManager.unlock("pattern_stripes")  # (the gate open: the Stripes pattern)
		await get_tree().create_timer(0.5).timeout
		$"../World Sprites/Keyhole".queue_free()
	else:
		$"../World Sprites/Keyhole/donthavekey".play()
		print("keyhole fail")


func _on_restart_button_pressed():
	$frogaim.play()
	Engine.time_scale = 1.0
	AdsManager.on_story_break()  # (leaving for the title: a natural break for a full-screen ad, now and then)
	get_tree().reload_current_scene()
	

## The speedrun timer (height, time and jumps up in the corner) on or off, kept in the save.
func set_speedrun(on: bool) -> void:
	SpeedrunMode = on
	save_game()
	_apply_speedrun_visibility()


func _apply_speedrun_visibility() -> void:
	$"CanvasLayer/MarginContainer/VBoxContainer/current height".visible = SpeedrunMode
	$CanvasLayer/MarginContainer/VBoxContainer/time.visible = SpeedrunMode
	$CanvasLayer/MarginContainer/VBoxContainer/jumpcount.visible = SpeedrunMode



func _on_blockedpath_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	if body != self:
		return
	velocity = Vector2(500, -300)
	$"../Environmental Audio/pathBreaking".play()
	$"../World Sprites/Blockedpath".queue_free()


func _on_button_pressed():
	if not MusicManager.look_made:
		# (his first climb: what does he look like? then he wakes, and climbs; START's own sounds are the cut's)
		_meet_the_frog_god(_on_button_pressed, false)
		return
	MusicManager.tell_held_news()  # (what the last win earned, said now: not over its win screen)
	$Trajectory.endGame = 0
	$".".visible = true
	$titlescreen. visible = false
	$"../finale/Control/frogappear".play()
	$"../frogNPC6/pathopen".play()
	_apply_speedrun_visibility()
	if currentHeight < 0:
		$"../World Sprites/tutorial".visible = true
		$"../World Sprites/tutorial2".visible = true
		$"../World Sprites/tutorial3".visible = true
		$"../World Sprites/tutorial4".visible = true
	if _waking_at_home():
		get_parent().wake_up(_from_the_dark)  # (asleep in his beanbag, the TV off: it comes on, he wakes...)
	_from_the_dark = false


## A climb starting at home, his own: by the TV (where a new one starts), the game not won yet, not with
## friends (up the tree with them he's straight off). Then he wakes up there first (Main.wake_up).
func _waking_at_home() -> bool:
	var tv := get_node_or_null("../Musecrtquarterview") as Node2D
	return tv != null and get_parent().has_method("wake_up") and not MusicManager.game_beaten and not Party.in_run 		and global_position.distance_to(tv.global_position) < 220.0


## Asleep (his eyes shut, little z's drifting up off him: Zzz) or not.
func set_asleep(on: bool) -> void:
	asleep = on
	_shut_eyes(on)
	if on and _zzz == null:
		_zzz = load("res://scripts/Zzz.gd").new()
		_zzz.anchor = Vector2(6.0, -9.0)  # (just over the top of his head)
		add_child(_zzz)
	elif not on and _zzz != null:
		_zzz.stop()
		_zzz = null


func _shut_eyes(on: bool) -> void:
	var mat := $Sprite2D.material as ShaderMaterial
	if mat != null and mat.shader != null and mat.shader.resource_path.ends_with("froggy_look.gdshader"):
		mat.set_shader_parameter("eyes_shut", on)


## Awake: his eyes open, and he starts up out of his beanbag a little (squashed, stretched, back), a "!"
## popping up over him.
func wake() -> void:
	set_asleep(false)
	var body: Node2D = $Sprite2D
	var base := Vector2(0.76, 0.76)  # (his size, as player.tscn has it)
	var hop := create_tween()
	hop.tween_property(body, "scale", base * Vector2(1.16, 0.84), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hop.tween_property(body, "scale", base * Vector2(0.9, 1.14), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hop.tween_property(body, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_exclaim()


## Left alone long enough (SLEEPY), standing still, he nods off: his eyes shut, z's drifting up off him.
## A touch, or anything moving him, and he's awake again (and the touch is his jump as ever).
func _nap(delta: float) -> void:
	var playing: bool = $Trajectory.endGame == 0 and not waking and Engine.time_scale > 0.5 and not $PauseScreen.visible
	var still: bool = is_on_floor() and velocity.length() < 1.0 and not Input.is_action_pressed("ui_mouse")
	if _napping:
		if not playing or not still or Input.is_action_just_pressed("ui_mouse"):
			_napping = false
			_idle_s = 0.0
			set_asleep(false)
		return
	if playing and still:
		_idle_s += delta
		if _idle_s >= SLEEPY:
			_napping = true
			set_asleep(true)
	else:
		_idle_s = 0.0


## A red "!" popping up just over his head with a little chirp (woken up; landed after a long fall), then
## fading. Its own (taking nothing of his but where his head is: never stretched with him), at three whole
## pixels to each of the font's, crisp.
func _exclaim() -> void:
	var holder: Node2D = load("res://scripts/Follow.gd").new()
	holder.name = "Exclaim"
	holder.z_index = 25
	holder.z_as_relative = false
	holder.anchor = Vector2(3.0, -21.0)
	add_child(holder)
	var mark := Label.new()
	mark.text = "!"
	load("res://scripts/UIStyle.gd").style_label(mark, 16, Color(1.0, 0.24, 0.2))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.pivot_offset = (mark.get_minimum_size() * 0.5).round()  # (it pops up from its middle)
	mark.position = -mark.pivot_offset
	mark.scale = Vector2(0.05, 0.05)
	holder.add_child(mark)
	var pop := mark.create_tween()
	# (up past its size, and back to it: a pop, eased all the way; a back-curve from nothing would turn it over)
	pop.tween_property(mark, "scale", Vector2(3.35, 3.35), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pop.tween_property(mark, "scale", Vector2(3.0, 3.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pop.tween_interval(1.0)
	pop.tween_property(mark, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pop.tween_callback(holder.queue_free)
	_sound("res://assets/exclaim.wav", -9.0, randf_range(0.96, 1.04))


## A sound, once, from him (not where he is: he's always where the camera is).
func _sound(path: String, db: float, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = &"FX"
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Landing hard, after a long fall (`fell`, in currentHeight): a thud (the further, the deeper and louder),
## and dust shooting out either side of him.
func _land_hard(fell: float) -> void:
	var hard := clampf((fell - LONG_FALL) / 120.0, 0.0, 1.0)
	_sound("res://assets/land_hard.wav", lerpf(-12.0, -3.0, hard), lerpf(1.08, 0.86, hard))
	_dust(to_global(Vector2(0.0, 11.0)), int(lerpf(12.0, 26.0, hard)), lerpf(1.0, 1.7, hard), 82.0)
	# (and there he stays a moment, squashed flat, then shivering: no jumping till he's shaken it off)
	stunned = lerpf(0.6, 0.95, hard)
	_shiver_t = 0.0
	var body: Node2D = $Sprite2D
	var base := Vector2(0.76, 0.76)
	var squash := create_tween()
	squash.tween_property(body, "scale", base * Vector2(1.28, 0.74), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	squash.tween_property(body, "scale", base * Vector2(1.12, 0.9), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	squash.tween_property(body, "scale", base, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


## Stuck after a hard landing (stunned): a little shiver side to side, quick and dying away, then still.
func _shivering(delta: float) -> void:
	var body: Node2D = $Sprite2D
	if stunned <= 0.0:
		if body.position.x != 0.0:
			body.position.x = 0.0
		return
	stunned = maxf(0.0, stunned - delta)
	_shiver_t += delta
	var shake := 1.0 if int(_shiver_t * 28.0) % 2 == 0 else -1.0
	body.position.x = 0.0 if stunned <= 0.0 else shake * (1.0 if stunned > 0.25 else 0.5)


## Free to jump: not waking up at home, not stuck shivering after a hard landing (Trajectory asks).
func can_act() -> bool:
	return not waking and stunned <= 0.0


## A little puff of dust from under him as he jumps (Trajectory, as he lets go).
func jumped() -> void:
	_dust(to_global(Vector2(0.0, 11.0)), 7, 0.45, 70.0)


## Dust from `at`: `amount` specks, `power` how hard they fly, `spread` how far round from straight up.
func _dust(at: Vector2, amount: int, power: float, spread: float) -> void:
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.amount = amount
	dust.lifetime = 0.45 + 0.35 * power
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = spread
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(7.0, 1.0)
	dust.initial_velocity_min = 45.0 * power
	dust.initial_velocity_max = 120.0 * power
	dust.gravity = Vector2(0.0, 320.0)
	dust.damping_min = 30.0
	dust.damping_max = 60.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(DUST, 0.95))
	fade.set_color(1, Color(DUST, 0.0))
	dust.color_ramp = fade
	dust.z_index = 22
	dust.z_as_relative = false
	get_parent().add_child(dust)
	dust.global_position = at
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


## The rush of air as he falls a long way: in once he's well into a fall and going fast, louder and
## higher the faster he goes, gone the moment he lands.
func _fall_sound(delta: float) -> void:
	var want := -60.0
	if not is_on_floor() and velocity.y > 760.0 and _fall_top - currentHeight > 40.0 and Engine.time_scale > 0.5:
		want = lerpf(-24.0, -7.0, clampf((velocity.y - 760.0) / 900.0, 0.0, 1.0))
	if _fall_air == null:
		if want <= -59.0:
			return
		_fall_air = AudioStreamPlayer.new()
		_fall_air.stream = load("res://assets/fall_wind.wav")
		_fall_air.bus = &"FX"
		_fall_air.volume_db = -60.0
		add_child(_fall_air)
	var rate := 40.0 if want > _fall_air.volume_db else 160.0  # (in as the fall picks up; cut off on landing)
	_fall_air.volume_db = move_toward(_fall_air.volume_db, want, rate * delta)
	_fall_air.pitch_scale = lerpf(0.85, 1.3, clampf((velocity.y - 760.0) / 900.0, 0.0, 1.0))
	if _fall_air.volume_db > -58.0 and not _fall_air.playing:
		_fall_air.play()
	elif _fall_air.volume_db <= -59.5 and _fall_air.playing:
		_fall_air.stop()
	


## How the game starts the first time (no title: `fade_in`, out of the dark), and before anything else he
## plays while he hasn't made his froggy (a climb, Endless, or Play Together): the frog god asks what he
## looks like (CreatorIntro). At its cut to black (with the finale's closing-in sound: `cut_sound`, unless
## what comes next plays it) on he goes (`then`: the climb, Endless, or Play Together's menu), and the
## TV's static (quiet till then) comes up as he fades in.
func _meet_the_frog_god(then: Callable, cut_sound := true, fade_in := false) -> void:
	if get_node_or_null("CreatorIntro"):
		return
	$titlescreen.visible = false
	var intro: CanvasLayer = load("res://scenes/CreatorIntro.gd").new()
	intro.cut_sound = cut_sound
	intro.fade_in = fade_in
	intro.slow_end = then == _on_button_pressed  # (into his bedroom, asleep: a long black, a slow fade)
	add_child(intro)
	var tv := get_node_or_null("../Musecrtquarterview/AudioStreamPlayer2D") as AudioStreamPlayer2D
	var tv_db := tv.volume_db if tv else 0.0
	if tv:
		tv.volume_db = -80.0
	intro.tree_exited.connect(func() -> void:
		if is_instance_valid(tv) and tv.volume_db <= -79.0 and not waking:
			tv.volume_db = tv_db)  # (gone some other way: the static as it was)
	intro.done.connect(func() -> void:
		_apply_equipped_cosmetics()
		_refresh_title_menu()
		_from_the_dark = true
		then.call()
		_from_the_dark = false
		if waking:
			return  # (he's asleep at home, the TV off: it comes on by itself, Main.wake_up)
		if is_instance_valid(tv):
			var up := tv.create_tween()
			up.tween_interval(intro.hold() * 0.8)
			up.tween_callback(func() -> void: tv.volume_db = -30.0)
			up.tween_property(tv, "volume_db", tv_db, intro.fade() + 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


func _on_thanksforplaying_timer_timeout():
	var thanks: Button = $winscreen/thanksforplayingButton
	thanks.modulate.a = 0.0
	thanks.visible = true
	create_tween().tween_property(thanks, "modulate:a", 1.0, WIN_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Home: the climb done (its save gone, the crown his), the screen easing to black, and the game starting
## again under it: the title comes up out of the black (_initial_title_layout), the goodbye song going on.
func _on_thanksforplaying_button_pressed():
	if _going_home:
		return
	_going_home = true
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("Save file deleted on game complete.")
	MusicManager.froggyCrown = 1
	MusicManager.equipped_hat = "froggycrown"
	MusicManager.game_beaten = true
	MusicManager.save_wardrobe()
	await MusicManager.curtain(1.0, HOME_FADE).finished
	MusicManager.MusicPosition = $winscreen/goodbyefroggy.get_playback_position()
	get_tree().reload_current_scene()
	Engine.time_scale = 1.0


## SETTINGS in the pause menu: SettingsScreen.gd over it (it stays as it is, behind).
func _on_settings_button_pressed():
	$frogaim.play()
	_open_settings()


## SETTINGS on the title screen: the title comes back when they're closed.
func _on_title_settings_pressed() -> void:
	$frogaim.play()
	$titlescreen.visible = false
	_open_settings().closed.connect(func() -> void:
		$titlescreen.visible = true
		_apply_ui_layout()
	)


func _open_settings() -> CanvasLayer:
	var screen: CanvasLayer = load("res://scenes/SettingsScreen.gd").new()
	screen.player = self
	add_child(screen)
	screen.closed.connect(screen.queue_free)
	return screen


func _on_resume_button_pressed():

	$frogjump.pitch_scale = randf_range(0.8, 1.2)
	$frogjump.play()
	#GAME IS UNPAUSED HERE
	$PauseScreen.visible=false
	Engine.time_scale = 1.0

## How hard a drag throws him: the settings' Sensitivity slider (3 to 5; 4, the middle, by default). Kept
## with the wardrobe when the slider's let go (SettingsScreen).
func set_aim(sensitivity: float) -> void:
	MusicManager.sensitivity = sensitivity
	$Trajectory.sensitivity = sensitivity


## Easy, Normal, Hard (or OG): kept for every climb from now on. Before this climb's first jump it's the
## climb's own; after, the climb only remembers the easiest it's been played on (Hard has to be the whole
## climb, for OG mode).
func set_difficulty(mode: String) -> void:
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	if not mode in difficulty.MODES or (mode == "og" and not MusicManager.og_unlocked):
		return
	MusicManager.difficulty = mode
	MusicManager.save_wardrobe()
	if jumpCount == 0 or easiest_rank < 0:
		easiest_rank = difficulty.rank(mode)
	else:
		easiest_rank = mini(easiest_rank, difficulty.rank(mode))
	if FileAccess.file_exists(save_path):
		save_game()


## Beaten on Hard and OG mode's news not read yet: "OG Mode Unlocked!" over the title (OgNews.gd).
func _maybe_og_news() -> void:
	if not MusicManager.og_unlocked or MusicManager.og_seen or not $titlescreen.visible:
		return
	var news: CanvasLayer = load("res://scripts/OgNews.gd").new()
	news.player = self
	get_parent().add_child(news)


## Whether this climb still counts as Hard (or OG) all the way.
func climb_is_hard() -> bool:
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	return easiest_rank >= difficulty.rank("hard")


## At the top: the achievements, and (beaten on Hard) OG mode, its news waiting at the title.
func _record_win() -> void:
	var achievements: GDScript = load("res://scripts/Achievements.gd")
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	achievements.earn("beat_game")
	if easiest_rank >= difficulty.rank("hard"):
		achievements.earn("beat_hard")
		if not MusicManager.og_unlocked:
			MusicManager.og_unlocked = true
			MusicManager.og_seen = false
			MusicManager.save_wardrobe()
	if easiest_rank >= difficulty.rank("og"):
		achievements.earn("beat_og")
	# The secrets: the World Tree remembers every climb. Five to the top, and ten.
	MusicManager.wins += 1
	MusicManager.save_wardrobe()
	if MusicManager.wins >= 5:
		achievements.earn("beat_5")
		MusicManager.unlock("aurora")
		MusicManager.unlock("laurel")
	if MusicManager.wins >= 10:
		achievements.earn("beat_10")
		MusicManager.unlock("legendary")
		MusicManager.unlock("starcrown")


## Starts over, once the settings have asked: "climb" deletes the save (back to the bottom), "all" the
## wardrobe and Endless's best scores too. Then the game starts again, at the title.
func reset_progress(kind: String) -> void:
	$frogaim.play()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if kind == "all":
		if FileAccess.file_exists(MusicManager.wardrobe_path):
			DirAccess.remove_absolute(MusicManager.wardrobe_path)
		const ENDLESS_SCORE_PATH := "user://endless_highscore.dat"
		if FileAccess.file_exists(ENDLESS_SCORE_PATH):
			DirAccess.remove_absolute(ENDLESS_SCORE_PATH)
		MusicManager.froggyCrown = 0
		MusicManager.equipped_hat = ""
		MusicManager.equipped_skin = ""
		MusicManager.unlocked_skins = []
		MusicManager.seen_cosmetics = []
		MusicManager.game_beaten = false
		MusicManager.desktop_frog_unlocked = false
		MusicManager.difficulty = "normal"
		MusicManager.sensitivity = MusicManager.SENSITIVITY
		MusicManager.og_unlocked = false
		MusicManager.og_seen = false
		MusicManager.achievements = []
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_pause_wardrobe_pressed() -> void:
	$frogaim.play()
	var ws = load("res://scenes/WardrobeScreen.gd").new()
	add_child(ws)
	_active_wardrobe = ws
	$PauseScreen.visible = false
	ws.cosmetic_changed.connect(_apply_equipped_cosmetics)
	ws.closed.connect(func():
		_active_wardrobe = null
		remove_child(ws)
		_apply_equipped_cosmetics()
		$PauseScreen.visible = false
		Engine.time_scale = 1.0
	)


func setup_key_trail():
	key_node = get_parent().get_node_or_null("World Sprites/Key")
	if key_node:
		key_node.visible = true
		key_trail_pos = position


## The climb's time played, split into hours, minutes and seconds (the corner, the save, the win screen).
func _split_play_time() -> void:
	var whole := int(play_secs)
	hours = whole / 3600
	minutes = (whole / 60) % 60
	seconds = whole % 60


## The climb's time played, as it's shown: 1:02:03, or 2:03 under an hour.
func play_time_text() -> String:
	_split_play_time()
	return "%d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%d:%02d" % [minutes, seconds]


## The game put away (a phone's home screen, another app) or closed, mid-climb: the climb's saved as it is,
## its time and jumps to the second, so none of it's lost.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	if is_inside_tree() and has_node("Trajectory") and $Trajectory.endGame == 0 and not waking and not _end_triggered:
		save_game()


func save_game():
	# (up in the finale he can't be put back where he is: the climb's still kept, its time and jumps to the
	# second, but from the last place saved below it)
	var at := position
	if currentHeight > 513:
		if _safe_spot == Vector2.INF:
			return
		at = _safe_spot
	else:
		_safe_spot = position
	_trace("Player save_game start")
	_split_play_time()
	var save_data = {
		"position": at,
		"play_secs": play_secs,
		"has_key": has_key,
		"has_lantern": has_lantern,
		"hours": hours,
		"minutes": minutes,
		"seconds": seconds,
		"SpeedrunMode": SpeedrunMode,
		"easiest": easiest_rank,
		"froggyCrown": MusicManager.froggyCrown,
		"jumpCount": jumpCount,
		"bangersCount": bangersCount,
		"songTrigger": songTrigger,
		"bestRun": bestRun,
		"jokeCheck": get_parent().jokeCheck,
		"foreshadowBool": get_parent().foreshadowBool,
		"gateDestroyed": get_parent().gateDestroyed,
		"npc1": get_parent().npc1,
		"npc2": get_parent().npc2,
		"npc3": get_parent().npc3,
		"npc4": get_parent().npc4,
		"npc5": get_parent().npc5,
		"npc6": get_parent().npc6,
	}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_warning("save_game: could not open save file for writing")
		return
	file.store_var(save_data)
	file.close()
	_trace("Player save_game end")
	print("Game saved.")


func load_game():
	_trace("Player load_game start")
	if not FileAccess.file_exists(save_path):
		_trace("Player load_game end missing file")
		return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_trace("Player load_game end open failed")
		return
	var save_data = file.get_var()
	file.close()

	if not save_data is Dictionary:
		push_warning("load_game: save file is corrupt or empty, starting fresh")
		_trace("Player load_game end corrupt")
		return

	position = save_data.get("position", position)
	has_key = save_data.get("has_key", has_key)
	has_lantern = save_data.get("has_lantern", has_lantern)
	hours = save_data.get("hours", 0)
	minutes = save_data.get("minutes", 0)
	seconds = save_data.get("seconds", 0)
	# (time played; a save from before it was kept to the fraction: its hours, minutes and seconds)
	play_secs = float(save_data.get("play_secs", int(hours) * 3600 + int(minutes) * 60 + float(seconds)))
	_split_play_time()
	_safe_spot = position  # (a save's always somewhere below the finale)
	SpeedrunMode = save_data.get("SpeedrunMode", false)
	easiest_rank = int(save_data.get("easiest", 1))  # (a climb from before difficulties: Normal)
	MusicManager.froggyCrown = save_data.get("froggyCrown", MusicManager.froggyCrown)
	jumpCount = save_data.get("jumpCount", 0)
	bangersCount = save_data.get("bangersCount", 0)
	songTrigger = save_data.get("songTrigger", 70)
	bestRun = save_data.get("bestRun", 1)
	if "jokeCheck" in save_data:
		get_parent().jokeCheck = save_data["jokeCheck"]
	if "foreshadowBool" in save_data:
		get_parent().foreshadowBool = save_data["foreshadowBool"]
	if "gateDestroyed" in save_data:
		get_parent().gateDestroyed = save_data["gateDestroyed"]
	if "npc1" in save_data:
		get_parent().npc1 = save_data["npc1"]
	if "npc2" in save_data:
		get_parent().npc2 = save_data["npc2"]
	if "npc3" in save_data:
		get_parent().npc3 = save_data["npc3"]
	if "npc4" in save_data:
		get_parent().npc4 = save_data["npc4"]
	if "npc5" in save_data:
		get_parent().npc5 = save_data["npc5"]
	if "npc6" in save_data:
		get_parent().npc6 = save_data["npc6"]
	_trace("Player load_game end")
	print("Game loaded.")


func _setup_crt_state() -> void:
	# Always resets CRT to static shader with record hidden.
	# Call _activate_beaten_crt() separately to enter the beaten state.
	var crt_node = get_node_or_null("../Musecrtquarterview")
	if not crt_node:
		return
	var color_rect = crt_node.get_node_or_null("ColorRect")
	var record     = crt_node.get_node_or_null("Record")
	var rec_shadow = crt_node.get_node_or_null("Recordshadow")
	if color_rect:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scenes/static.gdshader")
		color_rect.material = mat
	if record:     record.visible = false
	if rec_shadow: rec_shadow.visible = false


func _activate_beaten_crt() -> void:
	# Switches CRT to checkerboard shader, shows record, starts the song.
	var crt_node  = get_node_or_null("../Musecrtquarterview")
	if not crt_node:
		return
	var color_rect = crt_node.get_node_or_null("ColorRect")
	var record     = crt_node.get_node_or_null("Record")
	var rec_shadow = crt_node.get_node_or_null("Recordshadow")
	var crt_audio  = crt_node.get_node_or_null("AudioStreamPlayer2D")
	if color_rect:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://checkerboardendless.gdshader")
		color_rect.material = mat
	if record:     record.visible = true
	if rec_shadow: rec_shadow.visible = true
	if crt_audio:
		_crt_normal_volume = 0.0
		crt_audio.stream = load("res://assets/leafedfiltered.ogg")
		crt_audio.volume_db = _crt_normal_volume
		crt_audio.play()
		if $winscreen/goodbyefroggy.playing:
			_duck_crt_for_goodbye(crt_audio)


func _duck_crt_for_goodbye(crt_audio: AudioStreamPlayer2D) -> void:
	# Duck to ~1/3 amplitude (-9.5 dB) while goodbyefroggy plays, then restore.
	var tween := create_tween()
	tween.tween_property(crt_audio, "volume_db", _crt_normal_volume - 9.5, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await $winscreen/goodbyefroggy.finished
	if not is_instance_valid(crt_audio):
		return
	var restore := create_tween()
	restore.tween_property(crt_audio, "volume_db", _crt_normal_volume, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## His hat sits on his head: it comes down with his head when he breathes and when he crouches to aim
## (see FroggyHead.gd), and turns with him. Placed every physics frame and as soon as his frame
## changes, so it's never a frame behind his head.
func _place_hats() -> void:
	var body: AnimatedSprite2D = $Sprite2D
	if _froggy_head == null:
		_froggy_head = load("res://scripts/FroggyHead.gd")
	var frame: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame) if body.sprite_frames else null
	# (the negative skin shows the screen behind him, hats and all, so its hat sits a bit higher)
	var hat_y := -10.66667 if MusicManager.equipped_skin == "negative_skin" else -9.1667
	hat_y += _froggy_head.drop(frame) * body.scale.y
	for hat: Sprite2D in [$Froggycrown, $FroggyWizHat, $FroggyCakeHat]:
		if hat.visible:
			hat.rotation = body.rotation
			hat.position = Vector2(0, hat_y).rotated(body.rotation)
	# (a hat drawn in code is worn in front of his head: it sits at his feet, so the y-sort draws it
	# after him, and its offset puts it up on his head, turning with him)
	var look_hat := _look_hat()
	if look_hat.visible:
		look_hat.rotation = body.rotation
		look_hat.position = Vector2.ZERO
		look_hat.offset = _look_hat_offset + Vector2(0, hat_y / look_hat.scale.y)


func _apply_equipped_cosmetics() -> void:
	var hat := MusicManager.equipped_hat
	$Froggycrown.visible = (hat == "froggycrown" or hat == "blackcrown")
	if hat == "blackcrown":
		var hat_mat := ShaderMaterial.new()
		hat_mat.shader = load("res://assets/skin_tint.gdshader")
		hat_mat.set_shader_parameter("tint_color", Color(0.0, 0.0, 0.0))
		hat_mat.set_shader_parameter("tint_strength", 1.0)
		$Froggycrown.material = hat_mat
	else:
		$Froggycrown.material = null

	$FroggyWizHat.visible = (hat == "wizhat")
	$FroggyCakeHat.visible = (hat == "cakehat")

	# (the hats drawn in code, on his own grid: FroggyLook.HATS)
	var look_hat := _look_hat()
	look_hat.texture = load("res://scripts/FroggyLook.gd").hat_texture(hat)
	_look_hat_offset = load("res://scripts/FroggyLook.gd").hat_offset(hat)
	look_hat.visible = look_hat.texture != null

	# (your froggy, as you made him, with your skin's effect over him: FroggyLook)
	var skin := MusicManager.equipped_skin
	$Sprite2D.material = load("res://scripts/FroggyLook.gd").material(MusicManager.look, skin)
	_shut_eyes(asleep)
	$Shadow.visible = (skin != "negative_skin")
	_place_hats()


var _look_hat_offset := Vector2.ZERO  # (where his drawn hat goes on his head: FroggyLook.hat_offset)


## The hat that's drawn in code (FroggyLook.HATS), sized and placed as his others are.
func _look_hat() -> Sprite2D:
	var h := get_node_or_null("LookHat") as Sprite2D
	if h == null:
		h = Sprite2D.new()
		h.name = "LookHat"
		h.scale = $FroggyWizHat.scale  # (his own pixel's size)
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.position = $FroggyWizHat.position
		add_child(h)
	return h


func _on_wardrobe_button_pressed() -> void:
	$frogaim.play()
	var title_was_visible: bool = $titlescreen.visible
	$titlescreen.visible = false
	var ws = load("res://scenes/WardrobeScreen.gd").new()
	add_child(ws)
	_active_wardrobe = ws
	ws.closed.connect(func() -> void:
		_active_wardrobe = null
		remove_child(ws)
		_apply_equipped_cosmetics()
		$titlescreen.visible = title_was_visible
		_refresh_title_menu()
		if title_was_visible:
			_apply_ui_layout()
	)


## The title's menu, in the menus' chunky buttons (UIStyle): CONTINUE (START with no climb saved) big;
## ENDLESS and PLAY TOGETHER (a party: PartyScreen); then little square ones with a picture each: the
## wardrobe's crown (once there's something in it: it can turn up mid-game, Muse Pro brings Lil Froggy
## on a computer), Muse (gold with Muse Pro) and the settings' gear. _layout_title places it. (It took
## over from the scene's own buttons and from MUSE ACCOUNT up in the corner.)
func _build_title_menu() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var menu := VBoxContainer.new()
	menu.name = "TitleMenu"
	$titlescreen.add_child(menu)
	var play := _title_button(menu, "PlayButton", _on_button_pressed)
	play.text = "CONTINUE" if FileAccess.file_exists(save_path) else "START"
	var modes := BoxContainer.new()  # (side by side upright, one over the other sideways: _layout_title)
	modes.name = "Modes"
	menu.add_child(modes)
	var endless := _title_button(modes, "EndlessButton", _on_endlessmodebutton_pressed)
	endless.set_meta("words", "ENDLESS")
	endless.button_down.connect(_hold_for_og_endless.bind(endless))  # (a secret: OG Endless)
	_title_button(modes, "PartyButton", _on_party_button_pressed).set_meta("words", "PLAY TOGETHER")
	var extras := HBoxContainer.new()  # (little square buttons, a picture on each and no words)
	extras.name = "Extras"
	extras.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_child(extras)
	var wardrobe := _title_button(extras, "WardrobeButton", _on_wardrobe_button_pressed)
	wardrobe.tooltip_text = "Wardrobe"
	_attach_new_badge(wardrobe)
	_title_button(extras, "MuseButton", _on_muse_button_pressed)
	_title_button(extras, "SettingsButton", _on_title_settings_pressed).tooltip_text = "Settings"
	for b in modes.get_children() + extras.get_children():  # (UIStyle.button_face)
		b.set_meta("icon", {"EndlessButton": [load("res://assets/infinity.png"), false],
			"PartyButton": [ui.pixel_icon(ui.PARTY), true],
			"WardrobeButton": [load("res://assets/crownicon.png"), false],
			"MuseButton": [ui.pixel_icon(ui.PERSON), true],
			"SettingsButton": [ui.pixel_icon(ui.GEAR), true]}.get(str(b.name), []))
	_refresh_title_menu()


func _title_button(menu: Control, button_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = button_name
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	menu.add_child(b)
	return b


## What the title's menu shows: the wardrobe's button once there's something in it (and NEW on it), the
## Muse button in gold with Muse Pro.
func _refresh_title_menu() -> void:
	var menu := $titlescreen.get_node_or_null("TitleMenu")
	if menu == null:
		return
	var wardrobe: Button = menu.find_child("WardrobeButton", true, false)
	wardrobe.visible = MusicManager.has_any_cosmetic()
	_refresh_new_badge(wardrobe)
	menu.find_child("MuseButton", true, false).tooltip_text = "Muse Pro" if MuseAccount.has_pro() else "Muse Account"


## The title: the logo, then its menu under it upright (or beside it sideways), and "made by muse"
## at the bottom, all in the room clear of the notch and the bottom banner, which is kept from the
## very first frame (UIStyle.title_spots, where the loading screen put its logo too): nothing moves
## when the banner turns up. The menu: CONTINUE (or START) big, ENDLESS and PLAY TOGETHER side by side
## under it upright (one over the other sideways), then the little square buttons, a picture on each
## (the wardrobe, Muse, settings). It was six big buttons one over another. The biggest sizes that fit:
## on a short screen (an upright iPad, a foldable) they come down a step.
func _layout_title(vp: Vector2, is_portrait: bool) -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var title := $titlescreen/Title
	var by_muse := $"titlescreen/by muse"
	var menu: VBoxContainer = $titlescreen/TitleMenu
	var play: Button = menu.get_node("PlayButton")
	var modes: BoxContainer = menu.get_node("Modes")
	var extras: HBoxContainer = menu.get_node("Extras")
	var spots: Dictionary = ui.title_spots(vp)
	var room: Rect2 = spots.room
	var byline := _byline(by_muse, spots.byline_size, spots.byline_gap)
	var bottom: float = spots.floor  # (just over "made by muse")
	modes.vertical = not is_portrait
	# [CONTINUE's words, its height, ENDLESS and PLAY TOGETHER's, the little buttons', the gap]
	var sizes := [[32, 80.0, 52.0, 56.0, 12.0], [32, 72.0, 48.0, 48.0, 10.0], [32, 56.0, 44.0, 44.0, 8.0],
		[16, 44.0, 38.0, 38.0, 6.0], [16, 34.0, 30.0, 30.0, 4.0]] \
		if is_portrait else [[16, 40.0, 34.0, 34.0, 6.0], [16, 34.0, 28.0, 28.0, 4.0]]
	var logo: Vector2 = spots.logo
	title.scale = Vector2.ONE * spots.logo_scale
	var top: float
	var width: float
	if is_portrait:  # (whole pixels wide, so the words land dead in the middle)
		top = logo.y + 375.0 * 0.25 + 8.0
		width = floorf(minf(vp.x * 0.84, 420.0))
	else:
		top = room.position.y + 8.0
		width = floorf(minf(vp.x * 0.4, 260.0))
	var pick: Array = sizes[-1]
	for each in sizes:
		if _title_height(each, is_portrait) <= bottom - top:
			pick = each
			break
	var gap: float = pick[4]
	var height := _title_height(pick, is_portrait)
	menu.add_theme_constant_override("separation", int(gap))
	modes.add_theme_constant_override("separation", int(gap))
	extras.add_theme_constant_override("separation", int(gap * 1.5))
	ui.style_button(play, pick[0], "go")
	play.custom_minimum_size = Vector2(0, pick[1])
	# ENDLESS and PLAY TOGETHER: their words as big as CONTINUE's when both fit by their pictures, else a step down.
	var across: float = floorf((width - gap) * 0.5) if is_portrait else width
	var words_size: int = pick[0]
	for b: Button in modes.get_children():
		if not _words_fit(b.get_meta("words", ""), words_size, across, pick[2]):
			words_size = 16
	for b: Button in modes.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.style_button(b, words_size, "wood")
		b.custom_minimum_size = Vector2(0, pick[2])
		ui.button_face(b, b.get_meta("icon")[0], b.get_meta("icon")[1], b.get_meta("words", ""), words_size,
			(pick[2] - 2.0 - ui.lip_px(words_size)) * 0.5)
	for b: Button in extras.get_children():
		ui.style_button(b, 16, "gold" if b.name == "MuseButton" and MuseAccount.has_pro() else "quiet")
		b.custom_minimum_size = Vector2(pick[3], pick[3])
		var face: float = pick[3] - 2.0 - ui.lip_px(16)
		ui.button_face(b, b.get_meta("icon")[0], b.get_meta("icon")[1], "", 16, face * 0.62)
	menu.size = Vector2(width, height)
	var x: float = (vp.x - width) * 0.5 if is_portrait else vp.x * 0.72 - width * 0.5
	_place_title(vp, logo, Vector2(x, top + (bottom - top - height) * 0.5).round(), byline)


## How tall the title's menu is at these sizes (_layout_title's): CONTINUE, the two modes side by side
## (or one over the other), the little buttons, and the gaps between.
static func _title_height(s: Array, is_portrait: bool) -> float:
	return s[1] + s[4] + (s[2] if is_portrait else s[2] * 2.0 + s[4]) + s[4] + s[3]


## Whether words fit on a button this wide and tall at this size, clear of the picture at its left end
## (UIStyle.button_face: the words go in the middle of the face, the picture in its left end's square).
static func _words_fit(words: String, size: int, across: float, tall: float) -> bool:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var w: float = ui.font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + ui.outline_px(size) * 2.0
	var face: float = tall - 2.0 - ui.lip_px(size)
	var picture_end: float = 2.0 + face * 0.5 + face * 0.25 + 4.0  # (its middle, half of it, a little room)
	return (across - w) * 0.5 >= picture_end


## Puts the logo, the menu and "made by muse" where they go: straight there the first time and when the
## screen turns, and in a glide if they move while they're showing (a banner that came out taller than
## its room, or went with Muse Pro), so nothing jumps.
func _place_title(vp: Vector2, logo: Vector2, menu_at: Vector2, byline: Vector2) -> void:
	var title := $titlescreen/Title
	var by_muse := $"titlescreen/by muse"
	var menu: Control = $titlescreen/TitleMenu
	var moves := [[title, "position", logo], [menu, "position", menu_at],
		[by_muse, "offset_top", byline.x], [by_muse, "offset_bottom", byline.y]]
	if _title_glide:
		_title_glide.kill()
		_title_glide = null
	var glide: bool = $titlescreen.visible and vp == _title_laid_out_for
	_title_laid_out_for = vp
	for m in moves:
		if not glide:
			m[0].set(m[1], m[2])
		elif m[0].get(m[1]) != m[2]:
			if _title_glide == null:
				_title_glide = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_title_glide.tween_property(m[0], m[1], m[2], 0.4)


func _on_muse_button_pressed() -> void:
	$frogaim.play()
	var title_was_visible: bool = $titlescreen.visible
	$titlescreen.visible = false
	var screen = load("res://scenes/MuseAccountScreen.gd").new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		$titlescreen.visible = title_was_visible
		if title_was_visible:
			_apply_ui_layout()
			_show_logo(true)
	)


## PLAY TOGETHER: host or join a party on the same Wi-Fi (PartyScreen); starting it climbs Endless.
## The first time, he makes his froggy first (the frog god), so friends see him as he is.
func _on_party_button_pressed() -> void:
	if not MusicManager.look_made:
		_meet_the_frog_god(func() -> void:
			$titlescreen.visible = true  # (back to the title when Play Together's closed)
			_on_party_button_pressed())
		return
	$frogaim.play()
	var title_was_visible: bool = $titlescreen.visible
	$titlescreen.visible = false
	var screen = load("res://scenes/PartyScreen.gd").new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		$titlescreen.visible = title_was_visible
		if title_was_visible:
			_apply_ui_layout()
			_show_logo(true)
	)


func _on_muse_account_changed() -> void:
	_refresh_title_menu()
	if $titlescreen.visible:
		_show_logo(true)
		_apply_ui_layout()


## The title logo: FROG QUEST, or FROG QUEST+ with Muse Pro (it bounces when the + turns up or goes).
func _show_logo(pop := false) -> void:
	var title := $titlescreen/Title
	var path: String = MuseAccount.logo_path()
	if title.texture and title.texture.resource_path == path:
		return
	title.texture = load(path)
	if pop:
		title.spring_velocity += 0.5


## A secret: hold ENDLESS down (OG_HOLD seconds) and it's the original Endless, just as it was (OG Endless:
## the checkerboard, the pink platforms; scenes/og), with its own best score.
const OG_HOLD := 2.0
var _og_endless := false


func _hold_for_og_endless(button: Button) -> void:
	await get_tree().create_timer(OG_HOLD).timeout
	if not is_instance_valid(button) or not button.is_pressed() or not button.is_hovered() or not $titlescreen.visible:
		return
	_og_endless = true
	MusicManager.show_toast("OG Endless", null, "The original Endless, just as it was.")
	$frogaim.play()
	get_tree().change_scene_to_file("res://scenes/og/OGEndlessMode.tscn")


## ENDLESS. The first time, he makes his froggy first (the frog god), and its flash fades over Endless.
func _on_endlessmodebutton_pressed() -> void:
	if _og_endless:  # (held: it's the OG one, already on its way)
		return
	if not MusicManager.look_made:
		_meet_the_frog_god(func() -> void:
			var intro := get_node_or_null("CreatorIntro")
			if intro:
				intro.reparent(get_tree().root)  # (kept through the change, to fade out over Endless)
			_on_endlessmodebutton_pressed())
		return
	get_tree().change_scene_to_file("res://scenes/EndlessMode.tscn")


func _on_viewport_resized() -> void:
	_resize_timer = get_tree().create_timer(0.5, true, false, true)
	var t := _resize_timer
	await t.timeout
	if t != _resize_timer or not is_inside_tree():
		return
	_apply_ui_layout()
	_sync_banner_visibility_with_pause_orientation()


func _sync_banner_visibility_with_pause_orientation() -> void:
	if MusicManager.ads_removed:
		_banner_hidden_for_landscape_pause = false
		return

	if not $PauseScreen.visible:
		if _banner_hidden_for_landscape_pause:
			_banner_hidden_for_landscape_pause = false
			AdsManager.show_banner_bottom()
		return

	var vp := get_viewport().get_visible_rect().size
	var horizontal := vp.x >= vp.y
	if horizontal:
		if not _banner_hidden_for_landscape_pause:
			AdsManager.hide_banner()
			_banner_hidden_for_landscape_pause = true
	elif _banner_hidden_for_landscape_pause:
		AdsManager.show_banner_bottom()
		_banner_hidden_for_landscape_pause = false


func _on_pause_screen_visibility_changed() -> void:
	if $PauseScreen.visible:
		if _active_wardrobe and is_instance_valid(_active_wardrobe):
			_active_wardrobe.closed.emit()
		_apply_ui_layout()
	_sync_banner_visibility_with_pause_orientation()


func _on_end_animation_finished() -> void:
	# Freeze at the last keyframe then stop so nothing plays past it.
	$Camera2D/AnimationPlayer.pause()
	$Camera2D/AnimationPlayer.release_zoom_lock()
	$winscreen/time2.text = ("In " + str(finalTime) + " and " + str(int(jumpCount)) + " jumps")
	if finalbuttonBool == 0:
		# Revert CRT visuals to static during the win screen only on first win.
		# If the player already beat the game, leave the beaten CRT state as-is.
		if not MusicManager.game_beaten:
			_setup_crt_state()
		var _crt = get_node_or_null("../Musecrtquarterview")
		if _crt:
			var _crt_audio = _crt.get_node_or_null("AudioStreamPlayer2D")
			if _crt_audio and _crt_audio.playing and $winscreen/goodbyefroggy.playing:
				_duck_crt_for_goodbye(_crt_audio)
		$winscreen.visible = true
		$winscreen/thanksforplayingButton.visible = false
		_ease_in_win_screen()
		$winscreen/thanksforplayingTimer.start()
		finalbuttonBool = 1
		MusicManager.holding_news = true  # (its achievements and unlocks: said at the next START, not over this)
		_record_win()
		MusicManager.holding_news = false
		$Camera2D.position = END_IN_BEDROOM
		_apply_win_layout()
		_maybe_let_desktop_frog_out()


## Once in a long while, a win on a computer: Lil Froggy jumps out of the game window onto the desktop.
func _maybe_let_desktop_frog_out() -> void:
	var link = load("res://scripts/DesktopFrogLink.gd")
	if MusicManager.desktop_frog_unlocked or not link.is_supported() or not link.escapes_this_time():
		return
	MusicManager.desktop_frog_unlocked = true
	MusicManager.save_wardrobe()
	# Let the win screen land first (real seconds, even while credits run fast).
	await get_tree().create_timer(4.0, true, false, true).timeout
	if not is_inside_tree() or link.is_out():
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		return
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		# He needs some desktop to land on.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().create_timer(0.6, true, false, true).timeout
		if not is_inside_tree():
			return
	link.let_out(link.game_window_rect(), true)


func _apply_win_layout() -> void:
	var vp  := get_viewport().get_visible_rect().size
	var cx  := vp.x * 0.5
	var is_portrait := vp.y > vp.x * 1.3

	var title2    : Sprite2D = $winscreen/Title2
	var congrats  : Label    = $winscreen/congrats
	var time2_lbl : Label    = $winscreen/time2
	var btn       : Button   = $winscreen/thanksforplayingButton
	var by_muse2  : Label    = $"winscreen/by muse2"

	if is_portrait:
		# Title position — everything else is derived from this.
		var title_y: float = vp.y * 0.36
		title2.position = Vector2(cx, title_y)
		title2.scale    = Vector2(0.34, 0.34)

		# Congrats sits above the title sprite. The sprite at scale 0.34 is
		# roughly 130 px tall, so its top edge is ~65 px above title_y.
		# End congrats 20 px above that top edge to avoid any overlap.
		var congrats_bottom: float = title_y - 85.0
		var congrats_top: float    = congrats_bottom - 100.0
		congrats.anchor_left   = 0.0
		congrats.anchor_right  = 1.0
		congrats.anchor_top    = 0.0
		congrats.anchor_bottom = 0.0
		congrats.offset_left   = 8.0
		congrats.offset_right  = -8.0
		congrats.offset_top    = congrats_top
		congrats.offset_bottom = congrats_bottom
		_fit_text_size(congrats, 46, vp.x - 16.0)

		# time2 — below the cave area. Cave ends roughly at title_y + 27% of vp.
		var time_top: float = title_y + vp.y * 0.27
		time2_lbl.anchor_left   = 0.0
		time2_lbl.anchor_right  = 1.0
		time2_lbl.anchor_top    = 0.0
		time2_lbl.anchor_bottom = 0.0
		time2_lbl.offset_left   = 8.0
		time2_lbl.offset_right  = -8.0
		time2_lbl.offset_top    = time_top
		time2_lbl.offset_bottom = time_top + 60.0
		_fit_text_size(time2_lbl, 34, vp.x - 16.0)

		# Button below time2 with a small gap.
		var btn_top: float = time_top + 60.0 + 20.0
		var hw: float = min(175.0, (vp.x - 40.0) * 0.5)
		btn.anchor_left   = 0.0
		btn.anchor_right  = 0.0
		btn.anchor_top    = 0.0
		btn.anchor_bottom = 0.0
		btn.offset_left   = cx - hw
		btn.offset_right  = cx + hw
		btn.offset_top    = btn_top
		btn.offset_bottom = btn_top + 65.0
		load("res://scripts/UIStyle.gd").style_button(btn, 34, "go")  # (like every other button)

		_pin_to_bottom(by_muse2, 26)
	else:
		# Landscape — set all anchors/offsets explicitly so nothing from the
		# scene or a prior portrait layout bleeds in.
		var title_y_l: float = vp.y * 0.42
		title2.position = Vector2(cx, title_y_l)
		title2.scale    = Vector2(0.20, 0.20)

		# Congrats above the title (sprite at scale 0.20 is ~75 px tall).
		var c_bot: float = title_y_l - 15.0
		var c_top: float = c_bot - 80.0
		congrats.anchor_left   = 0.0
		congrats.anchor_right  = 1.0
		congrats.anchor_top    = 0.0
		congrats.anchor_bottom = 0.0
		congrats.offset_left   = 8.0
		congrats.offset_right  = -8.0
		congrats.offset_top    = c_top
		congrats.offset_bottom = c_bot
		_fit_text_size(congrats, 28, vp.x - 16.0)

		time2_lbl.anchor_left   = 0.0
		time2_lbl.anchor_right  = 1.0
		time2_lbl.anchor_top    = 0.6
		time2_lbl.anchor_bottom = 0.73
		time2_lbl.offset_left   = 8.0
		time2_lbl.offset_right  = -8.0
		time2_lbl.offset_top    = 0.0
		time2_lbl.offset_bottom = 0.0
		_text_size(time2_lbl, 16)

		var hw: float = min(120.0, vp.x * 0.22)
		btn.anchor_left   = 0.0
		btn.anchor_right  = 0.0
		btn.anchor_top    = 0.0
		btn.anchor_bottom = 0.0
		btn.offset_left   = cx - hw
		btn.offset_right  = cx + hw
		btn.offset_top    = vp.y * 0.74
		btn.offset_bottom = vp.y * 0.74 + 40.0
		load("res://scripts/UIStyle.gd").style_button(btn, 19, "go")

		_pin_to_bottom(by_muse2, 13)
	_snap_to_pixels([btn])


## Puts buttons' edges on whole pixels: half a pixel out, a button's words came out a pixel off its
## middle.
func _snap_to_pixels(buttons: Array) -> void:
	for b in buttons:
		if b is Control:
			for side in ["offset_left", "offset_top", "offset_right", "offset_bottom"]:
				b.set(side, roundf(b.get(side)))


## Sets a label's or button's words to about size: the nearest whole step of the pixel font's 16-pixel
## grid (in between, its pixels come out uneven and the words go lumpy), with a one-pixel outline.
func _text_size(c: Control, size: float) -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var px: int = ui.px(size)
	c.add_theme_font_size_override("font_size", px)
	c.add_theme_constant_override("outline_size", ui.outline_px(px))


## The biggest of the font's sizes from about size down at which every line of the label fits across width,
## outline and all. ("you have completed the" ran off both sides of a phone held upright.)
func _fit_text_size(c: Label, size: float, width: float) -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var font: Font = c.get_theme_font("font")
	var px: int = ui.px(size)
	while px > ui.PX:
		var widest := 0.0
		for line in c.text.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if widest + 2.0 * ui.outline_px(px) <= width:
			break
		px -= ui.PX
	c.add_theme_font_size_override("font_size", px)
	c.add_theme_constant_override("outline_size", ui.outline_px(px))


## Pins a "made by muse" label along the bottom edge, all of it on screen: just above the bottom
## banner when one is showing, otherwise just above the edge and any home-indicator area.
func _pin_to_bottom(label: Label, font_size: int) -> void:
	var banner: float = AdsManager.get_viewport_bottom_banner_clearance()
	var at := _byline(label, font_size, banner if banner > 0.0 else AdsManager.get_viewport_bottom_safe_inset() + 3.0)
	label.offset_top = at.x
	label.offset_bottom = at.y


## Sets a "made by muse" label up across the bottom of the screen, about font_size big, and gives the
## offsets (top, bottom) that put it gap up from the bottom edge, all of it on screen.
func _byline(label: Label, font_size: int, gap: float) -> Vector2:
	_text_size(label, font_size)
	font_size = label.get_theme_font_size("font_size")
	var outline: int = label.get_theme_constant("outline_size")
	label.scale = Vector2.ONE
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	var height: float = label.get_theme_font("font").get_height(font_size) + outline
	return Vector2(-gap - height, -gap)


func _initial_title_layout() -> void:
	_apply_ui_layout()
	if not MusicManager.look_made and get_node_or_null("CreatorIntro") == null:
		# (the very first time: no title; out of the dark, the frog god asks what he looks like, then the climb)
		_meet_the_frog_god(_on_button_pressed, false, true)
		return
	$titlescreen.visible = true
	_maybe_og_news()
	if MusicManager.curtain_shut():  # (home from the win: the title easing up out of the black)
		await get_tree().create_timer(0.25, true, false, true).timeout
		MusicManager.curtain(0.0, HOME_FADE * 1.2)


## The win screen's lines easing in, one after another: the congratulations, the title, the time and jumps,
## who made it.
func _ease_in_win_screen() -> void:
	var i := 0
	for line in ["congrats", "Title2", "time2", "jumpcount2", "by muse2"]:
		var item := get_node_or_null("winscreen/" + line) as CanvasItem
		if item == null or not item.visible:
			continue
		item.modulate.a = 0.0
		var up := create_tween()
		up.tween_interval(WIN_STAGGER * i)
		up.tween_property(item, "modulate:a", 1.0, WIN_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		i += 1


func _apply_ui_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.y > vp.x * 1.3
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5


	# ── TITLE SCREEN ─────────────────────────────────────────────────────
	$titlescreen.layer = AdsManager.canvas_layer_above_banner_placeholder()
	$"titlescreen/by muse".z_index = 8
	$"titlescreen/by muse".z_as_relative = false
	$titlescreen/earthboundbattleFX3.position = Vector2(cx, vp.y * 0.75 if is_portrait else 238.0)
	_layout_title(vp, is_portrait)

	# ── PAUSE SCREEN ──────────────────────────────────────────────────────
	var overlay      := $PauseScreen/MeshInstance2D
	var paused_lbl   := $PauseScreen/Paused
	var resume_btn   := $PauseScreen/ResumeButton
	var settings_btn := $PauseScreen/SettingsButton
	var restart_btn  := $PauseScreen/RestartButton  # (MAIN MENU: back to the title)
	var eb_fx        := $PauseScreen/earthboundbattleFX2
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	restart_btn.text = "MAIN MENU"

	# Overlay always covers the full viewport regardless of aspect ratio
	overlay.position = Vector2(cx, cy)
	overlay.scale    = Vector2(vp.x + 4.0, vp.y + 4.0)
	eb_fx.position = Vector2(cx, cy)
	eb_fx.scale    = Vector2(vp.x * 1.3 / 320.0, vp.y * 1.18 / 180.0)

	if is_portrait:
		paused_lbl.offset_left   = 10.0
		paused_lbl.offset_top    = vp.y * 0.20
		paused_lbl.offset_right  = vp.x - 10.0
		paused_lbl.offset_bottom = paused_lbl.offset_top + 60.0
		paused_lbl.pivot_offset  = Vector2((vp.x - 20.0) / 2.0, 30.0)
		_text_size(paused_lbl, 56)

		var bl: float = cx - 110.0
		var br: float = cx + 110.0
		var bh: float = 65.0
		# Anchor buttons just below PAUSED text rather than at a fixed percentage
		var bs: float = vp.y * 0.20 + 72.0

		resume_btn.offset_left   = bl;  resume_btn.offset_top    = bs
		resume_btn.offset_right  = br;  resume_btn.offset_bottom = bs + bh
		ui.style_button(resume_btn, 32, "go")
		settings_btn.offset_left  = bl;  settings_btn.offset_top    = bs + bh + 8.0
		settings_btn.offset_right = br;  settings_btn.offset_bottom = bs + bh * 2.0 + 8.0
		ui.style_button(settings_btn, 32, "wood")
		restart_btn.offset_left  = bl;  restart_btn.offset_top    = bs + (bh + 8.0) * 2.0
		restart_btn.offset_right = br;  restart_btn.offset_bottom = bs + (bh + 8.0) * 2.0 + bh
		ui.style_button(restart_btn, 32, "wood")

		var wardrobe_slot_p: int = 3
		var ra_slot_p: int = wardrobe_slot_p + (1 if MusicManager.has_any_cosmetic() else 0)
		_ensure_pause_wardrobe_btn(bl, br, bh, bs + (bh + 8.0) * wardrobe_slot_p, 32)
		_ensure_pause_remove_ads_btn(bl, br, bh, bs + (bh + 8.0) * ra_slot_p, 32)
	else:
		# All positions scale with vp so any aspect ratio works
		var num_btns_ls: int = 3 + (1 if MusicManager.has_any_cosmetic() else 0) + (1 if not AdsManager.is_ad_free() else 0)
		var gap_ls: float = max(3.0, vp.y * 0.03)
		var paused_font_ls: int = load("res://scripts/UIStyle.gd").px(maxf(20.0, vp.y * 0.18))
		var paused_top_ls: float = vp.y * 0.08
		var paused_bottom_ls: float = paused_top_ls + paused_font_ls * 1.3
		var avail_ls: float = vp.y - paused_bottom_ls - gap_ls
		var bh: float = min(36.0, max(16.0, (avail_ls - gap_ls * (num_btns_ls - 1)) / num_btns_ls))
		var total_ls: float = num_btns_ls * bh + (num_btns_ls - 1) * gap_ls
		var bs: float = paused_bottom_ls + (vp.y - paused_bottom_ls - total_ls) * 0.1

		var half_w_ls: float = vp.x * 0.165
		var bl: float = cx - half_w_ls
		var br: float = cx + half_w_ls

		paused_lbl.offset_left   = 0.0
		paused_lbl.offset_top    = paused_top_ls
		paused_lbl.offset_right  = vp.x
		paused_lbl.offset_bottom = paused_top_ls + float(paused_font_ls) * 1.3
		paused_lbl.pivot_offset  = Vector2(vp.x * 0.5, float(paused_font_ls) * 0.65)
		_text_size(paused_lbl, paused_font_ls)

		var btn_font_ls: int = load("res://scripts/UIStyle.gd").px(maxf(12.0, bh * 0.55))
		resume_btn.offset_left   = bl;  resume_btn.offset_top    = bs
		resume_btn.offset_right  = br;  resume_btn.offset_bottom = bs + bh
		ui.style_button(resume_btn, btn_font_ls, "go")
		settings_btn.offset_left  = bl;  settings_btn.offset_top    = bs + bh + gap_ls
		settings_btn.offset_right = br;  settings_btn.offset_bottom = bs + bh * 2.0 + gap_ls
		ui.style_button(settings_btn, btn_font_ls, "wood")
		restart_btn.offset_left  = bl;  restart_btn.offset_top    = bs + (bh + gap_ls) * 2.0
		restart_btn.offset_right = br;  restart_btn.offset_bottom = bs + (bh + gap_ls) * 2.0 + bh
		ui.style_button(restart_btn, btn_font_ls, "wood")
		var wardrobe_slot: int = 3
		var ra_slot: int = wardrobe_slot + (1 if MusicManager.has_any_cosmetic() else 0)
		_ensure_pause_wardrobe_btn(bl, br, bh, bs + (bh + gap_ls) * wardrobe_slot, btn_font_ls)
		_ensure_pause_remove_ads_btn(bl, br, bh, bs + (bh + gap_ls) * ra_slot, btn_font_ls)
	_snap_to_pixels([resume_btn, settings_btn, restart_btn, $PauseScreen.get_node_or_null("WardrobePauseBtn"),
		$PauseScreen.get_node_or_null("RemoveAdsPauseBtn")])

	# ── PAUSE BUTTON ──────────────────────────────────────────────────────
	# (it and the clock up in the corners, in from the notch, a Dynamic Island, the closed iPhone Duo's
	# camera strip and the ad banners: UIStyle.room)
	var room: Rect2 = ui.room(vp)
	var pause_btn := $CanvasLayer/TouchScreenButtonPause
	if pause_btn:
		var ratio: float = vp.y / vp.x
		var t_btn: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
		var btn_scale: float = lerp(1.5, 2.5, t_btn)
		var btn_pos: float = lerp(26.0, 42.0, t_btn)
		pause_btn.scale = Vector2(btn_scale, btn_scale)
		pause_btn.position = (room.position + Vector2(btn_pos, btn_pos)).round()

	# ── HUD LABELS ───────────────────────────────────────────────────────
	var ratio_hud: float = vp.y / vp.x
	var t_hud: float = inverse_lerp(0.65, 1.3, clamp(ratio_hud, 0.65, 1.3))
	var hud_font_size: int = int(round(lerp(20.0, 32.0, t_hud)))
	var vbox := $CanvasLayer.get_node_or_null("MarginContainer/VBoxContainer")
	if vbox:
		for child in vbox.get_children():
			if child is Label:
				_text_size(child, hud_font_size)
		var hud: MarginContainer = vbox.get_parent()  # (the clock, height and jumps: up in the room's corner)
		hud.add_theme_constant_override("margin_top", int(room.position.y) + 15)
		hud.add_theme_constant_override("margin_right", int(vp.x - room.end.x) + 15)

	# ── WIN SCREEN ────────────────────────────────────────────────────────
	_apply_win_layout()

	# ── CAMERA ZOOM ───────────────────────────────────────────────────────
	_apply_camera_zoom()


func _apply_camera_zoom() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ratio: float = vp.y / vp.x
	# Portrait threshold (zoom 1.0): ratio >= 1.3  (vp.y > vp.x * 1.3)
	# Landscape threshold (zoom 0.55): ratio <= 0.65
	var t: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
	var zoom_val: float = lerp(0.55, 1.0, t)
	var cam := $Camera2D
	if cam == null:
		return
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(cam, "zoom", Vector2(zoom_val, zoom_val), 0.7) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_zoom_tween.finished.connect(func(): _zoom_tween = null)


func _ensure_pause_wardrobe_btn(bl: float, br: float, bh: float, btn_top: float, font_sz: int) -> void:
	var wpb: Button = $PauseScreen.get_node_or_null("WardrobePauseBtn")
	if not MusicManager.has_any_cosmetic():
		if wpb:
			wpb.visible = false
		return
	if wpb == null:
		wpb = Button.new()
		wpb.name = "WardrobePauseBtn"
		wpb.focus_mode = Control.FOCUS_NONE
		wpb.pressed.connect(_on_pause_wardrobe_pressed)
		$PauseScreen.add_child(wpb)
		_attach_new_badge(wpb)
	wpb.text = "WARDROBE"
	_refresh_new_badge(wpb)
	load("res://scripts/UIStyle.gd").style_button(wpb, font_sz, "gold")
	wpb.offset_left   = bl
	wpb.offset_top    = btn_top
	wpb.offset_right  = br
	wpb.offset_bottom = btn_top + bh
	wpb.visible = true


func _ensure_pause_remove_ads_btn(bl: float, br: float, bh: float, btn_top: float, font_sz: int) -> void:
	var rapb: Button = $PauseScreen.get_node_or_null("RemoveAdsPauseBtn")
	if AdsManager.is_ad_free():  # bought already, or no ads on this platform (desktop/web)
		if rapb:
			rapb.queue_free()
		return
	if rapb == null:
		rapb = Button.new()
		rapb.name = "RemoveAdsPauseBtn"
		rapb.focus_mode = Control.FOCUS_NONE
		rapb.pressed.connect(_on_pause_remove_ads_pressed)
		$PauseScreen.add_child(rapb)
	rapb.text = "REMOVE ADS"
	load("res://scripts/UIStyle.gd").style_button(rapb, font_sz, "quiet")
	rapb.offset_left   = bl
	rapb.offset_top    = btn_top
	rapb.offset_right  = br
	rapb.offset_bottom = btn_top + bh


func _on_pause_remove_ads_pressed() -> void:
	var screen = load("res://scenes/RemoveAdsScreen.gd").new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		remove_child(screen)
		# Refresh layout in case ads were removed
		_apply_ui_layout()
	)


func _attach_new_badge(btn: Button) -> void:
	if btn.get_node_or_null("NewBadge"):
		return
	# Red pill badge anchored to the top-right corner of the button.
	# Uses PRESET_TOP_RIGHT so offsets track the button's right/top edges at any size.
	var badge := Panel.new()
	badge.name = "NewBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left   = -14
	badge.offset_top    = -4
	badge.offset_right  = 4
	badge.offset_bottom = 14
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.1, 0.1, 1.0)
	style.corner_radius_top_left     = 9
	style.corner_radius_top_right    = 9
	style.corner_radius_bottom_left  = 9
	style.corner_radius_bottom_right = 9
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.64, 0.0, 0.171, 1.0)
	badge.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = " "
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(lbl)
	badge.visible = MusicManager.has_unseen_cosmetics()
	btn.add_child(badge)


func _refresh_new_badge(btn: Button) -> void:
	if not btn.get_node_or_null("NewBadge"):
		_attach_new_badge(btn)
	var badge := btn.get_node_or_null("NewBadge")
	if badge:
		badge.visible = MusicManager.has_unseen_cosmetics()


func _refresh_all_wardrobe_badges() -> void:
	var wpb := $PauseScreen.get_node_or_null("WardrobePauseBtn") as Button
	if wpb:
		_refresh_new_badge(wpb)
	var menu := get_node_or_null("titlescreen/TitleMenu")
	var wb := menu.find_child("WardrobeButton", true, false) as Button if menu else null
	if wb:
		_refresh_new_badge(wb)


func _restore_world_pickups() -> void:
	if "cakehat" in MusicManager.unlocked_skins:
		var cake := get_node_or_null("../World Sprites/PineappleUpside-downCakeArea2D/PineappleUpside-downCake")
		if cake:
			cake.texture = load("res://assets/Pineapple_Upside-Down_Cake_EATEN.png")
	if "wizhat" in MusicManager.unlocked_skins:
		pass  # wiz stays visible; jump tween handles interaction


func _on_wiz_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body != self or _just_loaded:
		return
	var wiz_sprite := get_node_or_null("../WizArea2D/Wiz0Sprite")
	if wiz_sprite and _wiz_tween == null:
		_wiz_sprite_base_y = wiz_sprite.position.y
		_wiz_tween = create_tween().set_loops()
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y - 18.0, 0.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y, 0.25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_wiz_tween.tween_interval(0.15)
	if "wizhat" not in MusicManager.unlocked_skins:
		MusicManager.unlocked_skins.append("wizhat")
		MusicManager.save_wardrobe()
		MusicManager.show_unlock_notification("hat", "wizhat")
		_refresh_all_wardrobe_badges()
		for snd in ["res://assets/powerUp.wav", "res://assets/coolfind.mp3"]:
			var sfx := AudioStreamPlayer.new()
			sfx.stream = load(snd)
			add_child(sfx)
			sfx.play()
			sfx.finished.connect(sfx.queue_free)


func _on_wiz_area_2d_body_exited(body: Node2D) -> void:
	if body != self:
		return
	if _wiz_tween:
		_wiz_tween.kill()
		_wiz_tween = null
	var wiz_sprite := get_node_or_null("../WizArea2D/Wiz0Sprite")
	if wiz_sprite:
		_wiz_tween = create_tween()
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
		_wiz_tween.finished.connect(func(): _wiz_tween = null)


func _on_pineapple_upsidedown_cake_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body != self or _just_loaded:
		return
	var cake := get_node_or_null("../World Sprites/PineappleUpside-downCakeArea2D/PineappleUpside-downCake")
	if cake and cake.texture != load("res://assets/Pineapple_Upside-Down_Cake_EATEN.png"):
		cake.texture = load("res://assets/Pineapple_Upside-Down_Cake_EATEN.png")
		for snd in ["res://assets/powerUp.wav", "res://assets/coolfind.mp3"]:
			var sfx := AudioStreamPlayer.new()
			sfx.stream = load(snd)
			add_child(sfx)
			sfx.play()
			sfx.finished.connect(sfx.queue_free)
		if "cakehat" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("cakehat")
			MusicManager.save_wardrobe()
			MusicManager.show_unlock_notification("hat", "cakehat")
			_refresh_all_wardrobe_badges()


func _test_hat_notif() -> void:
	MusicManager.show_unlock_notification("hat", "wizhat")

func _test_skin_notif() -> void:
	MusicManager.show_unlock_notification("skin", "golden_skin")
