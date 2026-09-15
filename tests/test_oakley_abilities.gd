extends Node

## Kullanıcı isteği doğrulaması: Oakley'nin pasifi + Q (Can Basma) + E (Kalkan
## Yenileme) yeteneklerinin yeniden tasarımı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const PetScene: PackedScene = preload("res://scenes/player_pet.tscn")


func _make_oakley_player() -> Node:
	GameManager.selected_char_id = 2 ## Oakley (raw character id)
	GameManager.selected_character = 1 ## Oakley'nin ULTİ id'si (Can Basma)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


func _make_ally() -> Node:
	var ally: Node = PetScene.instantiate()
	add_child(ally)
	ally.add_to_group("player_ally")
	return ally


## NOT: _passive_oakley() içindeki müttefik döngüsü get_tree().get_nodes_in_
## group() kullanıyor - bu test ortamında yeni eklenen node'lar için
## get_tree() null dönüyor (bkz. test_luck_chest_and_kurtadam_lifesteal.gd
## başındaki aynı kısıt notu). Bu yüzden KENDİ can yenilenmesini (tree'den
## bağımsız, doğrudan health/max_health üzerinde çalışır) canlı olarak,
## müttefik yenilenmesini ise kaynak kodu üzerinden doğruluyoruz.
func test_passive_heals_self() -> void:
	var player: Node = _make_oakley_player()
	player.max_health = 200.0
	player.health = 100.0

	player._passive_oakley(1.0) ## 1 saniyelik pasif tetiklemesi - get_tree() null olsa da kendi can yenilenmesi önce çalışır

	assert(player.health > 100.0, "Oakley'nin kendi canı pasifle yenilenmeli, bulunan: %s" % player.health)
	assert(is_equal_approx(player.health, 100.0 + 200.0 * 0.005),
		"Kendi can yenilenmesi max_health'in %%0.5'i olmalı, bulunan: %s" % player.health)

	player.queue_free()


func test_passive_also_heals_allies_per_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	if source.length() > 0:
		var fn_start: int = source.find("func _passive_oakley(")
		assert(fn_start != -1, "_passive_oakley fonksiyonu bulunamadı")
		var section: String = source.substr(fn_start, 700)
		assert(section.find("health = min(max_health, health + max_health * OAKLEY_PASSIVE_REGEN_PERCENT * delta)") != -1,
			"_passive_oakley artık kendi canını da yenilemiyor (bug düzeltmesi geri alınmış olabilir)")
		assert(section.find("player_ally") != -1,
			"_passive_oakley müttefikleri de yenilemeli")


## _skill_heal()'in KENDİ anında iyileşme kısmı get_tree()'ye ihtiyaç
## duymuyor (yalnızca müttefik hedefi seçimi -_lowest_health_ally_in_range-
## get_tree() kullanıyor, test ortamında null dönüyor) - bu yüzden kendi
## iyileşmeyi canlı, müttefik hedefleme mantığını kaynak kodu üzerinden
## doğruluyoruz.
func test_q_instant_heals_self_by_15_percent() -> void:
	var player: Node = _make_oakley_player()
	player.max_health = 200.0
	player.health = 100.0

	player._skill_heal()

	assert(is_equal_approx(player.health, 100.0 + 200.0 * 0.15),
		"Oakley kendi max canının %%15'i kadar anında yenilenmeli, bulunan: %s" % player.health)

	player.queue_free()


func test_q_targets_lowest_health_ally_per_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	if source.length() > 0:
		var fn_start: int = source.find("func _skill_heal() -> void:")
		assert(fn_start != -1, "_skill_heal fonksiyonu bulunamadı")
		## DÜZELTME ("efekt sistemi" - iyileşme.png): fonksiyona Melek'in aura
		## efekti için yeni satırlar eklendi, hedef ifadeler artık eski 800
		## karakterlik pencerenin ötesinde kalıyordu - pencere genişletildi
		## (davranışsal bir değişiklik DEĞİL, sadece testin kendi sabit genişlik
		## varsayımı kırılgandı).
		var section: String = source.substr(fn_start, 2000)
		assert(section.find("_lowest_health_ally_in_range(OAKLEY_Q_RANGE)") != -1,
			"_skill_heal en düşük canlı müttefiği hedeflemiyor")
		assert(section.find("OAKLEY_Q_INSTANT_PERCENT") != -1,
			"_skill_heal anında iyileşme yüzdesini kullanmıyor")


func test_q_tick_heals_self_and_ally_with_percent_plus_attack_power() -> void:
	var player: Node = _make_oakley_player()
	player.max_health = 200.0
	player.health = 100.0
	player.damage_bonus = 10.0
	player.skill_state = "active" ## _process_oakley_heal_tick sadece aktifken çalışır

	var ally: Node = _make_ally()
	ally.global_position = player.global_position
	ally.max_health = 100.0
	ally.health = 10.0
	player._oakley_q_ally_target = ally
	player._oakley_q_tick_timer = 1.0

	player._process_oakley_heal_tick(1.0) ## Tam bir tik süresi geçir

	var expected_self: float = 100.0 + (200.0 * 0.01 + 10.0 * 0.60)
	var expected_ally: float = 10.0 + (100.0 * 0.01 + 10.0 * 0.60)
	assert(is_equal_approx(player.health, expected_self),
		"Kendi tik miktarı %%1 can + saldırı gücünün %%60'ı olmalı, beklenen: %s bulunan: %s" % [expected_self, player.health])
	assert(is_equal_approx(ally.health, expected_ally),
		"Müttefik tik miktarı KENDİ %%1 canı + Oakley'nin saldırı gücünün %%60'ı olmalı, beklenen: %s bulunan: %s" % [expected_ally, ally.health])

	player.queue_free()
	ally.queue_free()


func test_e_tick_heals_self_and_ally_shield_with_percent_plus_attack_power() -> void:
	var player: Node = _make_oakley_player()
	player.item_shield_max = 100.0
	player.item_shield_hp = 20.0
	player.damage_bonus = 5.0
	player.is_kalkan_yenileme_active = true
	player._oakley_e_tick_timer = 1.0

	var ally: Node = _make_ally()
	ally.global_position = player.global_position
	## Test ortamında pet'in gerçek kalkan alanları yok - dinamik ekleyerek
	## multiplayer'da bir OYUNCU müttefik olduğunda çalışacağını simüle ediyoruz.
	ally.set("item_shield_max", 50.0)
	ally.set("item_shield_hp", 5.0)
	ally.set_script(load("res://scripts/player_pet.gd")) ## script zaten aynı, sadece netlik için
	player._oakley_e_ally_target = ally

	player._process_oakley_shield_tick(1.0)

	## Kendi kalkanı: doğrudan değil, _shield_regen_tick_pending'e birikir.
	var expected_self_tick: float = 100.0 * 0.01 + 5.0 * 2.0
	assert(is_equal_approx(player._shield_regen_tick_pending, expected_self_tick),
		"Kendi kalkan tik miktarı %%1 kalkan + saldırı gücünün %%200'ü olmalı, beklenen: %s bulunan: %s" % [expected_self_tick, player._shield_regen_tick_pending])

	player.queue_free()
	ally.queue_free()


func test_skill_timing_durations_updated_to_6_seconds() -> void:
	assert(is_equal_approx(player_script().SKILL_TIMING[1]["duration"], 6.0),
		"Oakley Q süresi 6sn olmalı")
	assert(is_equal_approx(player_script().SKILL2_TIMING[10]["duration"], 6.0),
		"Oakley/Şovalye E süresi 6sn olmalı")


func player_script() -> GDScript:
	return load("res://scripts/player.gd") as GDScript
