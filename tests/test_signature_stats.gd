extends Node

## Karaktere özel başlangıç statı (Characters.SIGNATURE_STATS, madde 677): her karakterde bir Ruh Mağazası statı, oyuncuya / GameManager'a
## uygulanır, seçim ekranının 4. hücresinde görünür.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const MetaUpgradesScript: GDScript = preload("res://scripts/meta_upgrades.gd")


func test_every_character_has_valid_signature() -> void:
	for id in Characters.DEFS.keys():
		var sig: Dictionary = Characters.get_signature(int(id))
		assert(not sig.is_empty(), "özel stat eksik: id %s" % str(id))
		assert(not MetaUpgradesScript.def(str(sig["stat"])).is_empty(), "bilinmeyen stat: %s" % str(sig))
		assert(float(sig["value"]) > 0.0, "değer pozitif olmalı: %s" % str(sig))
	assert(Characters.signature_value(3, "crit_chance") == 0.05 and Characters.signature_value(3, "luck") == 0.0)


func _spawn(id: int) -> Node:
	GameManager.selected_char_id = id
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	return p


func test_player_gets_signature_stat() -> void:
	var saved: int = GameManager.selected_char_id
	var p: Node = _spawn(3)
	assert(p.crit_chance_bonus >= 0.05 - 0.0001, "Matthew kritik oran: %s" % p.crit_chance_bonus)
	p.queue_free()
	p = _spawn(8)
	assert(absf(p.fire_rate_mult - 0.9) < 0.0001, "Elara saldırı hızı (aralık x0,9): %s" % p.fire_rate_mult)
	p.queue_free()
	p = _spawn(13)
	## Pasifin %1'i ayrı yoldan (player.gd VAMPIR_LIFESTEAL_RATIO); özel stat genel can çalmaya eklenir.
	assert(p.get_total_lifesteal() >= 0.06 - 0.0001, "Vampir can çalma +%%6: %s" % p.get_total_lifesteal())
	p.queue_free()
	p = _spawn(15)
	assert(p.luck >= 8.0, "Cadı şans +8: %s" % p.luck)
	p.queue_free()
	p = _spawn(2)
	assert(absf(p.pickup_range_percent - 0.40) < 0.0001, "Oakley toplama +%%40: %s" % p.pickup_range_percent)
	p.queue_free()
	p = _spawn(1)
	assert(p.crit_chance_bonus < 0.05, "Talon'un özel statı oyuncu statı değil")
	p.queue_free()
	GameManager.selected_char_id = saved


func test_game_manager_side_signatures() -> void:
	var saved_id: int = GameManager.selected_char_id
	var saved_sp: String = GameManager.selected_spiritual
	GameManager.selected_spiritual = ""
	GameManager.selected_char_id = 9
	assert(absf(GameManager.shop_discount_fraction() - 0.05) < 0.0001, "Korsan indirim %%5: %s" % GameManager.shop_discount_fraction())
	assert(GameManager.apply_shop_discount(100) == 95)
	GameManager.selected_char_id = 1
	assert(is_zero_approx(GameManager.shop_discount_fraction()), "Talon'da indirim yok")
	GameManager.selected_char_id = 14
	GameManager.reset()
	assert(GameManager.max_revives == MetaUpgradesScript.BASE_REVIVES + 1, "Hadime +1 dirilme: %d" % GameManager.max_revives)
	assert(GameManager.revives_remaining == GameManager.max_revives)
	GameManager.selected_char_id = 1
	GameManager.reset()
	assert(GameManager.free_rerolls_per_card == 1, "Talon ücretsiz karıştırma: %d" % GameManager.free_rerolls_per_card)
	assert(GameManager.max_revives == MetaUpgradesScript.BASE_REVIVES)
	GameManager.selected_char_id = 12
	GameManager.reset()
	assert(GameManager.free_evo_rerolls_left == MetaUpgradesScript.BASE_FREE_EVO_REROLLS + 1, "Shaman evrim karıştırma +1")
	GameManager.selected_char_id = saved_id
	GameManager.selected_spiritual = saved_sp
	GameManager.reset()


func test_select_screen_shows_signature_cell() -> void:
	assert(MenuKit.signature_info(3)["value"] == "+%5", "Matthew: %s" % str(MenuKit.signature_info(3)))
	assert(MenuKit.signature_info(4)["value"] == "+1,8", "Büyücü Kız: %s" % str(MenuKit.signature_info(4)))
	var box: Control = MenuKit.make_stats_grid(1)
	add_child(box)
	var sig_label: Label = box.get_meta("sig_label")
	for id in Characters.DEFS.keys():
		MenuKit.set_stats_grid_character(box, int(id))
		assert(sig_label.text != "" and (box.get_meta("sig_icon") as TextureRect).texture != null, "özel stat hücresi boş: id %s" % str(id))
		assert(box.get_combined_minimum_size().x <= 336.0, "vitrine sığmıyor (id %s): %s" % [str(id), box.get_combined_minimum_size()])
	box.queue_free()
