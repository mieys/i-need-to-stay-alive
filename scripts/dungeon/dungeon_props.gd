extends Node2D
class_name DungeonProps

## ZİNDAN ETKİLEŞİM GÖRSELLERİ (madde 373): açılıp kapanan / tükenen parçalar TMX'te değil burada çizilir (kapı, kaynak düğümü, sandık, tuzak, NPC).
## Zindan kökünün çocuğu (yerel px). Durum DungeonManager'dan gelir (host yetkili, ağdan eşitlenir); bu düğüm sadece görsel.
## Sayfalar: harita/zindan/<zindan>/runtime/*.png ya da harita/zindan/<zindan>/*.png (tools/zindan/gen_*.py yazar). Kare düzenleri STYLE tablosunda:
##  - kapı "sheet": tek görsel, kareler = [sütun, satır] karo ofsetleri (0 = kapalı ... son = açık), "off" kapı dikdörtgenine göre karo kayması;
##  - kapı "tiles": hücre başına bir karo (diken), "frames_x" sütunları (0 = içeride/açık ... son = yukarıda/kapalı);
##  - kapı "slide": tek görsel kapalıyken görünür, açılırken aşağı kayıp söner (barikat, kristal).
##  - kaynak / sandık / tuzak / npc: "frames" sayısı, "step" [sütun, satır] kare adımı, "fps"; kaynak "spent": "base" (yalnız taban satırı) | "hide".

const TILE := 16.0
const GATE_FRAME_SEC := 0.11

const STYLE: Dictionary = {
	"kemik_mahzeni": {
		"parmaklik": {"mode": "sheet", "sheet": "runtime/doors.png", "w": 2, "h": 3, "off": [0, 0], "frames": [[6, 0], [6, 3], [6, 6], [6, 9]]},
		"diken": {"mode": "tiles", "sheet": "runtime/Spikes.png", "frames_x": [0, 3, 6, 9], "y": 1},
		"kaynak": {"sheet": "runtime/torches.png", "x": 1, "y": 0, "w": 2, "h": 3, "step": [0, 3], "frames": 6, "fps": 7.0, "spent": "base"},
		"sandik": {"sheet": "runtime/chest_lever.png", "x": 0, "y": 0, "w": 2, "h": 2, "step": [2, 0], "frames": 6},
		"tuzak": {"mode": "tiles", "sheet": "runtime/Spikes.png", "frames_x": [0, 3, 6, 9], "y": 1},
	},
	"et_kuyusu": {
		"kafes": {"mode": "sheet", "sheet": "runtime/Door_darker-lattice.png", "w": 5, "h": 5, "off": [-1, -2], "frames": [[0, 0], [5, 0], [10, 0], [15, 0]]},
		"barikat": {"mode": "slide", "sheet": "Downstairs_objects.png", "x": 6, "y": 7, "w": 2, "h": 3, "off": [-0.5, 0]},
		"kaynak": {"sheet": "et_nesneleri.png", "x": 22, "y": 11, "w": 3, "h": 3, "off": [-0.5, 0], "frames": 1, "spent": "hide", "pulse": true},
		"sandik": {"sheet": "Downstairs_objects.png", "x": 10, "y": 4, "w": 2, "h": 3, "off": [0, -1], "frames": 1, "opened_mod": 0.45},
		"tuzak": {"mode": "sheet1", "sheet": "runtime/Guillotine.png", "w": 3, "h": 3, "step": [3, 0], "frames": 12},
		"npc": {"sheet": "runtime/Alchemist_Idle.png", "fw": 32, "fh": 32, "row": 0, "frames": 6, "fps": 6.0, "off": [-8, -24]},
	},
	"boynuzlu_kapi": {
		"demir": {"mode": "sheet", "sheet": "runtime/doors_lever_chest_animation.png", "w": 2, "h": 3, "off": [0, 0],
				"frames": [[4, 0], [4, 3], [4, 6], [4, 9], [4, 12]]},
		"kristal": {"mode": "slide", "sheet": "magara_nesneleri.png", "x": 1, "y": 5, "w": 3, "h": 3, "off": [-1, 0]},
		"kaynak": {"sheet": "magara_nesneleri.png", "x": 1, "y": 5, "w": 3, "h": 3, "off": [-0.5, 0], "frames": 1, "spent": "hide", "pulse": true},
		"sandik": {"sheet": "runtime/doors_lever_chest_animation.png", "x": 8, "y": 1, "w": 2, "h": 2, "step": [0, 3], "frames": 5},
		"tuzak": {"mode": "sheet1", "sheet": "runtime/trap_animation.png", "w": 3, "h": 3, "off": [0, 0], "step": [0, 6], "frames": 5, "origin": [1, 2]},
	},
}

var dungeon_id: String = ""
var _style: Dictionary = {}
var _sheets: Dictionary = {}
var _gates: Dictionary = {} ## anahtar -> {"sprites", "style", "frame", "target", "acc", "kind", "base_pos"}
var _nodes: Dictionary = {} ## anahtar -> {"sprite", "style", "on", "t", "y0"}
var _chests: Dictionary = {}
var _traps: Array[Dictionary] = []
var _npcs: Array[Dictionary] = []
var _t: float = 0.0
var light: Node = null ## DungeonLight (kaynak ışıkları)


func setup(id: String, data: Resource) -> void:
	name = "ZindanParcalari"
	dungeon_id = id
	_style = STYLE.get(id, {})
	for o: Dictionary in data.objects:
		match str(o.get("type", "")):
			"kapi":
				_add_gate(o)
			"kaynak":
				_add_node(o)
			"sandik":
				_add_chest(o)
			"tuzak":
				_add_trap(o)
			"npc":
				_add_npc(o)


func _sheet(rel: String) -> Texture2D:
	if not _sheets.has(rel):
		var p: String = "res://harita/zindan/%s/%s" % [dungeon_id, rel]
		_sheets[rel] = load(p) if ResourceLoader.exists(p) else null
		if _sheets[rel] == null:
			push_warning("zindan sayfası yok: " + p)
	return _sheets[rel]


func _region_sprite(tex: Texture2D, region: Rect2, pos: Vector2, unlit: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if unlit:
		s.material = preload("res://scripts/cozy_ev_light.gd").unlit_material()
	add_child(s)
	return s


static func _off(st: Dictionary) -> Vector2:
	var o: Array = st.get("off", [0, 0])
	return Vector2(float(o[0]), float(o[1])) * TILE


# ------------------------------------------------------------------ kapılar
func _add_gate(o: Dictionary) -> void:
	var r: Rect2 = o["rect"]
	var kind: String = str((o.get("props", {}) as Dictionary).get("stil", ""))
	var st: Dictionary = _style.get(kind, {})
	var tex: Texture2D = _sheet(str(st.get("sheet", "")))
	if tex == null:
		return
	var mode: String = str(st.get("mode", "sheet"))
	var sprites: Array[Sprite2D] = []
	if mode == "tiles":
		for j in range(int(r.size.y / TILE)):
			for i in range(int(r.size.x / TILE)):
				sprites.append(_region_sprite(tex, Rect2(0, 0, TILE, TILE), r.position + Vector2(i, j) * TILE))
	elif mode == "slide":
		sprites.append(_region_sprite(tex, Rect2(float(st["x"]) * TILE, float(st["y"]) * TILE, float(st["w"]) * TILE, float(st["h"]) * TILE), r.position + _off(st)))
	else:
		sprites.append(_region_sprite(tex, Rect2(0, 0, float(st["w"]) * TILE, float(st["h"]) * TILE), r.position + _off(st)))
	var open_f: int = _gate_open_frame(st)
	var g := {"sprites": sprites, "style": st, "kind": kind, "mode": mode, "frame": open_f, "target": open_f, "acc": 0.0, "base_pos": sprites[0].position}
	_gates[str(o.get("gate_key", ""))] = g
	_apply_gate_frame(g)


static func _gate_open_frame(st: Dictionary) -> int:
	match str(st.get("mode", "sheet")):
		"tiles":
			return 0
		"slide":
			return 3
	return (st.get("frames", [[0, 0]]) as Array).size() - 1


func set_gate_closed(key: String, closed: bool) -> void:
	var g: Variant = _gates.get(key)
	if g == null:
		return
	var st: Dictionary = (g as Dictionary)["style"]
	var mode: String = str((g as Dictionary)["mode"])
	if mode == "tiles":
		(g as Dictionary)["target"] = ((st["frames_x"] as Array).size() - 1) if closed else 0
	else:
		(g as Dictionary)["target"] = 0 if closed else _gate_open_frame(st)


func _apply_gate_frame(g: Dictionary) -> void:
	var st: Dictionary = g["style"]
	var f: int = int(g["frame"])
	match str(g["mode"]):
		"tiles":
			var fx: Array = st["frames_x"]
			var n: int = 0
			for s: Sprite2D in g["sprites"]:
				s.region_rect.position = Vector2(float(int(fx[clampi(f, 0, fx.size() - 1)]) + n % 3) * TILE, float(st.get("y", 1)) * TILE)
				n += 1
		"slide":
			var s2: Sprite2D = (g["sprites"] as Array)[0]
			var k: float = float(f) / 3.0 ## 0 kapalı (görünür) .. 1 açık (yere gömülü)
			s2.position = (g["base_pos"] as Vector2) + Vector2(0, k * TILE * 1.5)
			s2.modulate.a = 1.0 - k
			s2.visible = k < 0.99
		_:
			var fr: Array = st["frames"]
			var c: Array = fr[clampi(f, 0, fr.size() - 1)]
			var s3: Sprite2D = (g["sprites"] as Array)[0]
			s3.region_rect.position = Vector2(float(c[0]), float(c[1])) * TILE


func _step_gates(delta: float) -> void:
	for g: Dictionary in _gates.values():
		if int(g["frame"]) == int(g["target"]):
			continue
		g["acc"] = float(g["acc"]) + delta
		if float(g["acc"]) < GATE_FRAME_SEC:
			continue
		g["acc"] = 0.0
		g["frame"] = int(g["frame"]) + (1 if int(g["target"]) > int(g["frame"]) else -1)
		_apply_gate_frame(g)


# ------------------------------------------------------------------ kaynak düğümleri
func _add_node(o: Dictionary) -> void:
	var st: Dictionary = _style.get("kaynak", {})
	var tex: Texture2D = _sheet(str(st.get("sheet", "")))
	if tex == null:
		return
	var r: Rect2 = o["rect"]
	var s := _region_sprite(tex, Rect2(float(st["x"]) * TILE, float(st["y"]) * TILE, float(st["w"]) * TILE, float(st["h"]) * TILE), r.position + _off(st), true)
	_nodes[str(o.get("node_key", ""))] = {"sprite": s, "style": st, "on": true, "t": randf() * 3.0, "y0": s.position.y}


func set_node_available(key: String, on: bool) -> void:
	var n: Variant = _nodes.get(key)
	if n == null:
		return
	(n as Dictionary)["on"] = on
	if light != null and is_instance_valid(light):
		light.call("set_keyed_light", key, on)
	_apply_node(n as Dictionary)


func _apply_node(n: Dictionary) -> void:
	var st: Dictionary = n["style"]
	var s: Sprite2D = n["sprite"]
	var w: float = float(st["w"]) * TILE
	var h: float = float(st["h"]) * TILE
	if bool(n["on"]):
		var frames: int = int(st.get("frames", 1))
		var f: int = int(float(n["t"]) * float(st.get("fps", 6.0))) % maxi(1, frames)
		var step: Array = st.get("step", [0, 0])
		s.region_rect = Rect2((float(st["x"]) + float(step[0]) * f) * TILE, (float(st["y"]) + float(step[1]) * f) * TILE, w, h)
		s.position.y = float(n["y0"])
		s.visible = true
		s.modulate = Color.WHITE
		if bool(st.get("pulse", false)):
			var k: float = 1.0 + 0.04 * sin(float(n["t"]) * 3.0)
			s.scale = Vector2(k, 1.0 / k)
	else:
		if str(st.get("spent", "base")) == "hide":
			s.visible = false
			return
		s.region_rect = Rect2(float(st["x"]) * TILE, float(st["y"]) * TILE + h - TILE, w, TILE)
		s.position.y = float(n["y0"]) + h - TILE
		s.modulate = Color(0.55, 0.55, 0.6)


# ------------------------------------------------------------------ sandıklar
func _add_chest(o: Dictionary) -> void:
	var st: Dictionary = _style.get("sandik", {})
	var tex: Texture2D = _sheet(str(st.get("sheet", "")))
	if tex == null:
		return
	var r: Rect2 = o["rect"]
	var s := _region_sprite(tex, Rect2(float(st["x"]) * TILE, float(st["y"]) * TILE, float(st["w"]) * TILE, float(st["h"]) * TILE), r.position + _off(st))
	_chests[str(o.get("chest_key", ""))] = {"sprite": s, "style": st, "frame": 0, "open": false, "acc": 0.0}


func set_chest_open(key: String, instant: bool = false) -> void:
	var c: Variant = _chests.get(key)
	if c == null:
		return
	(c as Dictionary)["open"] = true
	var st: Dictionary = (c as Dictionary)["style"]
	if int(st.get("frames", 1)) <= 1:
		((c as Dictionary)["sprite"] as Sprite2D).modulate = Color(1, 1, 1, 1) * float(st.get("opened_mod", 0.5))
		((c as Dictionary)["sprite"] as Sprite2D).modulate.a = 1.0
		return
	if instant:
		(c as Dictionary)["frame"] = int(st.get("frames", 1)) - 1
		_apply_chest(c as Dictionary)


func _apply_chest(c: Dictionary) -> void:
	var st: Dictionary = c["style"]
	var s: Sprite2D = c["sprite"]
	var step: Array = st.get("step", [2, 0])
	s.region_rect.position = Vector2(float(st["x"]) + float(step[0]) * int(c["frame"]), float(st["y"]) + float(step[1]) * int(c["frame"])) * TILE


# ------------------------------------------------------------------ tuzaklar (zamanlama DungeonManager.trap_level)
func _add_trap(o: Dictionary) -> void:
	var st: Dictionary = _style.get("tuzak", {})
	var tex: Texture2D = _sheet(str(st.get("sheet", "")))
	if tex == null:
		return
	var r: Rect2 = o["rect"]
	var sprites: Array[Sprite2D] = []
	if str(st.get("mode", "tiles")) == "tiles":
		for j in range(int(r.size.y / TILE)):
			for i in range(int(r.size.x / TILE)):
				sprites.append(_region_sprite(tex, Rect2(0, float(st.get("y", 1)) * TILE, TILE, TILE), r.position + Vector2(i, j) * TILE))
	else:
		sprites.append(_region_sprite(tex, Rect2(0, 0, float(st["w"]) * TILE, float(st["h"]) * TILE), r.position + _off(st)))
	_traps.append({"sprites": sprites, "rect": r, "style": st, "key": str(o.get("trap_key", ""))})


## up01: 0 = zararsız, 1 = vuruyor (DungeonManager zamanlar).
func set_trap_level(key: String, up01: float) -> void:
	for tr: Dictionary in _traps:
		if str(tr["key"]) != key:
			continue
		var st: Dictionary = tr["style"]
		if str(st.get("mode", "tiles")) == "tiles":
			var fx: Array = st["frames_x"]
			var idx: int = clampi(int(round(up01 * float(fx.size() - 1))), 0, fx.size() - 1)
			var n: int = 0
			for s: Sprite2D in tr["sprites"]:
				s.region_rect.position = Vector2(float(int(fx[idx]) + n % 3) * TILE, float(st.get("y", 1)) * TILE)
				n += 1
		else:
			var frames: int = int(st.get("frames", 1))
			var fi: int = clampi(int(round(up01 * float(frames - 1))), 0, frames - 1)
			var step: Array = st.get("step", [3, 0])
			var org: Array = st.get("origin", [0, 0])
			(tr["sprites"][0] as Sprite2D).region_rect.position = Vector2(float(org[0]) + float(step[0]) * fi, float(org[1]) + float(step[1]) * fi) * TILE


# ------------------------------------------------------------------ NPC (simyacı...)
func _add_npc(o: Dictionary) -> void:
	var st: Dictionary = _style.get("npc", {})
	var tex: Texture2D = _sheet(str(st.get("sheet", "")))
	if tex == null:
		return
	var r: Rect2 = o["rect"]
	var o2: Array = st.get("off", [0, 0])
	var s := _region_sprite(tex, Rect2(0, float(st.get("row", 0)) * float(st["fh"]), float(st["fw"]), float(st["fh"])), r.position + Vector2(float(o2[0]), float(o2[1])))
	s.z_index = 1
	_npcs.append({"sprite": s, "style": st})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_step_gates(delta)
	for n: Dictionary in _nodes.values():
		if bool(n["on"]):
			n["t"] = float(n["t"]) + delta
			_apply_node(n)
	for c: Dictionary in _chests.values():
		var st: Dictionary = c["style"]
		if bool(c["open"]) and int(c["frame"]) < int(st.get("frames", 1)) - 1:
			c["acc"] = float(c["acc"]) + delta
			if float(c["acc"]) >= 0.09:
				c["acc"] = 0.0
				c["frame"] = int(c["frame"]) + 1
				_apply_chest(c)
	for npc: Dictionary in _npcs:
		var st2: Dictionary = npc["style"]
		var f: int = int(_t * float(st2.get("fps", 6.0))) % int(st2.get("frames", 1))
		(npc["sprite"] as Sprite2D).region_rect.position.x = float(f) * float(st2["fw"])
