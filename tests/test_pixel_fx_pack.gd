extends Node

## Kullanıcı isteği (2026-09-21) - pixel-art efekt paketi:
##  - Melek bağ dalgası (can/kalkan) pixel dalga; Melek R'si (Kutsal Korku) sarı pixel parıltı, bağlı dostta da
##  - Talon Q (Hamle Vuruşu) ışınlanma DEĞİL atılış + pixel iz; E (Silah Salvosu) zincirli bağ; R (Ayna Formu) alev aurası + %10 boyut
##  - Korsan: pixel bomba/patlama/bombardıman (mermi düşene kadar hasar gelmez)/alan
##  - Matthew Feda Kalkanı tilki kulaklı pixel bariyer
##  - Talon formasyonunda uzak kuklada silahlar yerinden fırlamamalı (geri tepme ofset olarak eklenir)
##  - Vampir E: yaratıkların/duvarların içinden geçer, R yarasaları daha yavaş
## Çizim (_draw) doğrudan çağrılamaz (sadece çizim sırasında geçerli) - o yüzden çizim doğruluğu ekran görüntüleriyle,
## burada yaşam döngüsü + oyun mantığı + senkron sözleşmeleri test edilir.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const TalonMath: GDScript = preload("res://scripts/talon_formation_math.gd")
const KorsanMath: GDScript = preload("res://scripts/korsan_fx_math.gd")
const PixelDraw: GDScript = preload("res://scripts/pixel_draw.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var _body_radius: float = 20.0
	var hits: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)


func _make_player(char_id: int, skill_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = skill_id
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(2000.0, 2000.0)
	player.max_health = 100000.0
	player.health = 100000.0
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE
	player._last_damage_taken_at_msec = -999999
	return player


func _make_enemy(pos: Vector2) -> FakeEnemy:
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


func _count_children_with_script(host: Node, script_suffix: String) -> int:
	var n: int = 0
	for c in host.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with(script_suffix):
			n += 1
	return n


func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


# ------------------------------------------------------------------ ortak yardımcı

func test_pixel_grid_helpers() -> void:
	var snapped: Vector2 = PixelDraw.snap(Vector2(10.3, -7.9))
	assert(absf(fmod(snapped.x / PixelDraw.TEXEL, 1.0)) < 0.001 or absf(fmod(snapped.x / PixelDraw.TEXEL, 1.0)) > 0.999, "x ızgaraya oturmalı")
	assert(PixelDraw.fire_color(0.0).r > 0.9 and PixelDraw.fire_color(1.0).r < 0.6, "ateş rampası sıcaktan soğuğa")
	assert(PixelDraw.hash01(5) == PixelDraw.hash01(5), "hash deterministik")
	var host := Node2D.new()
	add_child(host)
	_spawned.append(host)
	var burst: Node2D = PixelDraw.spawn_burst(host, Vector2(5, 5), "fire", 6, 100.0, 0.2)
	assert(burst != null and burst.get_parent() == host, "pixel burst doğdu")
	_cleanup()


# ------------------------------------------------------------------ Melek

func test_wave_beam_pixel_lifecycle_for_both_themes() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var a := Node2D.new()
	var b := Node2D.new()
	add_child(a)
	add_child(b)
	_spawned.append(a)
	_spawned.append(b)
	b.global_position = Vector2(180, -20)
	for theme in ["heal", "shield"]:
		var beam: Node2D = (load("res://scenes/fx_wave_beam.tscn") as PackedScene).instantiate()
		get_tree().current_scene.add_child(beam)
		beam.setup(a.global_position, b, theme, a)
		assert(beam.fx_type == theme)
		for i in range(60):
			beam._process(0.016)
			if not is_instance_valid(beam) or beam.is_queued_for_deletion():
				break
		assert(not is_instance_valid(beam) or beam.is_queued_for_deletion(), "%s dalgası 0.8sn sonunda kendini siler" % theme)
	_cleanup()


func test_melek_r_spawns_holy_glow_on_self_and_on_linked_ally() -> void:
	var player: Node = _make_player(10, 32)
	var puppet: Node = RemotePlayerScene.instantiate()
	add_child(puppet)
	_spawned.append(puppet)
	puppet.setup(77, 2, "Dost")
	player._oakley_q_ally_target = puppet
	assert(is_equal_approx(player.MELEK_FEAR_RADIUS, 260.0), "korku yarıçapı FX ile aynı tek kaynaktan")
	player._skill_melek_fear()
	assert(_count_children_with_script(player, "fx_melek_holy.gd") == 1, "Melek'in kendi üstünde sarı pixel parıltı")
	assert(_count_children_with_script(puppet, "fx_melek_holy.gd") == 1, "bağlı dostun üstünde de çıkar")
	_cleanup()


# ------------------------------------------------------------------ Matthew

func test_matthew_fox_shield_pops_and_frees() -> void:
	var host := Node2D.new()
	add_child(host)
	_spawned.append(host)
	var shield: Node2D = (load("res://scenes/fx_matthew_fox_shield.tscn") as PackedScene).instantiate()
	host.add_child(shield)
	for i in range(20):
		shield._process(0.016)
	assert(is_instance_valid(shield) and not shield.popping)
	shield.pop()
	for i in range(40):
		shield._process(0.016)
		if shield.is_queued_for_deletion():
			break
	assert(shield.is_queued_for_deletion(), "pop animasyonu bitince silinir")
	_cleanup()


# ------------------------------------------------------------------ Talon

func test_talon_q_is_a_lunge_not_a_teleport_and_hits_when_passing() -> void:
	var player: Node = _make_player(1, 38)
	player.facing = "right"
	var start: Vector2 = player.global_position
	var enemy: FakeEnemy = _make_enemy(start + Vector2(80, 0))
	player.buy_weapon_copy("dagger", 1)
	assert(is_equal_approx(player.TALON_DASH_TIME, TalonMath.DASH_TIME) and TalonMath.DASH_TIME >= 0.25, "atılış süresi paylaşılan sabitten ve ışınlanma gibi kısa değil")
	assert(is_equal_approx(float(player.SKILL_TIMING[38]["duration"]), TalonMath.DASH_TIME), "skill süresi atılışla aynı")
	player._skill_talon_dash()
	assert(player._talon_dashing, "atılış sırasında hareket kilidi")
	assert(_count_children_with_script(player, "fx_talon_dash.gd") == 1, "pixel dash izi FX'i doğdu (diğer oyuncular için de yayınlanan sahne)")
	await _wait(0.06)
	var mid: float = player.global_position.x - start.x
	assert(mid > 5.0 and mid < player.TALON_DASH_DISTANCE - 5.0, "0.06sn'de yolun bir kısmında (ışınlanma değil): %s" % mid)
	await _wait(0.5)
	assert(is_equal_approx(player.global_position.x - start.x, player.TALON_DASH_DISTANCE), "sonunda tam mesafe: %s" % (player.global_position.x - start.x))
	assert(not player._talon_dashing, "kilit kalktı")
	assert(enemy.hits.size() == 1, "yoldaki düşman tam bir kez vurulur: %s" % str(enemy.hits))
	_cleanup()


func test_talon_e_spawns_chain_fx_and_r_grows_character_and_weapons_ten_percent() -> void:
	var player: Node = _make_player(1, 38)
	player.buy_weapon_copy("dagger", 1)
	player.buy_weapon_copy("tabanca", 1)
	player._skill_talon_weapon_salvo()
	assert(_count_children_with_script(player, "fx_talon_chains.gd") == 1, "E'ye basınca zincirli bağ FX'i")
	player._end_talon_weapon_salvo()
	var base_scale: Vector2 = player.char_base_anim_scale
	player._skill_talon_mirror_form()
	assert(_count_children_with_script(player, "fx_talon_form.gd") == 1, "R'de öfke formu aura FX'i")
	assert(player.char_base_anim_scale.is_equal_approx(base_scale * TalonMath.FORM_SCALE_MULT), "karakter %10 büyük")
	assert(player.anim.scale.is_equal_approx(base_scale * TalonMath.FORM_SCALE_MULT))
	player._process_talon_mirror_form(0.016)
	for w in player.owned_weapon_nodes:
		assert(is_equal_approx(w.form_scale_mult, TalonMath.FORM_SCALE_MULT), "silahlar (kopyalar dahil) %10 büyük")
	assert(player.modulate.r > 0.9 and player.modulate.g < 0.8 and player.modulate.b < 0.5, "turuncu-kırmızı ton: %s" % str(player.modulate))
	player._end_talon_mirror_form()
	assert(player.char_base_anim_scale.is_equal_approx(base_scale) and player.anim.scale.is_equal_approx(base_scale), "form bitince orijinal boyut")
	for w in player.owned_weapon_nodes:
		assert(is_equal_approx(w.form_scale_mult, 1.0), "silah boyutu geri döndü")
	_cleanup()


func test_remote_puppet_grows_with_talon_form_and_weapons_do_not_leap_during_formation() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(88, 1, "Talon")
	rp.update_weapon_visuals(["dagger", "tabanca"], {})
	var base: Vector2 = rp._base_anim_scale
	var icon_scale0: Vector2 = rp._weapon_icons[0].scale
	rp.update_extra_state_from_net(100.0, 100.0, 0.0, 0.0, false, false, ["dagger", "tabanca"], {"talon_form": true, "talon_formation": "mirror"})
	assert(rp.anim.scale.is_equal_approx(base * TalonMath.FORM_SCALE_MULT), "kukla %10 büyüdü")
	assert(rp._weapon_icons[0].scale.is_equal_approx(icon_scale0 * TalonMath.FORM_SCALE_MULT), "silah ikonları da (aynı çarpan)")
	## Formasyon sürerken ateş olayı: ikon slot konumuna FIRLAMAZ
	rp._update_talon_formation(0.016)
	var formation_pos: Vector2 = rp._weapon_icons[0].position
	rp._animate_weapon_fire_full({"slot_index": 0, "direction_x": 1.0, "direction_y": 0.0, "is_melee": true, "target_pos_x": 500.0, "target_pos_y": 0.0})
	rp._animate_weapon_recoil(1)
	await get_tree().process_frame
	## (rp kendi fizik karesinde formasyonu yeniden yazar; eski hata ikonu slot konumuna - onlarca px - fırlatıyordu)
	assert(rp._weapon_icons[0].position.distance_to(formation_pos) <= rp.FORMATION_KICK_MAX + 0.01, "ateş animasyonu konumu slota tween'lemez (fırlama yok): %s" % str(rp._weapon_icons[0].position.distance_to(formation_pos)))
	rp._update_talon_formation(0.016)
	assert(rp._weapon_icons[0].position.distance_to(formation_pos) <= rp.FORMATION_KICK_MAX + 0.01, "sadece küçük ofset eklenir: %s" % str(rp._weapon_icons[0].position.distance_to(formation_pos)))
	await _wait(0.3)
	rp._update_talon_formation(0.016)
	assert(rp._weapon_icons[0].position.distance_to(formation_pos) < 0.5, "ofset söner, ikon çember konumunda")
	rp.update_extra_state_from_net(100.0, 100.0, 0.0, 0.0, false, false, ["dagger", "tabanca"], {"talon_form": false})
	assert(rp.anim.scale.is_equal_approx(base) and rp._weapon_icons[0].scale.is_equal_approx(icon_scale0), "form bitince eski boyut")
	_cleanup()


# ------------------------------------------------------------------ Korsan

func test_korsan_bomb_detonation_uses_pixel_explosion_with_the_real_radius() -> void:
	var player: Node = _make_player(9, 18)
	var bomb: Node2D = (load("res://scenes/korsan_bomb.tscn") as PackedScene).instantiate()
	get_tree().current_scene.add_child(bomb)
	_spawned.append(bomb)
	bomb.global_position = Vector2(3000, 3000)
	bomb.radius = 180.0
	var victim: FakeEnemy = _make_enemy(Vector2(3050, 3000))
	var before: int = get_tree().current_scene.get_child_count()
	bomb.detonate()
	assert(victim.hits.size() == 1, "yarıçaptaki düşman vurulur")
	var boom: Node = null
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with("fx_korsan_explosion.gd"):
			boom = c
	assert(boom != null and is_equal_approx(boom.blast_radius, 180.0), "patlama görseli gerçek hasar yarıçapıyla")
	assert(KorsanMath.BOMB_RADIUS == 150.0 and is_equal_approx(player.KORSAN_BOMBARDMENT_RADIUS, KorsanMath.BOMBARDMENT_RADIUS), "paylaşılan sayılar")
	_cleanup()


func test_korsan_strike_falls_then_explodes_and_frees() -> void:
	var strike: Node2D = (load("res://scenes/fx_korsan_strike.tscn") as PackedScene).instantiate()
	get_tree().current_scene.add_child(strike)
	_spawned.append(strike)
	strike.setup(70.0)
	var t: float = 0.0
	while t < KorsanMath.STRIKE_FALL_TIME - 0.05:
		strike._process(0.016)
		t += 0.016
	assert(strike.get_child_count() == 0, "mermi düşerken patlama yok")
	strike._process(0.1)
	assert(strike.get_child_count() == 1 and is_equal_approx(strike.get_child(0).blast_radius, 70.0), "yere inince patlar")
	_cleanup()


func test_korsan_bombardment_damage_lands_when_the_shells_do() -> void:
	var player: Node = _make_player(9, 18)
	var enemy: FakeEnemy = _make_enemy(player.global_position + Vector2(120, 0))
	player._apply_korsan_bombardment_tick()
	assert(enemy.hits.is_empty(), "mermiler düşerken hasar henüz gelmez")
	assert(get_tree().current_scene.get_child_count() > 0)
	await _wait(KorsanMath.STRIKE_FALL_TIME + 0.15)
	assert(enemy.hits.size() == 1 and is_equal_approx(enemy.hits[0], player.damage_bonus * player.KORSAN_BOMBARDMENT_DAMAGE_RATIO), "mermi inince %%150 saldırı gücü: %s" % str(enemy.hits))
	var strikes: int = 0
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with("fx_korsan_strike.gd"):
			strikes += 1
	assert(strikes == KorsanMath.STRIKES_PER_TICK, "tik başına %d mermi görseli: %d" % [KorsanMath.STRIKES_PER_TICK, strikes])
	_cleanup()


func test_korsan_q_detonates_every_bomb_in_a_chain() -> void:
	var player: Node = _make_player(9, 18)
	var bombs: Array = []
	for i in range(3):
		var b: Node2D = (load("res://scenes/korsan_bomb.tscn") as PackedScene).instantiate()
		get_tree().current_scene.add_child(b)
		_spawned.append(b)
		b.global_position = player.global_position + Vector2(60.0 * float(i + 1), 0)
		b.owner_player = player
		player._korsan_bombs.append(b)
		bombs.append(b)
	var victim: FakeEnemy = _make_enemy(player.global_position + Vector2(120, 0))
	player._skill_korsan_detonate_all()
	var delays: Array = player.korsan_chain_delays([60.0, 120.0, 180.0])
	await _wait(float(delays[2]) + 0.2)
	assert(player._korsan_bombs.is_empty(), "liste boşaldı")
	for b in bombs:
		assert(not is_instance_valid(b) or b.is_queued_for_deletion(), "her bomba patladı")
	assert(victim.hits.size() >= 2, "ortadaki düşman birden çok bombanın alanında: %d" % victim.hits.size())
	_cleanup()


## Kullanıcı isteği (2026-09-24): çok sayıda bomba aynı anda patlayıp FPS düşürmesin - yakından uzağa, uzaklıkla
## orantılı ve aralarında boşluk olan bir dalga; aynı yere yığılmışlar da art arda; toplam süre sınırlı.
func test_korsan_chain_delays_spread_near_to_far() -> void:
	var player: Node = _make_player(9, 18)
	var wave: Array = player.korsan_chain_delays([0.0, 325.0, 650.0])
	assert(is_equal_approx(float(wave[0]), 0.0), "ilk bomba hemen: %s" % str(wave))
	assert(is_equal_approx(float(wave[1]), 325.0 / KorsanMath.CHAIN_WAVE_SPEED), "uzaklıkla orantılı: %s" % str(wave))
	assert(is_equal_approx(float(wave[2]), 650.0 / KorsanMath.CHAIN_WAVE_SPEED), "uzaklıkla orantılı: %s" % str(wave))
	var stacked: Array = []
	for i in range(40):
		stacked.append(50.0)
	var d: Array = player.korsan_chain_delays(stacked)
	for i in range(1, d.size()):
		assert(float(d[i]) - float(d[i - 1]) >= KorsanMath.CHAIN_MIN_GAP_FLOOR - 0.0001, "üst üste bombalar da aralıklı: %s" % str(d))
	assert(float(d[d.size() - 1]) <= KorsanMath.CHAIN_MAX_TOTAL + 0.0001, "toplam süre sınırlı: %f" % float(d[d.size() - 1]))
	_cleanup()


func test_korsan_r_spawns_zone_and_pixel_smoke() -> void:
	var player: Node = _make_player(9, 18)
	player._skill_korsan_bombardment()
	assert(_count_children_with_script(player, "fx_korsan_zone.gd") == 1, "alan halkası FX'i (karakterin çocuğu, diğer oyuncularda da aynı sahne)")
	assert(player._korsan_bombardment_active and is_equal_approx(player._korsan_bombardment_channel_timer, KorsanMath.BOMBARDMENT_DURATION))
	_cleanup()


# ------------------------------------------------------------------ Vampir

func test_vampir_e_lets_the_bat_pass_through_enemies_and_bats_fly_slower() -> void:
	var player: Node = _make_player(13, 40)
	player._process_vampir(0.016)
	var enemy: FakeEnemy = _make_enemy(player.global_position + Vector2(10, 0))
	player.velocity = Vector2(200, 0)
	player._block_movement_into_enemies()
	assert(player.velocity.x < 200.0 and not player.is_ghost_now(), "normalken yaratığın içine girilemez (hız kesilir): %s" % str(player.velocity))
	player.velocity = Vector2(200, 0)
	player.health = player.max_health
	player._activate_skill2()
	assert(player.is_ghost_now(), "yarasa formu = içinden geçilebilir")
	player._block_movement_into_enemies()
	assert(is_equal_approx(player.velocity.x, 200.0), "yarasa yaratığın içinden geçer: %s" % str(player.velocity))
	assert(player.VAMPIR_R_BASE_BAT_SPEED <= 200.0, "R yarasaları daha yavaş: %s" % player.VAMPIR_R_BASE_BAT_SPEED)
	assert(enemy != null)
	## Kukla tarafı: host'ta çalışan enemy.gd uzak Vampir'in de içinden geçilebilir sayar
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(66, 13, "Vamp")
	assert(not rp.is_ghost_now())
	rp.update_position_and_anim_from_net(Vector2(10, 10), "bat_left")
	assert(rp.is_ghost_now(), "uzak kukla bat_* animasyonunda geçilebilir")
	_cleanup()
