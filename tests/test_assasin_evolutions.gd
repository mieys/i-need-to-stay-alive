extends Node

## Kullanıcı isteği (2026-09-30): Assasin Çocuk evrimleri (bkz. scripts/skill_evolutions.gd DEFS[5], player.gd EVRİMLER bloğu
## "Assasin Çocuk" bölümü, evo_area.gd "assasin_*" türleri). Temel kesintiler: Gölge Adımı saldırı gücü vermez, Şahin Hamlesi
## 2 yük, Gölge Hücumu'nun temposu saldırı hızından bağımsız. Bu test GERÇEK Player + sahte yaratıklarla sayıları, ışınlanmayı,
## kunaileri ve gölge izini doğrular.
## Aynı gün Q ile E yer değiştirdi ("E yeteneği artık Q, Q yeteneği de artık E olsun"): Q = Şahin Hamlesi (id 5, yük tabanlı,
## yük başı 10 sn), E = Gölge Adımı (id 30, standart skill2 makinesi). Evrim id'leri yeni yuvaya göre (assasin_q* hamle,
## assasin_e* görünmezlik).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EvoArea: GDScript = preload("res://scripts/evo_area.gd")
const ASSASIN := 5


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var damage_taken: float = 0.0
	var hits: int = 0

	func take_damage(amount: float, _crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		damage_taken += amount
		hits += 1


var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self ## kopya / kunai / iz / efektler current_scene'e eklenir
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = ASSASIN
	GameManager.selected_character = int(Characters.DEFS[ASSASIN]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.item_shield_max = 1000.0 ## yetenek kalkan bedeli
	p.item_shield_hp = 1000.0
	return p


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_children():
		if c.get_script() == EvoArea and is_instance_valid(c):
			c.free()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


## E'nin (Gölge Adımı) süresini gerçek zamanlayıcı yolundan (_process_skill2 -> _end_skill2_effects) bitirir.
func _expire_e(p: Node) -> void:
	p.skill2_timer = 0.001
	p._process_skill2(0.01)


## Gerçek tuş basışı: aksiyonu bas, bir fizik karesi bekle (oyuncunun _physics_process'i is_action_just_pressed görür), bırak.
func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _evo_areas(area_kind: String) -> Array:
	var out: Array = []
	for c in get_children():
		if c.get_script() == EvoArea and str(c.get("kind")) == area_kind and not c.is_queued_for_deletion():
			out.append(c)
	return out


# ------------------------------------------------------------------ temel kesintiler + Q/E yerleşimi

func test_slots_swapped_and_base_nerfs() -> void:
	assert(int(Characters.DEFS[ASSASIN]["skill"]) == 5 and int(Characters.DEFS[ASSASIN]["skill2"]) == 30,
		"Q = Şahin Hamlesi (5), E = Gölge Adımı (30)")
	var p := _make_player()
	assert(is_equal_approx(p.ASSASIN_DASH2_RECHARGE_TIME, 10.0), "hamle yük başı bekleme 10 sn")
	assert(p.get_assasin_dash2_max_charges() == 2 and p.assasin_dash2_charges == 2, "Şahin Hamlesi temel 2 yük")
	assert(not p.get_assasin_dash_charge_state().is_empty(), "HUD'un Q ikonu hamle yüklerini göstermeli")
	var ap0: float = p.damage_bonus
	p._activate_skill2()
	assert(p.skill2_state == "active" and p.is_invisible, "E görünmezlik açmalı")
	assert(p.skill_state == "ready", "E, Q yuvasını etkilememeli")
	assert(is_equal_approx(p.damage_bonus, ap0), "Gölge Adımı temelde saldırı gücü vermemeli (%s -> %s)" % [ap0, p.damage_bonus])
	assert(is_equal_approx(float(p._skill2_timing_for(30)["duration"]), 6.0), "görünmezlik temel 6 sn")
	assert(is_equal_approx(float(p._skill2_timing_for(30)["cooldown"]), 60.0), "görünmezlik bekleme 60 sn")
	_expire_e(p)
	assert(not p.is_invisible and p.skill2_state == "cooldown", "E süresi dolunca görünmezlik kapanmalı, bekleme başlamalı")
	## BUG DÜZELTMESİ: bitişteki eski "collision_mask |= 4" oyuncuyu yaratıklarla kalıcı çarpıştırıyordu.
	assert(p.collision_mask == 0, "Gölge Adımı yaratık fizik katmanını açmamalı: mask=%d" % p.collision_mask)
	## R temposu saldırı hızından bağımsız (kartsız ~0.22 sn), "Hızlanan Hücum" ile bağlanır.
	var base_iv: float = p._assasin_dash_hit_interval()
	assert(is_equal_approx(base_iv, 1.0 / 4.5), "R temel tempo 1/4.5 sn: %s" % base_iv)
	p.fire_rate_mult = 0.5
	assert(is_equal_approx(p._assasin_dash_hit_interval(), base_iv), "evrimsiz R saldırı hızıyla hızlanmamalı")
	p.apply_skill_evolution("assasin_r1", true)
	assert(is_equal_approx(p._assasin_dash_hit_interval(), base_iv * 0.5), "Hızlanan Hücum: saldırı hızıyla hızlanmalı")
	_cleanup()


## Gerçek tuşlarla: Q hamle atar (yük düşer, standart Q makinesi / Oakley iyileştirmesi ÇALIŞMAZ), E görünmezlik açar,
## görünmezlikte E (1 sn spam korumasından sonra) kopyaya ışınlar.
func test_real_key_presses() -> void:
	var p := _make_player()
	p.level = 10 ## E 5., R 10. seviyede açılır
	p.apply_skill_evolution("assasin_ef", true)
	var start: Vector2 = p.global_position
	p.facing = "right"
	await _press("skill")
	assert(p.assasin_dash2_charges == 1, "Q hamle atmalı (yük 2 -> 1): %d" % p.assasin_dash2_charges)
	assert(p.skill_state == "ready", "Q standart bekleme makinesine girmemeli")
	for _i in range(20):
		await get_tree().physics_frame
	var after_dash: Vector2 = p.global_position
	assert(after_dash.x > start.x + 60.0, "hamle sağa ilerletmeli: %s" % str(after_dash))
	await _press("skill2")
	assert(p.skill2_state == "active" and p.is_invisible, "E görünmezlik açmalı")
	assert(p._assasin_clone_ready(), "E finali: kopya bırakılmalı")
	await _press("skill2")
	assert(p._assasin_clone_ready(), "spam koruması: hemen ikinci E ışınlamamalı")
	p._toggle_opened_msec["skill2"] = Time.get_ticks_msec() - 2000 ## 1 sn'lik korumanın geçtiğini simüle et
	p.global_position = after_dash + Vector2(0.0, 120.0)
	await _press("skill2")
	assert(p.global_position.distance_to(after_dash) < 1.0, "görünmezlikte E kopyaya ışınlamalı: %s" % str(p.global_position))
	assert(p.is_invisible, "ışınlanma görünmezliği bitirmemeli")
	_cleanup()


# ------------------------------------------------------------------ E (Gölge Adımı)

func test_e_evolutions_duration_ap_shield_speed() -> void:
	var p := _make_player()
	for id in ["assasin_e1", "assasin_e2", "assasin_e3", "assasin_e4"]:
		p.apply_skill_evolution(id, true)
	assert(is_equal_approx(float(p._skill2_timing_for(30)["duration"]), 8.0), "Uzun Gölge: 6 + 2 sn")
	var cd0: float = float(p.SKILL2_TIMING[30]["cooldown"])
	assert(is_equal_approx(float(p._skill2_timing_for(30)["cooldown"]), cd0), "Uzun Gölge bekleme süresine dokunmaz")
	p.item_shield_regen_delay = 3.0
	var ap0: float = p.damage_bonus
	var speed0: float = p.get_effective_move_speed()
	p._activate_skill2()
	assert(is_equal_approx(p.damage_bonus, ap0 * 1.25), "Pusu: +%%25 saldırı gücü (%s -> %s)" % [ap0, p.damage_bonus])
	assert(p.item_shield_regen_delay <= 0.0 and p.item_shield_ability_slow_timer <= 0.0,
		"Gölge Nefesi: kalkan bekleme / yavaşlama sıfırlanmalı (%s / %s)" % [p.item_shield_regen_delay, p.item_shield_ability_slow_timer])
	assert(is_equal_approx(p.get_effective_move_speed(), speed0 * 1.2), "Sessiz Adımlar: görünmezken +%%20 hız")
	assert(is_instance_valid(p._assasin_empower_fx), "Pusu parıltısı açık olmalı")
	_expire_e(p)
	assert(is_equal_approx(p.damage_bonus, ap0), "Pusu bitince saldırı gücü geri düşmeli")
	assert(is_equal_approx(p.get_effective_move_speed(), speed0), "görünmezlik bitince hız normale dönmeli")
	_cleanup()


func test_e_final_clone_teleport() -> void:
	var p := _make_player()
	p.apply_skill_evolution("assasin_ef", true)
	var start: Vector2 = p.global_position
	p._activate_skill2()
	assert(p._assasin_clone_ready(), "Gölge Kopyası bırakılmalı")
	assert(_evo_areas("assasin_clone").size() == 1, "dünyada tek kopya olmalı")
	assert((p._assasin_clone as Node2D).global_position.distance_to(start) < 0.5, "kopya başlangıç noktasında")
	assert(not p._toggle_close_allowed("skill2"), "spam koruması: açılıştan hemen sonraki basış ışınlamamalı")
	p.global_position = start + Vector2(300.0, 40.0)
	p._assasin_teleport_to_clone()
	assert(p.global_position.distance_to(start) < 0.5, "kopyaya ışınlanmalı: %s" % str(p.global_position))
	assert(p.is_invisible and p.skill2_state == "active", "ışınlanma görünmezliği bitirmemeli")
	assert(not p._assasin_clone_ready(), "kopya tek kullanımlık")
	## Görünmezlik bitince (ışınlanmadan) kopya da söner.
	_expire_e(p)
	p.skill2_state = "ready"
	p._activate_skill2()
	assert(p._assasin_clone_ready(), "ikinci kullanımda yeni kopya")
	var clone: Node = p._assasin_clone
	_expire_e(p)
	assert(not p._assasin_clone_ready() and clone.is_queued_for_deletion(), "görünmezlik bitince kopya sönmeli")
	_cleanup()


# ------------------------------------------------------------------ Q (Şahin Hamlesi)

func test_q_charges_refund_damage_dodge() -> void:
	var p := _make_player()
	p.assasin_dash2_charges = 2
	p._assasin_dash2_recharge_timer = 0.0
	p.apply_skill_evolution("assasin_q1", true)
	assert(p.get_assasin_dash2_max_charges() == 3, "Üçüncü Hamle: 3 yük")
	assert(is_equal_approx(p._assasin_dash2_recharge_timer, p.ASSASIN_DASH2_RECHARGE_TIME), "yeni yük hemen dolmaya başlamalı")
	## Av Zinciri: öldürme olayı dolan yükün süresini 0.2 sn kısaltır (evrimsizken hiçbir şey).
	p._assasin_dash2_recharge_timer = 5.0
	p.on_enchant_event("assasin_dash_kill", {})
	assert(is_equal_approx(p._assasin_dash2_recharge_timer, 5.0), "evrimsiz öldürme süreyi değiştirmemeli")
	p.apply_skill_evolution("assasin_q2", true)
	p.on_enchant_event("assasin_dash_kill", {})
	assert(is_equal_approx(p._assasin_dash2_recharge_timer, 4.8), "Av Zinciri: -0.2 sn (%s)" % p._assasin_dash2_recharge_timer)
	## Rüzgar Gibi: hamle anında %100 sıvışma penceresi.
	assert(p._assasin_evade_dodge() == 0.0, "pencere yokken ek sıvışma yok")
	p.apply_skill_evolution("assasin_q4", true)
	p.apply_skill_evolution("assasin_q3", true)
	var e := _enemy(p.global_position + Vector2(60.0, 0.0))
	p.facing = "right"
	p._try_assasin_dash2()
	assert(p._assasin_evade_dodge() == 1.0, "Rüzgar Gibi: hamleden sonra %100 sıvışma")
	for _i in range(30):
		await get_tree().physics_frame
	var total: float = 0.0
	for w in p.owned_weapon_nodes:
		if is_instance_valid(w) and "damage" in w:
			total += float(w.get("damage"))
	if total <= 0.0:
		total = 10.0
	var expected: float = total * p.ASSASIN_DASH2_DAMAGE_MULT * 1.3
	assert(e.hits == 1, "hamle yolundaki yaratığa bir kez vurmalı: %d" % e.hits)
	assert(e.damage_taken >= expected - 0.01, "Keskin Pençe: hasar x1.3 (%s < %s)" % [e.damage_taken, expected])
	_cleanup()


func test_q_final_kunai_pierce() -> void:
	var p := _make_player()
	p.apply_skill_evolution("assasin_qf", true)
	var o: Vector2 = p.global_position
	## Sağa giden kunainin yolunda arka arkaya iki yaratık (delip geçer), yukarıda biri, menzil dışında biri.
	var a := _enemy(o + Vector2(80.0, 0.0))
	var b := _enemy(o + Vector2(150.0, 0.0))
	var far := _enemy(o + Vector2(600.0, 0.0))
	await get_tree().physics_frame ## yaratık ızgarası bir sonraki fizik karesinde kurulur
	p._assasin_throw_kunai(Vector2.RIGHT)
	var fan: Array = _evo_areas("assasin_kunai")
	assert(fan.size() == 1 and (fan[0]._kunai as Array).size() == 6, "tek yayında 6 kunai")
	for _i in range(60):
		await get_tree().physics_frame
	var per_hit: float = p.damage_bonus * 0.5
	assert(a.hits == 1 and b.hits == 1, "kunai iki yaratığı da delip geçmeli (bir kez): %d / %d" % [a.hits, b.hits])
	assert(a.damage_taken >= per_hit - 0.01, "kunai hasarı saldırı gücünün %%50'si: %s" % a.damage_taken)
	assert(far.hits == 0, "menzil dışındaki yaratığa değmemeli")
	assert(_evo_areas("assasin_kunai").is_empty(), "kunailer menzil sonunda kaybolmalı")
	_cleanup()


# ------------------------------------------------------------------ R

func test_r_cooldown_and_shadow_trail() -> void:
	var p := _make_player()
	var cd0: float = float(p._skill3_timing_for(16)["cooldown"])
	p.apply_skill_evolution("assasin_r2", true)
	assert(is_equal_approx(float(p._skill3_timing_for(16)["cooldown"]), cd0 * 0.75), "Çabuk Gölge: bekleme -%25")
	var o: Vector2 = p.global_position
	var on_line := _enemy(o + Vector2(100.0, 5.0))
	var off_line := _enemy(o + Vector2(100.0, 90.0))
	await get_tree().physics_frame
	p._assasin_spawn_shadow_trail(o, o + Vector2(200.0, 0.0))
	assert(_evo_areas("assasin_trail").is_empty(), "evrimsiz iz yok")
	p.apply_skill_evolution("assasin_rf", true)
	p._assasin_spawn_shadow_trail(o, o + Vector2(200.0, 0.0))
	p._assasin_spawn_shadow_trail(o, o + Vector2(200.0, 0.0)) ## üst üste binen ikinci şerit hasarı katlamamalı
	assert(_evo_areas("assasin_trail").size() == 2, "iki şerit")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1200:
		await get_tree().physics_frame
	## 1 sn'lik şeritte en sık 0.5 sn'de bir: en fazla 2-3 isabet (iki şerit olsa bile).
	assert(on_line.hits >= 2 and on_line.hits <= 3, "ize değen yaratık 0.5 sn aralıkla vurulmalı: %d" % on_line.hits)
	assert(on_line.damage_taken >= p.damage_bonus * 0.8 * on_line.hits - 0.01, "iz hasarı saldırı gücünün %%80'i")
	assert(off_line.hits == 0, "ize değmeyen yaratık vurulmamalı")
	assert(_evo_areas("assasin_trail").is_empty(), "şeritler 1 sn sonra kaybolmalı")
	_cleanup()
