@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	
	var bot_bar = hud.get_node("BottomBar")
	var cc = bot_bar.get_node("CharacterCluster")
	
	# Update CharacterCluster size and position
	cc.size = Vector2(500, 160)
	cc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cc.position = Vector2(-250, -220)
	
	# 1. Health Bar (Left)
	var hb = cc.get_node("HealthBar")
	var new_hb = TextureProgressBar.new()
	new_hb.name = "HealthBar"
	new_hb.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	new_hb.texture_progress = load("res://assets/generated/health_fill_cute_frame_0.png")
	new_hb.nine_patch_stretch = true
	new_hb.stretch_margin_left = 6
	new_hb.stretch_margin_right = 6
	new_hb.stretch_margin_top = 6
	new_hb.stretch_margin_bottom = 6
	new_hb.position = Vector2(0, 20)
	new_hb.size = Vector2(192, 64)
	new_hb.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
	
	var shim_script = GDScript.new()
	shim_script.source_code = "extends TextureProgressBar\nfunc set_value(v: float, mv: float) -> void:\n\tmax_value = max(mv, 0.001)\n\tvalue = v"
	shim_script.reload()
	new_hb.set_script(shim_script)
	hb.replace_by(new_hb, true)
	new_hb.owner = hud
	
	var hl = cc.get_node("HealthValueLabel")
	hl.position = Vector2(0, 20)
	hl.size = Vector2(192, 64)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override("font_size", 18)
	hl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	# 2. Portrait (Center)
	var pc = cc.get_node("PortraitClip")
	pc.position = Vector2(218, 16)
	pc.size = Vector2(64, 64)
	
	var p = pc.get_node("Portrait")
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.scale = Vector2(1.0, 1.0)
	
	# Add portrait frame
	if not cc.has_node("PortraitFrame"):
		var pf = TextureRect.new()
		pf.name = "PortraitFrame"
		pf.texture = load("res://assets/generated/cute_ui_portrait_frame_frame_0.png")
		pf.position = Vector2(218, 16)
		pf.size = Vector2(64, 64)
		cc.add_child(pf)
		cc.move_child(pf, pc.get_index() + 1) # Draw over
		pf.owner = hud
	
	var ll = cc.get_node("LevelLabel")
	ll.position = Vector2(218, 80)
	ll.size = Vector2(64, 30)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.add_theme_font_size_override("font_size", 16)
	
	# 3. Shield Bar (Right)
	var sb = cc.get_node("ShieldBar")
	var new_sb = TextureProgressBar.new()
	new_sb.name = "ShieldBar"
	new_sb.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	new_sb.texture_progress = load("res://assets/generated/shield_fill_cute_frame_0.png")
	new_sb.nine_patch_stretch = true
	new_sb.stretch_margin_left = 6
	new_sb.stretch_margin_right = 6
	new_sb.stretch_margin_top = 6
	new_sb.stretch_margin_bottom = 6
	new_sb.position = Vector2(308, 20)
	new_sb.size = Vector2(192, 64)
	new_sb.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	new_sb.set_script(shim_script)
	sb.replace_by(new_sb, true)
	new_sb.owner = hud
	
	var sl = cc.get_node("ShieldValueLabel")
	sl.position = Vector2(308, 20)
	sl.size = Vector2(192, 64)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.add_theme_font_size_override("font_size", 18)
	sl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	# 4. Shield Mode Slots (Moved under CharacterCluster to right side)
	var smb = bot_bar.get_node("ShieldModeBarBG")
	smb.texture = null # Remove old background
	smb.position = Vector2(-74, -120) # Centered
	smb.size = Vector2(250, 50)
	smb.scale = Vector2(1.0, 1.0)
	
	for i in range(1, 6):
		var slot = smb.get_node("ShieldModeSlot" + str(i))
		slot.position = Vector2((i-1)*56, 0)
		slot.size = Vector2(48, 48)
		# Add a background slot texture
		if not slot.has_node("BG"):
			var bg = TextureRect.new()
			bg.name = "BG"
			bg.texture = load("res://assets/generated/cute_ui_skill_slot_frame_0.png")
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(bg)
			slot.move_child(bg, 0)
			bg.owner = hud
	
	# 5. Skills (Moved under CharacterCluster to left side)
	var skill_bar = hud.get_node("SkillBar")
	skill_bar.position = Vector2(-188, -120) # Centered to the left of shield modes
	
	var s1 = skill_bar.get_node("SkillIcon")
	s1.position = Vector2(0, 0)
	s1.size = Vector2(48, 48)
	if not s1.has_node("BG"):
		var bg = TextureRect.new()
		bg.name = "BG"
		bg.texture = load("res://assets/generated/cute_ui_skill_slot_frame_0.png")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s1.add_child(bg)
		s1.move_child(bg, 0)
		bg.owner = hud
		
	var s2 = skill_bar.get_node("Skill2Icon")
	s2.position = Vector2(56, 0)
	s2.size = Vector2(48, 48)
	if not s2.has_node("BG"):
		var bg = TextureRect.new()
		bg.name = "BG"
		bg.texture = load("res://assets/generated/cute_ui_skill_slot_frame_0.png")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s2.add_child(bg)
		s2.move_child(bg, 0)
		bg.owner = hud
	
	var packed = PackedScene.new()
	packed.pack(hud)
	var err = ResourceSaver.save(packed, "res://scenes/hud.tscn")
	if err == OK:
		print("Saved updated hud.tscn successfully.")
	else:
		print("Failed to save hud.tscn: ", err)
	quit()
