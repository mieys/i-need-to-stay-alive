extends SceneTree

## YÜKLEME EKRANI arka planı PROTOTİPLERİ - GERÇEK HARİTA (2026-10-17, oyuna bağlı DEĞİL).
## Kullanıcı ("Eve Dönüş" elle dizilmiş sahnesi için): "bunu sevmedim çevre çok ruhsuz gölgeler hatalı ve herşey havada duruyor shader
## bile yok". -> Arka plan oyunun KENDİ haritası (scenes/harita_baked.tscn) + main.gd'nin harita görsel sistemleri (sallanan ot/ağaç,
## orman örtüsü, pişmiş tepe gölgeleri, renk ayarı, su shader'ı, zemin geçişi) + oyunun gün-gece renk geçişi (atmosphere_overlay.gd,
## AtmosphereMath.grade). Üstünde GERÇEK yükleme arayüzü (loading_screen.tscn, kendi arka planı gizli, yükleyici kapalı).
## Kamera zoom 3 = harita pikseli başına 3 ekran pikseli (kahramanın ızgarası).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/yukleme_harita_proto.gd
##   YK_CAP_DIR = çıktı klasörü (zorunlu), YK_ONLY = "a,c" gibi seçili noktalar (boşsa hepsi).

const W := 1920.0
const H := 1080.0
const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")

## v2: kovalamaca DÜNYADA - kahraman + yaratıklar gerçek yolun üstünde (karelerindeki gömülü gölgeleriyle), bar ekranın altında.
## [kısa ad, açıklama, kamera merkezi (dünya), yol aranacak ekran y'si (merkeze göre, dünya px)]
const SPOTS: Array = [
	["a", "Sirt yolu", Vector2(1700, 2830), 20.0],
	["b", "Ev + nehir koprusu", Vector2(1480, 2400), 40.0],
	["c", "Tas kopruler", Vector2(2150, 1700), 30.0],
]
const TIMES: Array = [["gb", 362.0], ["gece", 440.0]] ## gün batımı, gece
const CHASERS: Array[String] = ["slime1", "slime2", "iskelet1", "zombie1", "slime3"]
const ES := preload("res://scripts/entity_scale.gd")

var _out := ""
var _world: Node2D = null
var _cam: Camera2D = null
var _overlay: CanvasLayer = null
var _ls: Control = null
var _actors: Node2D = null
var _toprak: TileMapLayer = null
var _cimen: TileMapLayer = null


func _initialize() -> void:
	_out = OS.get_environment("YK_CAP_DIR")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_setup_world()
	for i in range(40):
		await process_frame
	if OS.get_environment("YK_SCOUT") != "":
		await _scout()
		quit()
		return
	var only: String = OS.get_environment("YK_ONLY")
	for s: Array in SPOTS:
		if only != "" and not only.split(",").has(s[0]):
			continue
		_cam.position = s[2]
		_place_chase(s[2], float(s[3]), 0.45)
		for t: Array in TIMES:
			_overlay.call("apply", AtmosphereMath.grade(float(t[1]), 0.0, 0.0), false)
			for i in range(24):
				await process_frame
			var img: Image = root.get_texture().get_image()
			img.save_png(_out.path_join("yk2_%s_%s.png" % [s[0], t[0]]))
			print("shot ", s[0], " ", t[0])
	quit()


## Yol = çimen katmanı BOŞ (toprak görünen) hücreler. Ekranın her 8 dünya px'lik sütununda hedef y'ye en yakın toprak koşusunun ortası.
func _road_path(center: Vector2, target_dy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := Vector2(W, H) * 0.5 / _cam.zoom
	var prev_y: float = center.y + target_dy
	var x: float = center.x - half.x - 40.0
	while x <= center.x + half.x + 40.0:
		var best: float = INF
		var best_y: float = prev_y
		var run_start: float = NAN
		var y: float = prev_y - 90.0
		while y <= prev_y + 90.0:
			var dirt: bool = _is_dirt(Vector2(x, y))
			if dirt and is_nan(run_start):
				run_start = y
			if (not dirt or y + 4.0 > prev_y + 90.0) and not is_nan(run_start):
				var mid: float = (run_start + y) * 0.5
				if y - run_start >= 16.0 and absf(mid - prev_y) < best:
					best = absf(mid - prev_y)
					best_y = mid
				run_start = NAN
			y += 4.0
		prev_y = lerpf(prev_y, best_y, 0.6)
		pts.append(Vector2(x, prev_y))
		x += 8.0
	return pts


func _is_dirt(wp: Vector2) -> bool:
	var c: Vector2i = _cimen.local_to_map(_cimen.to_local(wp))
	if _cimen.get_cell_source_id(c) != -1:
		return false
	var t: Vector2i = _toprak.local_to_map(_toprak.to_local(wp))
	return _toprak.get_cell_source_id(t) != -1


func _path_at(pts: PackedVector2Array, x: float) -> Vector2:
	for i in range(pts.size() - 1):
		if x <= pts[i + 1].x:
			var k: float = clampf((x - pts[i].x) / maxf(1.0, pts[i + 1].x - pts[i].x), 0.0, 1.0)
			return pts[i].lerp(pts[i + 1], k).round()
	return pts[pts.size() - 1].round()


func _place_chase(center: Vector2, target_dy: float, ratio: float) -> void:
	for c in _actors.get_children():
		c.free()
	var pts: PackedVector2Array = _road_path(center, target_dy)
	var half_w: float = W * 0.5 / _cam.zoom.x
	var hx: float = center.x - half_w + 30.0 + (half_w * 2.0 - 60.0) * ratio
	## kahraman
	var d: Dictionary = Characters.get_def(int(root.get_node("GameManager").get("selected_char_id")))
	var sf: SpriteFrames = load(str(d.get("frames", ""))) as SpriteFrames
	var hero := AnimatedSprite2D.new()
	hero.sprite_frames = sf
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.scale = (d.get("scale", Vector2(1.27575, 1.27575)) as Vector2) * float(ES.SIZE) * 0.5
	hero.offset = d.get("offset", Vector2(0, -5)) as Vector2
	hero.play("run_right" if sf.has_animation("run_right") else "walk_right")
	var foot: float = _ls.call("_foot_offset", sf.get_frame_texture(hero.animation, 0)) * hero.scale.y
	hero.position = _path_at(pts, hx) - Vector2(0, foot)
	_actors.add_child(hero)
	## yaratıklar (yaratık sahnesinin kendi Sprite2D ölçeği; gölge karelerinde gömülü)
	for i in range(CHASERS.size()):
		var e: Node = (load("res://scenes/creatures/enemy_%s.tscn" % CHASERS[i]) as PackedScene).instantiate()
		var tex: Texture2D = e.get("walk_texture")
		var cell: int = int(e.get("cell_size"))
		var src: Sprite2D = e.get_node_or_null("Sprite2D") as Sprite2D
		var sc: float = src.scale.x if src else 1.0
		e.free()
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.hframes = maxi(1, int(tex.get_width() / cell))
		sp.vframes = 4
		sp.frame = 3 * sp.hframes + (i * 2) % sp.hframes
		sp.scale = Vector2.ONE * sc * float(ES.SIZE)
		var ff: float = _ls.call("_foot_offset", tex, Rect2i(0, 3 * cell, cell, cell)) * sp.scale.y
		sp.position = _path_at(pts, hx - 56.0 - i * 44.0) - Vector2(0, ff)
		_actors.add_child(sp)


## Keşif: arayüz gizli, zoom 2, gündüz - yatay yol aranır.
func _scout() -> void:
	(_ls.get("_overlay") as CanvasLayer).visible = false
	_cam.zoom = Vector2(2.0, 2.0)
	_overlay.call("apply", AtmosphereMath.grade(100.0, 0.0, 0.0), false)
	var pts: Array = [Vector2(900, 2846), Vector2(1700, 2846), Vector2(2500, 2846), Vector2(1250, 820), Vector2(1550, 2400),
		Vector2(2400, 2250), Vector2(3000, 2950), Vector2(2200, 1700)]
	for i in range(pts.size()):
		_cam.position = pts[i]
		for k in range(12):
			await process_frame
		root.get_texture().get_image().save_png(_out.path_join("scout_%d.png" % i))
		print("scout ", i)


func _setup_world() -> void:
	_world = Node2D.new()
	_world.name = "Main"
	root.add_child(_world)
	current_scene = _world
	var map: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	map.name = "Harita"
	_world.add_child(map)
	## main.gd ile aynı sıra (bkz. main.gd "Sallanan otlar" bloğu).
	load("res://scripts/grass_sway.gd").new().setup(map)
	load("res://scripts/tree_sway.gd").new().setup(map)
	load("res://scripts/forest_canopy.gd").new().setup(map)
	load("res://scripts/map_shadows.gd").attach(map)
	load("res://scripts/map_color_grade.gd").attach(map)
	load("res://scripts/water_fx.gd").attach(map)
	load("res://scripts/ground_texel_pass.gd").attach(map)
	_toprak = map.get_node("Yer/Zemin Toprak") as TileMapLayer
	_cimen = map.get_node("Yer/Zemin Çimen") as TileMapLayer
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.z_index = 1
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(3.0, 3.0)
	_world.add_child(_cam)
	_cam.make_current()
	_overlay = load("res://scripts/atmosphere_overlay.gd").new()
	root.add_child(_overlay)
	## Gerçek yükleme arayüzü (bar + kahraman + yaratıklar + yazılar); kendi sahne arka planı gizli, yükleyici kapalı.
	_ls = (load("res://scenes/loading_screen.tscn") as PackedScene).instantiate()
	_ls.set("autostart_loader", false)
	root.add_child(_ls)
	_ls.set_process(false)
	var sc: Control = _ls.get("_scene")
	if sc:
		sc.visible = false
	(_ls.get("progress_bar") as ProgressBar).value = 45.0
	(_ls.get("_stage") as Control).visible = false
	## v2 arayüz: bar ekranın altında ince bir şerit, yazılar üstünde/altında.
	_ls.call("_center_anchor", _ls.get("progress_bar"), Rect2(-520, 452, 1040, 22))
	_ls.call("_center_anchor", _ls.get("status_label"), Rect2(-520, 398, 1040, 44))
	var tip: Control = (_ls.get("_overlay") as Node).find_child("TipLabel", true, false) as Control
	if tip:
		_ls.call("_center_anchor", tip, Rect2(-520, 486, 1040, 32))
