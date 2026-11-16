extends SceneTree
## HARİTA CİLA DENETİMİ - döküm (2026-11-15, kullanıcı: "tüm haritalara cila çekip kusurlarını gider").
## Seçili haritayla (HARITA ortam değişkeni, editör ikilisi) GERÇEK Main'i açar ve analiz için döker (tools/harita_cila/analiz.py okur):
##  - out/grid_<id>.bin : hücre başına uint16 (satır satır, rect = orman katmanı ızgarası), bitler aşağıda (KÖK noktası = hücre ortası; zindanda
##    is_position_blocked_by_walls ayak kuralını kendi uygular).
##  - out/meta_<id>.json: rect / oyun alanı / doğuş / oyuncu, Harita altındaki her TileMapLayer (çarpışmaya giriyor mu + katı görünen nesne
##    sayısı ve örnek konumları: terrain_collision.is_solid_prop ile AYNI sınıflama), gruplu düğümlerin konumları, ışıklar.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/harita_cila/denetim.ps1 [-Haritalar "ana,bataklik"]

## -s betiği autoload'lardan ÖNCE derlenir: GameManager'a başvuran betikler preload edilemez, _run içinde load() edilir.
var TC: GDScript = null
var DepthScript: GDScript = null
const B_WALL := 1 ## is_position_blocked_by_walls (oyuncu hareketi)
const B_FOREST := 2 ## is_position_blocked_by_forest (orman / uçurum / zindan duvarı; mermi + görüş)
const B_ICE := 4
const CAT_BITS := {"water": 8, "trees": 16, "props": 32, "houses": 64, "mines": 128, "enemy_base": 256}
const SKIP_GROUPS := ["enemies", "player", "players", "player_ally", "depth_occluders"]

var _gm: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		paused = false
		await process_frame


func _run() -> void:
	TC = load("res://scripts/terrain_collision.gd")
	DepthScript = load("res://scripts/depth_occluders.gd")
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	var MP: GDScript = load("res://scripts/map_profiles.gd")
	var id: String = str(MP.call("current_id"))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("DENETIM main açılmadı")
		quit(1)
		return
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _frames(40)
	var forest: TileMapLayer = _gm.call("get_forest_layer")
	if forest == null:
		print("DENETIM orman katmanı yok")
		quit(1)
		return
	TC.ensure(forest)
	## ızgara: harita dünya dikdörtgeni (kamera = çerçeve dahil) -> orman katmanı hücreleri
	var wr: Rect2 = _gm.call("get_camera_world_rect")
	var c0: Vector2i = forest.local_to_map(forest.to_local(wr.position))
	var c1: Vector2i = forest.local_to_map(forest.to_local(wr.end))
	var rect := Rect2i(c0, c1 - c0 + Vector2i.ONE)
	var cat_of: Dictionary = {}
	for cat: String in CAT_BITS:
		for c: Vector2i in TC.by_category.get(cat, []):
			cat_of[c] = int(cat_of.get(c, 0)) | int(CAT_BITS[cat])
	var buf := PackedByteArray()
	buf.resize(rect.size.x * rect.size.y * 2)
	var nb: int = 0
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var c := Vector2i(rect.position.x + x, rect.position.y + y)
			var wp: Vector2 = forest.to_global(Vector2((float(c.x) + 0.5) * 16.0, (float(c.y) + 0.5) * 16.0))
			var v: int = int(cat_of.get(c, 0))
			if _gm.call("is_position_blocked_by_walls", wp):
				v |= B_WALL
				nb += 1
			if _gm.call("is_position_blocked_by_forest", wp):
				v |= B_FOREST
			if _gm.call("is_position_on_ice", wp + Vector2(0.0, 13.0)):
				v |= B_ICE
			buf.encode_u16((y * rect.size.x + x) * 2, v)
	var out_dir: String = ProjectSettings.globalize_path("res://tools/harita_cila/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("grid_%s.bin" % id), FileAccess.WRITE)
	f.store_buffer(buf)
	f.close()
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var spawn: Vector2 = MP.call("spawn_position")
	var MF: GDScript = load("res://scripts/map_frame.gd")
	var play: Rect2i = MF.call("play_cells")
	var meta := {
		"id": id, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"forest_xform": [forest.global_transform.origin.x, forest.global_transform.origin.y, forest.global_transform.x.x],
		"play": [play.position.x, play.position.y, play.size.x, play.size.y],
		"spawn": [spawn.x, spawn.y] if spawn != Vector2.INF else null,
		"player": [player.global_position.x, player.global_position.y] if player != null else null,
		"blocked": nb, "tc_stats": TC.stats,
		"layers": _layer_report(main.get_node("Harita"), forest),
		"nodes": _node_report(main),
		"depth": _depth_report(main.get_node("Harita")),
	}
	var fj := FileAccess.open(out_dir.path_join("meta_%s.json" % id), FileAccess.WRITE)
	fj.store_string(JSON.stringify(meta))
	fj.close()
	print("DENETIM %s rect=%s engel=%d katman=%d düğüm=%d" % [id, str(rect), nb, (meta["layers"] as Array).size(), (meta["nodes"] as Array).size()])
	quit(0)


## Harita altındaki her karo katmanı: yol, hücre sayısı, çarpışma kategorisinde mi, katı görünen nesneler (is_solid_prop) + örnek kökler (dünya px).
func _layer_report(harita: Node, forest: TileMapLayer) -> Array:
	var covered: Dictionary = {}
	for p: String in TC.PROP_LAYERS + TC.HOUSE_WALL_LAYERS + TC.MINE_LAYERS + TC.BASE_LAYERS + [TC.WATER_LAYER]:
		covered[p] = true
	var helper: Node = DepthScript.new()
	var out: Array = []
	for l: TileMapLayer in harita.find_children("*", "TileMapLayer", true, false):
		if l.tile_set == null or l.get_used_cells().is_empty():
			continue
		var path: String = str(harita.get_path_to(l))
		var is_tree: bool = path.begins_with(TC.TREE_PARENT + "/" + TC.TREE_PREFIX)
		var row := {"path": path, "cells": l.get_used_cells().size(), "visible": l.is_visible_in_tree(), "z": l.z_index,
			"ysort": l.y_sort_enabled, "covered": covered.has(path) or is_tree or l == forest, "solid": 0, "samples": []}
		if l != forest and l.is_visible_in_tree() and l.get_used_cells().size() < 60000:
			var ofs: Vector2 = helper.cell_origin(l)
			for grp: Dictionary in TC.object_groups(helper, l):
				if not TC.is_solid_prop(grp):
					continue
				row["solid"] = int(row["solid"]) + 1
				if (row["samples"] as Array).size() < 400:
					var bases: Dictionary = grp["bases"]
					var sx: float = 0.0
					var by: float = -1.0e9
					for c: Vector2i in bases:
						sx += ofs.x + (float(c.x) + 0.5) * 16.0
						by = maxf(by, float(bases[c]))
					(row["samples"] as Array).append([sx / float(bases.size()), by, grp["w"], grp["h"]])
		out.append(row)
	helper.free()
	return out


## Derinlik ön kopyaları (depth_occluders.gd fronts: ağaç / bina / nesne / çalılık / köprü), oyunun KENDİ kök tablosundan: katman başına nesneler
## (aynı kök + 4-komşu hücreler) [x0, y0, x1, y1 hücre, kök dünya y, hücre sayısı] ve dikey bitişik farklı köklü parça çiftleri ("bolunme": üstteki
## parçanın kökü nesnenin ortasında kalıyor olabilir -> arkasındaki karakter üst parçanın ÜSTÜNE çizilir; madde 627 sütun hatası gibi).
func _depth_report(harita: Node) -> Array:
	var out: Array = []
	for occ: Node in get_nodes_in_group(&"depth_occluders"):
		for f: Dictionary in occ.get("fronts"):
			var layer: TileMapLayer = f["layer"]
			if not is_instance_valid(layer):
				continue
			var bases: Dictionary = f["bases"]
			var gid: Dictionary = {}
			var groups: Array = []
			for c: Vector2i in bases:
				if gid.has(c):
					continue
				var root_y: float = float(bases[c])
				var idx: int = groups.size()
				var stack: Array[Vector2i] = [c]
				gid[c] = idx
				var g := [c.x, c.y, c.x, c.y, root_y, 0]
				while not stack.is_empty():
					var q: Vector2i = stack.pop_back()
					g[0] = mini(g[0], q.x)
					g[1] = mini(g[1], q.y)
					g[2] = maxi(g[2], q.x)
					g[3] = maxi(g[3], q.y)
					g[5] = int(g[5]) + 1
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n: Vector2i = q + d
						if bases.has(n) and not gid.has(n) and is_equal_approx(float(bases[n]), root_y):
							gid[n] = idx
							stack.append(n)
				groups.append(g)
			var splits: Dictionary = {}
			for c: Vector2i in bases:
				var up: Vector2i = c + Vector2i(0, -1)
				if gid.has(up) and gid[up] != gid[c]:
					splits[Vector2i(int(gid[up]), int(gid[c]))] = true
			var sp: Array = []
			for k: Vector2i in splits:
				sp.append([k.x, k.y])
			out.append({"path": str(harita.get_path_to(layer)) if harita.is_ancestor_of(layer) else str(layer.name), "mode": f["mode"],
				"ofs": [occ.call("cell_origin", layer).x, occ.call("cell_origin", layer).y], "groups": groups, "splits": sp})
	return out


## Grubu olan (iç gruplar hariç) her Node2D: ad, betik, gruplar, dünya konumu. Işıklar ayrıca ("light" grubu adıyla).
func _node_report(main: Node) -> Array:
	var out: Array = []
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if not (n is Node2D):
			continue
		var gs: Array = []
		for g: StringName in n.get_groups():
			var s: String = str(g)
			if not s.begins_with("_") and not SKIP_GROUPS.has(s):
				gs.append(s)
		if n is Light2D:
			gs.append("light")
		if gs.is_empty() or out.size() > 30000:
			continue
		var scr: Script = n.get_script()
		out.append({"n": str(n.name), "s": scr.resource_path.get_file() if scr != null else n.get_class(), "g": gs,
			"p": [(n as Node2D).global_position.x, (n as Node2D).global_position.y]})
	return out
