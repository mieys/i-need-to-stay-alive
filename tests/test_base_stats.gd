extends Node

## Karakter başına başlangıç statları (Characters.BASE_STATS, madde 123): her karakter listedeki Can/Hız/Saldırı Gücü/Saldırı Hızı ile başlamalı,
## seçim ekranı aynı sayıları göstermeli, her karakterin bir kaydı olmalı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func test_every_character_has_base_stats() -> void:
	for id in Characters.DEFS.keys():
		assert(Characters.BASE_STATS.has(id), "BASE_STATS'ta eksik karakter: %s" % str(id))
		var b: Dictionary = Characters.get_base_stats(int(id))
		for k in ["hp", "speed", "ap", "atk"]:
			assert(b.has(k), "%s alanı eksik (id %s)" % [k, str(id)])


func test_player_starts_with_character_base_stats() -> void:
	var saved_id: int = GameManager.selected_char_id
	var scene_speed: float = 0.0
	var tmp: Node = PlayerScene.instantiate()
	scene_speed = tmp.speed
	tmp.free()
	for id in Characters.BASE_STATS.keys():
		GameManager.selected_char_id = int(id)
		var b: Dictionary = Characters.get_base_stats(int(id))
		var p: Node = PlayerScene.instantiate()
		add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		assert(is_equal_approx(p.max_health, float(b["hp"])), "Can yanlış (id %s): %s" % [str(id), p.max_health])
		assert(is_equal_approx(p.health, float(b["hp"])), "Başlangıç canı dolu değil (id %s)" % str(id))
		assert(is_equal_approx(p.damage_bonus, float(b["ap"])), "Saldırı Gücü yanlış (id %s): %s" % [str(id), p.damage_bonus])
		var want_speed: float = scene_speed * float(b["speed"]) / Characters.BASE_MOVE_SPEED * EntityScale.SPEED
		assert(absf(p.speed - want_speed) < 0.01, "Hız yanlış (id %s): %s vs %s" % [str(id), p.speed, want_speed])
		## fire_rate_mult = ham taban (Elara/Matthew pasifleri ayrı çarpan, get_attack_speed_bonus_percent'e onlar da girer).
		var want_mult: float = 1.0 / (1.0 + float(b["atk"]) / 100.0)
		assert(absf(p.fire_rate_mult - want_mult) < 0.001, "Saldırı Hızı yanlış (id %s): %s vs %s" % [str(id), p.fire_rate_mult, want_mult])
		p.queue_free()
	GameManager.selected_char_id = saved_id


func test_menu_stat_text_matches_table() -> void:
	assert(MenuKit.base_stat_text(7, "hp") == "150", "Şovalye Can 150 olmalı")
	assert(MenuKit.base_stat_text(4, "atk") == "0,9/sn", "Büyücü Kız -%10 -> 0,9/sn: %s" % MenuKit.base_stat_text(4, "atk"))
	assert(MenuKit.base_stat_text(5, "atk") == "1,1/sn", "Assasin +%10 -> 1,1/sn")
	var box: Control = MenuKit.make_stats_grid(1)
	add_child(box)
	var labels: Array = box.get_meta("stat_labels")
	assert((labels[2] as Label).text == "Hasar 16", "Talon Hasar 16: %s" % (labels[2] as Label).text)
	MenuKit.set_stats_grid_character(box, 3)
	assert((labels[1] as Label).text == "Hız 265", "Matthew Hız 265: %s" % (labels[1] as Label).text)
	box.queue_free()
