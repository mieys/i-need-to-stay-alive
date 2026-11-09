extends Node2D

## GEZİCİ IŞIK (madde 496): ruh feneri bir rota boyunca süzülür (host ilerletir: ışığın içinde canlı oyuncu varken; bkz. world_event_manager.gd
## WANDERING_LIGHT). Bu düğüm her makinede main.gd'nin kurduğu GÖRSEL + YEREL KARANLIK HASARI:
##  - konum = rota üzerinde ilerleme (mission_van.gd point_on_path - host'la aynı fonksiyon), gelen ilerlemeye yumuşakça yaklaşır;
##  - ışığın çevresi karanlık halka (LIGHT_RADIUS .. DARK_OUTER): yumuşak kenarlı, zifiri değil (sis kuralı, hafıza fog-vision-style),
##    ışık sınırında ince parıltı; kalan rota sönük noktalarla, bitiş ucu küçük bir işaretle;
##  - halka EKRAN DÜZEYİNDE (madde 534): dünyanın üstünde (layer 1) kendi CanvasLayer'ında, yalnız halkanın ekrandaki dörtgenini kaplar;
##    halkadaki yaratık / oyuncu / ağaç tepesi / efekt / can çubuğu zemin gibi kararır (ilk sürüm z 0 zemin sprite'ıydı, üstündeki her şey
##    aydınlık kalıyordu). Katman düğüm ağacında bu düğümün ÇOCUĞU: sublayer = çocuk dizini (küçük) -> aynı layer'daki gün-gece/sis/HUD
##    katmanlarının ALTINDA kalır (gece geçişi karartılmış sahneyi okur, HUD ve sis etkilenmez);
##  - karanlık hasarı: halkanın içinde (ışığın dışında) DARK_GRACE sn'den uzun kalan YEREL oyuncu, DARK_TICK'te bir azami canının
##    DARK_DPS_RATIO x DARK_TICK'i kadar hasar alır (tuzak hasarıyla aynı desen: her makine yalnız kendi oyuncusunu, dungeon_manager.gd).
##    Halkanın dışındaki (görevden uzak) oyuncuya bir şey olmaz.

const VanScript := preload("res://scripts/mission_van.gd")
const SoftGlowScript := preload("res://scripts/soft_glow_blend.gd")
const SHEET: Texture2D = preload("res://assets/fx/gorev/fener.png")
const GLOW: Texture2D = preload("res://assets/fx/gorev/fener_isik.png") ## zemine düşen ışık (3 düz bant, toplamalı)
const HFRAMES := 6
const FPS := 9.0
const HOVER_Y := -28.0
const BOB := 2.5
const PATH_DOT_STEP := 26.0
const PATH_COLOR := Color(0.62, 0.95, 1.0, 0.5)
const FEATHER := 40.0
const OUTER_FADE := 170.0
const DARK_COLOR := Color(0.05, 0.03, 0.09, 0.42)
const RIM_COLOR := Color(0.62, 0.95, 1.0, 0.55)
const DARK_GRACE := 1.5
const DARK_TICK := 1.0 ## saniyede bir tik (aynı %3/sn): 0,5 sn'de bir kan sıçraması + hasar parlaması savaşta göz yoruyordu
const DARK_DPS_RATIO := 0.03
const NET_SMOOTHING := 6.0

const RING_SHADER: Shader = preload("res://shaders/gorev_karanlik_halka.gdshader") ## fx_warmup EXTRA_SHADERS ısıtır

var mission_id: int = 0
var light_radius: float = 150.0
var dark_outer: float = 620.0
var damage_enabled: bool = true ## testler / izleyici kapatabilir
var _route: PackedVector2Array = PackedVector2Array()
var _progress: float = 0.0
var _target_progress: float = 0.0
var _route_len: float = 1.0
var _t: float = 0.0
var _wisp: Sprite2D = null
var _glow: Sprite2D = null
var _dark_layer: CanvasLayer = null
var _dark_rect: ColorRect = null
var _ring_mat: ShaderMaterial = null
var _path_layer: Node2D = null
var _outside_t: float = 0.0
var _tick_acc: float = 0.0
var _moving_glow: float = 0.0


func setup(mid: int, route: PackedVector2Array, p_light_radius: float, p_dark_outer: float) -> void:
	mission_id = mid
	_route = route
	_route_len = maxf(1.0, VanScript.path_length(route))
	light_radius = p_light_radius
	dark_outer = p_dark_outer
	global_position = VanScript.point_on_path(_route, 0.0)
	if _ring_mat:
		_apply_ring_params()


func _ready() -> void:
	process_priority = 999 ## kameradan sonra: halka dörtgeni bu karenin kamerasıyla hizalanır (atmosphere_overlay.gd ile aynı sebep)
	_dark_layer = CanvasLayer.new()
	_dark_layer.name = "DarkLayer"
	_dark_layer.layer = 1 ## dünya layer 0; sublayer = çocuk dizini (bu ilk çocuk) -> main'in layer-1 katmanlarının altında
	add_child(_dark_layer)
	_dark_rect = ColorRect.new()
	_dark_rect.name = "DarkRing"
	_dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark_rect.color = Color.WHITE
	_dark_rect.visible = false
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_dark_rect.material = _ring_mat
	_dark_layer.add_child(_dark_rect)
	_apply_ring_params()
	_path_layer = Node2D.new()
	_path_layer.top_level = true
	_path_layer.z_index = 0
	_path_layer.draw.connect(_draw_path)
	add_child(_path_layer)
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.material = SoftGlowScript.material() ## toplamalı yerine yumuşak parıltı (2026-11-08, soft_glow_blend.gd)
	_glow.z_index = 0
	add_child(_glow)
	_wisp = Sprite2D.new()
	_wisp.texture = SHEET
	_wisp.hframes = HFRAMES
	_wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wisp.position = Vector2(0, HOVER_Y)
	_wisp.z_index = 3
	add_child(_wisp)


func _apply_ring_params() -> void:
	_ring_mat.set_shader_parameter("r_light", light_radius)
	_ring_mat.set_shader_parameter("r_outer", dark_outer)
	_ring_mat.set_shader_parameter("feather", FEATHER)
	_ring_mat.set_shader_parameter("outer_fade", OUTER_FADE)
	_ring_mat.set_shader_parameter("dark", DARK_COLOR)
	_ring_mat.set_shader_parameter("rim", RIM_COLOR)


## main.gd: world_event_progress (değer = rota üzerindeki mesafe).
func set_progress(value: float, _target: float) -> void:
	if value > _target_progress + 0.01:
		_moving_glow = 1.0
	_target_progress = value
	if _path_layer:
		_path_layer.queue_redraw()


func current_position() -> Vector2:
	return VanScript.point_on_path(_route, _progress)


func _process(delta: float) -> void:
	_t += delta
	if absf(_target_progress - _progress) > 120.0:
		_progress = _target_progress
	else:
		_progress = lerpf(_progress, _target_progress, 1.0 - exp(-NET_SMOOTHING * delta))
	global_position = current_position()
	_moving_glow = maxf(0.0, _moving_glow - delta * 1.5)
	if _wisp:
		_wisp.frame = int(_t * FPS) % HFRAMES
		_wisp.position = Vector2(0, HOVER_Y + sin(_t * 2.2) * BOB).round()
		_wisp.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.35, 1.35, 1.35), _moving_glow)
	if _glow:
		_glow.modulate.a = 0.8 + 0.2 * sin(_t * 3.1) + 0.2 * _moving_glow
	_update_dark_ring()
	if damage_enabled:
		_local_darkness(delta)


## Karanlık halkanın ekran dörtgeni: halkanın (dış yarıçap + pay) kamera dönüşümüyle ekrana düşen kutusu, görünür alanla kesişimi
## (ekran dışındaysa gizli = çizim yok). Shader dünya konumunu bu dörtgenden + kameradan çözer (shaders/gorev_karanlik_halka.gdshader).
func _update_dark_ring() -> void:
	if _dark_rect == null or _ring_mat == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var xf: Transform2D = vp.get_canvas_transform()
	var zoom: float = absf(xf.get_scale().x)
	var c: Vector2 = xf * global_position
	var r: float = (dark_outer + 8.0) * zoom
	var box: Rect2 = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).intersection(Rect2(Vector2.ZERO, vp.get_visible_rect().size))
	if box.size.x < 1.0 or box.size.y < 1.0:
		_dark_rect.visible = false
		return
	var p0: Vector2 = box.position.floor()
	var p1: Vector2 = box.end.ceil()
	_dark_rect.position = p0
	_dark_rect.size = p1 - p0
	_dark_rect.visible = true
	_ring_mat.set_shader_parameter("rect_pos", p0)
	_ring_mat.set_shader_parameter("rect_size", p1 - p0)
	_ring_mat.set_shader_parameter("view_origin", xf.origin)
	_ring_mat.set_shader_parameter("view_zoom", zoom)
	_ring_mat.set_shader_parameter("light_pos", global_position)
	_ring_mat.set_shader_parameter("t", _t)


## Kalan rota: ilerlemeden bitişe sönük nokta dizisi + bitişte küçük elmas (dünya koordinatı; katman top_level).
func _draw_path() -> void:
	if _route.size() < 2:
		return
	var d: float = ceilf(_target_progress / PATH_DOT_STEP) * PATH_DOT_STEP
	while d < _route_len:
		var p: Vector2 = VanScript.point_on_path(_route, d).round()
		_path_layer.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), PATH_COLOR)
		d += PATH_DOT_STEP
	var e: Vector2 = _route[_route.size() - 1].round()
	var pts := PackedVector2Array([e + Vector2(0, -7), e + Vector2(5, 0), e + Vector2(0, 7), e + Vector2(-5, 0)])
	_path_layer.draw_colored_polygon(pts, Color(PATH_COLOR, 0.85))


## Yalnız bu makinenin yerel oyuncusu (bkz. dosya başı). Ölü / yere düşmüş / Hadime hayaleti / ruh hâlindeki (dokunulmaz) oyuncu sayılmaz.
func _local_darkness(delta: float) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p) or not (p is Node2D) or p.get("is_dead") == true or p.get("is_downed") == true:
		_outside_t = 0.0
		return
	if p.has_method("is_hadime_ghost") and bool(p.call("is_hadime_ghost")):
		_outside_t = 0.0
		return
	var ppos: Vector2 = (p as Node2D).global_position
	var d: float = ppos.distance_to(global_position)
	## seyyar satıcının güvenli alanı (zaman donar) karanlıktan da korur; ruh hâli zaten dokunulmaz (take_damage)
	var safe: bool = GameManager.merchant_zone_active and GameManager.is_position_in_merchant_zone(ppos)
	if d <= light_radius or d >= dark_outer or safe or p.get("in_limbo") == true:
		_outside_t = 0.0
		_tick_acc = 0.0
		return
	_outside_t += delta
	if _outside_t < DARK_GRACE:
		return
	_tick_acc += delta
	if _tick_acc < DARK_TICK:
		return
	_tick_acc -= DARK_TICK
	if p.has_method("take_damage"):
		p.call("take_damage", float(p.get("max_health")) * DARK_DPS_RATIO * DARK_TICK)


func is_in_darkness(world_pos: Vector2) -> bool:
	var d: float = world_pos.distance_to(global_position)
	return d > light_radius and d < dark_outer
