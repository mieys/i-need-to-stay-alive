extends SceneTree
## HARİTA İÇERİĞİ Aşama 1 DUMAN TESTİ (madde 597): gerçek Main'i açar, kademe saatini K5 / K10 boss zamanına atlatır, bossları doğurup öldürür,
## K10 bossu ölünce ZAFERİ ve "Sonsuza Devam Et"i doğrular. Başsız:
##   $env:HARITA="ana"; Godot --headless --path . -s res://tools/harita_icerik/duman_asama1.gd   (HARITA boşsa ana harita)
## Çıktı "DUMAN ..." satırları; sonda "DUMAN_SONUC ok" ya da "DUMAN_SONUC HATA <sayı>". Oyun koduna dokunmaz (kayıt/rekor bastırılır).

var _gm: Node = null
var _errors: int = 0
var _heard: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _check(cond: bool, msg: String) -> void:
	print("DUMAN ", "OK   " if cond else "HATA ", msg)
	if not cond:
		_errors += 1


func _on_tier(t: int) -> void:
	_heard.append(t)


func _clear_enemies() -> void:
	for e: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	await process_frame


## Kademe kapısı (eski kademenin yakındaki yaratıkları ölmeden yeni kademe/boss başlamaz) gerçek oyundaki gibi çalışır: duman testi her 0,5 sn'de bossu OLMAYAN
## yaratıkları siler (ev kuşatmacıları dahil) ve istenen boss çıkana kadar bekler.
func _await_boss(id: String, max_sec: float) -> Array:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(max_sec * 1000.0):
		for e: Node in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.get("is_boss") != true and not e.is_in_group("boss"):
				e.queue_free()
		await _wait(0.5)
		var found: Array = []
		for b: Node in _bosses():
			if str(b.get_meta("creature_id", "")) == id:
				found.append(b)
		if not found.is_empty():
			return found
	return []


func _bosses() -> Array:
	var out: Array = []
	for b: Node in get_nodes_in_group("boss"):
		if is_instance_valid(b) and b.get("is_dead") != true and b.get("is_boss") == true:
			out.append(b)
	return out


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("DUMAN main açılmadı")
		quit(1)
		return
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	nm.creature_tier_reached.connect(_on_tier)
	await _wait(6.0)
	_gm.set("invasion_pending", false) ## açılış sahnesini (ev kuşatması geri sayımı) bekleme
	var pl: Node = main.get_node_or_null("Player")
	var hi: Node = main.get_node_or_null("HouseInterior")
	print("DUMAN oyuncu içeride=", pl.get("is_indoors") if pl else "?", " HouseInterior=", hi != null)
	if pl != null and pl.get("is_indoors") == true and hi != null:
		hi.call("_do_exit_house") ## doğuş yalnız DIŞARIDAKİ canlı oyuncu varken çalışır (_any_living_player_outdoors)
		await _wait(0.5)
		print("DUMAN dışarı çıkarıldı: içeride=", pl.get("is_indoors"))
	var sp: Node = main.get_node_or_null("EnemySpawner")
	var mp: GDScript = load("res://scripts/map_profiles.gd")
	var map_id: String = str(mp.call("current_id")) if mp != null else "?"
	var want_map: String = OS.get_environment("HARITA") if OS.get_environment("HARITA") != "" else "ana"
	_check(sp != null, "EnemySpawner bulundu")
	_check(map_id == want_map, "yüklenen harita = istenen: %s (istenen %s, selected_map=%s)" % [map_id, want_map, str(_gm.get("selected_map"))])
	if sp == null:
		quit(1)
		return
	var dur: float = float(sp.get("tier_duration"))
	var last: int = int(sp.get("LAST_TIER"))
	_check(last == 10, "LAST_TIER 10: %d (kademe süresi %.0f sn)" % [last, dur])
	var roster: Dictionary = sp.get("TIER_ROSTER")
	_check(roster.size() == 10, "TIER_ROSTER 10 kademe: %d" % roster.size())

	# ---- Kademe 5 bossu (Minotaur): can 50.000 / kalkan 60.000
	_gm.set("game_time", 4.0 * dur + 0.75 * dur + 2.0)
	var b5: Array = await _await_boss("minotaur1", 30.0)
	_check(b5.size() == 1 and _bosses().size() == 1, "K5'te tek boss Minotaur: %d (toplam boss %d)" % [b5.size(), _bosses().size()])
	if not b5.is_empty():
		_check(is_equal_approx(float(b5[0].max_health), 50000.0) and is_equal_approx(float(b5[0].item_shield_max), 60000.0),
				"K5 yuva statları 50.000 / 60.000: %.0f / %.0f" % [float(b5[0].max_health), float(b5[0].item_shield_max)])
		_check(float(b5[0].get_meta("boss_damage_mult", 0.0)) > 1.4, "K5 boss hasar çarpanı metası: %s" % str(b5[0].get_meta("boss_damage_mult", 0.0)))
	_check(not bool(sp.get("_final_spawned")), "K5 bossu SON boss değil")
	_check(sp.call("is_tier_held_by_boss") or int(sp.call("_current_tier")) == 5, "kademe saati K5'te")
	for b: Node in b5:
		b.call("die")
	await _wait(1.0)
	_check(int(sp.call("get_run_phase")) == 0, "K5 bossu ölünce zafer yok")

	# ---- Kademe 10 bossu (Wendigo): can 300.000 / kalkan 400.000, ölünce ZAFER
	_gm.set("game_time", 9.0 * dur + 0.75 * dur + 2.0)
	var b10: Array = await _await_boss("wendigo1", 30.0)
	_check(b10.size() == 1 and _bosses().size() == 1, "K10'da tek boss Wendigo: %d (toplam boss %d)" % [b10.size(), _bosses().size()])
	if not b10.is_empty():
		_check(is_equal_approx(float(b10[0].max_health), 300000.0) and is_equal_approx(float(b10[0].item_shield_max), 400000.0),
				"K10 yuva statları 300.000 / 400.000: %.0f / %.0f" % [float(b10[0].max_health), float(b10[0].item_shield_max)])
	_check(bool(sp.get("_final_spawned")), "K10 bossu SON boss olarak kayıtlı")
	_check(int(sp.call("get_run_phase")) == 0, "son boss sağken zafer yok")
	_gm.set("game_time", 9.0 * dur + dur + 500.0) ## saat K10 sınırında bekler (otomatik sonsuz yok)
	await _wait(1.0)
	_check(int(sp.call("_current_tier")) == 10 and int(sp.call("get_endless_layer")) == 0, "boss sağken K10'da kalındı, sonsuz yok")
	for b: Node in b10:
		b.call("die")
	await _wait(1.5)
	_check(int(sp.call("get_run_phase")) == 1 and bool(_gm.get("victory_reached")), "son boss ölünce ZAFER")
	_check(bool(sp.call("begin_endless")) and int(sp.call("get_endless_layer")) == 1, "Sonsuza Devam Et -> Kat 1")
	_check(not _heard.has(11) and _heard.max() <= 10 if not _heard.is_empty() else true, "kademe bildirimleri 10'u geçmedi: %s" % str(_heard))
	await _wait(2.0)
	var sample: Array = []
	for e: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_boss") != true:
			sample.append("%s@%d" % [str(e.get_meta("creature_id", "?")), int(e.get("_current_tier"))])
			if sample.size() >= 6:
				break
	print("DUMAN sonsuz doğan örnek: ", sample)
	print("DUMAN_SONUC ", "ok" if _errors == 0 else "HATA %d" % _errors)
	quit(0 if _errors == 0 else 1)
