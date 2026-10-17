extends Node

## Kullanıcı bildirimi (2. kez): "assasin çocuğun ultisi yine çalışmıyor, R'ye basınca karakter
## siyaha dönüyor ama saldırmıyor". Kök neden: Gölge Hücumu (id 16) "Q ile R'nin yerini değiştir"
## isteğiyle R (skill3) slotuna taşınmıştı ama _skill_assasin_dash döngüsü hâlâ Q'nun durumuna
## (skill_state) bakıyordu -> ilk turda break, saldırı yok; karakter koyu tonda/hareket kilidinde
## R'nin 15 sn süresi dolana kadar kalıyor, ayrıca sonda Q (Gölge Adımı) yanlışlıkla bekleme
## süresine giriyordu. Bu test GERÇEK Player ile R'yi tetikleyip zincirin bitmesini bekler.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const UltFlashScript: GDScript = preload("res://scripts/fx_assasin_ult_flash.gd")
const UltStreakScript: GDScript = preload("res://scripts/fx_assasin_ult_streak.gd")

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
## 2026-10-16 (kullanıcı isteği): en fazla 20 çarpış, sadece KENDİ görüş elipsindeki yaratıklar (sis yokken yarıçap
## VISION_RADIUS 250, yatay x1,4), bekleme 10 sn; yeni efektler (kesik/patlama + sıçrayış çizgisi) gerçekten doğmalı.
func test_pressing_r_attacks_nearby_enemies_and_cleans_up_the_right_slot() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## vuruş efektleri current_scene'e ekleniyor
	var fx_seen: Dictionary = {}
	var on_child := func(n: Node) -> void:
		if n.get_script() != null:
			fx_seen[n.get_script()] = int(fx_seen.get(n.get_script(), 0)) + 1
	child_entered_tree.connect(on_child)
	var p := _make_assasin()
	var origin: Vector2 = p.global_position
	var e1 := _enemy(origin + Vector2(120.0, 0.0))
	var e2 := _enemy(origin + Vector2(-200.0, 60.0))
	var e3 := _enemy(origin + Vector2(0.0, 200.0))
	var out_of_sight := _enemy(origin + Vector2(0.0, 300.0)) ## eski 600'lük yarıçapın içinde ama görüş elipsinin (250) dışında
	var far := _enemy(origin + Vector2(2000.0, 0.0))

	assert(p.skill3_state == "ready" and p.skill_state == "ready", "test kurulumu: tüm slotlar hazır olmalı")
	p._activate_skill3()
	assert(p.skill3_state == "active", "R basılınca skill3 aktif olmalı")

	## Herkes vurulunca tur baştan başlar (aynı yaratıklara tekrar vurulur, ~4,5 vuruş/sn); 20 çarpışta (~4,4 sn) biter.
	## 10 sn'lik pencere güvenlik tavanı - en fazla 13 sn bekle.
	var waited: float = 0.0
	var poses: Dictionary = {}
	var sprite: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	while p.skill3_state == "active" and waited < 13.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		poses[String(sprite.animation)] = true
	## 10sn dolunca durum önce "cooldown"a geçer, cast noktasına dönüş (kısa tween) hemen ardından gelir.
	for _i in range(20):
		await get_tree().physics_frame

	child_entered_tree.disconnect(on_child)
	assert(e1.hits >= 2 and e2.hits >= 2 and e3.hits >= 2,
		"Görüşteki yaratıklara tekrar tekrar vurulmalı: %d/%d/%d" % [e1.hits, e2.hits, e3.hits])
	assert(e1.hits + e2.hits + e3.hits == p.ASSASIN_DASH_MAX_HITS and p.ASSASIN_DASH_MAX_HITS == 20,
		"Ulti en fazla 20 kez vurmalı, toplam: %d" % (e1.hits + e2.hits + e3.hits))
	## Kullanıcı isteği (2026-10-16): ulti sırasında ayakta durma yok - gidiş yönüne bakan atılma pozu (dash_<yön>).
	## e1 sağda (dash_right), e3 aşağıda (dash_down), e2 solda (dash_left).
	assert(poses.has("dash_right") and poses.has("dash_down") and poses.has("dash_left"),
		"Sıçrayışlarda gidiş yönündeki atılma pozu oynamalı, görülen: %s" % str(poses.keys()))
	assert(String(sprite.animation).begins_with("idle_"), "Ulti bitince normal bekleme klibine dönmeli: %s" % sprite.animation)
	assert(out_of_sight.hits == 0, "Kendi görüş alanı dışındaki yaratığa (eski 600 yarıçap içinde olsa da) vurulmamalı")
	assert(absi(e1.hits - e3.hits) <= 1, "Vurulmamış yaratık önceliği: vuruşlar yaratıklar arasında dengeli dağılmalı")
	assert(e1.damage_taken / float(e1.hits) >= p.damage_bonus * p.ASSASIN_DASH_DAMAGE_RATIO - 0.001,
		"Vuruş başı hasar en az saldırı gücü x ASSASIN_DASH_DAMAGE_RATIO (%300) olmalı (kritikle fazlası)")
	assert(far.hits == 0, "Yarıçap dışındaki yaratığa vurulmamalı")
	assert(p.skill3_state == "cooldown", "Zincir bitince R bekleme süresine geçmeli, durum: %s" % p.skill3_state)
	assert(p.skill3_timer > 1.0 and p.skill3_timer <= 10.0 + 0.001, "R bekleme sayacı 10 sn olmalı: %.2f" % p.skill3_timer)
	assert(int(fx_seen.get(UltFlashScript, 0)) >= 20 + 1, "Her isabete kesik + cast patlaması doğmalı: %d" % int(fx_seen.get(UltFlashScript, 0)))
	assert(int(fx_seen.get(UltStreakScript, 0)) >= 20, "Her sıçrayışın kendi çizgisi doğmalı: %d" % int(fx_seen.get(UltStreakScript, 0)))
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


## Sadece Assasin'in KENDİ görüşündeki yaratığa saldırılır (VisionFog.own_vision_contains, 2026-10-16): takım arkadaşının
## gördüğü (sis değeri 1) ama kendi elipsinin dışındaki yaratık ve görünmez hayalet ("untargetable") vurulmaz.
func test_hidden_enemies_are_not_targeted_but_visible_ones_are() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var p := _make_assasin()
	var origin: Vector2 = p.global_position
	var visible_enemy := _enemy(origin + Vector2(100.0, 0.0), 1.0)
	var hidden_enemy := _enemy(origin + Vector2(0.0, -320.0), 1.0) ## takım görüşünde, kendi görüşünde değil
	var ghost := _enemy(origin + Vector2(-80.0, 0.0), 1.0)
	ghost.set_meta(&"untargetable", true)
	p._activate_skill3()
	var waited: float = 0.0
	while p.skill3_state == "active" and waited < 13.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	## 2026-09-24: tek görünen yaratık varsa ona birden fazla kez saldırılır (kullanıcı isteği).
	assert(visible_enemy.hits >= 2, "Tek görünen yaratığa birden fazla kez vurulmalı: %d" % visible_enemy.hits)
	assert(hidden_enemy.hits == 0, "Kendi görüşü dışındaki yaratığa vurulmamalı")
	assert(ghost.hits == 0, "Görünmez hayalete vurulmamalı")
	assert(visible_enemy.hits == p.ASSASIN_DASH_MAX_HITS, "Tek yaratığa 20 çarpışın hepsi gitmeli: %d" % visible_enemy.hits)
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


## Atılma pozu klipleri (tools/add_dash_pose_clips.py): dört yön, koşu klibinin DASH_POSE_RUN_FRAME karesi; yön yardımcısı
## baskın ekseni seçer (uzak kopya aynı vektörden aynı yönü bulur). Talon (talha_frames) 2026-10-17'den beri Q atılışında aynı pozu oynatır.
func test_dash_pose_clips_exist_and_direction_helper() -> void:
	const CharAnimScript: GDScript = preload("res://scripts/char_anim.gd")
	for path: String in ["res://assets/characters/assasin_frames.tres", "res://assets/characters/talha_frames.tres"]:
		var frames: SpriteFrames = load(path) as SpriteFrames
		for d: String in ["down", "left", "right", "up"]:
			var pose: String = CharAnimScript.DASH_POSE_PREFIX + d
			assert(frames.has_animation(pose) and frames.get_frame_count(pose) == 1, "%s: %s tek kareli klip olmalı" % [path, pose])
			assert(frames.get_frame_texture(pose, 0) == frames.get_frame_texture("run_" + d, CharAnimScript.DASH_POSE_RUN_FRAME),
				"%s: %s koşu klibinin %d. karesi olmalı" % [path, pose, CharAnimScript.DASH_POSE_RUN_FRAME])
	assert(CharAnimScript.dir_from_vector(Vector2(10, 3)) == "right" and CharAnimScript.dir_from_vector(Vector2(-10, -9)) == "left")
	assert(CharAnimScript.dir_from_vector(Vector2(2, 9)) == "down" and CharAnimScript.dir_from_vector(Vector2(-2, -9)) == "up")


## 2026-10-17 (kullanıcı): "talon dash atarken tıpkı assasin çocuktaki gibi koşma animasyonunun framelerinden birindeyken
## görünmeli". GERÇEK Player: Q atılışı boyunca (ilk kare dahil - fx_talon_dash'in ilk hayaleti) gidiş yönündeki dash_<yön>
## pozu oynar, atılış bitince normal akışa döner.
func test_talon_dash_holds_the_run_frame_pose() -> void:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var p: CharacterBody2D = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(500.0, 500.0)
	p.facing = "left"
	var sprite: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	p._skill_talon_dash()
	assert(p._talon_dashing, "atılış başlamalı")
	assert(String(sprite.animation) == "dash_left", "atılışın ilk karesinde poz kurulmalı, bulunan: %s" % sprite.animation)
	var waited: float = 0.0
	while p._talon_dashing and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if p._talon_dashing:
			assert(String(sprite.animation) == "dash_left", "atılış boyunca poz kalmalı, bulunan: %s" % sprite.animation)
	assert(not p._talon_dashing, "atılış 1 sn içinde bitmeli")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(not String(sprite.animation).begins_with("dash_"), "atılıştan sonra poz bırakılmalı, bulunan: %s" % sprite.animation)
	_cleanup()
