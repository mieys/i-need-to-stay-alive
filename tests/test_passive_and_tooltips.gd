extends Node

func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	hud._ready()
	return hud

func test_passive_icon_node_exists() -> void:
	var hud: Node = _make_hud()
	var skill_bar: Control = hud.get_node("SkillBar") as Control
	assert(skill_bar != null, "SkillBar node must exist")
	
	var passive_icon: TextureRect = skill_bar.get_node("PassiveIcon") as TextureRect
	assert(passive_icon != null, "PassiveIcon node must exist under SkillBar")
	
	var skill_icon: TextureRect = skill_bar.get_node("SkillIcon") as TextureRect
	assert(skill_icon != null, "SkillIcon node must exist under SkillBar")
	
	# Position verification: PassiveIcon must be to the left of Q's SkillIcon
	assert(passive_icon.offset_left < skill_icon.offset_left, "PassiveIcon must be positioned to the left of Q skill icon")
	
	# Size verification: PassiveIcon scaled 40% smaller (e.g. size around 32x32 vs 52x52)
	assert(passive_icon.size.x < skill_icon.size.x, "PassiveIcon must be smaller than Q skill icon")
	assert(is_equal_approx(passive_icon.size.x / skill_icon.size.x, 32.0 / 52.0), "PassiveIcon should be ~40% smaller (approx 60% of Q size)")
	
	hud.queue_free()

func test_tooltip_creation_and_destruction() -> void:
	var hud: Node = _make_hud()
	var skill_bar: Control = hud.get_node("SkillBar") as Control
	var skill_icon: TextureRect = skill_bar.get_node("SkillIcon") as TextureRect
	
	# Initially no tooltip
	assert(skill_icon.tooltip_panel == null, "Tooltip panel must be null initially")
	
	# Hover event
	skill_icon._on_mouse_entered()
	assert(skill_icon.tooltip_panel != null, "Tooltip panel should be created on mouse entered")
	assert(is_instance_valid(skill_icon.tooltip_panel), "Tooltip panel must be a valid instance")
	
	# Check tooltip content
	var vbox: VBoxContainer = skill_icon.tooltip_panel.get_child(0) as VBoxContainer
	assert(vbox != null, "Tooltip should have a VBoxContainer")
	
	# Exit hover event
	skill_icon._on_mouse_exited()
	assert(skill_icon.tooltip_panel == null, "Tooltip panel should be cleared and deleted on mouse exited")
	
	hud.queue_free()

func test_lol_style_bbcode_formatting() -> void:
	var hud: Node = _make_hud()
	var skill_bar: Control = hud.get_node("SkillBar") as Control
	var skill_icon: TextureRect = skill_bar.get_node("SkillIcon") as TextureRect
	
	var raw_text: String = "Etrafındaki yaratıkları keser, %120 hasar verir. Bekleme süresi 15 saniye."
	var formatted: String = skill_icon._format_lol_style(raw_text)
	
	assert("[color=#ff5555]hasar[/color]" in formatted, "Should colorize 'hasar'")
	assert("[color=#ffaa00]%120[/color]" in formatted, "Should colorize '%120'")
	assert("[color=#ffaa00]15 saniye[/color]" in formatted, "Should colorize '15 saniye'")
	
	# Make sure it doesn't break color hex numbers like #ff5555
	assert("[color=#ffaa00]#ff5555[/color]" not in formatted, "Should not colorize digits inside color tags")
	
	hud.queue_free()
