extends SceneTree

## GÖLGE AÇIK / KAPALI örnekleri (2026-11-08, oyuna bağlı DEĞİL). Kullanıcı: "oyundaki gölgeler kapalıyken ve açıkken nasıl
## göründüğünü gösteren örnekler hazırlar mısın".
## Gerçek Main + gerçek çizici, gizli masaüstü (golge_run.ps1). Her noktada aynı anda (art arda karelerde) 4 hâl:
##   1_hepsi_acik   : bugünkü Yüksek ayarı (bulut gölgesi + harita gölgeleri + ayak gölgeleri)
##   2_bulut_kapali : Ayarlar > Grafik > "Güneş Işığı / Bulut Gölgesi" kapalı (= Orta / Düşük kalite)
##   3_harita_kapali: + pişmiş harita gölgeleri (Harita/Gölgeler) gizli - ayarı YOK, yalnız görmek için
##   4_hic_golge    : + karakter ayak gölgesi / obje gölgesi (ground_shadow.gd, drop_shadow.gd) gizli - ayarı YOK
## Yaratık gölgeleri sprite'larına gömülü (With_shadow sayfaları): hiçbir hâlde kapanmaz.
## Bulut gölgesi seyrek (kaplama %40): bulut kadraja düşmezse SunClouds._drift kaydırılır (değişen piksel oranı 0,2-0,8).
## Çıktı: out/<nokta>_<hal>.png (ekranın ortası CROP) -> python -I golge_sayfa.py

const OUT := "res://tools/proto_20261108/golge/out/"
const CROP := Vector2i(1200, 675)
const STATES := ["1_hepsi_acik", "2_bulut_kapali", "3_harita_kapali", "4_hic_golge"]
## Harita gölge dokusunda ağaç gölgesi yoğun pencereler (harita_golgeleri.png taraması) + göl kıyısı; "ev" = evden çıkış noktası.
const SPOTS := {
	"ev": Vector2.ZERO,
	"kuzey_agaclar": Vector2(1470, 680),
	"orta_orman": Vector2(2470, 850),
	"gol": Vector2(1760, 1966),
}

var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _ui: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_frame() -> void:
	paused = false
	if _player != null and is_instance_valid(_player):
		_player.set("xp_to_next_level", 1.0e12)
	if _gm != null:
		_gm.set("team_xp_needed", 1.0e12)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var sz: Vector2i = img.get_size()
	var c := Vector2i((sz.x - CROP.x) / 2, (sz.y - CROP.y) / 2)
	return img.get_region(Rect2i(c, CROP))


## Küçültülmüş iki görüntüde belirgin farklı piksel oranı (bulut kadrajda mı).
func _diff_ratio(a: Image, b: Image) -> float:
	var sa: Image = a.duplicate()
	var sb: Image = b.duplicate()
	sa.resize(150, 84, Image.INTERPOLATE_BILINEAR)
	sb.resize(150, 84, Image.INTERPOLATE_BILINEAR)
	var n: int = 0
	for y in 84:
		for x in 150:
			var ca: Color = sa.get_pixel(x, y)
			var cb: Color = sb.get_pixel(x, y)
			if absf(ca.v - cb.v) > 0.02:
				n += 1
	return float(n) / float(150 * 84)


func _set_foot_shadows(on: bool) -> void:
	var stack: Array = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var sc: Variant = n.get_script()
		if sc != null:
			var p: String = str((sc as Script).resource_path)
			if p.ends_with("ground_shadow.gd") or p.ends_with("drop_shadow.gd"):
				(n as CanvasItem).visible = on
		for c in n.get_children():
			stack.append(c)


func _apply(state: int) -> void:
	_ui.set("gfx_sun_clouds", state == 0)
	## Ayar kapanınca SunClouds gücü anında 0'a iner, açılınca 0,5/sn ile dolar - örnekte tam gündüz gücü hemen geri gelsin.
	var clouds: Node = _main.get_node_or_null("SunClouds")
	if clouds != null and state == 0:
		clouds.set("_cloud_k", 1.0)
	var sh: CanvasItem = _main.get_node_or_null("Harita/Gölgeler") as CanvasItem
	if sh:
		sh.visible = state < 2
	_set_foot_shadows(state < 3)


func _boot() -> bool:
	_gm = root.get_node("GameManager")
	_ui = root.get_node("UISound")
	_ui.set("show_fps", false)
	_ui.call("set_gfx_preset", 2) ## Yüksek: bulut açık, zemin ayrıntısı açık, çözünürlük %100
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var char_id: int = int(OS.get_environment("GOLGE_CHAR")) if OS.get_environment("GOLGE_CHAR") != "" else 2
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_start_weapon", "uzunkilic")
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt (Ruh Kıymığı/rekor) yazılmasın
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	_player = _main.get_node_or_null("Player") as Node2D
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	process_frame.connect(_on_frame)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0) ## gündüz, açık hava
		atmo.call("debug_set_weather", 0)
	await _wait(3.0) ## bulut gücü 0,5/sn ile dolar
	return _player != null


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not await _boot():
		print("GOLGE boot basarisiz")
		quit(1)
		return
	var clouds: Node = _main.get_node_or_null("SunClouds")
	var ev_pos: Vector2 = _player.global_position
	## GOLGE_VERIFY=1 (madde 469 doğrulaması): hiçbir şeye dokunmadan oyunun bugünkü hâli -> <nokta>_5_simdi.png
	if OS.get_environment("GOLGE_VERIFY") == "1":
		for spot: String in SPOTS:
			_player.global_position = ev_pos if spot == "ev" else SPOTS[spot]
			await _wait(1.5)
			var img: Image = await _grab()
			img.save_png(ProjectSettings.globalize_path(OUT + "%s_5_simdi.png" % spot))
			print("GOLGE dogrulama ", spot, " harita_golgesi_dugumu=", _main.get_node_or_null("Harita/Gölgeler") != null,
					" bulut_gorunur=", clouds != null and (clouds.get_node("GunesBulut") as CanvasItem).visible)
		print("GOLGE bitti")
		quit()
		return
	for spot: String in SPOTS:
		var pos: Vector2 = ev_pos if spot == "ev" else SPOTS[spot]
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				e.queue_free()
		_player.global_position = pos
		_player.set("velocity", Vector2.ZERO)
		await _wait(1.5)
		## Bulut kadraja düşsün: hepsi açık / bulut kapalı farkına bak, gerekirse sürüklenmeyi kaydır.
		var tries: int = 0
		while clouds != null and tries < 10:
			_apply(0)
			await _frames(3)
			var a: Image = await _grab()
			_apply(1)
			await _frames(3)
			var b: Image = await _grab()
			var r: float = _diff_ratio(a, b)
			print("GOLGE %s bulut orani %.2f" % [spot, r])
			if r > 0.2 and r < 0.8:
				break
			clouds.set("_drift", (clouds.get("_drift") as Vector2) + Vector2(437.0, 263.0))
			tries += 1
		for i in STATES.size():
			_apply(i)
			await _frames(3)
			var img: Image = await _grab()
			img.save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [spot, STATES[i]]))
		_apply(0)
		print("GOLGE yazildi ", spot)
	print("GOLGE bitti")
	quit()
