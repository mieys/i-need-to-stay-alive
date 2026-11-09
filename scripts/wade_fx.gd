extends Node

## SUYA GİREN AYAKLAR (madde 525, Kara Bataklık; kullanıcı: "bataklık sularından geçilebilmeli ancak geçerken karakterlerin (uçanlar hariç)
## ayakları suya girmiş gibi görünmeli, hafif derinlik hissi olmalı"). main.gd kurar (MapProfiles.water_walkable()). Tamamen görsel + yerel:
## her ekran kendi gördüğü karakterleri çizer, ağ olayı YOK (konumlar zaten eşitli, su maskesi haritanın sabit verisi).
##
## Kim: yerel oyuncu + uzak oyuncu kuklaları ("player" / "remote_players"), yerde yürüyen evciller (Kirpi, Minik Cadı; sahibin çocuğu),
## çağrılan dostlar ("player_allies"; süzülen Hayalet Hizmetkâr hariç) ve görüntüdeki yaratıklar (EnemyQuery). UÇANLAR HARİÇ: yarasa formu,
## süpürge (süren + yolcu), Melek havalanması, Büyücü Yükselişi, Hadime Q süzülmesi, Shaman golem sıçrayışı, Matthew Elektrik Topu, ruh hâli;
## yaratıklarda hayalet / yarasa / uçan şeytan / banshee / röntgen (süzülen göz) / yeraltı kurtları (FLYING_FAMILIES).
##
## Nasıl: karakterin ayak noktası (main._creature_foot_y: sprite'ın görünen alt satırı, boy buff'ları dahil) su maskesinde suysa
## (assets/map/bataklik_su_derinlik.png, 2 dünya px / teksel, değer = kıyıya uzaklık) karakterin sprite'ının HEMEN ARDINA bir örtü düğümü
## (aynı z, sprite'ın kardeşi -> önündeki/arkasındaki karakterlerle çizim sırası doğru) eklenir; örtü scenes/bataklik_su_ayak.gdshader ile
## ayağın çevresine suyun kendi rengini boyar (şerit + su çizgisi + halkalar, kıyıda kara piksele taşmaz). Derinlik kıyıda 1-2 px, kıyıdan
## uzaklaştıkça artar (oyuncu en çok DEPTH_PLAYER, yaratık boyuna oranla). Hareket ederken halka sık, dururken seyrek.
## Maliyet: yalnız görüntüdeki ve suda olan karakterlere örtü çizilir (örtü başına tek dörtgen); yaratıklar her WADE_ENEMY_EVERY karede bir
## yoklanır, örtüsü olanlar her kare.

const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
const SHADER := preload("res://scenes/bataklik_su_ayak.gdshader")
const MASK_TEXEL := 2.0
const FLYING_FAMILIES := {"hayalet": true, "yarasa": true, "ucansetan": true, "banshee": true, "rontgen": true, "underground": true,
	"sandworm": true}
const PET_NODES: Array[String] = ["Kirpi", "Slime"]
const MELEK_ASCEND_SCENE := "res://scenes/fx_melek_ascend.tscn"
const DEPTH_PLAYER := 5.0      ## oyuncunun en derin su çizgisi (ayaktan px; karakter ~29 px boyunda -> baldır)
const DEPTH_MIN := 1.0
const DEPTH_CREATURE_RATIO := 0.15
const DEPTH_CREATURE_MAX := 8.0
const CREATURE_SHADOW_PAD := 2.0 ## yaratık karelerinin altında gömülü gölge var: ayak satırı gölgenin altı -> su çizgisi biraz yukarı
const HALF_PLAYER := 7.0
const RING_GROW := 9.0
const RING_LIFE := 0.8         ## halkanın büyüyüp sönme süresi (sn)
const RING_EVERY_MOVING := 0.38
const RING_EVERY_IDLE := 1.7
const MOVE_EPS := 6.0          ## px/sn üstü = hareket
const WADE_ENEMY_EVERY := 2
const VIEW_PAD := 64.0
const OVERLAY_NAME := "SuAyakOrtusu"

var _mask_img: Image = null
var _mask_tex: Texture2D = null
var _mask_size := Vector2.ONE
var _overlays: Dictionary = {} ## sahip örnek kimliği -> Overlay
var _frame: int = 0
var _main: Node = null


class Overlay extends Node2D:
	var owner_node: Node2D = null
	var mat: ShaderMaterial = null
	var half: float = 7.0
	var depth: float = 3.0
	var feet := Vector2.ZERO
	var rings := [Vector2(1.0, 0.0), Vector2(1.0, 0.0)] ## (faz, güç)
	var ring_timer: float = 0.0
	var last_pos := Vector2.INF
	var seen_frame: int = -1
	var shadow: CanvasItem = null ## sahibin ayak gölgesi ("Shadow", ground_shadow.gd): suyun içinde koyu delik gibi duruyordu -> suda gizli

	## Suda / değil: örtü görünürlüğü + ayak gölgesi (self_modulate: gölgenin başka kodlarca kullanılan visible / modulate'ine dokunmaz).
	func set_wading(on: bool) -> void:
		if visible != on:
			visible = on
		if shadow != null and is_instance_valid(shadow):
			shadow.self_modulate.a = 0.0 if on else 1.0

	func _draw() -> void:
		## Dünya koordinatında tek dörtgen (sahibin ölçek / çevirmesinden bağımsız); shader dünya pikseline göre çizer.
		draw_set_transform_matrix(get_global_transform().affine_inverse())
		var rx: float = half + 1.0 + RING_GROW + 1.0
		var ry: float = maxf(2.0, rx * 0.42) + 1.0
		var top: float = feet.y - depth - ry - 1.0
		var bottom: float = feet.y + maxf(ry - depth, 0.0) + 3.0
		draw_rect(Rect2(feet.x - rx - 1.0, top, rx * 2.0 + 3.0, bottom - top), Color.WHITE)


func _ready() -> void:
	name = "WadeFx"
	var path: String = str(MapProfilesScript.current().get("su_maskesi", ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("WadeFx: su maskesi yok (%s) - tools/bataklik/gen_bataklik.py --write" % path)
		set_process(false)
		return
	_mask_tex = load(path) as Texture2D
	_mask_img = _mask_tex.get_image() if _mask_tex != null else null
	if _mask_img == null:
		set_process(false)
		return
	if _mask_img.is_compressed():
		_mask_img.decompress()
	_mask_size = Vector2(_mask_img.get_size())


## Dünya konumundaki su değeri 0..1 (0 = kara / maske dışı).
func water_at(world: Vector2) -> float:
	if _mask_img == null:
		return 0.0
	var tx: int = floori(world.x / MASK_TEXEL)
	var ty: int = floori(world.y / MASK_TEXEL)
	if tx < 0 or ty < 0 or tx >= int(_mask_size.x) or ty >= int(_mask_size.y):
		return 0.0
	var v: float = _mask_img.get_pixel(tx, ty).r
	return 0.0 if v <= 0.002 else (v * 255.0 - 1.0) / 254.0 + 0.001


## Havada mı (suya girmez): oyuncu / kukla durumları ve uçan yaratık aileleri.
static func is_airborne(n: Node) -> bool:
	if n.has_method("is_buyucu_airborne") and bool(n.call("is_buyucu_airborne")):
		return true
	for prop: String in ["_vampir_bat_form_active", "_vampir_bat_form", "_cadi_broom_active", "_cadi_broom", "_hadime_q_active", "_hadime_q",
			"_shaman_golem_jumping", "_matthew_ball_active", "in_limbo", "is_dead"]:
		if n.get(prop) == true:
			return true
	var mb: Variant = n.get("_matthew_ball")
	if mb is int and int(mb) > 0:
		return true
	var ride: Variant = n.get("cadi_ride_host_peer")
	if ride is int and int(ride) != 0:
		return true
	if n.has_method("creature_family") and FLYING_FAMILIES.has(str(n.call("creature_family"))):
		return true
	for c in n.get_children():
		if c.scene_file_path == MELEK_ASCEND_SCENE:
			return true
	return false


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene
		if _main == null:
			return
	var view: Rect2 = _view_rect().grow(VIEW_PAD)
	var tree := get_tree()
	var chars: Array = []
	for g: String in ["player", "remote_players"]:
		for p in tree.get_nodes_in_group(g):
			if p is Node2D:
				chars.append(p)
				for pn: String in PET_NODES:
					var pet: Node = (p as Node).get_node_or_null(pn)
					if pet is Node2D:
						chars.append(pet)
	for a in tree.get_nodes_in_group("player_allies"):
		if a is Node2D and not str((a as Node).get_script().resource_path if (a as Node).get_script() else "").contains("wraith"):
			chars.append(a)
	for n in chars:
		_update(n as Node2D, view, delta, false)
	if _frame % WADE_ENEMY_EVERY == 0 or not _overlays.is_empty():
		var cand: Array = EnemyQueryScript.candidates(tree, view.get_center(), view.size.length() * 0.5)
		var full: bool = _frame % WADE_ENEMY_EVERY == 0
		for e in cand:
			var e2 := e as Node2D
			if e2 == null or not is_instance_valid(e2):
				continue
			if not full and not _overlays.has(e2.get_instance_id()):
				continue
			_update(e2, view, delta, true)
	## bu karede görülmeyen (görüntü dışı / ölmüş) örtüler gizlenir, sahibi silinenler unutulur
	for id in _overlays.keys():
		var ov_v: Variant = _overlays[id] ## serbest kalmış örtü tipli değişkene atanırsa hata verir (sahibi ölen yaratık) - önce denetim
		if not is_instance_valid(ov_v) or not is_instance_valid((ov_v as Overlay).owner_node):
			_overlays.erase(id)
			continue
		var ov: Overlay = ov_v
		if ov.seen_frame != _frame and ov.visible:
			ov.set_wading(false)


func _update(n: Node2D, view: Rect2, delta: float, creature: bool) -> void:
	if not n.visible or not n.is_inside_tree():
		return
	var pos: Vector2 = n.global_position
	if not view.has_point(pos):
		return
	var id: int = n.get_instance_id()
	var ov: Overlay = null
	var ov_v: Variant = _overlays.get(id)
	if ov_v != null:
		if is_instance_valid(ov_v):
			ov = ov_v
		else:
			_overlays.erase(id)
	if is_airborne(n) or (creature and n.get("is_dead") == true):
		if ov != null:
			ov.set_wading(false)
		return
	var feet := Vector2(pos.x, float(_main.call("_creature_foot_y", n)) if _main.has_method("_creature_foot_y") else pos.y)
	feet = feet.floor()
	var w: float = water_at(feet)
	if w <= 0.0:
		if ov != null:
			ov.last_pos = Vector2.INF
			ov.set_wading(false)
		return
	if ov == null:
		ov = _make_overlay(n)
		if ov == null:
			return
		_overlays[id] = ov
	ov.seen_frame = _frame
	var half: float = HALF_PLAYER
	var depth_max: float = DEPTH_PLAYER
	if creature or not (n.is_in_group("player") or n.is_in_group("remote_players")):
		var body: Vector2 = _creature_body(n)
		half = clampf(body.x * 0.62, 3.0, 26.0)
		depth_max = clampf(body.y * DEPTH_CREATURE_RATIO, 2.0, DEPTH_CREATURE_MAX) + (CREATURE_SHADOW_PAD if creature else 0.0)
	## kıyıda sığ: derinlik kıyıya uzaklıkla artar (yumuşak), tam sayıya yuvarlanır (piksel ızgarası)
	var depth: float = roundf(lerpf(DEPTH_MIN, depth_max, smoothstep(0.0, 1.0, w)))
	var moving: bool = ov.last_pos != Vector2.INF and ov.last_pos.distance_to(pos) / maxf(delta, 0.0001) > MOVE_EPS
	ov.last_pos = pos
	## halkalar: hareket ederken sık ve güçlü, dururken seyrek ve soluk
	for i in range(2):
		var r: Vector2 = ov.rings[i]
		if r.x < 1.0:
			r.x = minf(1.0, r.x + delta / RING_LIFE)
			ov.rings[i] = r
	ov.ring_timer -= delta
	if ov.ring_timer <= 0.0:
		ov.ring_timer = RING_EVERY_MOVING if moving else RING_EVERY_IDLE
		var slot: int = 0 if float(ov.rings[0].x) >= float(ov.rings[1].x) else 1
		ov.rings[slot] = Vector2(0.0, 1.0 if moving else 0.45)
	ov.half = roundf(half)
	ov.depth = depth
	ov.feet = feet
	var m: ShaderMaterial = ov.mat
	m.set_shader_parameter("ayak", feet)
	m.set_shader_parameter("yari_genislik", ov.half)
	m.set_shader_parameter("derinlik", depth)
	m.set_shader_parameter("halkalar", Vector4(ov.rings[0].x, ov.rings[0].y, ov.rings[1].x, ov.rings[1].y))
	ov.set_wading(true)
	ov.queue_redraw()


## Örtü: sahibin görselinin (AnimatedSprite2D / Sprite2D) HEMEN ardına, onun z'siyle -> sprite'ın üstünde, sahibin diğer süslerinin
## (kalkan baloncuğu, can çubuğu) altında; başka karakterlerle sıralama sahibin z'sini izler.
func _make_overlay(n: Node2D) -> Overlay:
	var vis: Node2D = null
	for cn: String in ["AnimatedSprite2D", "Sprite2D", "Anim", "Sprite"]:
		var c: Node = n.get_node_or_null(cn)
		if c is AnimatedSprite2D or c is Sprite2D:
			vis = c
			break
	if vis == null:
		for c in n.get_children():
			if c is AnimatedSprite2D or c is Sprite2D:
				vis = c
				break
	var ov := Overlay.new()
	ov.name = OVERLAY_NAME
	ov.owner_node = n
	ov.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("maske", _mask_tex)
	m.set_shader_parameter("maske_boyut", _mask_size)
	m.set_shader_parameter("maske_teksel", MASK_TEXEL)
	m.set_shader_parameter("halka_maks", RING_GROW)
	ov.mat = m
	ov.material = m
	ov.visible = false
	var sh: Node = n.get_node_or_null("Shadow")
	ov.shadow = sh as CanvasItem
	n.add_child(ov)
	if vis != null and vis.get_parent() == n:
		ov.z_index = vis.z_index
		ov.z_as_relative = vis.z_as_relative
		n.move_child(ov, vis.get_index() + 1)
	return ov


func _creature_body(n: Node2D) -> Vector2:
	if n.has_meta("_wade_body"):
		return n.get_meta("_wade_body")
	var body := Vector2(10.0, 24.0)
	var harita: Node = _main.get_node_or_null("Harita") if _main != null else null
	var depth: Node = harita.get_node_or_null("DepthOccluders") if harita != null else null
	if depth != null and depth.has_method("creature_body"):
		body = depth.call("creature_body", n)
		body = Vector2(body.x / 1.15, body.y / 1.15) ## creature_body'nin BODY_MARGIN payı geri alınır
	n.set_meta("_wade_body", body)
	return body


func _view_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
