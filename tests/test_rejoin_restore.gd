extends Node

## Kullanıcı isteği (2026-10-04): oyundan düşen oyuncu geri katılınca KALDIĞI HALİYLE devam eder, seviyesi takımla eşitlenir, düşükken
## seçemediği seviye kartları rastgele verilir (bkz. player.gd get_rejoin_snapshot / restore_from_rejoin_snapshot, network_manager.gd
## geri katılım bloğu). Gerçek 3 istemcili (düşen / geri giren / yabancı) iki süreçli doğrulama ayrıca elle koşuldu; bu dosya
## oyuncu tarafının hızlı, tek süreçli regresyon korumasıdır.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
var _spawned: Array = []
var _prev_char: int = 1
var _prev_character: int = 1


func _make_player(char_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = 3
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	return p


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char
	GameManager.selected_character = _prev_character
	GameManager.reset()
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_game_manager_run_state_roundtrip() -> void:
	GameManager.reset()
	GameManager.gold = 77
	GameManager.shield_standart_level = 3
	GameManager.owned_weapons = [{"key": "tufek", "level": 3, "spent": 10}]
	GameManager.owned_items = [{"key": "kutsal_tilsim", "spent": 5}]
	var snap: Dictionary = GameManager.capture_run_state()
	GameManager.reset()
	assert(GameManager.owned_weapons.is_empty() and GameManager.gold == 0, "reset sıfırladı")
	GameManager.restore_run_state(snap)
	assert(GameManager.gold == 77 and GameManager.shield_standart_level == 3, "altın/kalkan geri geldi")
	assert(GameManager.owned_weapons.size() == 1 and str(GameManager.owned_weapons[0]["key"]) == "tufek", "silah kaydı geri geldi")
	assert(GameManager.owned_items.size() == 1, "eşya kaydı geri geldi")
	snap["owned_weapons"].clear()
	assert(GameManager.owned_weapons.size() == 1, "anlık görüntü derin kopya - sonradan değişmesi etkilemez")
	GameManager.reset()


func test_restore_matches_team_level_and_gives_random_cards_for_missed_levels() -> void:
	var p: Node = _make_player(4)
	## Düşmeden önce: seviye 3, 2 kart
	p.on_team_leveled_up(2)
	p.on_team_leveled_up(3)
	p.apply_upgrade("damage", 2)
	p.apply_upgrade("max_health", 1)
	var snap: Dictionary = p.get_rejoin_snapshot()
	assert(int(snap["level"]) == 3 and (snap["upgrades"] as Array).size() == 2, "anlık görüntü seviye ve kartları taşır")
	## Yeni Player (geri giriş): takım şimdi 7. seviyede
	p.free()
	_spawned.clear()
	GameManager.reset()
	GameManager.restore_run_state(snap["gm"])
	var q: Node = _make_player(4)
	var missed: int = q.restore_from_rejoin_snapshot(snap, 7)
	assert(missed == 4, "3'ten 7'ye 4 seviye kaçırıldı: %d" % missed)
	assert(int(q.level) == 7, "oyuncu seviyesi takımla eşit")
	assert(int(q.max_item_slots) == 7, "eşya yuvaları seviyeyle gelir")
	var counts: Dictionary = q.upgrade_counts
	assert(int(counts.get("damage", 0)) >= 1 and int(counts.get("max_health", 0)) >= 1, "kayıtlı kartlar geri uygulandı")
	var total: int = 0
	for k in counts:
		total += int(counts[k])
	## 2 kayıtlı + kaçırılan 4 seviyeden 5. seviye evrim (Büyücü evrimleri var), diğer 3 rastgele kart = en az 5 kart
	assert(total >= 5, "kaçırılan seviyeler için rastgele kartlar verildi: toplam %d" % total)
	assert(q.skill_evolutions.size() == 1, "5. seviye: rastgele evrim verildi: %d" % q.skill_evolutions.size())
	assert(float(q.health) > 0.0 and float(q.max_health) > 155.0 - 0.01, "can seviye kazanımlarıyla büyüdü")
	_cleanup()


func test_empty_snapshot_still_levels_player_to_team() -> void:
	var p: Node = _make_player(1)
	var missed: int = p.restore_from_rejoin_snapshot({}, 4)
	assert(missed == 3 and int(p.level) == 4, "anlık görüntü yoksa da takım seviyesine eşitlenir")
	_cleanup()


## 2026-10-05: anlık görüntü imzası sürekli değişen alanları (konum/can/kalkan/altın/öldürme) saymaz, yoksa "değişmedi" kuralı hiç işlemez
## ve ~4 KB'lık güvenilir RPC her 6 sn'de gider (bkz. NetworkManager.rejoin_snapshot_signature).
func test_rejoin_snapshot_signature_ignores_volatile_fields() -> void:
	var base := {
		"gm": {"gold": 10, "run_kills": 5, "owned_weapons": [{"key": "tufek", "level": 1, "spent": 0}], "owned_items": []},
		"level": 5, "upgrades": [["damage", 1]], "evos": [], "hp": 100.0, "max_hp": 200.0, "shield": 10.0,
		"pos": Vector2(1, 2), "indoors": false, "char": 4,
	}
	var sig0: int = NetworkManager.rejoin_snapshot_signature(base)
	var moved: Dictionary = base.duplicate(true)
	moved["pos"] = Vector2(900, 400)
	moved["hp"] = 12.0
	moved["shield"] = 0.0
	moved["indoors"] = true
	(moved["gm"] as Dictionary)["gold"] = 999
	(moved["gm"] as Dictionary)["run_kills"] = 77
	assert(NetworkManager.rejoin_snapshot_signature(moved) == sig0, "konum/can/kalkan/altın/öldürme imzayı değiştirmemeli")
	var carded: Dictionary = base.duplicate(true)
	(carded["upgrades"] as Array).append(["max_health", 1])
	assert(NetworkManager.rejoin_snapshot_signature(carded) != sig0, "yeni seviye kartı imzayı değiştirmeli")
	var bought: Dictionary = base.duplicate(true)
	((bought["gm"] as Dictionary)["owned_items"] as Array).append({"key": "kutsal_tilsim", "spent": 3})
	assert(NetworkManager.rejoin_snapshot_signature(bought) != sig0, "yeni eşya imzayı değiştirmeli")
	assert(int((base["gm"] as Dictionary)["gold"]) == 10 and (base as Dictionary).has("pos"), "imza girdiyi bozmamalı")


func test_run_kills_survive_the_rejoin_snapshot() -> void:
	GameManager.reset()
	GameManager.run_kills = 123
	var snap: Dictionary = GameManager.capture_run_state()
	GameManager.reset()
	assert(GameManager.run_kills == 0, "reset öldürmeyi sıfırlar")
	GameManager.restore_run_state(snap)
	assert(GameManager.run_kills == 123, "geri katılan öldürme sayısını geri alır: %d" % GameManager.run_kills)
	GameManager.reset()


func test_reset_announces_before_wiping_run_state() -> void:
	GameManager.reset()
	GameManager.run_kills = 40
	var seen: Array = []
	var cb := func() -> void: seen.append(GameManager.run_kills)
	GameManager.run_about_to_reset.connect(cb)
	GameManager.reset()
	GameManager.run_about_to_reset.disconnect(cb)
	assert(seen == [40], "sinyal reset silmeden ÖNCE gelmeli: %s" % str(seen))
	assert(GameManager.run_kills == 0, "reset yine sıfırlar")
