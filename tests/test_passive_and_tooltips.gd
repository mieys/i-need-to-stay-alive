extends Node

func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	## (2026-10-03) add_child zaten _ready'yi çalıştırıyor; Godot 4.7'de elle _ready() @onready'leri yeniden çözüyor ve
	## _ready'de başka katmana taşınan InventoryPanelInstance'ı null yapıyordu - ikinci çağrı kaldırıldı.
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
	
	# 2026-09-27 oyuncu paneli (dock): yetenek dizisindeki her slot AYNI boyutta (hud.gd _layout_ability_icons - eski "%40 küçük
	# pasif" kuralı dock tasarımıyla kalktı; 2026-10-03 test güncellemesi). Pasif yine Q'nun solunda (yukarıda).
	assert(is_equal_approx(passive_icon.size.x, skill_icon.size.x), "Dock'ta pasif ikon Q ile aynı boyutta olmalı")
	
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
	
	## 2026-09-24: ipucu parşömen kit - renkler TEK kaynak UIKit.INK mürekkep tonları (eski neon #ff5555/#ffaa00 değil).
	var ink: Dictionary = UIKit.INK
	assert(("[color=%s]hasar[/color]" % ink["damage"]) in formatted, "Should colorize 'hasar'")
	assert(("[color=%s]%%120[/color]" % ink["value"]) in formatted, "Should colorize '%120'")
	assert(("[color=%s]15 saniye[/color]" % ink["value"]) in formatted, "Should colorize '15 saniye'")
	
	# Make sure it doesn't break color hex numbers inside the tags
	assert(not ("[color=%s]%s[/color]" % [ink["value"], ink["damage"]]) in formatted, "Should not colorize digits inside color tags")
	
	hud.queue_free()
