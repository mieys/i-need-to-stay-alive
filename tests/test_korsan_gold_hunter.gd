extends Node

## Korsan pasifi "Altın Avcısı" (kullanıcı isteği 2026-10-12): her öldürmede 1 altın, cüzdandaki her 30 altın = +1 saldırı gücü
## (güncel altından, kalıcı değil). Papağan artık menüden seçilen evcil hayvan (test_pets).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _players: Array = []
var _saved_char: int = 0
var _saved_gold: int = 0


func _begin(char_id: int) -> Node:
	_saved_char = GameManager.selected_char_id
	_saved_gold = GameManager.gold
	GameManager.selected_char_id = char_id
	GameManager.gold = 0
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_players.append(p)
	return p


func _end() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	GameManager.selected_char_id = _saved_char
	GameManager.gold = _saved_gold


func test_ap_formula_is_one_per_ten_gold() -> void:
	var P: GDScript = PlayerScene.instantiate().get_script()
	assert(P.korsan_gold_ap(0) == 0.0 and P.korsan_gold_ap(29) == 0.0, "30 altından azda bonus yok")
	assert(P.korsan_gold_ap(30) == 1.0 and P.korsan_gold_ap(59) == 1.0 and P.korsan_gold_ap(300) == 10.0, "her 30 altın +1")
	assert(P.korsan_gold_ap(-5) == 0.0, "eksi altın 0")


func test_kill_gives_one_gold_and_ap_follows_current_wallet() -> void:
	var p: Node = _begin(9)
	var base: float = p.damage_bonus
	for i in range(30):
		p.on_enemy_killed_remote(false)
	assert(GameManager.gold == 30, "30 öldürme = 30 altın, bulunan %d" % GameManager.gold)
	p._refresh_korsan_gold_ap()
	assert(is_equal_approx(p.damage_bonus, base + 1.0), "30 altın = +1 saldırı gücü: %f / %f" % [p.damage_bonus, base])
	GameManager.gold = 95
	p._refresh_korsan_gold_ap()
	assert(is_equal_approx(p.damage_bonus, base + 3.0), "95 altın = +3")
	GameManager.gold = 3 ## harcandı: bonus geri düşer (kalıcı değil)
	p._refresh_korsan_gold_ap()
	assert(is_equal_approx(p.damage_bonus, base), "altın harcanınca saldırı gücü düşmeli")
	_end()


func test_other_characters_get_nothing() -> void:
	var p: Node = _begin(1)
	var base: float = p.damage_bonus
	p.on_enemy_killed_remote(false)
	GameManager.gold = 500
	p._refresh_korsan_gold_ap()
	assert(GameManager.gold == 500 and is_equal_approx(p.damage_bonus, base), "Korsan dışı karakter etkilenmemeli")
	_end()


func test_korsan_no_longer_gets_parrot_by_default() -> void:
	var saved_pet: String = GameManager.selected_pet
	GameManager.selected_pet = ""
	var p: Node = _begin(9)
	assert(not p.has_node("KorsanParrot"), "Korsan'da papağan menüden seçilmedikçe olmamalı (bkz. test_pets)")
	_end()
	GameManager.selected_pet = saved_pet
