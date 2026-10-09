extends Node

## Matthew'in evcil hayvanı KÖPEK (eskiden tilki) - 2026-10-08. Kullanıcı: "masaüstündeki wolf-hellhound spritesheet'i ile tilkiyi değiştir, adı köpek"
## + "yeni köpeğin hareket anlayışını değiştir, çok bugluydu. Matthewi takip etmesi, çevresindeki yaratıklara saldırması gerekiyordu".
## Kapsam: sprite sayfası/animasyon sözleşmesi, yeni takip modeli (topuk noktası, durmadan akış, yumuşak duruş, uzak atlayış), savaş (sahibe yakın
## yaratığa koşma, hedefe dönüp ısırma, hedef değiştirme, tasma), ağ kopyası (akıcı hareket + ısırma klibi).

const PetScene: PackedScene = preload("res://scenes/player_pet.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const DogFrames: SpriteFrames = preload("res://assets/pets/dog/dog_frames.tres")
const Dirs := ["down", "left", "right", "up"]

var _nodes: Array[Node] = []


class FakeOwner extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var speed: float = 252.0
	var damage_bonus: float = 10.0
	var is_in_merchant_zone: bool = false

	func _physics_process(delta: float) -> void:
		global_position += velocity * delta


func _phys(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _make(owner_pos: Vector2) -> Array:
	var o := FakeOwner.new()
	add_child(o)
	o.global_position = owner_pos
	var pet: Node2D = PetScene.instantiate()
	add_child(pet)
	pet.global_position = owner_pos + Vector2(-54.0, 30.0)
	pet.call("setup_from_player", o)
	_nodes.append(o)
	_nodes.append(pet)
	return [o, pet]


func _enemy(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	_nodes.append(e)
	return e


# ------------------------------------------------------------------ sprite sayfası

func test_dog_frames_cover_the_pet_animation_contract() -> void:
	for d in Dirs:
		for base in ["idle", "walk", "run", "hurt", "death", "bite", "eat"]:
			assert(DogFrames.has_animation("%s_%s" % [base, d]), "köpek karesi: %s_%s yok" % [base, d])
		assert(DogFrames.get_frame_count("walk_" + d) == 4 and DogFrames.get_frame_count("run_" + d) == 4, "yürüyüş/koşu 4 kare: " + d)
		assert(DogFrames.get_frame_count("bite_" + d) == 5, "ısırma 5 kare: " + d)
		assert(DogFrames.get_animation_loop("walk_" + d) and DogFrames.get_animation_loop("run_" + d) and DogFrames.get_animation_loop("idle_" + d), "yürüyüş/koşu/bekleme döngülü")
		assert(not DogFrames.get_animation_loop("bite_" + d) and not DogFrames.get_animation_loop("death_" + d), "ısırma/ölüm döngüsüz")
	assert(DogFrames.has_animation("howl_left") and DogFrames.has_animation("howl_right") and DogFrames.has_animation("sleep_down"), "uluma/uyku klipleri hazır")
	var tex: Texture2D = DogFrames.get_frame_texture("walk_left", 0)
	assert(tex != null and tex.get_size() == Vector2(48, 48), "kare 48x48: %s" % str(tex.get_size() if tex else null))
	## Yan görünüşte köpek gerçekten SOLA / SAĞA bakıyor (kılavuz: WALK LEFT / WALK RIGHT): burun tarafı daha dolu.
	var pet: Node2D = PetScene.instantiate()
	add_child(pet)
	_nodes.append(pet)
	assert(pet.get("anim").sprite_frames == DogFrames or pet.get("anim").sprite_frames.has_animation("bite_down"), "pet sahnesi köpek karelerini kullanıyor")
	_cleanup()


# ------------------------------------------------------------------ takip

func test_dog_flows_with_the_walking_owner_without_stop_and_go() -> void:
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	o.velocity = Vector2(252.0, 0.0)
	await _phys(70) ## yakalama/oturma
	var stalls: int = 0
	var max_dist: float = 0.0
	var speeds: Array = []
	for _i in range(170):
		await get_tree().physics_frame
		var sp: float = (pet.get("velocity") as Vector2).length()
		speeds.append(sp)
		if sp < 12.0:
			stalls += 1
		max_dist = maxf(max_dist, pet.global_position.distance_to(o.global_position))
	assert(stalls <= 3, "sahip yürürken köpek DURMADAN akmalı (dur-kalk yok): %d durak" % stalls)
	assert(max_dist < 140.0, "köpek sahibinden uzaklaşmamalı: en çok %.0f px" % max_dist)
	var d_end: float = pet.global_position.distance_to(o.global_position)
	assert(d_end > 20.0 and d_end < 110.0, "sahibin yanında (topuk noktası): %.0f px" % d_end)
	var behind: float = (pet.global_position - o.global_position).x
	assert(behind < 0.0, "sahibin hareket yönünün ARKASINDA: dx %.0f" % behind)
	## animasyon: sahip koşar hızda yürürken köpek koşu klibinde (yürüme/duruş değil)
	assert(String(pet.get("anim").animation).begins_with("run_"), "akışta koşu klibi: %s" % pet.get("anim").animation)
	assert(String(pet.get("facing")) == "right", "hareket yönüne bakıyor: %s" % pet.get("facing"))
	_cleanup()


func test_dog_settles_and_idles_when_the_owner_stops() -> void:
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	o.velocity = Vector2(252.0, 0.0)
	await _phys(90)
	o.velocity = Vector2.ZERO
	await _phys(150)
	assert((pet.get("velocity") as Vector2).length() < 5.0, "sahip durunca köpek durur: %.1f" % (pet.get("velocity") as Vector2).length())
	var d: float = pet.global_position.distance_to(o.global_position)
	assert(d < 95.0 and d > 10.0, "yanında bekler (üstüne binmez): %.0f px" % d)
	assert(String(pet.get("anim").animation).begins_with("idle_"), "duruşta bekleme klibi: %s" % pet.get("anim").animation)
	## Titreme yok: bekleme sırasında konum oynamıyor.
	var p0: Vector2 = pet.global_position
	await _phys(60)
	assert(pet.global_position.distance_to(p0) < 1.0, "beklerken kıpırdamaz (titreme yok)")
	_cleanup()


func test_dog_warps_next_to_the_owner_when_left_far_behind() -> void:
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(5)
	o.global_position += Vector2(2000.0, 0.0) ## ışınlanma / ev girişi
	await _phys(4)
	assert(pet.global_position.distance_to(o.global_position) < 110.0, "uzakta kalan köpek topuk noktasına atlar: %.0f px" % pet.global_position.distance_to(o.global_position))
	_cleanup()


# ------------------------------------------------------------------ savaş

func test_dog_attacks_creatures_near_the_owner_facing_them_and_biting() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(20)
	var e: Node2D = _enemy(o.global_position + Vector2(170.0, 20.0))
	var hp0: float = float(e.health)
	var seen := {}
	var melee_seen: bool = false
	for _i in range(260):
		await get_tree().physics_frame
		seen[String(pet.get("anim").animation)] = true
		melee_seen = melee_seen or bool(pet.get("_in_melee_stance"))
		if float(e.health) < hp0 * 0.999 and seen.has("bite_right"):
			break
	assert(float(e.health) < hp0, "köpek sahibine yakın yaratığa SALDIRMALI (can %.0f -> %.0f)" % [hp0, float(e.health)])
	assert(melee_seen, "hedefe koşup yakın dövüş duruşuna girmeli")
	assert(seen.has("bite_right"), "hedefe DÖNÜP sağa ısırma klibini oynamalı: %s" % str(seen.keys()))
	assert(pet.global_position.distance_to(e.global_position) < 60.0, "hedefin dibinde: %.0f px" % pet.global_position.distance_to(e.global_position))
	## Hedef ölünce sahibine döner.
	e.set("is_dead", true)
	e.global_position += Vector2(5000.0, 0.0)
	await _phys(150)
	assert(pet.global_position.distance_to(o.global_position) < 110.0, "hedef bitince sahibinin yanına döner: %.0f px" % pet.global_position.distance_to(o.global_position))
	get_tree().current_scene = prev_scene
	_cleanup()


## "Matthew'in silahları yakına gelenleri hemen öldürüyor" taklidi: her 0,4 sn'de sahibe en yakın (<= 230 px) yaratık ölür.
func _weapons_kill_nearest(o: Node2D) -> void:
	var best: Node2D = null
	var best_d: float = 230.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = o.global_position.distance_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e as Node2D
	if best != null:
		best.set("is_dead", true)
		best.global_position += Vector2(6000.0, 0.0)


## 2026-10-08 (kullanıcı: "silahlarım yakına gelenleri hemen öldürdüğü için köpek hemen hedef değiştirmek zorunda kalıyor; gittiği yönde kararlı bir
## şekilde yaratık öldürüp sonra gelsin, sürekli zigzag çizerek kararsızca hedef aramasın"): dört yönde yaratık, silahlar sahibe en yakını sürekli öldürüyor.
## Köpek bir AKIN başlatıp hedeflerini o yönün konisinden seçmeli, yön tersine dönmemeli.
func test_dog_commits_to_one_direction_per_sortie_while_weapons_kill_everything_near_the_owner() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(20)
	for k in range(4):
		var dir := Vector2.from_angle(float(k) * PI * 0.5 + 0.3)
		for j in range(4):
			_enemy(o.global_position + dir * (140.0 + 28.0 * float(j)))
	var sorties: int = 0
	var was_active: bool = false
	var bad_targets: int = 0
	var reversals: int = 0
	var last_vel := Vector2.ZERO
	var targets_seen: int = 0
	for i in range(900):
		await get_tree().physics_frame
		if i % 24 == 0:
			_weapons_kill_nearest(o)
		var active: bool = bool(pet.get("_sortie_active"))
		if active and not was_active:
			sorties += 1
		was_active = active
		if active and is_instance_valid(pet.get("_focus_target")):
			targets_seen += 1
			var t: Node2D = pet.get("_focus_target")
			var off: Vector2 = t.global_position - o.global_position
			## Silahın öldürüp uzağa attığı hedef, köpek bir sonraki karede bırakana kadar atanmış görünür: ölü hedefler sayılmaz.
			if t.get("is_dead") != true and off.length() > 50.0 and absf((pet.get("_sortie_dir") as Vector2).angle_to(off)) > deg_to_rad(62.0):
				bad_targets += 1
		if active and i % 15 == 0:
			var v: Vector2 = pet.get("velocity")
			if v.length() > 60.0:
				if last_vel.length() > 60.0 and absf(v.angle_to(last_vel)) > deg_to_rad(110.0):
					reversals += 1
				last_vel = v
	assert(sorties >= 1 and targets_seen > 0, "köpek akın başlatıp hedef almalı (%d akın, %d kare hedefli)" % [sorties, targets_seen])
	assert(bad_targets == 0, "akının hedefleri HEP seçilen yönün konisinde (zigzag yok): %d koni dışı kare" % bad_targets)
	assert(reversals <= 3, "köpek yön değiştirip geri dönmemeli (zigzag): %d ters dönüş" % reversals)
	assert(sorties <= 6, "sürekli yeni akın başlatıp kararsızlaşmamalı: %d akın" % sorties)
	get_tree().current_scene = prev_scene
	_cleanup()


func test_dog_ends_the_sortie_and_returns_when_its_direction_is_empty() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(20)
	var e: Node2D = _enemy(o.global_position + Vector2(200.0, 0.0))
	await _phys(30)
	assert(bool(pet.get("_sortie_active")) and pet.get("_focus_target") == e, "yakındaki yaratık için akın başlar")
	e.set("is_dead", true) ## silahlar öldürdü
	e.global_position += Vector2(6000.0, 0.0)
	await _phys(90) ## koni boş: 1 sn sonra akın biter
	assert(not bool(pet.get("_sortie_active")), "yön boşalınca akın biter")
	assert(float(pet.get("_sortie_cooldown")) >= 0.0)
	await _phys(180)
	assert(pet.global_position.distance_to(o.global_position) < 110.0, "akın bitince sahibinin yanına döner: %.0f px" % pet.global_position.distance_to(o.global_position))
	assert(pet.get("_focus_target") == null, "hedefsiz")
	get_tree().current_scene = prev_scene
	_cleanup()


func test_dog_drops_the_sortie_when_the_target_goes_beyond_the_leash_and_ignores_far_creatures() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(10)
	var far_e: Node2D = _enemy(o.global_position + Vector2(330.0, 0.0)) ## odak yarıçapı (240) dışında: akın başlatmaz
	await _phys(40)
	assert(not bool(pet.get("_sortie_active")) and pet.get("_focus_target") == null, "odak yarıçapı dışındaki yaratık akın başlatmaz")
	far_e.global_position = o.global_position + Vector2(200.0, 0.0)
	await _phys(30)
	assert(bool(pet.get("_sortie_active")) and pet.get("_focus_target") == far_e, "yaklaşınca akın başlar")
	far_e.global_position = o.global_position + Vector2(700.0, 0.0) ## tasma (360) dışına kaçtı
	await _phys(90)
	assert(pet.get("_focus_target") != far_e and not bool(pet.get("_sortie_active")), "tasma dışına çıkan hedef bırakılır, akın biter")
	get_tree().current_scene = prev_scene
	_cleanup()


## Akın süresi dolunca: yaratık akışı hâlâ AYNI yönden sürüyorsa akın kesilmeden devam eder (sahibine dönüp aynı yöne yeniden çıkmak ters dönüş olurdu),
## en yoğun yön değiştiyse biter (dönüp yeni akın başlatılır).
func test_sortie_continues_past_its_time_limit_in_the_same_direction_and_ends_when_the_direction_changes() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	await _phys(10)
	var e: Node2D = _enemy(o.global_position + Vector2(200.0, 0.0))
	await _phys(30)
	assert(bool(pet.get("_sortie_active")), "akın başlamış olmalı")
	pet.set("_sortie_t", 100.0)
	pet.call("_update_sortie", 0.016)
	assert(bool(pet.get("_sortie_active")) and float(pet.get("_sortie_t")) < 1.0, "süre doldu ama aynı yönde yaratık var: akın sürer, sayaç sıfırlanır")
	e.global_position = o.global_position + Vector2(-200.0, 0.0) ## yaratık akışı ters yöne geçti
	pet.set("_sortie_t", 100.0)
	pet.call("_update_sortie", 0.016)
	assert(not bool(pet.get("_sortie_active")), "en yoğun yön değişti: akın biter, köpek dönüp yenisini başlatır")
	get_tree().current_scene = prev_scene
	_cleanup()


func test_dog_does_not_fight_inside_the_merchant_safe_zone() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var pair: Array = _make(Vector2(3000, 3000))
	var o: FakeOwner = pair[0]
	var pet: Node2D = pair[1]
	o.is_in_merchant_zone = true
	await _phys(10)
	var e: Node2D = _enemy(o.global_position + Vector2(120.0, 0.0))
	var hp0: float = float(e.health)
	await _phys(120)
	assert(pet.get("_focus_target") == null and float(e.health) >= hp0, "seyyar satıcı güvenli bölgesinde kovalamaz/saldırmaz")
	get_tree().current_scene = prev_scene
	_cleanup()


# ------------------------------------------------------------------ ağ kopyası

func test_network_copy_flows_smoothly_and_plays_the_bite_clip() -> void:
	var copy: Node2D = PetScene.instantiate()
	add_child(copy)
	_nodes.append(copy)
	copy.global_position = Vector2(500.0, 500.0)
	copy.call("mark_as_network_visual")
	var real_pos := Vector2(500.0, 500.0)
	var clip_changes: int = 0
	var last_clip: String = ""
	var frames_since: int = 0
	for i in range(220):
		real_pos += Vector2(250.0 / 60.0, 0.0)
		frames_since += 1
		if frames_since >= 9: ## gerçek köpek 0,15 sn'de bir konum yayınlar
			frames_since = 0
			copy.call("update_network_pet_state", real_pos, false, -1, false)
		await get_tree().physics_frame
		var clip: String = String(copy.get("anim").animation)
		if i > 60 and clip != last_clip:
			clip_changes += 1
		last_clip = clip
	assert(copy.global_position.distance_to(real_pos) < 55.0, "kopya gerçek köpeği izler: %.0f px" % copy.global_position.distance_to(real_pos))
	assert(clip_changes <= 2, "kopyada klip titremez (walk/run/idle): %d değişim" % clip_changes)
	assert(last_clip.begins_with("run_") and String(copy.get("facing")) == "right", "kopya koşu klibinde ve sağa bakıyor: %s / %s" % [last_clip, copy.get("facing")])
	## Isırma: is_attacking + yön dizini -> kopya aynı yöne dönüp bite klibini oynar.
	copy.call("update_network_pet_state", real_pos, true, 1, false)
	assert(String(copy.get("facing")) == "left" and String(copy.get("anim").animation) == "bite_left", "ısırma paketi: %s / %s" % [copy.get("facing"), copy.get("anim").animation])
	await get_tree().physics_frame
	assert(String(copy.get("anim").animation) == "bite_left", "ısırma klibi hemen ezilmez")
	## Işınlanma (teleport/dash): çok uzaktaki konuma anında ya da dash ile gider.
	copy.call("update_network_pet_state", real_pos + Vector2(900.0, 0.0), false, -1, true)
	await _phys(30)
	assert(copy.global_position.distance_to(real_pos + Vector2(900.0, 0.0)) < 60.0, "teleport paketi kopyayı yeni konuma götürür")
	_cleanup()


## 2026-10-08 iki süreçli denetim bulgusu: kopyada duruş sırasında idle <-> walk 0,1 sn aralıkla titriyordu (hız eşik civarında dolaşıyordu).
func test_network_copy_does_not_flicker_between_idle_and_walk_when_the_dog_stops() -> void:
	var copy: Node2D = PetScene.instantiate()
	add_child(copy)
	_nodes.append(copy)
	copy.global_position = Vector2(500.0, 500.0)
	copy.call("mark_as_network_visual")
	var real_pos := Vector2(500.0, 500.0)
	var frames_since: int = 0
	var changes: int = 0
	var last_clip: String = ""
	for i in range(420):
		if i < 150:
			real_pos += Vector2(250.0 / 60.0, 0.0) ## 2,5 sn koşar, sonra durur
		frames_since += 1
		if frames_since >= 9:
			frames_since = 0
			copy.call("update_network_pet_state", real_pos, false, -1, false)
		await get_tree().physics_frame
		var clip: String = String(copy.get("anim").animation)
		if i >= 150 and clip != last_clip:
			changes += 1
		if i >= 150 or last_clip == "":
			last_clip = clip
		else:
			last_clip = clip
	assert(changes <= 3, "durma sırasında klip titremez (run -> walk -> idle en çok): %d değişim" % changes)
	assert(String(copy.get("anim").animation).begins_with("idle_"), "sonunda bekleme klibinde: %s" % copy.get("anim").animation)
	assert((copy.get("velocity") as Vector2).length() < 5.0, "kopya tamamen durur: %.1f" % (copy.get("velocity") as Vector2).length())
	assert(String(copy.get("facing")) == "right", "duruşta aşma bakış yönünü çevirmez: %s" % copy.get("facing"))
	_cleanup()
