extends Node

## Shaman R - Elemental Golem (kullanıcı isteği 2026-09-30): 20 sn dev golem formu, otomatik alan darbeleri (%120 AP, kritik
## vurabilir, yakın mesafe), formda Q = Sarsıcı Darbe (1 sn sersemletme, %250 AP, 3 sn) ve E = Golem Sıçrayışı (ileri atlar,
## inişte çeker, %150 AP, 8 sn). Pixel golem: idle/walk/slam/jump x 4 yön (tools/gen_shaman_golem.py).
## Bu test çoğunlukla SÖZLEŞMELERİ doğrular: tek kaynak sayılar, klip adları/kare sayıları (uzak oyuncular klip ADINI görür -
## CLAUDE.md madde 4), efekt sahneleri, HUD form hâli, ağ tarafının aynı kuralı kullandığı.

const GolemMath := preload("res://scripts/shaman_golem_math.gd")
const FRAMES_PATH := "res://assets/characters/shaman_frames.tres"
const PLAYER_PATH := "res://scripts/player.gd"
const REMOTE_PATH := "res://scripts/remote_player.gd"


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var idx: int = line.find("#")
		out.append(line.substr(0, idx) if idx != -1 else line)
	return "\n".join(out)


func test_character_def_has_golem_r_and_form_skills() -> void:
	var def: Dictionary = Characters.DEFS[GolemMath.CHAR_ID]
	assert(int(def.get("skill3", 0)) == GolemMath.R_SKILL_ID, "Shaman R = Elemental Golem")
	for key in ["skill3_icon", "golem_skill_icon", "golem_skill2_icon"]:
		var tex: Texture2D = load(str(def[key]))
		assert(tex != null, "%s yüklenebilmeli" % key)
		assert(tex.get_width() == 144 and tex.get_height() == 144, "%s 48x48 x3 olmalı" % key)
	for key in ["golem_skill_name", "golem_skill_desc", "golem_skill2_name", "golem_skill2_desc"]:
		assert(str(def.get(key, "")) != "", "%s dolu olmalı" % key)
	assert(str(def["golem_skill_desc"]).contains("%250") and str(def["golem_skill_desc"]).contains("3sn"), "Q metni")
	assert(str(def["golem_skill2_desc"]).contains("%150") and str(def["golem_skill2_desc"]).contains("8sn"), "E metni")
	assert(str(def["skill3_desc"]).contains("%120"), "R metni")


func test_numbers_match_request() -> void:
	assert(GolemMath.DURATION == 20.0)
	assert(GolemMath.AUTO_DAMAGE_RATIO == 1.2)
	assert(GolemMath.Q_DAMAGE_RATIO == 2.5 and GolemMath.Q_STUN_TIME == 1.0 and GolemMath.Q_COOLDOWN == 3.0)
	assert(GolemMath.E_DAMAGE_RATIO == 1.5 and GolemMath.E_COOLDOWN == 8.0)
	var timing: Dictionary = (load(PLAYER_PATH) as GDScript).get_script_constant_map()["SKILL3_TIMING"]
	assert(timing.has(GolemMath.R_SKILL_ID), "SKILL3_TIMING'de golem kaydı olmalı")
	assert(float(timing[GolemMath.R_SKILL_ID]["duration"]) == GolemMath.DURATION)


## Sprite sözleşmesi: her klip 4 yönde, doğru kare sayısıyla; kareler 96x144 (ayak satırı hücre merkezinin 16 px altı -
## insan formunun 48x48 kareleriyle aynı göreli konum). slam2 = slam'in AYNI kareleri (ağda klip adı değişsin diye).
func test_frames_have_all_golem_clips() -> void:
	var frames: SpriteFrames = load(FRAMES_PATH)
	assert(frames != null, "shaman_frames.tres yüklenebilmeli (golem_sheet.png import edilmiş olmalı)")
	var counts := {GolemMath.IDLE: 4, GolemMath.WALK: 6, GolemMath.SLAM: GolemMath.SLAM_FRAMES, GolemMath.SLAM_ALT: GolemMath.SLAM_FRAMES,
		GolemMath.JUMP: GolemMath.JUMP_FRAME_DURATIONS.size()}
	for prefix: String in counts:
		for d in ["down", "left", "right", "up"]:
			var clip: String = prefix + d
			assert(frames.has_animation(clip), "%s klibi olmalı" % clip)
			assert(frames.get_frame_count(clip) == int(counts[prefix]), "%s kare sayısı" % clip)
			var tex: Texture2D = frames.get_frame_texture(clip, 0)
			assert(tex.get_width() == 96 and tex.get_height() == 144, "%s kareleri 96x144 olmalı" % clip)
	assert(frames.get_animation_loop(GolemMath.IDLE + "down") and frames.get_animation_loop(GolemMath.WALK + "down"))
	assert(not frames.get_animation_loop(GolemMath.SLAM + "down") and not frames.get_animation_loop(GolemMath.JUMP + "down"))
	assert(is_equal_approx(frames.get_animation_speed(GolemMath.SLAM + "down"), GolemMath.SLAM_FPS))
	assert(is_equal_approx(frames.get_animation_speed(GolemMath.JUMP + "down"), GolemMath.JUMP_FPS))
	for i in range(GolemMath.JUMP_FRAME_DURATIONS.size()):
		assert(is_equal_approx(frames.get_frame_duration(GolemMath.JUMP + "left", i), GolemMath.JUMP_FRAME_DURATIONS[i]),
			"sıçrayış kare süreleri shaman_golem_math.gd ile aynı olmalı")
		if i < GolemMath.SLAM_FRAMES:
			assert(frames.get_frame_texture(GolemMath.SLAM + "up", i) == frames.get_frame_texture(GolemMath.SLAM_ALT + "up", i))
	## İnsan klipleri bozulmamış olmalı
	for clip in ["idle_down", "walk_left", "shrug_up", "death_right", "downed_down"]:
		assert(frames.has_animation(clip), "%s korunmalı" % clip)


func test_math_helpers() -> void:
	assert(GolemMath.is_golem_anim("golem_idle_down") and not GolemMath.is_golem_anim("idle_down"))
	assert(GolemMath.is_golem_action_anim("golem_slam2_left") and GolemMath.is_golem_action_anim("golem_jump_up"))
	assert(not GolemMath.is_golem_action_anim("golem_walk_up"))
	assert(_char_anim().is_action_anim("golem_slam_down") and _char_anim().is_action_anim("golem_jump_left"))
	var land: float = GolemMath.jump_time_to_frame(GolemMath.JUMP_LAND_FRAME)
	assert(land > GolemMath.jump_time_to_frame(GolemMath.JUMP_TAKEOFF_FRAME) and land < GolemMath.jump_total_time())
	assert(absf(land - 0.41) < 0.02, "iniş ~0.41 sn (sesteki iniş gümlemesi de orada - gen_skill_sounds.py)")
	assert(GolemMath.slam_impact_time() < GolemMath.slam_total_time())
	assert(GolemMath.shadow_scale_for("idle_down", 0) == Vector2.ONE)
	assert(GolemMath.shadow_scale_for("golem_idle_down", 0).x > 1.5)
	assert(GolemMath.shadow_scale_for("golem_jump_down", 3).x < GolemMath.shadow_scale_for("golem_jump_down", 0).x,
		"havadayken gölge küçülmeli")


func _char_anim() -> GDScript:
	return load("res://scripts/char_anim.gd") as GDScript


func test_fx_scenes() -> void:
	for kind in ["slam", "quake", "land", "transform"]:
		var path: String = "res://scenes/fx_shaman_golem_%s.tscn" % kind
		var packed: PackedScene = load(path)
		assert(packed != null, "%s yüklenebilmeli" % path)
		var fx: AnimatedSprite2D = packed.instantiate() as AnimatedSprite2D
		assert(fx != null and fx.sprite_frames != null and fx.sprite_frames.has_animation(&"play"), path)
		assert(not fx.sprite_frames.get_animation_loop(&"play"), "%s tek seferlik olmalı" % path)
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		assert(is_equal_approx(fx.scale.x, 1.212), "%s karakterin piksel boyunda (TEXEL) olmalı" % path)
		assert(bool(fx.get("on_ground")) == (kind != "transform"), "%s zemin efekti mi" % path)
		fx.free()


func test_sounds_exist_and_are_registered() -> void:
	var sfx: Dictionary = (load(PLAYER_PATH) as GDScript).get_script_constant_map()["SKILL_SFX"]
	for key in ["shaman_golem_form", "shaman_golem_slam", "shaman_golem_quake", "shaman_golem_leap"]:
		assert(sfx.has(key), "SKILL_SFX[%s]" % key)
		assert(load("res://assets/audio/skills/%s.wav" % key) is AudioStream, "%s.wav" % key)


## player.gd bağlantıları: R dispatch/bitiş, Q/E bypass dalları, yere düşme, silah çekilmesi, sıçrayışta hareket kilidi.
func test_player_wiring() -> void:
	var src: String = _strip_comments(_read(PLAYER_PATH))
	assert(src.contains("49: _skill_shaman_golem()"), "_activate_skill3 match")
	assert(src.contains("if _shaman_golem_active:\n\t\t\t_shaman_golem_try_q()"), "Q girişi golem formunda Sarsıcı Darbe")
	assert(src.contains("if _shaman_golem_active:\n\t\t\t_shaman_golem_try_e()"), "E girişi golem formunda Golem Sıçrayışı")
	assert(src.contains("_shaman_golem_on_go_down()"), "yere düşünce form biter")
	assert(src.contains("or _shaman_golem_active"), "silahlar golem formunda da çekilir (_vampir_weapons_absorbed)")
	assert(src.contains("or _shaman_golem_jumping:"), "sıçrayışta hareket kilitli")
	assert(src.contains("func get_hud_skill_override("), "HUD form hâli")
	assert(src.contains("e.apply_stun(stun)") and src.contains("e.apply_skill_push(center - epos, d - pull_keep)"))
	assert(src.contains("_roll_ability_crit()"), "darbeler kritik vurabilir")


## Uzak kukla aynı kuralı klip adından çıkarır (yeni ağ alanı yok) - CLAUDE.md hata sınıfı.
func test_remote_uses_same_rules() -> void:
	var src: String = _strip_comments(_read(REMOTE_PATH))
	assert(src.contains("_shaman_golem_form = ShamanGolemMath.is_golem_anim(cur_anim)"))
	assert(src.contains("_shaman_golem_jumping = ShamanGolemMath.is_jump_anim(cur_anim)"))
	assert(src.contains("ShamanGolemMath.apply_overhead_lift(self"))
	assert(src.contains("or _shaman_golem_form"), "uzak kuklada da silahlar çekilir")
	assert(src.contains("or _shaman_golem_jumping"), "uzak kukla sıçrayışta içinden geçilebilir")
	assert(_read("res://scripts/ground_shadow.gd").contains("ShamanGolemMath.shadow_scale_for("), "gölge iki tarafta aynı")
	## Uzak ekranda Q/E/R efektleri: sahne yolu "hitscan_impact" ile gider - network_manager o dalı sahne yolundan kurar.
	assert(_read(PLAYER_PATH).contains('"hitscan_impact", pos, {"scene_path": path}'))


func test_hud_override_is_applied_and_restored() -> void:
	var src: String = _read("res://scripts/hud.gd")
	assert(src.contains("func _apply_hud_skill_override("))
	assert(src.contains('_apply_hud_skill_override(skill_icon, q_override, "skill")'))
	assert(src.contains('_apply_hud_skill_override(skill2_icon, e_override, "skill2")'))
	assert(_read("res://scripts/skill_icon.gd").contains("var cooldown_override: float = -1.0"))



# ------------------------------------------------------------------ oynanış (canlı oyuncu + sahte yaratıklar)
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var hits: Array = []
	var stuns: Array = []
	var pushes: Array = [] ## [yön, mesafe]

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)

	func apply_stun(duration: float) -> void:
		stuns.append(duration)

	func apply_skill_push(dir: Vector2, distance: float) -> void:
		pushes.append([dir, distance])


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = GolemMath.CHAR_ID
	GameManager.selected_character = 27
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -player.ABILITY_BASE_CRIT_CHANCE ## kritik yok: hasar sayıları tam
	player.facing = "right"
	return player


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _step(player: Node, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		player._process_shaman_golem(0.02)
		t += 0.02


func test_form_start_and_end_swap_clips_and_weapons() -> void:
	var p: Node = _make_player()
	p._skill_shaman_golem()
	assert(p._shaman_golem_active, "form açık")
	assert(str(p.anim.animation).begins_with(GolemMath.IDLE), "golem bekleme klibi: %s" % str(p.anim.animation))
	assert(p._vampir_weapons_absorbed(), "silahlar gövdeye çekilir")
	p._update_animation(true)
	assert(str(p.anim.animation) == GolemMath.WALK + "right", "yürürken golem yürüme klibi: %s" % str(p.anim.animation))
	p._play_action_anim("hurt_right")
	assert(str(p.anim.animation) == GolemMath.WALK + "right", "formda insan hasar klibi oynamaz")
	p._end_shaman_golem()
	assert(not p._shaman_golem_active and not p._vampir_weapons_absorbed())
	assert(not GolemMath.is_golem_anim(str(p.anim.animation)), "form bitince insan klibi: %s" % str(p.anim.animation))
	_cleanup()


func test_auto_slam_hits_only_nearby_enemies_for_120_percent() -> void:
	var p: Node = _make_player()
	var near: FakeEnemy = _make_enemy(Vector2(1040.0, 1000.0))
	var far: FakeEnemy = _make_enemy(Vector2(1000.0 + GolemMath.AUTO_RADIUS + 60.0, 1000.0))
	p._skill_shaman_golem()
	_step(p, 0.9)
	assert(near.hits.size() >= 1, "yakındaki yaratık darbe yedi")
	assert(near.hits.size() >= 1 and is_equal_approx(float(near.hits[0]), 100.0 * GolemMath.AUTO_DAMAGE_RATIO), "darbe AP x1.2: " + str(near.hits))
	assert(far.hits.is_empty(), "uzaktaki yaratığa değmez (yakın mesafe)")
	assert(near.stuns.is_empty(), "otomatik darbe sersemletmez")
	assert(GolemMath.is_slam_anim(str(p.anim.animation)), "darbe klibi oynadı: " + str(p.anim.animation))
	_cleanup()


func test_no_enemy_no_slam() -> void:
	var p: Node = _make_player()
	var far: FakeEnemy = _make_enemy(Vector2(1400.0, 1000.0))
	p._skill_shaman_golem()
	_step(p, 1.5)
	assert(far.hits.is_empty() and p._golem_pending_kind == "", "yakında yaratık yoksa darbe inmez")
	_cleanup()


func test_q_quake_stuns_and_deals_250_percent_with_3s_cooldown() -> void:
	var p: Node = _make_player()
	var e: FakeEnemy = _make_enemy(Vector2(1000.0 + GolemMath.Q_RADIUS - 10.0, 1000.0))
	p._skill_shaman_golem()
	p._shaman_golem_try_q()
	assert(p._golem_q_cd > 2.9, "Q bekleme süresine girdi")
	var ov: Dictionary = p.get_hud_skill_override("skill")
	assert(str(ov.get("name", "")) == "Sarsıcı Darbe" and float(ov.get("progress", 1.0)) < 0.05, "HUD Q form hâli: " + str(ov))
	_step(p, 0.3)
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0]), 100.0 * GolemMath.Q_DAMAGE_RATIO), "Q AP x2.5: " + str(e.hits))
	assert(e.stuns == [GolemMath.Q_STUN_TIME], "Q 1 sn sersemletir: " + str(e.stuns))
	p._shaman_golem_try_q()
	_step(p, 0.3)
	assert(e.stuns.size() == 1, "bekleme süresindeyken Q tekrar çalışmaz")
	_step(p, 3.0)
	assert(p._golem_q_cd == 0.0 and float(p.get_hud_skill_override("skill").get("progress", 0.0)) == 1.0, "3 sn sonra hazır")
	_cleanup()


func test_e_jump_lands_forward_pulls_and_deals_150_percent() -> void:
	var p: Node = _make_player()
	p._skill_shaman_golem()
	var start: Vector2 = p.global_position
	var end: Vector2 = p._golem_safe_jump_end(start, Vector2.RIGHT)
	assert(end.distance_to(start + Vector2.RIGHT * GolemMath.E_DISTANCE) < 0.5, "haritasız ortamda tam mesafe: " + str(end))
	var e: FakeEnemy = _make_enemy(end + Vector2(60.0, 0.0))
	var out: FakeEnemy = _make_enemy(end + Vector2(GolemMath.E_RADIUS + 30.0, 0.0))
	p._shaman_golem_try_e()
	assert(p._shaman_golem_jumping and p.is_ghost_now(), "havadayken içinden geçilir")
	assert(str(p.anim.animation) == GolemMath.JUMP + "right", "sıçrayış klibi: " + str(p.anim.animation))
	assert(p._golem_e_cd > 7.9, "E bekleme süresine girdi")
	## Tween'i beklemeden: yolun sonu + iniş (zamanlama shaman_golem_math.gd'den - kare süreleriyle aynı)
	p._golem_jump_step(1.0, start, end)
	p._shaman_golem_land()
	assert(p.global_position.distance_to(end) < 0.5)
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0]), 100.0 * GolemMath.E_DAMAGE_RATIO), "E AP x1.5: " + str(e.hits))
	assert(e.pushes.size() == 1, "iniş noktasına çekildi")
	if e.pushes.size() == 1:
		var push_dir: Vector2 = e.pushes[0][0]
		assert(push_dir.normalized().dot(Vector2.LEFT) > 0.99 and absf(float(e.pushes[0][1]) - (60.0 - GolemMath.E_PULL_KEEP)) < 0.5,
			"merkeze doğru, E_PULL_KEEP kadar yakına: " + str(e.pushes))
	assert(out.hits.is_empty() and out.pushes.is_empty(), "alan dışı etkilenmez")
	p._shaman_golem_jump_done()
	assert(not p._shaman_golem_jumping and not p.is_ghost_now())
	_cleanup()


func test_downed_ends_form_and_starts_r_cooldown() -> void:
	var p: Node = _make_player()
	p._skill_shaman_golem()
	p.skill3_state = "active"
	p._skill3_cooldown = GolemMath.COOLDOWN
	p._shaman_golem_on_go_down()
	assert(not p._shaman_golem_active, "yere düşünce form biter")
	assert(p.skill3_state == "cooldown" and is_equal_approx(p.skill3_timer, GolemMath.COOLDOWN), "R bekleme süresine girer")
	assert(p.get_hud_skill_override("skill").is_empty(), "HUD Q normal hâline döner")
	_cleanup()


func test_remote_puppet_follows_golem_clip_names() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(98, GolemMath.CHAR_ID, "Shaman")
	var bar: Node = rp.get_node("OverheadBar")
	var base_bar: float = float(bar.y_offset)
	rp.update_position_and_anim_from_net(Vector2(500, 500), GolemMath.IDLE + "down")
	assert(str(rp.anim.animation) == GolemMath.IDLE + "down", "kukla golem klibini oynar: " + str(rp.anim.animation))
	assert(rp._shaman_golem_form and not rp.is_ghost_now())
	assert(float(bar.y_offset) < base_bar - 10.0, "can çubuğu golemin üstüne çıkar")
	for i in range(40):
		rp._process_vampir_remote(0.016)
	assert(is_equal_approx(rp._vampir_pull, 1.0), "kuklanın silahları da çekildi")
	rp.update_position_and_anim_from_net(Vector2(520, 500), GolemMath.JUMP + "down")
	assert(rp.is_ghost_now(), "sıçrayışta yaratıklar içinden geçer")
	rp.update_position_and_anim_from_net(Vector2(520, 500), GolemMath.SLAM + "down")
	rp.update_position_and_anim_from_net(Vector2(520, 500), GolemMath.SLAM_ALT + "down")
	assert(str(rp.anim.animation) == GolemMath.SLAM_ALT + "down" and rp.anim.frame == 0, "ardışık darbe baştan oynar")
	rp.update_position_and_anim_from_net(Vector2(520, 500), "idle_down")
	assert(not rp._shaman_golem_form and is_equal_approx(float(bar.y_offset), base_bar), "form bitince her şey geri")
	_cleanup()



## Kullanıcı isteği (2026-09-30): "shaman ulti formundayken %40 hasar azaltma kazansın ve yetenekleri kalkan tüketmesin".
func _hit(p: Node, amount: float) -> float:
	p._last_damage_taken_at_msec = -999999 ## temas i-frame'i testte engellemesin
	var before: float = p.health
	p.take_damage(amount, null)
	return before - p.health


func test_form_takes_40_percent_less_damage() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 0.0
	p.item_shield_hp = 0.0
	p.max_health = 10000.0
	p.health = 10000.0
	var normal: float = _hit(p, 100.0)
	assert(normal > 0.0, "formsuz hasar işlendi: %s" % str(normal))
	p._skill_shaman_golem()
	var golem: float = _hit(p, 100.0)
	assert(is_equal_approx(golem, normal * GolemMath.DAMAGE_TAKEN_MULT), "formda %%40 az hasar: %s vs %s" % [str(golem), str(normal)])
	assert(is_equal_approx(GolemMath.DAMAGE_TAKEN_MULT, 0.6))
	var fx: Array = p.get_status_effects()
	var has_badge: bool = false
	for e in fx:
		if str(e.get("kind", "")) == "golem":
			has_badge = true
	assert(has_badge, "buff satırında golem rozeti")
	p._end_shaman_golem()
	assert(is_equal_approx(_hit(p, 100.0), normal), "form bitince azaltma kalkar")
	_cleanup()


func test_form_skills_cost_no_shield() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	p._skill_shaman_golem()
	p._shaman_golem_try_q()
	_step(p, 0.4)
	p._shaman_golem_try_e()
	p._shaman_golem_stop_jump()
	assert(p._golem_q_cd > 0.0 and p._golem_e_cd > 0.0, "ikisi de kullanıldı")
	assert(is_equal_approx(p.item_shield_hp, 1000.0), "formdaki Q/E kalkan harcamaz: %s" % str(p.item_shield_hp))
	_cleanup()
