extends CharacterBody2D

@export var debug_unlock_crown: bool = false
@export var debug_unlock_golden_skin: bool = false
@export var debug_unlock_grayscale_skin: bool = false
@export var debug_unlock_negative_skin: bool = false
@export var debug_unlock_blackcrown: bool = false
@export var debug_unlock_wizhat: bool = false
@export var debug_unlock_cakehat: bool = false
@export var debug_beat_game: bool = false

@export_group("Settings Panel Nudge")
@export var settings_nudge_landscape: Vector2 = Vector2(0, 0)
@export var settings_nudge_portrait: Vector2 = Vector2(0, 0)
@export_group("")

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var bestRun = 1
var jumpCount = 0
var time_elapsed
var time_now
var time_start
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
var finalTime
var finalTimeBool = 0
var finalbuttonBool = 0
var hours = 0
var lanternbool = 0

var save_path = "user://save_game.save"
var _pending_reset_type: String = ""
var was_airborne = false
var key_node = null
var key_trail_pos = Vector2.ZERO
var key_last_dir = -1.0
var _resize_timer: SceneTreeTimer = null
var _just_loaded: bool = false
var _active_wardrobe: CanvasLayer = null
var _wiz_tween: Tween = null
var _wiz_sprite_base_y: float = 0.0
var _zoom_tween: Tween = null
var _crt_normal_volume: float = -20.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var highScore
var currentHeight

func _ready():

	get_tree().root.content_scale_size = Vector2i(480, 270)

	currentHeight = (-position.y - 472) /10
	highScore = currentHeight
	time_start = Time.get_unix_time_from_system()

	load_game()
	_just_loaded = true
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func(): _just_loaded = false)

	if FileAccess.file_exists(save_path):
		$titlescreen/HBoxContainer/Button.text = "Continue"

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

	# Move endless button into a dedicated row2 container so portrait can use a 2-row layout
	var _row2 := HBoxContainer.new()
	_row2.name = "TitleRow2"
	_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_row2.anchor_left = 0.5; _row2.anchor_top = 0.5
	_row2.anchor_right = 0.5; _row2.anchor_bottom = 0.5
	_row2.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row2.grow_vertical = Control.GROW_DIRECTION_BOTH
	$titlescreen.add_child(_row2)
	$titlescreen/HBoxContainer/endlessmodebutton.reparent(_row2)

	if MusicManager.has_any_cosmetic():
		var wb := Button.new()
		wb.name = "WardrobeButton"
		var ref_btn := _row2.get_node("endlessmodebutton")
		wb.theme = ref_btn.theme
		wb.add_theme_font_override("font", ref_btn.get_theme_font("font"))
		wb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		wb.add_theme_constant_override("outline_size", 5)
		wb.text = "   "
		wb.icon = load("res://assets/crownicon.png")
		wb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wb.expand_icon = true
		_row2.add_child(wb)
		wb.pressed.connect(_on_wardrobe_button_pressed)
		_attach_new_badge(wb)

	get_viewport().size_changed.connect(_on_viewport_resized)
	$PauseScreen.visibility_changed.connect(_on_pause_screen_visibility_changed)
	AdsManager.connect("ads_removed_changed", _apply_ui_layout)

	_setup_crt_state()
	if MusicManager.game_beaten:
		_activate_beaten_crt()
	# Hide title screen immediately so buttons never appear at their .tscn default sizes.
	# _initial_title_layout() fires before the first rendered frame and shows the
	# title screen only after layout is already correct.
	$titlescreen.visible = false
	call_deferred("_initial_title_layout")
	$Camera2D/AnimationPlayer.last_keyframe_reached.connect(_on_end_animation_finished)

	await get_tree().create_timer(0.5, true, false, true).timeout
	_apply_ui_layout()


func _physics_process(delta):
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
	
	if Engine.time_scale != 0.05 and $Trajectory.endGame == 0:
		time_now = Time.get_unix_time_from_system()
		var time_elapsed = time_now - time_start

		seconds = time_elapsed

		if time_elapsed >= 60:
			minutes += 1
			time_elapsed = 0
			seconds = 0
			time_start = Time.get_unix_time_from_system()

		if minutes >= 60:
			hours += 1
			minutes = 0
	else:
		time_start = Time.get_unix_time_from_system() - seconds
		
	
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
		velocity = Vector2(0,0)
		$"../finale/finale walls/toshow".visible = false
		$"../Blackfaderect".visible = false
		$"../World Sprites/tutorial".visible = false
		$"../World Sprites/tutorial2".visible = false
		$"../World Sprites/tutorial3".visible = false
		$"../World Sprites/tutorial4".visible = false
		await get_tree().create_timer(1.0).timeout
		$Camera2D/AnimationPlayer.play("end")
		if finalTimeBool == 0:
			# THIS HAPPENS ONCE WHEN GAME ENDS
			finalTime = str(int(minutes))+ ":"+str("%02d" % seconds)
			finalTimeBool =1
			
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
	

		
	# Add the gravity.
	if not is_on_floor():
		was_airborne = true
		velocity.y += gravity * delta
		$Sprite2D.play("airborne")
		$Shadow.play("airborne")
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, 0.0, 10.0 * delta)
		$Shadow.rotation = $Sprite2D.rotation

		if is_on_wall():
			print("Wall detected at position: ", position)
			velocity.x = -tempVelocityx
			print("New velocity: ", velocity)


	if is_on_floor():
		if was_airborne:
			was_airborne = false
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
		if hours == 0:
			$CanvasLayer/MarginContainer/VBoxContainer/time.text = ("time: " + str(int(minutes))+ ":"+str("%02d" % seconds) )
		else:
			if minutes < 10:
				$CanvasLayer/MarginContainer/VBoxContainer/time.text = ("time: "+ str(int(hours)) + ":0" + str(int(minutes))+ ":"+str("%02d" % seconds) )
			else:
				$CanvasLayer/MarginContainer/VBoxContainer/time.text = ("time: "+ str(int(hours)) + ":" + str(int(minutes))+ ":"+str("%02d" % seconds) )
	
	
	fade_darkness()

	if has_key and key_node and is_instance_valid(key_node):
		if velocity.x != 0:
			key_last_dir = sign(velocity.x)
		var trail_offset = Vector2(-key_last_dir * 30, 0)
		key_trail_pos = lerp(key_trail_pos, position + trail_offset, delta * 5.0)
		key_node.position = key_trail_pos

	var _hat_y := -11.16667 if MusicManager.equipped_skin == "negative_skin" else -9.16667
	if $Froggycrown.visible:
		$Froggycrown.rotation = $Sprite2D.rotation
		$Froggycrown.position = Vector2(0, _hat_y).rotated($Sprite2D.rotation)

	if $FroggyWizHat.visible:
		$FroggyWizHat.rotation = $Sprite2D.rotation
		$FroggyWizHat.position = Vector2(0, _hat_y).rotated($Sprite2D.rotation)

	if $FroggyCakeHat.visible:
		$FroggyCakeHat.rotation = $Sprite2D.rotation
		$FroggyCakeHat.position = Vector2(0, _hat_y).rotated($Sprite2D.rotation)

	move_and_slide()


func _on_area_2d_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	velocity = Vector2(-500, -400)
	$"../frogNPC3/campfire/Area2D/burnSound".play()
	
	
	

func fade_lantern(target_alpha):
	var t := create_tween()
	t.tween_property($FrogLantern, "modulate:a", target_alpha, fade_duration)

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
		await get_tree().create_timer(0.5).timeout
		$"../World Sprites/Keyhole".queue_free()
	else:
		$"../World Sprites/Keyhole/donthavekey".play()
		print("keyhole fail")


func _on_restart_button_pressed():
	$frogaim.play()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	

func _on_mute_button_pressed():
	$frogaim.play()
	#MUTE MUSIC
	AudioServer.set_bus_mute(1, not AudioServer.is_bus_mute(1))


func _on_speedrun_mode_button_pressed():
	$frogaim.play()
	SpeedrunMode = !SpeedrunMode
	save_game()
	_apply_speedrun_visibility()


func _apply_speedrun_visibility() -> void:
	$"CanvasLayer/MarginContainer/VBoxContainer/current height".visible = SpeedrunMode
	$CanvasLayer/MarginContainer/VBoxContainer/time.visible = SpeedrunMode
	$CanvasLayer/MarginContainer/VBoxContainer/jumpcount.visible = SpeedrunMode
	var smb := $PauseScreen/settingsContainer.get_node_or_null("SpeedrunModeButton")
	if smb:
		smb.button_pressed = SpeedrunMode



func _on_blockedpath_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	velocity = Vector2(500, -300)
	$"../Environmental Audio/pathBreaking".play()
	$"../World Sprites/Blockedpath".queue_free()


func _on_button_pressed():
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
	


func _on_thanksforplaying_timer_timeout():
	$winscreen/thanksforplayingButton.visible = true


func _on_thanksforplaying_button_pressed():
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("Save file deleted on game complete.")
	MusicManager.MusicPosition = $winscreen/goodbyefroggy.get_playback_position()
	MusicManager.froggyCrown = 1
	MusicManager.equipped_hat = "froggycrown"
	MusicManager.game_beaten = true
	MusicManager.save_wardrobe()
	get_tree().reload_current_scene()
	Engine.time_scale = 1.0


func _on_settings_button_pressed():
	$frogaim.play()
	$PauseScreen/RestartButton.visible=false
	$PauseScreen/SettingsButton.visible=false
	$PauseScreen/ResumeButton.visible=false
	var _wpb = $PauseScreen.get_node_or_null("WardrobePauseBtn")
	if _wpb: _wpb.visible = false
	var _rapb = $PauseScreen.get_node_or_null("RemoveAdsPauseBtn")
	if _rapb: _rapb.visible = false
	$PauseScreen/settingsContainer.visible=true
	$PauseScreen/BackfromSettingsButton.visible = true
	


func _on_backfrom_settings_button_pressed():
	$frogaim.play()
	$PauseScreen/RestartButton.visible=true
	$PauseScreen/SettingsButton.visible=true
	$PauseScreen/ResumeButton.visible=true
	var _wpb = $PauseScreen.get_node_or_null("WardrobePauseBtn")
	if _wpb: _wpb.visible = true
	var _rapb = $PauseScreen.get_node_or_null("RemoveAdsPauseBtn")
	if _rapb: _rapb.visible = not MusicManager.ads_removed
	$PauseScreen/settingsContainer.visible=false
	$PauseScreen/BackfromSettingsButton.visible = false


func _on_resume_button_pressed():

	$frogjump.pitch_scale = randf_range(0.8, 1.2)
	$frogjump.play()
	#GAME IS UNPAUSED HERE
	$PauseScreen.visible=false
	Engine.time_scale = 1.0

#CHANGE SENSITIVITY
#CHANGE SENSITIVITY
#CHANGE SENSITIVITY
func _on_l_pressed():
	$frogaim.play()
	$Trajectory.sensitivity = 3.5


func _on_m_pressed():
	$frogaim.play()
	$Trajectory.sensitivity = 4


func _on_h_pressed():
	$frogaim.play()
	$Trajectory.sensitivity = 4.5


func _on_restart_yes_pressed():
	$frogaim.play()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if _pending_reset_type == "all":
		if FileAccess.file_exists(MusicManager.WARDROBE_PATH):
			DirAccess.remove_absolute(MusicManager.WARDROBE_PATH)
		const ENDLESS_SCORE_PATH := "user://endless_highscore.dat"
		if FileAccess.file_exists(ENDLESS_SCORE_PATH):
			DirAccess.remove_absolute(ENDLESS_SCORE_PATH)
		MusicManager.froggyCrown = 0
		MusicManager.equipped_hat = ""
		MusicManager.equipped_skin = ""
		MusicManager.unlocked_skins = []
		MusicManager.seen_cosmetics = []
		MusicManager.game_beaten = false
	_pending_reset_type = ""
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_restart_no_pressed():
	$frogaim.play()
	$PauseScreen/RestartConfirmContainer.visible = false
	# Return to settings (this confirm is only reachable from there now)
	$PauseScreen/settingsContainer.visible = true
	$PauseScreen/BackfromSettingsButton.visible = true


func _on_reset_climb_btn_pressed() -> void:
	$frogaim.play()
	_pending_reset_type = "climb"
	$PauseScreen/settingsContainer.visible = false
	$PauseScreen/BackfromSettingsButton.visible = false
	var lbl = $PauseScreen/RestartConfirmContainer.get_node_or_null("Paused2")
	if lbl:
		lbl.text = "RESET\nCLIMB?"
	$PauseScreen/RestartConfirmContainer.visible = true


func _on_reset_all_data_btn_pressed() -> void:
	$frogaim.play()
	_pending_reset_type = "all"
	$PauseScreen/settingsContainer.visible = false
	$PauseScreen/BackfromSettingsButton.visible = false
	var lbl = $PauseScreen/RestartConfirmContainer.get_node_or_null("Paused2")
	if lbl:
		lbl.text = "DELETE ALL\nDATA?"
	$PauseScreen/RestartConfirmContainer.visible = true


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


func _on_mute_button_2_pressed():
	$frogaim.play()
	#MUTE MUSIC
	AudioServer.set_bus_mute(2, not AudioServer.is_bus_mute(2))


func setup_key_trail():
	key_node = get_parent().get_node_or_null("World Sprites/Key")
	if key_node:
		key_node.visible = true
		key_trail_pos = position


func save_game():
	if currentHeight > 513:  # skip autosave in finale area
		return
	var save_data = {
		"position": position,
		"has_key": has_key,
		"has_lantern": has_lantern,
		"hours": hours,
		"minutes": minutes,
		"seconds": seconds,
		"SpeedrunMode": SpeedrunMode,
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
	file.store_var(save_data)
	file.close()
	print("Game saved.")


func load_game():
	if not FileAccess.file_exists(save_path):
		return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	var save_data = file.get_var()
	file.close()

	position = save_data.get("position", position)
	has_key = save_data.get("has_key", has_key)
	has_lantern = save_data.get("has_lantern", has_lantern)
	hours = save_data.get("hours", 0)
	minutes = save_data.get("minutes", 0)
	seconds = save_data.get("seconds", 0)
	time_start = Time.get_unix_time_from_system() - seconds
	SpeedrunMode = save_data.get("SpeedrunMode", false)
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
	tween.tween_property(crt_audio, "volume_db", _crt_normal_volume - 9.5, 4.0)
	await $winscreen/goodbyefroggy.finished
	if not is_instance_valid(crt_audio):
		return
	var restore := create_tween()
	restore.tween_property(crt_audio, "volume_db", _crt_normal_volume, 4.0)


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

	var skin := MusicManager.equipped_skin
	match skin:
		"golden_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/skin_tint.gdshader")
			mat.set_shader_parameter("tint_color", Color(1.0, 0.75, 0.0))
			mat.set_shader_parameter("tint_strength", 0.55)
			$Sprite2D.material = mat
		"grayscale_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/grayscale.gdshader")
			$Sprite2D.material = mat
		"negative_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/negative.gdshader")
			$Sprite2D.material = mat
		_:
			$Sprite2D.material = null
	$Shadow.visible = (skin != "negative_skin")


func _on_wardrobe_button_pressed() -> void:
	$frogaim.play()
	var ws = load("res://scenes/WardrobeScreen.gd").new()
	add_child(ws)
	_active_wardrobe = ws
	ws.closed.connect(func() -> void:
		_active_wardrobe = null
		remove_child(ws)
		_apply_equipped_cosmetics()
		for container in [$titlescreen.get_node_or_null("TitleRow2"), $titlescreen/HBoxContainer]:
			if not container:
				continue
			var wb = container.get_node_or_null("WardrobeButton")
			if wb:
				wb.visible = MusicManager.has_any_cosmetic()
				_refresh_new_badge(wb)
	)


func _on_endlessmodebutton_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/EndlessMode.tscn")


func _on_viewport_resized() -> void:
	_resize_timer = get_tree().create_timer(0.5, true, false, true)
	var t := _resize_timer
	await t.timeout
	if t != _resize_timer or not is_inside_tree():
		return
	_apply_ui_layout()


func _on_pause_screen_visibility_changed() -> void:
	if $PauseScreen.visible:
		if _active_wardrobe and is_instance_valid(_active_wardrobe):
			_active_wardrobe.closed.emit()
		_apply_ui_layout()


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
		$winscreen/thanksforplayingTimer.start()
		finalbuttonBool = 1
		$Camera2D.position = Vector2(-1770.67, 7144.045)
		_apply_win_layout()


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
		congrats.add_theme_font_size_override("font_size", 46)
		congrats.add_theme_constant_override("outline_size", 7)

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
		time2_lbl.add_theme_font_size_override("font_size", 34)
		time2_lbl.add_theme_constant_override("outline_size", 6)

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
		btn.add_theme_font_size_override("font_size", 34)

		by_muse2.add_theme_font_size_override("font_size", 26)
		by_muse2.add_theme_constant_override("outline_size", 5)
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
		congrats.add_theme_font_size_override("font_size", 28)
		congrats.add_theme_constant_override("outline_size", 6)

		time2_lbl.anchor_left   = 0.0
		time2_lbl.anchor_right  = 1.0
		time2_lbl.anchor_top    = 0.6
		time2_lbl.anchor_bottom = 0.73
		time2_lbl.offset_left   = 8.0
		time2_lbl.offset_right  = -8.0
		time2_lbl.offset_top    = 0.0
		time2_lbl.offset_bottom = 0.0
		time2_lbl.add_theme_font_size_override("font_size", 16)
		time2_lbl.add_theme_constant_override("outline_size", 4)

		var hw: float = min(120.0, vp.x * 0.22)
		btn.anchor_left   = 0.5
		btn.anchor_right  = 0.5
		btn.anchor_top    = 0.74
		btn.anchor_bottom = 0.74
		btn.offset_left   = -hw
		btn.offset_right  =  hw
		btn.offset_top    = 0.0
		btn.offset_bottom = 40.0
		btn.add_theme_font_size_override("font_size", 19)

		by_muse2.add_theme_font_size_override("font_size", 13)
		by_muse2.add_theme_constant_override("outline_size", 3)


func _initial_title_layout() -> void:
	_apply_ui_layout()
	$titlescreen.visible = true


func _apply_ui_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.y > vp.x * 1.3
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5


	# ── TITLE SCREEN ─────────────────────────────────────────────────────
	var title    := $titlescreen/Title
	var fx3      := $titlescreen/earthboundbattleFX3
	var by_muse  := $"titlescreen/by muse"
	var hbox     := $titlescreen/HBoxContainer

	var row2 = $titlescreen.get_node_or_null("TitleRow2")
	if is_portrait:
		title.position    = Vector2(cx, vp.y * 0.25)
		title.scale       = Vector2(0.5, 0.5)
		fx3.position      = Vector2(cx, vp.y * 0.75)
		# "by muse" pinned near bottom — anchor_top=1.0 so negative offset = above bottom
		by_muse.offset_left   = 0.0
		by_muse.offset_top    = -36.0
		by_muse.offset_right  = 0.0
		by_muse.offset_bottom = 0.0
		by_muse.scale         = Vector2(1.0, 1.0)
		by_muse.add_theme_font_size_override("font_size", 32)
		by_muse.add_theme_constant_override("outline_size", 5)
		if row2:
			row2.visible = true
			# Move endlessmodebutton/WardrobeButton back from hbox if landscape moved them there
			for _btn_name in ["endlessmodebutton", "WardrobeButton"]:
				var _btn = hbox.get_node_or_null(_btn_name)
				if _btn:
					_btn.reparent(row2)
			# Two-row: START alone on row1 (full width), ENDLESS+WARDROBE on row2
			hbox.offset_left   = -(cx - 10.0)
			hbox.offset_top    = vp.y * 0.50 - cy
			hbox.offset_right  = cx - 10.0
			hbox.offset_bottom = hbox.offset_top + 60.0
			$titlescreen/HBoxContainer/Button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			$titlescreen/HBoxContainer/Button.add_theme_font_size_override("font_size", 46)
			row2.offset_left   = -(cx - 10.0)
			row2.offset_top    = hbox.offset_bottom + 8.0
			row2.offset_right  = cx - 10.0
			row2.offset_bottom = row2.offset_top + 60.0
			var eb_p = row2.get_node_or_null("endlessmodebutton")
			if eb_p:
				eb_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				eb_p.add_theme_font_size_override("font_size", 46)
			var wb_p = row2.get_node_or_null("WardrobeButton")
			if wb_p:
				wb_p.visible = MusicManager.has_any_cosmetic()
				wb_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				wb_p.add_theme_font_size_override("font_size", 46)
		else:
			hbox.offset_left   = -(cx - 10.0)
			hbox.offset_top    = vp.y * 0.50 - cy
			hbox.offset_right  = cx - 10.0
			hbox.offset_bottom = hbox.offset_top + 80.0
			$titlescreen/HBoxContainer/Button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			$titlescreen/HBoxContainer/Button.add_theme_font_size_override("font_size", 46)
			$titlescreen/HBoxContainer/endlessmodebutton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			$titlescreen/HBoxContainer/endlessmodebutton.add_theme_font_size_override("font_size", 46)
	else:
		title.position    = Vector2(cx, 85.0)
		title.scale       = Vector2(0.3, 0.3)
		fx3.position      = Vector2(cx, 238.0)
		# "by muse" pinned near bottom — same trick as portrait
		by_muse.offset_left   = 0.0
		by_muse.offset_top    = -22.0
		by_muse.offset_right  = 0.0
		by_muse.offset_bottom = 0.0
		by_muse.scale         = Vector2(1.0, 1.0)
		by_muse.add_theme_font_size_override("font_size", 32)
		by_muse.add_theme_constant_override("outline_size", 8)
		# All title buttons in one hbox for uniform gaps in landscape
		var ls_half: float = vp.x * 0.34
		if row2:
			row2.visible = false
			# Move endlessmodebutton/WardrobeButton into hbox so spacing is handled by HBoxContainer
			for _btn_name in ["endlessmodebutton", "WardrobeButton"]:
				var _btn = row2.get_node_or_null(_btn_name)
				if _btn:
					_btn.reparent(hbox)
		hbox.offset_left   = -ls_half
		hbox.offset_top    = 16.0
		hbox.offset_right  = ls_half
		hbox.offset_bottom = 64.0
		$titlescreen/HBoxContainer/Button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$titlescreen/HBoxContainer/Button.add_theme_font_size_override("font_size", 32)
		$titlescreen/HBoxContainer/Button.remove_theme_stylebox_override("normal")
		$titlescreen/HBoxContainer/Button.remove_theme_stylebox_override("hover")
		for _state in ["normal", "hover"]:
			var _sb: StyleBox = $titlescreen/HBoxContainer/Button.get_theme_stylebox(_state)
			if _sb:
				var _dup := _sb.duplicate()
				var _cur_l: float = _dup.get_content_margin(SIDE_LEFT)
				var _cur_r: float = _dup.get_content_margin(SIDE_RIGHT)
				_dup.set_content_margin(SIDE_LEFT,  (0.0 if _cur_l < 0 else _cur_l)  + 14)
				_dup.set_content_margin(SIDE_RIGHT, (0.0 if _cur_r < 0 else _cur_r) + 14)
				$titlescreen/HBoxContainer/Button.add_theme_stylebox_override(_state, _dup)
		var eb_l = hbox.get_node_or_null("endlessmodebutton")
		if eb_l:
			eb_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eb_l.add_theme_font_size_override("font_size", 32)
		var wb_l = hbox.get_node_or_null("WardrobeButton")
		if wb_l:
			wb_l.visible = MusicManager.has_any_cosmetic()
			wb_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wb_l.add_theme_font_size_override("font_size", 32)

	# ── PAUSE SCREEN ──────────────────────────────────────────────────────
	var overlay      := $PauseScreen/MeshInstance2D
	var paused_lbl   := $PauseScreen/Paused
	var resume_btn   := $PauseScreen/ResumeButton
	var settings_btn := $PauseScreen/SettingsButton
	var restart_btn  := $PauseScreen/RestartButton
	var back_btn     := $PauseScreen/BackfromSettingsButton
	var settings_c   := $PauseScreen/settingsContainer
	var confirm_c    := $PauseScreen/RestartConfirmContainer
	var eb_fx        := $PauseScreen/earthboundbattleFX2

	# Overlay always covers the full viewport regardless of aspect ratio
	overlay.position = Vector2(cx, cy)
	overlay.scale    = Vector2(vp.x + 4.0, vp.y + 4.0)
	eb_fx.position = Vector2(cx, cy)
	eb_fx.scale    = Vector2(vp.x * 1.3 / 320.0, vp.y * 1.18 / 180.0)

	# Always restore settings children to .tscn values before any container scaling
	# so the scaled layout starts from the correct baseline every time
	$PauseScreen/settingsContainer/MuteButton.offset_left   = -100.0
	$PauseScreen/settingsContainer/MuteButton.offset_top    = -1.0
	$PauseScreen/settingsContainer/MuteButton.offset_right  = -56.0
	$PauseScreen/settingsContainer/MuteButton.offset_bottom = 23.0
	$PauseScreen/settingsContainer/MuteButton2.offset_left   = -101.0
	$PauseScreen/settingsContainer/MuteButton2.offset_top    = 24.0
	$PauseScreen/settingsContainer/MuteButton2.offset_right  = -57.0
	$PauseScreen/settingsContainer/MuteButton2.offset_bottom = 48.0
	$PauseScreen/settingsContainer/SpeedrunModeButton.offset_left   = 41.0
	$PauseScreen/settingsContainer/SpeedrunModeButton.offset_top    = -1.0
	$PauseScreen/settingsContainer/SpeedrunModeButton.offset_right  = 85.0
	$PauseScreen/settingsContainer/SpeedrunModeButton.offset_bottom = 23.0
	$PauseScreen/settingsContainer/Sensitivity.offset_left   = 65.0
	$PauseScreen/settingsContainer/Sensitivity.offset_top    = 2.00001
	$PauseScreen/settingsContainer/Sensitivity.offset_right  = 375.0
	$PauseScreen/settingsContainer/Sensitivity.offset_bottom = 47.0

	if is_portrait:
		paused_lbl.offset_left   = 10.0
		paused_lbl.offset_top    = vp.y * 0.20
		paused_lbl.offset_right  = vp.x - 10.0
		paused_lbl.offset_bottom = paused_lbl.offset_top + 60.0
		paused_lbl.pivot_offset  = Vector2((vp.x - 20.0) / 2.0, 30.0)
		paused_lbl.add_theme_font_size_override("font_size", 56)

		var bl: float = cx - 82.0
		var br: float = cx + 82.0
		var bh: float = 52.0
		# Anchor buttons just below PAUSED text rather than at a fixed percentage
		var bs: float = vp.y * 0.20 + 72.0

		resume_btn.offset_left   = bl;  resume_btn.offset_top    = bs
		resume_btn.offset_right  = br;  resume_btn.offset_bottom = bs + bh
		resume_btn.add_theme_font_size_override("font_size", 36)
		settings_btn.offset_left  = bl;  settings_btn.offset_top    = bs + bh + 8.0
		settings_btn.offset_right = br;  settings_btn.offset_bottom = bs + bh * 2.0 + 8.0
		settings_btn.add_theme_font_size_override("font_size", 32)
		restart_btn.offset_left  = bl;  restart_btn.offset_top    = bs + (bh + 8.0) * 2.0
		restart_btn.offset_right = br;  restart_btn.offset_bottom = bs + (bh + 8.0) * 2.0 + bh
		restart_btn.add_theme_font_size_override("font_size", 32)
		back_btn.offset_left  = bl;  back_btn.offset_top    = bs
		back_btn.offset_right = br;  back_btn.offset_bottom = bs + bh
		back_btn.add_theme_font_size_override("font_size", 32)

		# Scale settings: fit width AND ensure reset buttons (local y=102) stay on screen.
		# settingsContainer content spans local y -7..102 (total height 109).
		var settings_top_p: float = bs + bh + 14.0 + settings_nudge_portrait.y
		var avail_h_p: float = vp.y - settings_top_p - 4.0
		var sc: float = clamp(min((vp.x - 32.0) / 294.0, avail_h_p / 109.0), 0.3, 1.5)
		settings_c.anchor_left = 0.0; settings_c.anchor_top = 0.0
		settings_c.anchor_right = 0.0; settings_c.anchor_bottom = 0.0
		settings_c.offset_left   = cx - 44.0 * sc + settings_nudge_portrait.x
		settings_c.offset_top    = settings_top_p
		settings_c.offset_right  = settings_c.offset_left + 40.0
		settings_c.offset_bottom = settings_c.offset_top + 40.0
		settings_c.scale         = Vector2(sc, sc)
		settings_c.pivot_offset  = Vector2(0.0, 0.0)

		# Confirm dialog: full scale, centered on cx (YES/NO local centers at 97.5 and 228.5)
		confirm_c.offset_left   = cx - 163.0
		confirm_c.offset_top    = vp.y * 0.25
		confirm_c.offset_right  = cx - 123.0
		confirm_c.offset_bottom = vp.y * 0.75
		confirm_c.scale         = Vector2(1.0, 1.0)
		confirm_c.pivot_offset  = Vector2(0.0, 0.0)
		var wardrobe_slot_p: int = 3
		var ra_slot_p: int = wardrobe_slot_p + (1 if MusicManager.has_any_cosmetic() else 0)
		_ensure_pause_wardrobe_btn(bl, br, bh, bs + (bh + 8.0) * wardrobe_slot_p, 26)
		_ensure_pause_remove_ads_btn(bl, br, bh, bs + (bh + 8.0) * ra_slot_p, 26)
	else:
		# All positions scale with vp so any aspect ratio works
		var num_btns_ls: int = 3 + (1 if MusicManager.has_any_cosmetic() else 0) + (1 if not MusicManager.ads_removed else 0)
		var gap_ls: float = max(3.0, vp.y * 0.03)
		var paused_font_ls: int = max(20, int(vp.y * 0.18))
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
		paused_lbl.add_theme_font_size_override("font_size", paused_font_ls)

		var btn_font_ls: int = max(12, int(bh * 0.55))
		resume_btn.offset_left   = bl;  resume_btn.offset_top    = bs
		resume_btn.offset_right  = br;  resume_btn.offset_bottom = bs + bh
		resume_btn.add_theme_font_size_override("font_size", btn_font_ls)
		settings_btn.offset_left  = bl;  settings_btn.offset_top    = bs + bh + gap_ls
		settings_btn.offset_right = br;  settings_btn.offset_bottom = bs + bh * 2.0 + gap_ls
		settings_btn.add_theme_font_size_override("font_size", btn_font_ls)
		restart_btn.offset_left  = bl;  restart_btn.offset_top    = bs + (bh + gap_ls) * 2.0
		restart_btn.offset_right = br;  restart_btn.offset_bottom = bs + (bh + gap_ls) * 2.0 + bh
		restart_btn.add_theme_font_size_override("font_size", btn_font_ls)
		var settings_top_ls: float = bs + bh + gap_ls + settings_nudge_landscape.y
		var back_top_ls: float = paused_bottom_ls + gap_ls * -1.5
		back_btn.offset_left  = bl;  back_btn.offset_top    = back_top_ls
		back_btn.offset_right = br;  back_btn.offset_bottom = back_top_ls + bh

		# Settings container: fit width AND height so reset buttons (local y=102) stay on screen.
		# settingsContainer content spans local y -7..102 (total height 109).
		var avail_h_ls: float = vp.y - settings_top_ls - 4.0
		var sc_ls: float = clamp(min((vp.x - 32.0) / 294.0, avail_h_ls / 109.0), 0.3, 1.5)
		settings_c.anchor_left = 0.0; settings_c.anchor_top = 0.0
		settings_c.anchor_right = 0.0; settings_c.anchor_bottom = 0.0
		settings_c.offset_left   = cx - 44.0 * sc_ls + settings_nudge_landscape.x
		settings_c.offset_top    = settings_top_ls
		settings_c.offset_right  = settings_c.offset_left + 40.0
		settings_c.offset_bottom = settings_c.offset_top + 40.0
		settings_c.scale         = Vector2(sc_ls, sc_ls)
		settings_c.pivot_offset  = Vector2(0.0, 0.0)

		# Confirm dialog: centered
		confirm_c.offset_left   = cx - 100.0
		confirm_c.offset_top    = vp.y * 0.25
		confirm_c.offset_right  = cx - 60.0
		confirm_c.offset_bottom = vp.y * 0.75
		confirm_c.scale         = Vector2(0.6, 0.6)
		confirm_c.pivot_offset  = Vector2(0.0, 0.0)
		var wardrobe_slot: int = 3
		var ra_slot: int = wardrobe_slot + (1 if MusicManager.has_any_cosmetic() else 0)
		_ensure_pause_wardrobe_btn(bl, br, bh, bs + (bh + gap_ls) * wardrobe_slot, max(12, int(bh * 0.5)))
		_ensure_pause_remove_ads_btn(bl, br, bh, bs + (bh + gap_ls) * ra_slot, max(12, int(bh * 0.5)))

	# ── COMMON (both orientations) ────────────────────────────────────────
	restart_btn.text = "EXIT"
	_ensure_reset_progress_btn()

	# ── PAUSE BUTTON ──────────────────────────────────────────────────────
	var pause_btn := $CanvasLayer/TouchScreenButtonPause
	if pause_btn:
		var ratio: float = vp.y / vp.x
		var t_btn: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
		var btn_scale: float = lerp(1.5, 2.5, t_btn)
		var btn_pos: float = lerp(26.0, 42.0, t_btn)
		pause_btn.scale = Vector2(btn_scale, btn_scale)
		pause_btn.position = Vector2(btn_pos, btn_pos)

	# ── HUD LABELS ───────────────────────────────────────────────────────
	var ratio_hud: float = vp.y / vp.x
	var t_hud: float = inverse_lerp(0.65, 1.3, clamp(ratio_hud, 0.65, 1.3))
	var hud_font_size: int = int(round(lerp(24.0, 36.0, t_hud)))
	var vbox := $CanvasLayer.get_node_or_null("MarginContainer/VBoxContainer")
	if vbox:
		for child in vbox.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", hud_font_size)

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
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
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
		wpb.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
		wpb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		wpb.add_theme_constant_override("outline_size", 8)
		wpb.pressed.connect(_on_pause_wardrobe_pressed)
		$PauseScreen.add_child(wpb)
		_attach_new_badge(wpb)
	wpb.text = "WARDROBE"
	_refresh_new_badge(wpb)
	wpb.add_theme_font_size_override("font_size", font_sz)
	wpb.add_theme_color_override("font_color", Color("#FFD966"))
	wpb.offset_left   = bl
	wpb.offset_top    = btn_top
	wpb.offset_right  = br
	wpb.offset_bottom = btn_top + bh
	var _settings_open: bool = $PauseScreen/settingsContainer.visible or $PauseScreen/RestartConfirmContainer.visible
	wpb.visible = not _settings_open


func _ensure_pause_remove_ads_btn(bl: float, br: float, bh: float, btn_top: float, font_sz: int) -> void:
	var rapb: Button = $PauseScreen.get_node_or_null("RemoveAdsPauseBtn")
	if MusicManager.ads_removed:
		if rapb:
			rapb.queue_free()
		return
	if rapb == null:
		rapb = Button.new()
		rapb.name = "RemoveAdsPauseBtn"
		rapb.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
		rapb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		rapb.add_theme_constant_override("outline_size", 8)
		rapb.pressed.connect(_on_pause_remove_ads_pressed)
		$PauseScreen.add_child(rapb)
	rapb.text = "REMOVE ADS"
	rapb.add_theme_font_size_override("font_size", font_sz)
	rapb.offset_left   = bl
	rapb.offset_top    = btn_top
	rapb.offset_right  = br
	rapb.offset_bottom = btn_top + bh
	var _settings_open: bool = $PauseScreen/settingsContainer.visible or $PauseScreen/RestartConfirmContainer.visible
	rapb.visible = not _settings_open


func _on_pause_remove_ads_pressed() -> void:
	var screen = load("res://scenes/RemoveAdsScreen.gd").new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		remove_child(screen)
		# Refresh layout in case ads were removed
		_apply_ui_layout()
	)


func _ensure_reset_progress_btn() -> void:
	var sc := $PauseScreen/settingsContainer
	# Remove old single-button if upgrading from older code
	var old := sc.get_node_or_null("ResetProgressBtn")
	if old:
		old.queue_free()
	var font := load("res://assets/fibberish.ttf")
	# Left: reset current climb only
	var rcb: Button = sc.get_node_or_null("ResetClimbBtn")
	if rcb == null:
		rcb = Button.new()
		rcb.name = "ResetClimbBtn"
		rcb.text = "RESET\nCLIMB"
		rcb.add_theme_font_override("font", font)
		rcb.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
		rcb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		rcb.add_theme_constant_override("outline_size", 3)
		rcb.pressed.connect(_on_reset_climb_btn_pressed)
		sc.add_child(rcb)
	rcb.add_theme_font_size_override("font_size", 15)
	rcb.offset_left   = -103.0
	rcb.offset_top    = 64.0
	rcb.offset_right  = 41.0
	rcb.offset_bottom = 102.0
	# Right: wipe all user data (skins + scores + save)
	var rdb: Button = sc.get_node_or_null("ResetAllDataBtn")
	if rdb == null:
		rdb = Button.new()
		rdb.name = "ResetAllDataBtn"
		rdb.text = "RESET ALL\nDATA"
		rdb.add_theme_font_override("font", font)
		rdb.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		rdb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		rdb.add_theme_constant_override("outline_size", 3)
		rdb.pressed.connect(_on_reset_all_data_btn_pressed)
		sc.add_child(rdb)
	rdb.add_theme_font_size_override("font_size", 15)
	rdb.offset_left   = 47.0
	rdb.offset_top    = 64.0
	rdb.offset_right  = 191.0
	rdb.offset_bottom = 102.0


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
	for path in ["titlescreen/TitleRow2/WardrobeButton", "titlescreen/HBoxContainer/WardrobeButton"]:
		var wb := get_node_or_null(path) as Button
		if wb:
			_refresh_new_badge(wb)
			break


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
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y - 18.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_wiz_tween.tween_interval(0.15)
	if "wizhat" not in MusicManager.unlocked_skins:
		MusicManager.unlocked_skins.append("wizhat")
		MusicManager.save_wardrobe()
		MusicManager.show_unlock_notification("hat")
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
		_wiz_tween.tween_property(wiz_sprite, "position:y", _wiz_sprite_base_y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
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
			MusicManager.show_unlock_notification("hat")
			_refresh_all_wardrobe_badges()
