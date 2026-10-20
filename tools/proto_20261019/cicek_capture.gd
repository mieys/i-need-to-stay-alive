extends SceneTree

## Oakley çiçeği y-sıralaması + zemin efekti GERÇEK MAIN'de (2026-10-19): Oakley (id 2) ile oyun açılır, yaratıklar temizlenir; oyuncunun
## çevresine 3 çiçek (açmış = aşama 2) ve 2 slime dizilir. Çekimler (CC_DIR):
##   cc_arkada.png  oyuncu 1. çiçeğin ARKASINDA (ayağı kökün 6 px üstü) -> çiçek bacaklarını örtmeli
##   cc_onde.png    oyuncu 1. çiçeğin ÖNÜNDE (ayağı kökün 6 px altı) -> oyuncu çiçeği örtmeli, çember ayağının altında
##   2. çiçeğin arkasında / 3. çiçeğin önünde birer slime (main.gd ayak sırası), ağaç varsa ön kopya örtüsü
## Ayrıca CC_BG=1 iken çiçek/slime OLMADAN oyuncunun sağında boş çayır çekilir (prototip arka planı: cc_bg.png).
## Koşturucu: tools/proto_20261019/cicek_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

var _dir: String = OS.get_environment("CC_DIR")
var _gm: Node = null
var _main: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name))
	print("SHOT ", name)


func _slime(pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	return e


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(2).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz (fps_micro._boot ile aynı)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	var player: Node2D = _main.get_node("Player")
	player.set("_oakley_flower_auto_timer", 1.0e9) ## pasif kendi çiçeğini bırakmasın
	var spot := Vector2(float(OS.get_environment("CC_X")) if OS.get_environment("CC_X") != "" else 3616.0,
			float(OS.get_environment("CC_Y")) if OS.get_environment("CC_Y") != "" else 2000.0)
	player.global_position = spot
	await _wait(1.0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	if OS.get_environment("CC_BG") == "1":
		player.visible = false
		for n in _main.get_children():
			if n is CanvasLayer:
				(n as CanvasLayer).visible = false
		await _wait(0.5)
		await _shot("cc_bg.png")
		quit()
		return
	if OS.get_environment("CC_PERF") == "1":
		await _fx_perf(player, spot)
		quit()
		return
	if OS.get_environment("CC_FX") == "1":
		await _fx_sequence(player, spot)
		quit()
		return
	if OS.get_environment("CC_TREE") == "1":
		await _tree_shot(player, spot)
		quit()
		return
	var feet_off: float = float((load("res://scripts/depth_occluders.gd") as GDScript).get_script_constant_map()["FEET_OFFSET"])
	var flowers: Array[Node2D] = []
	for off in [Vector2(0, 0), Vector2(70, -6), Vector2(-70, -6)]:
		player.call("_spawn_oakley_flower_at", spot + off + Vector2(0, -20), spot)
		var nf: Node2D = get_nodes_in_group("oakley_flowers").back() as Node2D
		nf.set("_pickup_delay_remaining", 1.0e9)
		flowers.append(nf)
	await _wait(0.3)
	for f in flowers:
		f.set("_pickup_delay_remaining", 1.0e9) ## oyuncu dibinde duruyor - toplamasın
		f.set("_growth_stage", 2)
		f.call("_update_depth_body")
		(f.get_node("AnimatedSprite2D") as AnimatedSprite2D).play("stage2")
	## 2. çiçeğin ARKASINDA, 3. çiçeğin ÖNÜNDE slime (kök noktası ~ gövde ortası; ayak sırası main.gd'de ölçülür)
	_slime(flowers[1].global_position + Vector2(4, -4))
	_slime(flowers[2].global_position + Vector2(-4, 22))
	var base_y: float = flowers[0].global_position.y + 20.0
	player.global_position = Vector2(flowers[0].global_position.x + 3.0, base_y - 6.0 - feet_off)
	await _wait(1.2)
	print("Z arkada: cicek=", flowers[0].z_index, " oyuncu=", player.z_index)
	await _shot("cc_arkada.png")
	player.global_position = Vector2(flowers[0].global_position.x + 3.0, base_y + 6.0 - feet_off)
	await _wait(1.2)
	print("Z onde: cicek=", flowers[0].z_index, " oyuncu=", player.z_index)
	await _shot("cc_onde.png")
	print("BITTI")
	quit()


## CC_TREE=1: en yakın ağacın (Shader Eklenecek/Ağaç 1) gövde dibi (depth_occluders kökü); kalkan baloncuğu açık oyuncu gövdenin hemen ARKASINDA
## (cc_agac_arkada.png) ve ÖNÜNDE (cc_agac_onde.png); ağacın arkasında bir çiçek + çayırda bir çiçek.
func _tree_shot(player: Node2D, spot: Vector2) -> void:
	var layer: TileMapLayer = _main.get_node_or_null("Harita/Shader Eklenecek/Ağaç 1") as TileMapLayer
	var occ: Node = null
	for c in _main.find_children("*", "", true, false):
		if c.has_method("max_base_in"):
			occ = c
			break
	if layer == null or occ == null:
		print("AGAC KATMANI / OCC YOK")
		return
	var used: Dictionary = {}
	for c: Vector2i in layer.get_used_cells():
		used[c] = true
	var best := Vector2i.ZERO
	var best_d: float = 1.0e12
	for c: Vector2i in used:
		var d: float = layer.to_global(layer.map_to_local(c)).distance_squared_to(spot)
		if d < best_d:
			best_d = d
			best = c
	while used.has(best + Vector2i(0, 1)):
		best += Vector2i(0, 1)
	var cell_pos: Vector2 = layer.to_global(layer.map_to_local(best))
	var found: Vector3 = _nearest_sway_root(spot)
	if found.z > 0.0:
		cell_pos = Vector2(found.x, found.y - 8.0)
	if OS.get_environment("CC_TX") != "":
		cell_pos = Vector2(float(OS.get_environment("CC_TX")), float(OS.get_environment("CC_TY")))
	var base: float = -1.0e9
	for ln in ["Ağaç 0", "Ağaç 1", "Ağaç 2"]:
		var l2: TileMapLayer = _main.get_node_or_null("Harita/Shader Eklenecek/" + ln) as TileMapLayer
		if l2 != null:
			base = maxf(base, _tree_root(l2, cell_pos))
	var feet_off: float = float((load("res://scripts/depth_occluders.gd") as GDScript).get_script_constant_map()["FEET_OFFSET"])
	if found.z > 0.0 and OS.get_environment("CC_TX") == "":
		base = found.y
	if base < -1.0e8 and OS.get_environment("CC_ROOT") != "":
		base = float(OS.get_environment("CC_ROOT")) ## orman parçası ağacı: kök elle (sallanan ağaç verisinde yok)
	print("AGAC hucre ", cell_pos, " kok ", base)
	for l in _main.get_node("Harita").find_children("*", "TileMapLayer", true, false):
		var tl := l as TileMapLayer
		for probe in [cell_pos + Vector2(0, -40), cell_pos, cell_pos + Vector2(0, 10)]:
			var mc: Vector2i = tl.local_to_map(tl.to_local(probe))
			if tl.get_cell_source_id(mc) != -1:
				print("KATMAN ", tl.get_path(), " z=", tl.z_index, " @", probe, " mat=", tl.material.shader.resource_path if tl.material is ShaderMaterial and (tl.material as ShaderMaterial).shader else "-")
	player.global_position = Vector2(cell_pos.x, base - 6.0 - feet_off)
	await _wait(0.8)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for off in [Vector2(-34, -10 - 20), Vector2(-120, 30 - 20)]: ## 1: kökün 10 px yukarısı (ağacın arkası), 2: çayır
		player.call("_spawn_oakley_flower_at", Vector2(cell_pos.x, base) + off, player.global_position)
		var nf: Node2D = get_nodes_in_group("oakley_flowers").back() as Node2D
		nf.set("_pickup_delay_remaining", 1.0e9)
		nf.set("_growth_stage", 2)
		nf.call("_update_depth_body")
		(nf.get_node("AnimatedSprite2D") as AnimatedSprite2D).play("stage2")
	player.set("_damage_flash_timer", 1.0e9) ## kalkan baloncuğu açık kalsın
	await _wait(1.2)
	await _shot("cc_agac_arkada.png")
	player.global_position = Vector2(cell_pos.x, base + 8.0 - feet_off)
	await _wait(1.0)
	await _shot("cc_agac_onde.png")


## Ağaç shader'ının veri dokusundan (tree_sway.gd yazar: R + G*256 = kökün dünya y'si) noktanın altındaki/üstündeki hücrelerin en büyük kökü.
func _tree_root(layer: TileMapLayer, p: Vector2) -> float:
	var mat := layer.material as ShaderMaterial
	if mat == null:
		print("AGAC mat yok ", layer.material)
		return -1.0e9
	var tex: Texture2D = mat.get_shader_parameter("veri")
	if tex == null:
		print("AGAC veri yok")
		return -1.0e9
	var img: Image = tex.get_image()
	var start: Vector2 = mat.get_shader_parameter("veri_baslangic")
	var ofs: Vector2 = mat.get_shader_parameter("hucre_ofset")
	print("AGAC veri ", img.get_size(), " start ", start, " ofs ", ofs, " fmt ", img.get_format(), " hucre ", ((p - ofs) / 16.0).floor() - start)
	var best: float = -1.0e9
	for dy in range(-4, 3):
		var c: Vector2 = (((p - ofs) / 16.0).floor() - start) + Vector2(0, dy)
		if c.x < 0 or c.y < 0 or c.x >= img.get_width() or c.y >= img.get_height():
			continue
		var px: Color = img.get_pixel(int(c.x), int(c.y))
		if px.b8 > 128:
			best = maxf(best, float(px.r8 + px.g8 * 256))
	return best


## Sallanan ağaç katmanlarının veri dokularında noktaya en yakın GÖVDE DİBİ hücresi (kök hücrenin içinde): (x, kök y, 1) - yoksa z 0.
func _nearest_sway_root(p: Vector2) -> Vector3:
	var best := Vector3.ZERO
	var best_d: float = 1.0e12
	for ln in ["Ağaç 0", "Ağaç 1", "Ağaç 2"]:
		var l2: TileMapLayer = _main.get_node_or_null("Harita/Shader Eklenecek/" + ln) as TileMapLayer
		if l2 == null or not (l2.material is ShaderMaterial):
			continue
		var mat := l2.material as ShaderMaterial
		var tex: Texture2D = mat.get_shader_parameter("veri")
		if tex == null:
			continue
		var img: Image = tex.get_image()
		var start: Vector2 = mat.get_shader_parameter("veri_baslangic")
		var ofs: Vector2 = mat.get_shader_parameter("hucre_ofset")
		for y in img.get_height():
			for x in img.get_width():
				var px: Color = img.get_pixel(x, y)
				## tree_sway.gd: R = kökün hücre üstüne göre yeri (px), G = ağaç boyu; R <= 16 = gövde dibi hücresi
				if px.r8 == 0 or px.r8 > 16 or px.g8 < 40:
					continue
				var cx: float = ofs.x + (float(x) + start.x) * 16.0 + 8.0
				var cy0: float = ofs.y + (float(y) + start.y) * 16.0
				var root: float = cy0 + float(px.r8)
				var d: float = Vector2(cx, root).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = Vector3(cx, root, 1.0)
	return best


## CC_FX=1: Yaprak Halkası (madde 285) gerçek oyunda - Oakley çiçeğin solunda, çiçek her 2,5 sn'de büyür (oyunda 5 sn); çiçeğin KENDİ saatiyle
## 0,07 sn'de bir ekranın çiçek çevresi (CC_FX_W x CC_FX_H ekran px) kırpılıp fx_NNN.png olarak yazılır (GIF'i Python birleştirir).
func _fx_sequence(player: Node2D, spot: Vector2) -> void:
	var flower_pos: Vector2 = spot + Vector2(40, -14)
	player.global_position = spot + Vector2(-6, 0)
	await _wait(0.6)
	player.call("_spawn_oakley_flower_at", flower_pos, player.global_position)
	var f: Node2D = get_nodes_in_group("oakley_flowers").back() as Node2D
	f.set("_pickup_delay_remaining", 1.0e9)
	f.set("_growth_timer", 2.5)
	var cw: int = int(OS.get_environment("CC_FX_W")) if OS.get_environment("CC_FX_W") != "" else 420
	var ch: int = int(OS.get_environment("CC_FX_H")) if OS.get_environment("CC_FX_H") != "" else 260
	var n: int = 0
	var next_t: float = 0.0
	var last_stage: int = 0
	while is_instance_valid(f) and next_t < 7.6:
		await process_frame
		if int(f.get("_growth_stage")) != last_stage:
			last_stage = int(f.get("_growth_stage"))
			f.set("_growth_timer", 2.5)
		if float(f.get("_fx_age")) < next_t:
			continue
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var ratio: Vector2 = Vector2(img.get_size()) / root.get_visible_rect().size ## pencere 2560x1440, tuval 1920x1080 uzayında
		var sp: Vector2 = (root.get_canvas_transform() * (f.global_position + Vector2(-20, 6))) * ratio
		var r := Rect2i(int(sp.x) - cw / 2, int(sp.y) - ch / 2, cw, ch)
		img.get_region(r).save_png(_dir.path_join("fx_%03d.png" % n))
		n += 1
		next_t += 0.07
	print("FX kare ", n, " olcek ", root.get_canvas_transform().get_scale(), " goruntu ", root.get_visible_rect().size)


## CC_PERF=1: Yaprak Halkası maliyeti. 12 açmış çiçek ekranda (bir Oakley'nin 180 sn'lik ömürde en fazla ~10 + ağaçtan 3). (1) MİKRO: bir düğümün draw
## sinyalinde çiçek başına 3 parçanın (zemin + arka + ön) çizim komutu üretimi 300 kez zamanlanır -> çiçek başına kare başı us. (2) _process_fx
## (saat + redraw isteği). (3) KABA kare: 3 sn ortalama TIME_PROCESS + kare süresi, efekt açık / redraw kapalı (gürültülü, yalnız fikir verir).
var _bench_us: float = 0.0
var _bench_n: int = 0


func _fx_perf(player: Node2D, spot: Vector2) -> void:
	var Fx: GDScript = load("res://scripts/oakley_flower_fx.gd")
	var flowers: Array[Node2D] = []
	for i in 12:
		var pos: Vector2 = spot + Vector2(-150 + (i % 6) * 60, -60 + (i / 6) * 80)
		player.call("_spawn_oakley_flower_at", pos, player.global_position)
		var f: Node2D = get_nodes_in_group("oakley_flowers").back() as Node2D
		f.set("_pickup_delay_remaining", 1.0e9)
		f.set("_growth_timer", 1.0e9)
		f.set("_growth_stage", 2)
		f.set("_grow_from", 2)
		flowers.append(f)
	await _wait(1.5)
	var mat: ShaderMaterial = flowers[0].get("_fx_mat")
	var st: Array = flowers[0].call("fx_state")
	var tb: int = Time.get_ticks_usec()
	for k in 1000:
		Fx.update_material(mat, st)
	_bench_us = float(Time.get_ticks_usec() - tb) / 1000.0
	print("PERF update_material (shader surumu): cicek basina kare basi %.1f us (acmis 6 yaprak)" % _bench_us)
	var t1: int = Time.get_ticks_usec()
	for k in 1000:
		flowers[0].call("_process_fx", 0.016)
	print("PERF _process_fx: %.2f us" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	for mode in ["acik", "gizli", "acik", "gizli"]:
		for f in flowers:
			f.set("_fx_on_screen", mode == "acik")
			for q in [f.get_node("FxBack"), f.get_node("FxFront"), (f.get("_ground_fx") as Node).get_node("FxGround")]:
				(q as CanvasItem).visible = mode == "acik"
		await _wait(0.5)
		var proc := 0.0
		var frame := 0.0
		var n := 0
		var t0: int = Time.get_ticks_msec()
		var last: int = Time.get_ticks_usec()
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			var now: int = Time.get_ticks_usec()
			frame += float(now - last) / 1000.0
			last = now
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			n += 1
		print("PERF kare (%s, 12 cicek): process %.2f ms, kare %.2f ms, %d kare" % [mode, proc / n, frame / n, n])
