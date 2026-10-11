extends Node2D

## YERALTI CANAVARI: ZEMİN ÇATLAKLARI + HAFİF DEPREM (2026-10-10, kullanıcı: "yeraltı canavarı aktifken zeminin çatlaklarla dolu olması ve hafif deprem oluyormuş gibi parçalanmasını
## istiyorum efekt olarak"). Boss (underground_boss.gd) yaşadıkça HER peer'de yerelde çalışan, tamamen görsel bir efekt düğümü:
##  - ZEMİN ÇATLAKLARI: görüntüdeki her CELL px'lik hücrede (tohuma bağlı, her peer'de AYNI) ~%85 olasılıkla 1-2 çatlak karesi; her küme kendi gecikmesiyle (boss doğduktan sonra ilk
##    FADE_IN sn içinde) çıkmaya başlar ve GROW_TIME sn'de 4 büyüme karesinden geçerek tam boyuna uzar (yer yavaş yavaş çatlıyor).
##  - UZUV ÇIKIŞ YILDIZI: her solucan uzvu yüzeye çıkarken (worm_limb.gd POSE_EMERGE, add_burst) o noktada kısa sürede açılan ışınsal çatlak; 16 sn kalır, sonra söner.
##  - DEPREM: kameraya sürekli HAFİF titreme tabanı (QUAKE_FLOOR travma; ayar kapalıysa/duraklayınca hiçbir şey yapmaz), yeraltı gümbürtüsünde (pulse) çatlaklar bir an koyulaşır
##    + birkaç noktada toz kalkar + belirgin ama kısa sarsıntı (underground_boss.gd).
## Boss ölünce çatlaklar FADE_OUT sn içinde solar ve düğüm silinir. KATMAN: haritanın ZEMİN grubunun ("Harita/Yer") hemen üstü - su, uçurum duvarı, ağaç, çalı, bina ve tüm yaratık/oyuncular
## çatlakların ÜSTÜNDE çizilir (ilk sürüm haritanın en üstündeydi: çatlaklar ağaçların üzerinden geçiyordu); harita sınırının dışına konmaz.
## AĞDAN HİÇBİR ŞEY GİTMEZ: boss ve uzuvlar zaten her peer'de var; tohum bossun ağ kimliğinden (aynı çatlaklar herkeste).
##
## SPRITE SAYFALARI (2026-10-10, kullanıcı: "çatlaklar zeminle uyumsuz; çatlaklar olduğunda fps inanılmaz düştü, spritesheet yap"). KÖK NEDEN: eski sürüm görüntüdeki ~100 hücrenin
## yüzlerce çatlağını HER KAREDE _draw() ile (çokgen + çizgi + daire) yeniden çiziyordu - uzuv çıkış yıldızları 19 sn yaşadığı için neredeyse sürekli. Artık her çatlak hazır piksel
## sanatı bir karedir (tools/gen_underground_cracks.py: zemin tonlarında ince yarık + yırtık çim dudağı + kırıntı; siyah kalın çizgi yok), hücre başına Sprite2D havuzu; bölge (kare)
## yalnız büyüme karesi DEĞİŞİNCE yazılır, solma/gümbürtü tek bir modulate. Görüntüye giren/çıkan hücrelerin sprite'ları havuza döner. _draw() YOK.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const CameraShakeScript := preload("res://scripts/camera_shake.gd")
const MinotaurDustScript := preload("res://scripts/minotaur_dust.gd")
const CRACK_SHEET := preload("res://assets/fx/underground_cracks/cracks.png")
const BURST_SHEET := preload("res://assets/fx/underground_cracks/bursts.png")

const GROUP := &"underground_cracks"
const CELL := 112.0 ## çatlak hücresi (dünya px)
const CELL_CHANCE := 0.85 ## hücrede çatlak kümesi olma olasılığı
const FADE_IN := 6.0 ## kümelerin çıkış gecikmesi 0..FADE_IN sn
const GROW_TIME := 2.2 ## bir çatlağın tam boyuna uzaması
const FADE_OUT := 4.0 ## boss gidince solma süresi
const QUAKE_FLOOR := 0.12 ## 2026-10-10: 0,24 -> 0,12 (kullanıcı: "sarsıntıyı biraz daha az yap"); ## sürekli deprem tabanı (kamera travması: genlik 12 x 0,24^2 = ~0,7 dünya px, zoom 2'de ~1,4 ekran px - "hafif")
const QUAKE_RAMP := 2.5 ## taban boss doğduktan bu kadar sn içinde tam değere çıkar
const PULSE_DECAY := 0.9 ## gümbürtü parlaması saniyede bu kadar söner (1 -> 0 ~1,1 sn)
const MAX_BURSTS := 40
const BURST_GROW := 0.22
const BURST_LIFE := 16.0
const BURST_FADE := 3.0
const CACHE_LIMIT := 700
const DUST_PER_PULSE := 2
const CRACK_PX := 64 ## cracks.png karesi (sütun = büyüme karesi, satır = çeşit)
const BURST_PX := 48 ## bursts.png karesi
const CRACK_VARIANTS := 8
const BURST_VARIANTS := 4
const SHEET_FRAMES := 4
const PULSE_TINT := Color(0.78, 0.72, 0.68) ## gümbürtüde çatlaklar bir an koyulaşır (çarpımsal)
const MAP_EDGE_MARGIN := 24.0 ## harita kenarına bu kadar yakın kare konmaz (taşmasın)

var boss: Node = null
var seed_value: int = 0
var _age: float = 0.0
var _fade: float = 0.0 ## 0..1 (boss varken 1'e çıkar, gidince iner)
var _pulse: float = 0.0
var _bursts: Array = [] ## [{"pos": Vector2, "t": float, "variant": int, "node": Sprite2D}]
var _cache: Dictionary = {} ## hücre -> küme (cluster_for)
var _last_view := Rect2i()
var _shown: Dictionary = {} ## hücre -> Array (görüntüdeki hücrelerin çatlak sprite'ları)
var _pool: Array[Sprite2D] = []
var _layer: Node2D = null
var _growing: bool = true
var _rng := RandomNumberGenerator.new()
var force_quake: bool = false ## testler: başsız çalışmada da kamera depremini uygula
var _map_rect: Rect2 = Rect2()
var _map_rect_checked: bool = false


# ---------------------------------------------------------------- static API (boss / uzuv çağırır)
## Boss için efekti kurar (zaten varsa aynı düğümü döndürür). HER peer'de çağrılır.
static func ensure(boss_node: Node) -> Node:
	if boss_node == null or not boss_node.is_inside_tree():
		return null
	var tree: SceneTree = boss_node.get_tree()
	var existing: Node = tree.get_first_node_in_group(GROUP)
	if existing != null and is_instance_valid(existing):
		existing.set("boss", boss_node)
		return existing
	if tree.current_scene == null:
		return null
	var fx: Node2D = (load("res://scripts/underground_cracks.gd") as GDScript).new()
	fx.boss = boss_node
	fx.seed_value = int(boss_node.get_meta("network_enemy_id", 1)) * 7919 + 13
	fx.name = "UndergroundCracks"
	fx.add_to_group(GROUP)
	_place_on_map_ground(tree, fx)
	return fx


## Düğümü haritanın zemin grubunun ("Harita/Yer") HEMEN ÜSTÜNE koyar: su/uçurum/ağaç/çalı/bina/yaratıklar çatlakların üstünde çizilir. Harita yoksa (test/menü) sahne köküne eklenir.
static func _place_on_map_ground(tree: SceneTree, fx: Node2D) -> void:
	var root: Node = tree.current_scene
	var harita: Node = root.get_node_or_null("Harita")
	var ground: Node = harita.get_node_or_null("Yer") if harita != null else null
	if harita != null and ground != null:
		harita.add_child(fx)
		harita.move_child(fx, ground.get_index() + 1)
		## DİKKAT: top_level KULLANMA - Godot top_level bir öğeyi tuval köküne alıp en üste çıkarır (çatlaklar ağaçların/yaratıkların üstünde çizilirdi). Harita ve Main dönüşümleri birim.
	else:
		root.add_child(fx)
		AbilitiesScript.place_on_ground(tree, fx)


## Yeraltı gümbürtüsü: çatlaklar bir an koyulaşır + toz.
static func pulse(tree: SceneTree) -> void:
	var fx: Node = tree.get_first_node_in_group(GROUP) if tree != null else null
	if fx != null and is_instance_valid(fx):
		fx.call("_on_pulse")


## Bir uzuv yüzeye çıktı: o noktada ışınsal çatlak yıldızı.
static func add_burst(tree: SceneTree, pos: Vector2) -> void:
	var fx: Node = tree.get_first_node_in_group(GROUP) if tree != null else null
	if fx != null and is_instance_valid(fx):
		fx.call("_add_burst", pos)


## Hücrenin çatlak kümesi (saf, tohum + hücreye göre AYNI sonuç; testli). Boş sözlük = bu hücrede çatlak yok.
## {"origin": Vector2, "delay": 0..FADE_IN, "decals": Array[{"pos","v" (sayfa satırı),"fh","fv"}], "cracks": Array[{"pts","w"}], "chips": PackedVector2Array}
## GÖRÜNEN = "decals" (sprite kareleri). "cracks"/"chips" eski geometri verisi: artık çizilmez, toz noktaları/testler için duruyor.
static func cluster_for(cell: Vector2i, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, seed_v))
	if rng.randf() > CELL_CHANCE:
		return {}
	var origin := Vector2((float(cell.x) + rng.randf()) * CELL, (float(cell.y) + rng.randf()) * CELL)
	var cracks: Array = []
	var chips := PackedVector2Array()
	for m in range(rng.randi_range(2, 3)):
		var angle: float = rng.randf() * TAU
		var pts := PackedVector2Array([origin + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))])
		for st in range(rng.randi_range(6, 10)):
			angle += rng.randf_range(-0.55, 0.55)
			pts.append(pts[pts.size() - 1] + Vector2.from_angle(angle) * rng.randf_range(7.0, 14.0))
		cracks.append({"pts": pts, "w": rng.randf_range(1.8, 2.6)})
		chips.append(pts[rng.randi_range(1, pts.size() - 1)])
	var decals: Array = []
	for d in range(rng.randi_range(1, 2)):
		var at: Vector2 = origin
		if d > 0:
			at += Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
		decals.append({"pos": at.round(), "v": rng.randi() % CRACK_VARIANTS, "fh": rng.randf() < 0.5, "fv": rng.randf() < 0.5})
	return {"origin": origin, "delay": rng.randf() * FADE_IN, "decals": decals, "cracks": cracks, "chips": chips}


## Uzuv çıkış yıldızı: 6-9 zikzaklı kol (saf; `rng` testlerde tohumlanır). Artık görsel bursts.png'den; bu veri yalnız geometri/test için.
static func burst_spokes(rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var count: int = rng.randi_range(6, 9)
	var base: float = rng.randf() * TAU
	for i in range(count):
		var angle: float = base + float(i) / float(count) * TAU + rng.randf_range(-0.2, 0.2)
		var length: float = rng.randf_range(20.0, 46.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		var steps: int = rng.randi_range(3, 4)
		for k in range(steps):
			angle += rng.randf_range(-0.45, 0.45)
			pts.append(pts[pts.size() - 1] + Vector2.from_angle(angle) * length / float(steps))
		out.append(pts)
	return out


## Büyüme oranından (0..1) sayfa karesi: -1 = henüz çıkmadı, 0..SHEET_FRAMES-1 (saf, testli).
static func grow_frame(grow: float) -> int:
	if grow <= 0.0:
		return -1
	return mini(SHEET_FRAMES - 1, int(ceil(clampf(grow, 0.0, 1.0) * float(SHEET_FRAMES - 1))))


# ---------------------------------------------------------------- yaşam döngüsü
func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_layer = Node2D.new()
	_layer.name = "Decals"
	add_child(_layer)


func _boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and boss.get("is_dead") != true


func _process(delta: float) -> void:
	var alive: bool = _boss_alive()
	if alive:
		_age += delta
		_fade = minf(1.0, _fade + delta / 1.5)
		_quake()
	else:
		_fade -= delta / FADE_OUT
		if _fade <= 0.0:
			queue_free()
			return
		_growing = true ## solarken hepsi tam boy
	_pulse = maxf(0.0, _pulse - delta * PULSE_DECAY)
	modulate = Color.WHITE.lerp(PULSE_TINT, _pulse) * Color(1.0, 1.0, 1.0, clampf(_fade, 0.0, 1.0))
	_update_bursts(delta)
	var view: Rect2i = _view_cells()
	if view != _last_view:
		_last_view = view
		_sync_cells(view)
	if _growing:
		_growing = _update_growth()


## Görüntüdeki hücre kümesini günceller: çıkan hücrelerin sprite'ları havuza, giren hücrelere sprite.
func _sync_cells(view: Rect2i) -> void:
	for cell: Vector2i in _shown.keys():
		if not view.has_point(cell):
			for sp: Sprite2D in _shown[cell]:
				sp.visible = false
				_pool.append(sp)
			_shown.erase(cell)
	for cx in range(view.position.x, view.end.x):
		for cy in range(view.position.y, view.end.y):
			var cell := Vector2i(cx, cy)
			if _shown.has(cell):
				continue
			var list: Array = []
			var cl: Dictionary = _cluster(cell)
			for d: Dictionary in cl.get("decals", []):
				var pos: Vector2 = d["pos"]
				if not _inside_map(pos):
					continue
				var sp: Sprite2D = _take_sprite()
				sp.position = pos
				sp.flip_h = bool(d["fh"])
				sp.flip_v = bool(d["fv"])
				sp.set_meta(&"row", int(d["v"]))
				sp.set_meta(&"delay", float(cl["delay"]))
				sp.set_meta(&"frame", -2)
				_apply_growth(sp)
				list.append(sp)
			_shown[cell] = list
	_growing = true


func _take_sprite() -> Sprite2D:
	var sp: Sprite2D = _pool.pop_back() if not _pool.is_empty() else null
	if sp == null:
		sp = Sprite2D.new()
		sp.texture = CRACK_SHEET
		sp.region_enabled = true
		_layer.add_child(sp)
	return sp


## Kareyi yalnız DEĞİŞİNCE yazar. Dönüş: hâlâ büyüyor mu.
func _apply_growth(sp: Sprite2D) -> bool:
	var grow: float = (_age - float(sp.get_meta(&"delay"))) / GROW_TIME
	if not _boss_alive():
		grow = 1.0 ## boss gittikten sonra solarken çatlaklar geri kapanmasın (alfa iner)
	var frame: int = grow_frame(grow)
	if frame != int(sp.get_meta(&"frame")):
		sp.set_meta(&"frame", frame)
		sp.visible = frame >= 0
		if frame >= 0:
			sp.region_rect = Rect2(frame * CRACK_PX, int(sp.get_meta(&"row")) * CRACK_PX, CRACK_PX, CRACK_PX)
	return frame < SHEET_FRAMES - 1


func _update_growth() -> bool:
	var any: bool = false
	for cell: Vector2i in _shown:
		for sp: Sprite2D in _shown[cell]:
			if _apply_growth(sp):
				any = true
	return any


func _update_bursts(delta: float) -> void:
	if _bursts.is_empty():
		return
	var keep: Array = []
	for b: Dictionary in _bursts:
		b["t"] = float(b["t"]) + delta
		var t: float = float(b["t"])
		var sp: Sprite2D = b.get("node")
		if t >= BURST_LIFE + BURST_FADE:
			if sp != null and is_instance_valid(sp):
				sp.queue_free()
			continue
		keep.append(b)
		if sp == null or not is_instance_valid(sp):
			continue
		if t < BURST_GROW + 0.1:
			var frame: int = maxi(0, grow_frame(t / BURST_GROW))
			sp.region_rect = Rect2(frame * BURST_PX, int(b["variant"]) * BURST_PX, BURST_PX, BURST_PX)
		elif t > BURST_LIFE:
			sp.self_modulate.a = clampf((BURST_LIFE + BURST_FADE - t) / BURST_FADE, 0.0, 1.0)
	_bursts = keep


## Sürekli HAFİF deprem: kamera travması en az QUAKE_FLOOR (ayar kapalıysa add() zaten hiçbir şey yapmaz). Duraklayınca sürücü ofseti sıfırlar.
func _quake() -> void:
	if DisplayServer.get_name() == "headless" and not force_quake:
		return
	var want: float = QUAKE_FLOOR * clampf(_age / QUAKE_RAMP, 0.0, 1.0)
	if CameraShakeScript.trauma < want:
		CameraShakeScript.add(want - CameraShakeScript.trauma)


func _on_pulse() -> void:
	_pulse = 1.0
	if get_tree() == null:
		return
	var cells: Array = _shown.keys()
	if cells.is_empty():
		return
	for i in range(DUST_PER_PULSE):
		var cl: Dictionary = _cluster(cells[_rng.randi() % cells.size()])
		if cl.is_empty():
			continue
		var at: Vector2 = cl["origin"]
		if _inside_map(at):
			MinotaurDustScript.burst(get_tree(), at, Vector2.UP, 0.08)


func _add_burst(pos: Vector2) -> void:
	if _bursts.size() >= MAX_BURSTS:
		var old: Dictionary = _bursts.pop_front()
		var osp: Sprite2D = old.get("node")
		if osp != null and is_instance_valid(osp):
			osp.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(pos.x), roundi(pos.y), seed_value))
	var variant: int = rng.randi() % BURST_VARIANTS
	var sp: Sprite2D = null
	if _layer != null and _inside_map(pos):
		sp = Sprite2D.new()
		sp.texture = BURST_SHEET
		sp.region_enabled = true
		sp.region_rect = Rect2(0, variant * BURST_PX, BURST_PX, BURST_PX)
		sp.position = pos.round()
		sp.flip_h = rng.randf() < 0.5
		_layer.add_child(sp)
	_bursts.append({"pos": pos, "t": 0.0, "variant": variant, "node": sp})


# ---------------------------------------------------------------- görüntü
## Haritanın dünya dikdörtgeni (GameManager.get_map_world_rect; harita yoksa/boşsa Rect2() = kırpma yok). Otoyükleme düğümü yolla okunur (test/araç betiklerinde de güvenli).
func _inside_map(p: Vector2) -> bool:
	if not _map_rect_checked:
		_map_rect_checked = true
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("get_map_world_rect"):
			_map_rect = gm.call("get_map_world_rect")
	return _map_rect.size == Vector2.ZERO or _map_rect.grow(-MAP_EDGE_MARGIN).has_point(p)


## Görüntünün (kamera) çevresindeki hücre aralığı: Rect2i(ilk hücre, hücre sayısı). Kamera yoksa (başsız/test) boş.
func _view_cells() -> Rect2i:
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Rect2i()
	var size: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var center: Vector2 = cam.get_screen_center_position()
	var first := Vector2i(floori((center.x - size.x * 0.5) / CELL) - 1, floori((center.y - size.y * 0.5) / CELL) - 1)
	var last := Vector2i(floori((center.x + size.x * 0.5) / CELL) + 1, floori((center.y + size.y * 0.5) / CELL) + 1)
	return Rect2i(first, last - first + Vector2i.ONE)


func _cluster(cell: Vector2i) -> Dictionary:
	if not _cache.has(cell):
		if _cache.size() > CACHE_LIMIT:
			_cache.clear()
		_cache[cell] = cluster_for(cell, seed_value)
	return _cache[cell]
