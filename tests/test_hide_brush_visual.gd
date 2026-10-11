extends Node

## Saklanma çalılığı görünümü (2026-10-10): sallanan çalı kümeleri + içindeki karakterin üstüne yarı saydam yaprak + içinden yürüyünce hışırtı.
## Pikselin GPU'da gerçekten nasıl göründüğü ekranlı ekran görüntüsüyle bakıldı; burada kurulum/veri/kural testleri var.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const VisualScript := preload("res://scripts/hide_brush_visual.gd")
const HideBrushScript := preload("res://scripts/hide_brush.gd")

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	HideBrushScript.reset()
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _real_map() -> Array:
	var main := Node2D.new()
	main.name = "Main"
	_track(main)
	add_child(main)
	var harita: Node = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	main.add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	return [harita, dep]


func test_real_map_brush_layer_gets_sway_material_and_front_copy() -> void:
	var r: Array = _real_map()
	var harita: Node = r[0]
	var dep: Node = r[1]
	var layer: TileMapLayer = HideBrushScript.find_layer(harita)
	assert(layer != null, "çalılık katmanı bulunamadı")
	assert(dep.brush_visual != null, "görünüm kurulmadı")
	var mat := layer.material as ShaderMaterial
	assert(mat != null and mat.shader.resource_path.ends_with("saklanma_calilik.gdshader"), "yer katmanı sallanan shader'ı almadı")
	var front: Dictionary = {}
	for f: Dictionary in dep.fronts:
		if f["mode"] == "brush":
			front = f
	assert(not front.is_empty(), "ön kopya yok")
	var fm := (front["front"] as TileMapLayer).material as ShaderMaterial
	assert(fm.get_shader_parameter("on_katman") == true and mat.get_shader_parameter("on_katman") != true)
	## yer katmanı ile kopya AYNI sallanma verisini kullanır (aksi halde kopya kayık görünür)
	assert(fm.get_shader_parameter("veri_sway") == mat.get_shader_parameter("veri_sway"))
	assert(fm.get_shader_parameter("egilme_veri") == mat.get_shader_parameter("egilme_veri"))
	_cleanup()


## 2026-10-10: her dolu hücre BAĞIMSIZ bir çalı (tek karelik çalılar): küme yok, hücre başına grup + kendi kökü/fazı.
func test_every_filled_cell_is_its_own_bush_with_its_own_root() -> void:
	var r: Array = _real_map()
	var layer: TileMapLayer = HideBrushScript.find_layer(r[0])
	var a: Dictionary = VisualScript.analyze(layer)
	var groups: Dictionary = a["groups"]
	assert(groups.size() >= 300, "tek karelik çalı sayısı: %d" % groups.size())
	assert(groups.size() == (a["rows"] as Dictionary).size(), "her hücre ayrı grup olmalı")
	assert(layer.get_used_cells().size() == groups.size(), "katmandaki her hücre bir çalı (boş karo yok)")
	var bases: Dictionary = VisualScript.root_bases(layer, a)
	var origin: Vector2 = VisualScript.cell_origin(layer)
	for g: int in groups:
		var cells: Array = groups[g]["cells"]
		assert(cells.size() == 1, "grupta tek hücre olmalı")
		var c: Vector2i = cells[0]
		## kök = o hücrenin tabanı (en fazla hücre altı), komşunun köküyle karışmaz
		assert(float(bases[c]) > origin.y + c.y * 16.0 and float(bases[c]) <= origin.y + c.y * 16.0 + 16.0, "kök hücrenin içinde")
	## Komşu bir hücre çifti bulunursa farklı grup
	for c: Vector2i in a["gid"]:
		if (a["gid"] as Dictionary).has(c + Vector2i(1, 0)):
			assert(a["gid"][c] != a["gid"][c + Vector2i(1, 0)], "bitişik hücreler farklı çalı")
			break
	_cleanup()


func _any_cells(vis: Node) -> Array:
	## İçinde durulacak hücre + ondan çok uzak başka bir hücre + dik komşusu olan bir hücre (varsa)
	var cells: Array = vis._cell_gid.keys()
	cells.sort()
	return cells


func _cell_center(vis: Node, cell: Vector2i) -> Vector2:
	return vis.layer.to_global(vis.layer.map_to_local(cell))


func test_walking_inside_rustles_only_around_the_character_and_settles_after_leaving() -> void:
	var r: Array = _real_map()
	var vis: Node = r[1].brush_visual
	var cells: Array = _any_cells(vis)
	assert(cells.size() >= 100, "yeterince çalı yok")
	var here: Vector2i = cells[0]
	var feet: Vector2 = _cell_center(vis, here) + Vector2(0.0, VisualScript.RUSTLE_CENTER_UP)
	var far: Vector2i = here
	for c: Vector2i in cells:
		if _cell_center(vis, c).distance_to(feet) > _cell_center(vis, far).distance_to(feet):
			far = c
	assert(_cell_center(vis, far).distance_to(feet) > VisualScript.RUSTLE_RADIUS * 2.0, "uzak hücre yeterince uzak değil")
	var mx_here: float = 0.0
	var mx_far: float = 0.0
	for i in range(60):
		vis.step(1.0 / 30.0, [[feet, 120.0, 1.0]])
		mx_here = maxf(mx_here, absf(vis.bend_at(here)))
		mx_far = maxf(mx_far, absf(vis.bend_at(far)))
	assert(mx_here > 0.5, "karakterin olduğu yer sallanmadı (en çok %f)" % mx_here)
	assert(mx_far < 0.001, "karakterden uzak çalı kısmı da sallandı (%f)" % mx_far)
	for i in range(300):
		vis.step(1.0 / 30.0, [])
	assert(absf(vis.bend_at(here)) < 0.05 and vis._state.is_empty(), "çıkınca çalı durulmadı")
	_cleanup()


func test_standing_still_inside_does_not_rustle_but_entering_gives_an_impulse() -> void:
	var r: Array = _real_map()
	var vis: Node = r[1].brush_visual
	var cells: Array = _any_cells(vis)
	var here: Vector2i = cells[0]
	var feet: Vector2 = _cell_center(vis, here) + Vector2(0.0, VisualScript.RUSTLE_CENTER_UP)
	for i in range(20):
		vis.step(1.0 / 30.0, [[feet, 0.0, 1.0]])
	assert(absf(vis.bend_at(here)) < 0.01, "yerinde duran karakter çalıyı sallamamalı")
	vis._state.clear()
	vis.step(1.0 / 30.0, [[feet, 100.0, 1.0]])
	assert(vis._state.has(here) and absf(float(vis._state[here][1])) > 1.0, "girişte itki yok")
	_cleanup()


func test_the_bush_has_no_ambient_wind_sway() -> void:
	var r: Array = _real_map()
	var layer: TileMapLayer = HideBrushScript.find_layer(r[0])
	var mat := layer.material as ShaderMaterial
	assert(is_equal_approx(float(mat.get_shader_parameter("strength")), VisualScript.AMBIENT_STRENGTH))
	assert(VisualScript.AMBIENT_STRENGTH == 0.0, "kullanıcı sadece bulunduğu noktanın sallanmasını istedi")
	_cleanup()


func test_character_inside_gets_translucent_foliage_outside_gets_full() -> void:
	var r: Array = _real_map()
	var dep: Node = r[1]
	var layer: TileMapLayer = HideBrushScript.find_layer(r[0])
	HideBrushScript.set_layer_override(layer)
	var inside: Vector2 = layer.to_global(layer.map_to_local((layer.get_used_cells())[0]))
	var outside: Vector2 = inside + Vector2(900.0, 900.0)
	assert(HideBrushScript.contains(get_tree(), inside) and not HideBrushScript.contains(get_tree(), outside))
	var chars: Array[Vector4] = [Vector4(inside.x, inside.y, 8.0, 30.0), Vector4(outside.x, outside.y, 8.0, 30.0)]
	dep._update_brush_alpha(chars)
	var m: ShaderMaterial = dep._brush_materials[0]
	var vals: Array = m.get_shader_parameter("karakter_orter")
	assert(is_equal_approx(float(vals[0]), VisualScript.INSIDE_FOLIAGE_ALPHA + 1.0), "içerideki karakter yarı saydam yaprak almadı: %s" % str(vals))
	assert(is_equal_approx(float(vals[1]), 2.0), "dışarıdaki karakter tam örtü almalı")
	assert(VisualScript.INSIDE_FOLIAGE_ALPHA <= 0.7, "içerideki karakter yaprakların arkasında hâlâ seçilebilmeli (2026-10-10: 0,65)")
	_cleanup()


## Tek karelik çalılar: karakterin durduğu hücredeki çalı en çok sallanır; çaprazdaki komşu (22,6 px) hiç oynamaz, dik komşu (16 px) belirgin daha az.
func test_only_the_cell_the_character_stands_in_really_rustles() -> void:
	var r: Array = _real_map()
	var vis: Node = r[1].brush_visual
	var here := Vector2i(-1, -1)
	var side := Vector2i(-1, -1)
	var diag := Vector2i(-1, -1)
	for c: Vector2i in vis._cell_gid.keys():
		if side.x < 0 and vis._cell_gid.has(c + Vector2i(1, 0)):
			here = c
			side = c + Vector2i(1, 0)
		if diag.x < 0 and vis._cell_gid.has(c + Vector2i(1, 1)):
			diag = c + Vector2i(1, 1)
			if here.x < 0:
				here = c
	if here.x < 0 or not vis._cell_gid.has(here + Vector2i(1, 1)):
		return ## haritada çaprazı dolu hücre yoksa kontrol edilecek bir şey yok
	var feet: Vector2 = _cell_center(vis, here) + Vector2(0.0, VisualScript.RUSTLE_CENTER_UP)
	var mx_here: float = 0.0
	var mx_diag: float = 0.0
	for i in range(60):
		vis.step(1.0 / 30.0, [[feet, 120.0, 1.0]])
		mx_here = maxf(mx_here, absf(vis.bend_at(here)))
		mx_diag = maxf(mx_diag, absf(vis.bend_at(here + Vector2i(1, 1))))
	assert(mx_here > 0.5, "durulan hücredeki çalı sallanmalı: %f" % mx_here)
	assert(mx_diag < mx_here * 0.35, "çaprazdaki komşu çalı neredeyse sallanmamalı: %f (durulan %f)" % [mx_diag, mx_here])
	_cleanup()
