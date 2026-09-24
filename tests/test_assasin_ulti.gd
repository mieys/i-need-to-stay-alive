extends Node

## Kullanıcı bildirimi (2. kez): "assasin çocuğun ultisi yine çalışmıyor, R'ye basınca karakter
## siyaha dönüyor ama saldırmıyor". Kök neden: Gölge Hücumu (id 16) "Q ile R'nin yerini değiştir"
## isteğiyle R (skill3) slotuna taşınmıştı ama _skill_assasin_dash döngüsü hâlâ Q'nun durumuna
## (skill_state) bakıyordu -> ilk turda break, saldırı yok; karakter koyu tonda/hareket kilidinde
## R'nin 15 sn süresi dolana kadar kalıyor, ayrıca sonda Q (Gölge Adımı) yanlışlıkla bekleme
## süresine giriyordu. Bu test GERÇEK Player ile R'yi tetikleyip zincirin bitmesini bekler.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

const ASSASIN_ROSTER_ID := 5


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_frozen: bool = false
	var health: float = 100.0
	var damage_taken: float = 0.0
	var hits: int = 0

	func take_damage(amount: float, _crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		damage_taken += amount
		hits += 1


var _spawned: Array[Node] = []


func _enemy(pos: Vector2, seen: float = -1.0) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	if seen >= 0.0:
		e.set_meta(VisionFogScript.VIS_META, seen)
	_spawned.append(e)
	return e


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _make_assasin() -> CharacterBody2D:
	GameManager.selected_char_id = ASSASIN_ROSTER_ID
	GameManager.selected_character = ASSASIN_ROSTER_ID
	var p: CharacterBody2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	p.item_shield_max = 1000.0 ## ulti kalkan bedeli ister (bkz. _activate_skill3)
	p.item_shield_hp = 1000.0
	_spawned.append(p)
	return p


func test_r_is_the_shadow_strike_ultimate() -> void:
	var p := _make_assasin()
	assert(p.get_skill3_id() == 16, "Assasin'in R'si Gölge Hücumu (id 16) olmalı, bulunan: %s" % p.get_skill3_id())
	_cleanup()


## R'ye basınca: yaratıklara GERÇEKTEN vurmalı, bitince R "cooldown"a geçmeli, karakter normale dönmeli,
## Q (Gölge Adımı) etkilenmemeli, karakter başladığı yere dönmeli.
func test_pressing_r_attacks_nearby_enemies_and_cleans_up_the_right_slot() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## vuruş efektleri current_scene'e ekleniyor
	var p := _make_assasin()
	var origin: Vector2 = p.global_position
	var e1 := _enemy(origin + Vector2(120.0, 0.0))
	var e2 := _enemy(origin + Vector2(-200.0, 60.0))
	var e3 := _enemy(origin + Vector2(0.0, 300.0))
	var far := _enemy(origin + Vector2(2000.0, 0.0)) ## ASSASIN_DASH_RADIUS (600) dışında -> vurulmamalı

	assert(p.skill3_state == "ready" and p.skill_state == "ready", "test kurulumu: tüm slotlar hazır olmalı")
	p._activate_skill3()
	assert(p.skill3_state == "active", "R basılınca skill3 aktif olmalı")

	## 2026-09-24 denge turu: Gölge Hücumu artık 10sn'lik bir pencere (SKILL3_TIMING[16]) - herkes vurulunca tur baştan
	## başlar, yani 10sn boyunca yakındaki yaratıklara TEKRAR TEKRAR vurulur (~3 vuruş/sn). En fazla 13 sn bekle.
	var waited: float = 0.0
	while p.skill3_state == "active" and waited < 13.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	## 10sn dolunca durum önce "cooldown"a geçer, cast noktasına dönüş (kısa tween) hemen ardından gelir.
	for _i in range(20):
		await get_tree().physics_frame

	assert(e1.hits >= 2 and e2.hits >= 2 and e3.hits >= 2,
		"10sn boyunca yakındaki yaratıklara tekrar tekrar vurulmalı: %d/%d/%d" % [e1.hits, e2.hits, e3.hits])
	assert(absi(e1.hits - e3.hits) <= 1, "Vurulmamış yaratık önceliği: vuruşlar yaratıklar arasında dengeli dağılmalı")
	assert(e1.damage_taken / float(e1.hits) >= p.damage_bonus * p.ASSASIN_DASH_DAMAGE_RATIO - 0.001,
		"Vuruş başı hasar en az saldırı gücünün %%150'si olmalı (kritikle fazlası)")
	assert(far.hits == 0, "Yarıçap dışındaki yaratığa vurulmamalı")
	assert(p.skill3_state == "cooldown", "Zincir bitince R bekleme süresine geçmeli, durum: %s" % p.skill3_state)
	assert(p.skill3_timer > 1.0, "R bekleme sayacı kurulmalı")
	assert(p.skill_state == "ready", "R kullanımı Q'yu (Gölge Adımı) bekleme süresine SOKMAMALI, Q durumu: %s" % p.skill_state)
	assert(not p.is_assasin_dashing, "Zincir bitince hareket kilidi (is_assasin_dashing) kalkmalı")
	assert(is_equal_approx(p.modulate.a, 1.0) and p.modulate.r > 0.9, "Karakter koyu/yarı saydam tonda takılı kalmamalı: %s" % str(p.modulate))
	assert(p.global_position.distance_to(origin) < 5.0, "Karakter başladığı konuma dönmeli: %s" % str(p.global_position))
	get_tree().current_scene = previous_scene
	_cleanup()


## Hedef bulunamasa bile (etrafta yaratık yok) karakter siyah/kilitli KALMAMALI.
func test_with_no_enemies_the_ultimate_ends_cleanly_instead_of_locking_the_character() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var p := _make_assasin()
	p._activate_skill3()
	var waited: float = 0.0
	while p.skill3_state == "active" and waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	assert(p.skill3_state == "cooldown", "Hedef yokken R hemen bitip bekleme süresine geçmeli")
	assert(not p.is_assasin_dashing and p.modulate.a > 0.99, "Hedef yokken karakter kilitli/koyu kalmamalı")
	assert(p.skill_state == "ready", "Q etkilenmemeli")
	get_tree().current_scene = previous_scene
	_cleanup()


## Görmediğimiz (sisin ardındaki) yaratığa saldırılmamalı (bkz. VisionFog.can_target) - görünen vurulur.
func test_hidden_enemies_are_not_targeted_but_visible_ones_are() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var p := _make_assasin()
	var origin: Vector2 = p.global_position
	var visible_enemy := _enemy(origin + Vector2(100.0, 0.0), 1.0)
	var hidden_enemy := _enemy(origin + Vector2(-100.0, 0.0), 0.0)
	p._activate_skill3()
	var waited: float = 0.0
	while p.skill3_state == "active" and waited < 13.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	## 2026-09-24: tek görünen yaratık varsa ona birden fazla kez saldırılır (kullanıcı isteği).
	assert(visible_enemy.hits >= 2, "Tek görünen yaratığa birden fazla kez vurulmalı: %d" % visible_enemy.hits)
	assert(hidden_enemy.hits == 0, "Görünmeyen yaratığa vurulmamalı")
	get_tree().current_scene = previous_scene
	_cleanup()


## Regresyon koruması: döngü Q'nun durumuna (skill_state) bağlanmasın.
func test_dash_loop_uses_the_r_slot_state() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var start: int = src.find("func _skill_assasin_dash() -> void:")
	var end: int = src.find("func _skill_haste() -> void:")
	assert(start != -1 and end > start, "fonksiyon bulunamadı")
	var body: String = src.substr(start, end - start)
	var code: String = ""
	for line: String in body.split("\n"):
		var idx: int = line.find("#")
		code += (line.substr(0, idx) if idx != -1 else line) + "\n"
	assert(code.contains('skill3_state != "active"'), "Gölge Hücumu döngüsü R'nin durumuna (skill3_state) bakmalı")
	assert(not code.contains('skill_state != "active"'), "Gölge Hücumu artık Q'nun durumuna bakmamalı")
	assert(code.contains("_cancel_active_skill3_early()") and not code.contains("_cancel_active_skill_early()"),
		"Gölge Hücumu sonunda R'yi bitirmeli, Q'yu değil")
