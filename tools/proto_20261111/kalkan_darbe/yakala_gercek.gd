extends SceneTree

## KALKAN DARBE PROTOTİPİ - GERÇEK HEDEFTEN hasar (oyuna bağlı DEĞİL). Kullanıcı (2026-11-11): "gerçek bir hedeften hasar
## alırkenki hallerini gösterir misin". Gerçek Main (buyuk_test.gd _boot yolu: evden çıkış, gündüz, açık hava), oyuncu
## silahsız ve yerinde, çevresine EnemySpawner.debug_spawn_creature ile gerçek yaratıklar (yakın dövüş + kemik atan iskelet)
## doğar ve gerçekten saldırır (temas / atılış / mermi -> player.take_damage). Her karede kalkan + can doldurulur (kırılma /
## yenilenme baloncuğu karışmasın, ölmesin). Seçenekler aynı oturumda sırayla: bugünkü efekt yerine hit_variant.gd takılır,
## yaratıklar temizlenip AYNI tohumla yeniden doğar. KD_DIR/<seçenek>/f_###.png (15 fps, --fixed-fps 30 ile her 2. kare).
## Kullanım: yakala_gercek.ps1 (gizli masaüstü, APPDATA yalıtılı).

const SPAWN_FRAMES := 30 ## doğuştan sonra çekim öncesi (yaratıklar yaklaşsın)
const REC_FRAMES_DEFAULT := 180 ## 6 sn (KD_REC ile değişir)
const CROP := Vector2i(400, 300)
const ROSTER_DEFAULT := "zombie1,ork1,iskelet2,zombie2,slime2"
const TIER := 2

var _dir: String = OS.get_environment("KD_DIR")
var _shield_type: String = OS.get_environment("KD_SHIELD")
var _variants: PackedStringArray = (OS.get_environment("KD_VARIANTS") if OS.get_environment("KD_VARIANTS") != "" else "suan,a,b,c,d").split(",")
## KD_ROSTER: virgüllü yaratık listesi (menzilli örnek: "zombie1,ork1,iskelet2,lich1,iskelet3")
var _roster: PackedStringArray = (OS.get_environment("KD_ROSTER") if OS.get_environment("KD_ROSTER") != "" else ROSTER_DEFAULT).split(",")
var _rec_frames: int = int(OS.get_environment("KD_REC")) if OS.get_environment("KD_REC") != "" else REC_FRAMES_DEFAULT
var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _spawner: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_frame() -> void:
	paused = false
	if _gm != null:
		_gm.set("team_xp_needed", 1.0e12)
	if _player == null or not is_instance_valid(_player):
		return
	_player.set("xp_to_next_level", 1.0e12)
	_player.set("item_shield_max", 100.0)
	_player.set("item_shield_hp", 100.0)
	_player.set("item_shield_regen_delay", 0.0)
	_player.set("health", float(_player.get("max_health")))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	if _shield_type == "":
		_shield_type = "shield_standart"
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 10)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(10).get("skill", 1))
	_gm.set("debug_mode_unlocked", true) ## kayıt (Ruh Kıymığı/rekor) yazılmasın
	_gm.set("shield_standart_level", 1)
	_gm.set("shield_enchant", "" if _shield_type == "shield_standart" else _shield_type)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("KD HATA main yok")
		quit()
		return
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _frames(75)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _frames(60)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	if _player == null or _spawner == null:
		print("KD HATA oyuncu/spawner yok")
		quit()
		return
	_spawner.set("_spawn_timer", 1.0e9)
	process_frame.connect(_on_frame)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	_player.set_physics_process(true)
	print("KD oyuncu %s" % str(_player.global_position))
	for v: String in _variants:
		await _run_variant(v)
	print("BITTI")
	quit()


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()


func _swap_fx(v: String) -> void:
	var old_fx: Node = _player.get("mana_fx")
	var old_back: Node = _player.get_node_or_null("ManaShieldBack")
	var old_surf: Node = _player.get_node_or_null("BubbleHitProto")
	for n: Node in [old_fx, old_back, old_surf]:
		if n != null and is_instance_valid(n):
			_player.remove_child(n)
			n.free()
	var back := Node2D.new()
	back.name = "ManaShieldBack"
	back.show_behind_parent = true
	_player.add_child(back)
	var fx: Node2D = (load("res://tools/proto_20261111/kalkan_darbe/hit_variant.gd") as GDScript).new()
	fx.name = "ManaShieldFx"
	fx.set("host", _player)
	fx.set("_back", back)
	fx.set("variant", v)
	_player.add_child(fx)
	fx.set("hit_only", true)
	_player.set("mana_fx", fx)
	fx.call("set_shield_type", _shield_type)


func _run_variant(v: String) -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join(v))
	_clear_enemies()
	await _frames(6)
	if v != "oyun": ## "oyun" = oyundaki GERÇEK efekt + mermi kuralı (madde 572), prototip takılmaz
		_swap_fx(v)
	await _frames(4)
	seed(20261111)
	var pp: Vector2 = _player.global_position
	for i in _roster.size():
		_spawner.call("debug_spawn_creature", _roster[i], TIER, 1, pp)
	var hits: int = 0
	var last_shield_t: int = int(_player.get("_last_damage_taken_at_msec")) ## önceki seçenekten kalan değer darbe sayılmasın
	var fx0: Node = _player.get("mana_fx")
	var last_contact: int = int(fx0.get("_last_ranged_msec")) if (fx0 != null and fx0.get("_last_ranged_msec") != null) else 0
	await _frames(SPAWN_FRAMES)
	for i in range(_rec_frames):
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var img: Image = root.get_texture().get_image()
			var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
			var rect := Rect2i(c - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			img.get_region(rect).save_png(_dir.path_join(v).path_join("f_%03d.png" % (i / 2)))
		## oyun: mermi baloncuğun kenarına DEĞDİ (mana_shield_fx.gd ranged_hit) - gif.py özeti bu karelerden seçer
		var fxr: Node = _player.get("mana_fx")
		if v == "oyun" and fxr != null and fxr.get("_last_ranged_msec") != null:
			var lc: int = int(fxr.get("_last_ranged_msec"))
			if lc != last_contact:
				last_contact = lc
				var proj_d: float = -1.0
				for pr in get_nodes_in_group("enemy_projectiles"):
					if is_instance_valid(pr) and (pr as Node).is_queued_for_deletion():
						proj_d = (pr as Node2D).global_position.distance_to(_player.global_position)
				print("DEGME %s %d %.1f" % [v, i / 2, proj_d])
		var lt: int = int(_player.get("_last_damage_taken_at_msec"))
		if lt != last_shield_t:
			last_shield_t = lt
			hits += 1
			var fx: Node = _player.get("mana_fx")
			var kind: String = "menzilli" if (fx != null and fx.get("last_hit_ranged") == true) else "yakin"
			print("DARBE %s %d %s %s" % [v, i / 2, kind, str(fx.get("last_hit_info")) if fx != null else ""]) ## gif.py özet sayfası bu karelerden seçer (tür yalnız E'de anlamlı)
	print("SECENEK %s kare %d darbe %d yaratik %d" % [v, _rec_frames / 2, hits, get_nodes_in_group("enemies").size()])
