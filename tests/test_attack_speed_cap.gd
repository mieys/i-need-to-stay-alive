extends Node

## Saldırı hızı üst sınırı %600 + taşmanın CANLI saldırı gücüne dönüşmesi (kullanıcı isteği 2026-10-11; player.gd get_attack_speed_bonus_percent /
## _sync_attack_speed_overflow_ap). Buff kaynaklı taşma kalıcı OLMAMALI.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array[Node] = []


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	return player


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Kartlarla sınırı aşan hız: fire_rate_mult = 1/(1+bonus) -> bonus % olarak TOPLAM (eşya/buff yokken).
func _set_total_bonus(p: Node, percent: float) -> void:
	p.fire_rate_mult = 1.0 / (1.0 + percent / 100.0)


func test_below_cap_untouched_and_no_overflow() -> void:
	var p: Node = _make_player()
	var ap0: float = p.damage_bonus
	_set_total_bonus(p, 250.0)
	p._sync_attack_speed_overflow_ap()
	assert(absf(p.get_attack_speed_bonus_percent() - 250.0) < 0.01, "sınırın altında bonus aynen gösterilmeli: %f" % p.get_attack_speed_bonus_percent())
	assert(is_zero_approx(p.get_attack_speed_overflow_percent()))
	assert(is_equal_approx(p.damage_bonus, ap0), "taşma yokken saldırı gücü değişmemeli")
	_cleanup()


func test_cap_is_600_and_interval_floor() -> void:
	var p: Node = _make_player()
	_set_total_bonus(p, 900.0)
	assert(absf(p.get_attack_speed_bonus_percent() - 600.0) < 0.01, "gösterilen bonus 600'de durmalı")
	assert(absf(p.get_attack_interval_mult() - 1.0 / 7.0) < 0.0001, "aralık çarpanı 1/7'den küçük olamaz")
	_cleanup()


func test_overflow_gives_half_ap_per_percent() -> void:
	var p: Node = _make_player()
	var ap0: float = p.damage_bonus
	_set_total_bonus(p, 700.0) ## 100 puan taşma -> 50 saldırı gücü
	p._sync_attack_speed_overflow_ap()
	assert(absf(p.get_attack_speed_overflow_percent() - 100.0) < 0.01)
	assert(absf(p.damage_bonus - (ap0 + 50.0)) < 0.01, "100 puan taşma = +50 saldırı gücü: %f" % (p.damage_bonus - ap0))
	## aynı değerle tekrar çağrı çift saymamalı
	p._sync_attack_speed_overflow_ap()
	assert(absf(p.damage_bonus - (ap0 + 50.0)) < 0.01, "ikinci senkron çift saymamalı")
	_cleanup()


func test_temporary_buff_overflow_is_not_permanent() -> void:
	var p: Node = _make_player()
	var ap0: float = p.damage_bonus
	## Taban 600'e yakın (kart/eşya), geçici ruhani "Adc" (+%30 additive) sınırı aştırıyor.
	p.fire_rate_mult = 1.0 / 7.0 * 1.0
	p.spirit_attack_speed = 0.0
	p._sync_attack_speed_overflow_ap()
	assert(is_equal_approx(p.damage_bonus, ap0), "buff yokken taşma yok")
	p.spirit_attack_speed = 0.30
	p._sync_attack_speed_overflow_ap()
	assert(p.damage_bonus > ap0 + 1.0, "buff açıkken taşma saldırı gücü vermeli")
	var during: float = p.damage_bonus
	assert(during - ap0 == p.attack_speed_overflow_ap() or absf((during - ap0) - p.attack_speed_overflow_ap()) < 0.001)
	p.spirit_attack_speed = 0.0 ## buff bitti
	p._sync_attack_speed_overflow_ap()
	assert(absf(p.damage_bonus - ap0) < 0.001, "buff bitince kazanılan saldırı gücü GERİ ALINMALI (kalıcı olmamalı): %f" % (p.damage_bonus - ap0))
	_cleanup()


func test_other_ap_changes_are_preserved_when_overflow_ends() -> void:
	var p: Node = _make_player()
	_set_total_bonus(p, 800.0)
	p._sync_attack_speed_overflow_ap()
	p.damage_bonus += 12.0 ## taşma sürerken kazanılan kalıcı güç (ör. seviye kartı)
	_set_total_bonus(p, 100.0)
	var base_after: float = p.damage_bonus
	p._sync_attack_speed_overflow_ap()
	assert(absf((base_after - p.damage_bonus) - 100.0) < 0.01, "yalnız taşma payı (200 puan x0.5 = 100) geri alınmalı, kart gücü kalmalı")
	_cleanup()


## Elara pasifi (2026-10-12 denge): metindeki gibi gerçekten +%50 hız (aralık 1/1,5) ve sınır aşımı -> saldırı gücü dönüşümüne GİRMEZ.
func test_elara_passive_is_true_fifty_percent_and_not_in_overflow() -> void:
	var p: Node = _make_player()
	var saved: int = GameManager.selected_character
	GameManager.selected_character = 12
	p.level = 50
	assert(absf(p._elara_passive_fire_rate_mult() - 1.0 / 1.5) < 0.0001, "50. seviyede aralık çarpanı 1/1,5 olmalı: %f" % p._elara_passive_fire_rate_mult())
	p.level = 20
	assert(absf(p._elara_passive_fire_rate_mult() - 1.0 / 1.2) < 0.0001, "20. seviyede +%20")
	## Kartlar toplam +%500 verir, pasif (+%50) sınırı aşırır: gösterilen hız 600'de durur ama taşma (kart/eşya kaynaklı) 0 kalır.
	p.level = 50
	_set_total_bonus(p, 500.0)
	p._sync_attack_speed_overflow_ap()
	assert(absf(p.get_attack_speed_bonus_percent() - 600.0) < 0.01, "pasifle toplam sınıra dayanır")
	assert(is_zero_approx(p.get_attack_speed_overflow_percent()), "pasif taşma->saldırı gücüne girmemeli: %f" % p.get_attack_speed_overflow_percent())
	## Kartlar tek başına 700 ise taşma 100 (pasiften bağımsız).
	_set_total_bonus(p, 700.0)
	assert(absf(p.get_attack_speed_overflow_percent() - 100.0) < 0.01, "kart kaynaklı taşma aynen sayılır: %f" % p.get_attack_speed_overflow_percent())
	GameManager.selected_character = saved
	_cleanup()
