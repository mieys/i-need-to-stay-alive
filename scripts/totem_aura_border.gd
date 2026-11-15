extends Node2D

## SHAMAN E (Kalkan Totemi) AURA SINIRI - "C Işık Perdesi" (madde 586, 2026-11-11; kullanıcı: "Shaman'ın E yeteneğinin aura sınırının
## görünmesini sağla" -> 4 prototip, C seçildi). Çizim tamamen shaders/shaman_aura_perde.gdshader'da (dünya ızgarası, parazitsiz).
## - Sınır = totemin KENDİ totem_radius'u (220; "Geniş Alan" x1,3), her karede okunur. Alan hasarı yarıçapı (totem_base.gd AREA_RADIUS 180)
##   AYRI ve çizilmez.
## - KATMAN: totemin çocuğu DEĞİL; haritanın İÇİNE, zemin katmanlarının hemen arkasına girer (GroundSlot.add_on_floor): zemin + suyun üstü,
##   ağaç/ev/çalı/köprü/plato/zindan duvarı ve bütün karakterlerin altı. (Sahne kökündeki zemin yuvası 440 birimlik halkayı evin çatısının
##   ve ağaç taçlarının ÜSTÜNE çiziyordu.) top_level KULLANILMAZ (çizim sırasını en üste taşır).
## - Ömür: totem yoksa / silinmek üzereyse (süre dolumu, ağ kopyasının kaldırılması) 0,45 sn'de söner ve kendini siler - ayrı çağrı gerekmez.
##   Açılış: yarıçap 0,45 sn'de taştan dışa açılır (ease-out), perde boyu 0,6 sn'de büyür.
## - Ruh hâli (madde 438): totem donmuşsa (Limbo.is_frozen) perde de durur.
## - Ağ: gerçek totem ve ağ görsel kopyası aynı _ready yolundan kurar (totem_shield.gd) -> herkes görür, ek RPC yok. TAKIM efekti:
##   ally_fx_density.gd tablosunda yok = hep tam.

const ShaderRes: Shader = preload("res://shaders/shaman_aura_perde.gdshader")
const LimboScript := preload("res://scripts/limbo.gd")
const GROUP := "shaman_aura_borders"
const OPEN_TIME := 0.45
const GROW_TIME := 0.6
const FADE_TIME := 0.45
const START_ALPHA_TIME := 0.3
## Çizim dörtgeninin daireden taşma payı (dünya): perde en çok 13 + zerre 4 hücre (~16 birim) + çizgi.
const MARGIN := 24.0

var totem: Node2D = null
var _mat: ShaderMaterial = null
var _t: float = 0.0
var _fade: float = -1.0
var _radius: float = 220.0
var _center: Vector2 = Vector2.ZERO
var _drawn_r: float = -1.0
var _drawn_c: Vector2 = Vector2(INF, INF)


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 0
	z_as_relative = true
	global_position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = ShaderRes
	material = _mat
	## Totem konumunu _ready'den SONRA alır (player.gd setup_from_player / remote_player.gd global_position = ...): ilk _process'e kadar
	## gizli, yoksa bir kare dünya başlangıcında (0,0) çizilebilirdi (MP denetimi: merkez ilk karede 2374 birim kayıktı).
	visible = false
	_read_totem()
	_sync()


func _totem_alive() -> bool:
	return totem != null and is_instance_valid(totem) and not totem.is_queued_for_deletion()


func _read_totem() -> void:
	if not _totem_alive():
		return
	_center = totem.global_position
	var v: Variant = totem.get("totem_radius")
	if v != null:
		_radius = float(v)


## Şu an çizilen yarıçap (açılış dahil) - test / ayıklama.
func drawn_radius() -> float:
	return float(_mat.get_shader_parameter("radius")) if _mat else 0.0


func is_fading() -> bool:
	return _fade >= 0.0


func _process(delta: float) -> void:
	if _totem_alive():
		if LimboScript.is_frozen(totem):
			return
		_read_totem()
		visible = true
	elif _fade < 0.0:
		_fade = 0.0
	_t += delta
	if _fade >= 0.0:
		_fade += delta
		if _fade >= FADE_TIME:
			queue_free()
			return
	_sync()


func _sync() -> void:
	var open_k: float = clampf(_t / OPEN_TIME, 0.0, 1.0)
	open_k = 1.0 - pow(1.0 - open_k, 3.0)
	var a: float = clampf(_t / START_ALPHA_TIME, 0.0, 1.0)
	if _fade >= 0.0:
		a *= 1.0 - clampf(_fade / FADE_TIME, 0.0, 1.0)
	_mat.set_shader_parameter("center", _center)
	_mat.set_shader_parameter("radius", _radius * maxf(open_k, 0.02))
	_mat.set_shader_parameter("time_s", _t)
	_mat.set_shader_parameter("alpha_mult", a)
	_mat.set_shader_parameter("grow", clampf(_t / GROW_TIME, 0.0, 1.0))
	if not is_equal_approx(_radius, _drawn_r) or not _center.is_equal_approx(_drawn_c):
		_drawn_r = _radius
		_drawn_c = _center
		queue_redraw()


func _draw() -> void:
	var h: float = _drawn_r + MARGIN
	var a: Vector2 = to_local(_drawn_c - Vector2(h, h))
	var b: Vector2 = to_local(_drawn_c + Vector2(h, h))
	draw_rect(Rect2(a, b - a), Color.WHITE)
