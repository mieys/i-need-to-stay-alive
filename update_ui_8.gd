@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	
	var bot_bar = hud.get_node("BottomBar")
	var cc = bot_bar.get_node("CharacterCluster")
	
	cc.size = Vector2(500, 160)
	cc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cc.position = Vector2(-250, -220)
	
	var hb = cc.get_node("HealthBar")
	hb.position = Vector2(0, 20)
	hb.size = Vector2(192, 64)
	var shim_script = load("res://scripts/bar_shim.gd")
	hb.set_script(shim_script)
	
	if not hb.has_node("Prog"):
		var p = TextureProgressBar.new()
		p.name = "Prog"
		p.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
		p.texture_progress = load("res://assets/generated/health_fill_cute_frame_0.png")
		p.nine_patch_stretch = true
		p.stretch_margin_left = 6
		p.stretch_margin_right = 6
		p.stretch_margin_top = 6
		p.stretch_margin_bottom = 6
		p.texture_progress_offset = Vector2(6, 6)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		hb.add_child(p)
		p.owner = hud
	
	var hl = cc.get_node("HealthValueLabel")
	hl.position = Vector2(0, 20)
	hl.size = Vector2(192, 64)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override("font_size", 18)
	hl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	var pc = cc.get_node("PortraitClip")
	pc.position = Vector2(218, 16)
	pc.size = Vector2(64, 64)
	
	var pt = pc.get_node("Portrait")
	pt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pt.scale = Vector2(1.0, 1.0)
	
	if not cc.has_node("PortraitFrame"):
		var pf = TextureRect.new()
		pf.name = "PortraitFrame"
		pf.texture = load("res://assets/generated/cute_ui_portrait_frame_frame_0.png")
		pf.position = Vector2(218, 16)
		pf.size = Vector2(64, 64)
		cc.add_child(pf)
		cc.move_child(pf, pc.get_index() + 1)
		pf.owner = hud
	
	var ll = cc.get_node("LevelLabel")
	ll.position = Vector2(218, 80)
	ll.size = Vector2(64, 30)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.add_theme_font_size_override("font_size", 16)
	
	var sb = cc.get_node("ShieldBar")
	sb.position = Vector2(308, 20)
	sb.size = Vector2(192, 64)
	sb.set_script(shim_script)
	
	if not sb.has_node("Prog"):
		var p2 = TextureProgressBar.new()
		p2.name = "Prog"
		p2.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
		p2.texture_progress = load("res://assets/generated/shield_fill_cute_frame_0.png")
		p2.nine_patch_stretch = true
		p2.stretch_margin_left = 6
		p2.stretch_margin_right = 6
		p2.stretch_margin_top = 6
		p2.stretch_margin_bottom = 6
		p2.texture_progress_offset = Vector2(6, 6)
		p2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p2.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		sb.add_child(p2)
		p2.owner = hud
	
	var sl = cc.get_node("ShieldValueLabel")
	sl.position = Vector2(308, 20)
	sl.size = Vector2(192, 64)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.add_theme_font_size_override("font_size", 18)
	sl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	var smb = bot_bar.get_node("ShieldModeBarBG")
	smb.texture = null
	smb.position = Vector2(-74, -120)
	smb.size = Vector2(250, 50)
	smb.scale = Vector2(1.0, 1.0)
	
	for i in range(1, 6):
		var slot = smb.get_node("ShieldModeSlot" + str(i))
		slot.position = Vector2((i-1)*56, 0)
		slot.size = Vector2(48, 48)
		if not slot.has_node("BG"):
			var bg = TextureRect.new()
			bg.name = "BG"
			bg.texture = load("res://assets/generated/cute_ui_skill_slot_frame_0.png")
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(bg)
			slot.move_child(bg, 0)
			bg.owner = hud
	
	var skill_bar = hud.get_node("SkillBar")
	skill_bar.position = Vector2(-188, -120)
	
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
	print("Save result: ", err)
	quit()
