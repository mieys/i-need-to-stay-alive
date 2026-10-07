extends Node

## Kullanıcı isteği (2026-10-05): kamera sarsıntısı + ayarlardan kapatma. scripts/camera_shake.gd (+ olay bağlantıları, ayar arayüzü).
## Testler gerçek kullanıcı ayarına DOKUNMAZ: güç CameraShake.set_strength_override ile sabitlenir, UISound'un kaydeden setter'ı çağrılmaz.

const ShakeScript: GDScript = preload("res://scripts/camera_shake.gd")
const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const StormScript: GDScript = preload("res://scripts/weather_storm.gd")
const MeteorScript: GDScript = preload("res://scripts/fx_meteor_strike.gd")
const PaladinShatterScript: GDScript = preload("res://scripts/fx_paladin_shatter.gd")
const MatthewExplosionScript: GDScript = preload("res://scripts/fx_matthew_explosion.gd")
const KorsanExplosionScene: PackedScene = preload("res://scenes/fx_korsan_explosion.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


var _made: Array[Node] = []


func _begin() -> void:
	_cleanup()
	ShakeScript.reset()
	ShakeScript.set_strength_override(1.0)


func _cleanup() -> void:
	get_tree().paused = false
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	ShakeScript.reset()
	ShakeScript.set_strength_override(-1.0)


func _camera(pos: Vector2 = Vector2.ZERO, zoom: float = 2.0) -> Camera2D:
	var c := Camera2D.new()
	c.zoom = Vector2(zoom, zoom)
	add_child(c)
	c.global_position = pos
	c.make_current()
	_made.append(c)
	return c


func _driver() -> Node:
	var d := Node.new()
	d.set_script(ShakeScript)
	add_child(d)
	_made.append(d)
	return d


# ---------------------------------------------------------------- saf matematik
func test_falloff_is_one_at_the_centre_and_zero_at_the_radius() -> void:
	assert(is_equal_approx(ShakeScript.falloff(0.0, 1000.0), 1.0))
	assert(is_equal_approx(ShakeScript.falloff(1000.0, 1000.0), 0.0))
	assert(is_equal_approx(ShakeScript.falloff(5000.0, 1000.0), 0.0), "yarıçaptan uzakta 0")
	assert(is_equal_approx(ShakeScript.falloff(500.0, 1000.0), 0.5), "smoothstep ortası 0.5")
	assert(ShakeScript.falloff(200.0, 1000.0) > ShakeScript.falloff(600.0, 1000.0), "uzaklaştıkça azalmalı")
	assert(ShakeScript.falloff(10.0, 0.0) == 0.0, "geçersiz yarıçap çökmemeli")


func test_offset_grows_with_the_square_of_trauma_and_scales_with_strength() -> void:
	var d := Vector2(1, 1)
	assert(ShakeScript.raw_offset(0.0, 1.0, d) == Vector2.ZERO, "travma 0 -> sarsıntı yok")
	assert(ShakeScript.raw_offset(1.0, 1.0, d) == Vector2(ShakeScript.MAX_OFFSET, ShakeScript.MAX_OFFSET), "tam travma = MAX_OFFSET")
	assert(is_equal_approx(ShakeScript.raw_offset(0.5, 1.0, d).x, ShakeScript.MAX_OFFSET * 0.25), "travma 0.5 -> 1/4 genlik")
	assert(ShakeScript.raw_offset(1.0, 0.0, d) == Vector2.ZERO, "güç 0 (ayar kapalı) -> sarsıntı yok")
	assert(is_equal_approx(ShakeScript.raw_offset(1.0, 0.5, d).x, ShakeScript.MAX_OFFSET * 0.5), "güç %50 -> yarı genlik")
	assert(ShakeScript.raw_offset(5.0, 1.0, d).x <= ShakeScript.MAX_OFFSET + 0.001, "travma 1'in üstüne çıkmamalı")


func test_offset_snaps_to_whole_screen_pixels() -> void:
	var o: Vector2 = ShakeScript.snap(Vector2(1.23, -0.77), 2.0) ## zoom 2: 1 ekran px = 0.5 dünya birimi
	assert(is_equal_approx(fmod(absf(o.x), 0.5), 0.0) or is_equal_approx(fmod(absf(o.x), 0.5), 0.5), "x ekran pikseline oturmalı: %s" % str(o))
	assert(is_equal_approx(o.x, 1.0) and is_equal_approx(o.y, -1.0), "1.23 -> 1.0, -0.77 -> -1.0: %s" % str(o))
	assert(ShakeScript.snap(Vector2(0.2, 0.2), 2.0) == Vector2.ZERO, "yarım pikselden küçük titreme sıfırlanır")


# ---------------------------------------------------------------- olay API'si
func test_add_accumulates_caps_at_one_and_does_nothing_when_disabled() -> void:
	_begin()
	ShakeScript.add(0.4)
	assert(is_equal_approx(ShakeScript.trauma, 0.4))
	ShakeScript.add(0.9)
	assert(is_equal_approx(ShakeScript.trauma, 1.0), "travma 1'de kesilmeli")
	ShakeScript.reset()
	ShakeScript.set_strength_override(0.0) ## ayar KAPALI
	ShakeScript.add(0.8)
	assert(ShakeScript.trauma == 0.0, "ayar kapalıyken HİÇBİR şey birikmemeli")
	_cleanup()


func test_add_limited_blocks_repeats_inside_the_interval() -> void:
	_begin()
	ShakeScript.add_limited("t", 0.3, 0.2)
	ShakeScript.add_limited("t", 0.3, 0.2)
	assert(is_equal_approx(ShakeScript.trauma, 0.3), "aralık içinde ikinci olay sayılmamalı: %s" % str(ShakeScript.trauma))
	ShakeScript.add_limited("baska", 0.1, 0.2)
	assert(is_equal_approx(ShakeScript.trauma, 0.4), "farklı anahtar ayrı sayılır")
	await get_tree().create_timer(0.3).timeout
	ShakeScript.add_limited("t", 0.3, 0.2)
	assert(is_equal_approx(ShakeScript.trauma, 0.7), "aralık geçince tekrar sayılmalı: %s" % str(ShakeScript.trauma))
	_cleanup()


func test_add_at_uses_the_distance_to_the_camera() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	ShakeScript.add_at(Vector2.ZERO, 0.5)
	assert(is_equal_approx(ShakeScript.trauma, 0.5), "kamera merkezinde tam güç: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	ShakeScript.add_at(Vector2(650, 0), 0.5)
	assert(is_equal_approx(ShakeScript.trauma, 0.25), "yarım mesafede yarı güç: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	ShakeScript.add_at(Vector2(5000, 0), 0.5)
	assert(ShakeScript.trauma == 0.0, "çok uzaktaki olay sarsmamalı")
	_cleanup()


# ---------------------------------------------------------------- sürücü
func test_driver_shakes_the_camera_then_returns_it_exactly_to_where_it_was() -> void:
	_begin()
	var cam: Camera2D = _camera()
	cam.offset = Vector2(3, 4) ## başka biri de ofset kullanıyor olabilir
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(1.0)
	var moved: bool = false
	for i in range(8):
		drv.call("_process", 0.04)
		if cam.offset != Vector2(3, 4):
			moved = true
		var d: Vector2 = cam.offset - Vector2(3, 4)
		assert(absf(d.x) <= ShakeScript.MAX_OFFSET + 0.001 and absf(d.y) <= ShakeScript.MAX_OFFSET + 0.001, "ofset sınırı aşıldı: %s" % str(d))
		assert(is_equal_approx(fmod(absf(d.x), 0.5), 0.0) or is_equal_approx(fmod(absf(d.x), 0.5), 0.5), "ekran pikseline oturmalı: %s" % str(d))
	assert(moved, "travma varken kamera sarsılmalı")
	drv.call("_process", 3.0) ## travma tamamen söner
	assert(cam.offset == Vector2(3, 4), "sarsıntı bitince kamera TAM eski yerine dönmeli (sürüklenme yok): %s" % str(cam.offset))
	_cleanup()


func test_driver_does_not_overwrite_another_writer_of_the_camera_offset() -> void:
	_begin()
	var cam: Camera2D = _camera()
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(0.8)
	drv.call("_process", 0.04)
	cam.offset += Vector2(10, 0) ## sarsıntı sürerken başka bir sistem ofseti kaydırdı
	drv.call("_process", 3.0)
	assert(is_equal_approx(cam.offset.x, 10.0) and is_equal_approx(cam.offset.y, 0.0), "başkasının ofseti korunmalı: %s" % str(cam.offset))
	_cleanup()


func test_driver_does_nothing_and_clears_trauma_when_the_setting_is_off() -> void:
	_begin()
	var cam: Camera2D = _camera()
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(1.0) ## (ayar kapanmadan önce birikmiş olsa bile)
	ShakeScript.set_strength_override(0.0)
	drv.call("_process", 0.04)
	assert(cam.offset == Vector2.ZERO, "ayar kapalıyken kamera hiç oynamamalı: %s" % str(cam.offset))
	assert(ShakeScript.trauma == 0.0, "kapalıyken travma temizlenir")
	_cleanup()


func test_driver_clears_the_shake_while_the_game_is_paused() -> void:
	_begin()
	var cam: Camera2D = _camera()
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(1.0)
	drv.call("_process", 0.04)
	get_tree().paused = true
	drv.call("_process", 0.04)
	assert(cam.offset == Vector2.ZERO, "oyun duraklayınca (menü/level atlama) ofset sıfırlanmalı: %s" % str(cam.offset))
	assert(ShakeScript.trauma == 0.0)
	_cleanup()


func test_the_offset_is_given_back_when_the_camera_changes() -> void:
	_begin()
	var cam1: Camera2D = _camera(Vector2(0, 0))
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(1.0)
	drv.call("_process", 0.04)
	var cam2: Camera2D = _camera(Vector2(500, 0))
	await get_tree().process_frame
	drv.call("_process", 0.04) ## kamera değişti: eskisinden uygulanan ofset geri alınır
	assert(cam1.offset == Vector2.ZERO, "eski kamera ofseti geri alınmalı: %s" % str(cam1.offset))
	_cleanup()


func test_the_offset_is_removed_when_the_driver_leaves_the_tree() -> void:
	_begin()
	var cam: Camera2D = _camera()
	await get_tree().process_frame
	var drv: Node = _driver()
	ShakeScript.add(1.0)
	drv.call("_process", 0.04)
	drv.free()
	assert(cam.offset == Vector2.ZERO, "sürücü silinince kamera eski yerine dönmeli: %s" % str(cam.offset))
	_cleanup()


# ---------------------------------------------------------------- olay bağlantıları
func _spawner() -> Node:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000
	get_tree().current_scene = self
	_made.append(sp)
	return sp


func test_boss_spawn_and_boss_death_shake_the_camera() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var sp: Node = _spawner()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_made.append(p)
	sp.call("_spawn_boss_group", ["golem3"], 12)
	assert(ShakeScript.trauma > 0.3, "boss doğunca sarsıntı: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	var boss: Node = sp.call("_spawn_creature", "golem3", Vector2.ZERO, 77)
	boss.call("apply_boss_stats", 1000.0, 10.0, 1.7, 12)
	boss.call("die")
	assert(ShakeScript.trauma > 0.5, "boss ölünce kameraya yakınsa güçlü sarsıntı: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	var far: Node = sp.call("_spawn_creature", "golem3", Vector2(9000, 0), 78)
	far.call("apply_boss_stats", 1000.0, 10.0, 1.7, 12)
	far.call("die")
	assert(ShakeScript.trauma == 0.0, "çok uzaktaki boss ölümü sarsmamalı")
	_cleanup()


func test_a_normal_creature_death_does_not_shake() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var sp: Node = _spawner()
	var rat: Node = sp.call("_spawn_creature", "rat1", Vector2.ZERO, 5)
	rat.call("die")
	assert(ShakeScript.trauma == 0.0, "sıradan yaratık ölümü sarsmamalı")
	_cleanup()


func test_lightning_strike_shakes_only_when_near() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var storm: Node = StormScript.new()
	add_child(storm)
	_made.append(storm)
	storm.call("_on_strike_landed", Vector2(100, 0))
	assert(ShakeScript.trauma > 0.3, "yakın yıldırım sarsmalı: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	storm.call("_on_strike_landed", Vector2(8000, 0))
	assert(ShakeScript.trauma == 0.0, "uzak yıldırım sarsmamalı")
	_cleanup()


func test_meteor_explosion_shakes() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	get_tree().current_scene = self
	var m: Node2D = MeteorScript.new()
	add_child(m)
	_made.append(m)
	m.call("setup", Vector2(50, 0))
	m.call("_explode")
	assert(ShakeScript.trauma > 0.3, "meteor patlaması sarsmalı: %s" % str(ShakeScript.trauma))
	_cleanup()


func test_paladin_shatter_and_matthew_explosion_shake() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var a: Node2D = PaladinShatterScript.new()
	add_child(a)
	_made.append(a)
	await get_tree().process_frame ## sarsıntı bir kare sonra (konum add_child'dan sonra verilebilir)
	assert(ShakeScript.trauma > 0.3, "paladin kubbe kırılması sarsmalı: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	var b: Node2D = MatthewExplosionScript.new()
	add_child(b)
	_made.append(b)
	await get_tree().process_frame
	assert(ShakeScript.trauma > 0.3, "Matthew patlaması sarsmalı: %s" % str(ShakeScript.trauma))
	_cleanup()


func test_only_the_big_korsan_explosion_shakes_not_the_bombardment_shells() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var big: Node2D = KorsanExplosionScene.instantiate()
	add_child(big)
	_made.append(big)
	big.call("setup", 150.0)
	await get_tree().process_frame
	assert(ShakeScript.trauma > 0.2, "büyük (bomba) patlaması sarsmalı: %s" % str(ShakeScript.trauma))
	ShakeScript.reset()
	var small: Node2D = KorsanExplosionScene.instantiate()
	add_child(small)
	_made.append(small)
	small.call("setup", 68.0)
	await get_tree().process_frame
	assert(ShakeScript.trauma == 0.0, "Bombardıman mermisi (saniyede 3 patlama) sarsmamalı")
	_cleanup()


func test_player_heavy_hit_shakes_but_a_light_hit_does_not() -> void:
	_begin()
	_camera(Vector2.ZERO)
	await get_tree().process_frame
	var pl: Node = PlayerScene.instantiate()
	add_child(pl)
	_made.append(pl)
	await get_tree().process_frame
	pl.set("max_health", 100.0)
	pl.set("health", 100.0)
	pl.call("take_damage", 2.0, null)
	assert(ShakeScript.trauma == 0.0, "hafif vuruş sarsmamalı: %s" % str(ShakeScript.trauma))
	await get_tree().create_timer(0.5).timeout ## temas kilidi (iframe) geçsin
	pl.call("take_damage", 30.0, null)
	assert(ShakeScript.trauma >= 0.25, "ağır vuruş (maks canın %30'u) sarsmalı: %s" % str(ShakeScript.trauma))
	_cleanup()


# ---------------------------------------------------------------- ayar arayüzü (kaydetmeden)
func test_main_menu_settings_has_the_shake_slider_and_shows_off_at_zero() -> void:
	var original: float = UISound.camera_shake_percent
	UISound.camera_shake_percent = 0.0 ## doğrudan atama: dosyaya yazmaz
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	_made.append(menu)
	await get_tree().process_frame
	var slider: HSlider = menu.find_child("ShakeSlider", true, false)
	assert(slider != null, "ana menü ayarlarında 'Ekran Sarsıntısı' kaydırıcısı olmalı")
	assert(slider.min_value == 0.0 and slider.max_value == 100.0, "0-100 aralığı (0 = kapalı)")
	assert(slider.value == 0.0, "kayıtlı değer kaydırıcıya yansımalı")
	var texts: Array = []
	for l in menu.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert(texts.has("Kapalı"), "0'da değer 'Kapalı' yazmalı: %s" % str(texts))
	assert(texts.has("Ekran Sarsıntısı"), "satır etiketi")
	UISound.camera_shake_percent = original
	_cleanup()


func test_pause_menu_settings_has_the_shake_slider() -> void:
	var original: float = UISound.camera_shake_percent
	UISound.camera_shake_percent = 40.0
	var menu: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	_made.append(menu)
	await get_tree().process_frame
	var slider: HSlider = menu.find_child("ShakeSlider", true, false)
	assert(slider != null and is_equal_approx(slider.value, 40.0), "duraklatma menüsü ayarlarında kaydırıcı ve değeri")
	var value_lbl: Label = menu.find_child("ShakeValue", true, false)
	assert(value_lbl != null and value_lbl.text == "40%", "değer etiketi: %s" % (value_lbl.text if value_lbl else "yok"))
	UISound.camera_shake_percent = original
	_cleanup()
