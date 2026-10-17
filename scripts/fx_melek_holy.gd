extends Node2D

## Melek'in R'si (Kutsal Korku, skill3 id 32) parıltısı: karakterin (ve can/kalkan bağı kurduğu dostun) etrafında güçlü, sarı,
## pixel-art kutsal ışık. Katmanlar (hepsi pixel_draw.gd ızgarasında):
##   ARKA : dönen/nabız atan 14 altın ışık ışını + dither ışıma (iki halka)
##   ÖN   : ilk 0.12sn beyaz-altın parlama, korku yarıçapına genişleyen kesikli pixel şok halkası (MELEK_FEAR_RADIUS ile aynı),
##          başın üstünde parlayan pixel halo, yükselen altın "+" parıltılar
## FPS (madde 215): ışıma + ışınlar (ARKA) ve ilk parlama + halo + parıltılar (ÖN) SPRITE SAYFASINA pişirildi (assets/fx/baked/
## melek_holy_back/front_*, `tools/fx_bake.ps1`; özgün çizim `tools/fx_bake_src/fx_melek_holy.gd` + `holy_back/front.gd`), kesikli şok halkaları
## tek dörtgenlik shader (`shaders/melek_holy_ring.gdshader`; eskiden kare başı ~2000 draw_rect).
## Karakterin (Player) ya da diğer istemcideki kuklanın (RemotePlayer) ÇOCUĞU olarak doğar: Melek'te _play_and_broadcast_skill_fx,
## bağlı dostta _set_ally_aura(ally, "holy") ile (yerel + ağ). Tek seferliktir, kendini siler.

const BakedFx := preload("res://scripts/baked_fx.gd")
const BACK_FRAMES := preload("res://assets/fx/baked/melek_holy_back_frames.tres")
const FRONT_FRAMES := preload("res://assets/fx/baked/melek_holy_front_frames.tres")
const RING_SHADER := preload("res://shaders/melek_holy_ring.gdshader")
const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli

## player.gd MELEK_FEAR_RADIUS bunu okur (tek kaynak): korkunun etki yarıçapı = şok halkasının yarıçapı.
const RADIUS := 260.0
const LIFE := 1.5
const BODY_CENTER := Vector2(0, -4)
const RING_TIME := 0.65

const GOLD := Color(1.0, 0.82, 0.22)
const GOLD_LIGHT := Color(1.0, 0.95, 0.6)

var _host: Node2D = null
var _t: float = 0.0
var _front: Node2D = null
var _ring: Node2D = null
var _ring_mat: ShaderMaterial = null


func _ready() -> void:
	show_behind_parent = true
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	BakedFx.attach(self, BACK_FRAMES, TEXEL, false)
	_front = Node2D.new()
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	BakedFx.attach(_front, FRONT_FRAMES, TEXEL, false)
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING_SHADER
	_ring_mat.set_shader_parameter("center", BODY_CENTER)
	_ring_mat.set_shader_parameter("texel", TEXEL)
	_ring_mat.set_shader_parameter("col1", GOLD)
	_ring_mat.set_shader_parameter("col2", GOLD_LIGHT)
	_ring = Node2D.new()
	_ring.material = _ring_mat
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ring.draw.connect(_draw_ring)
	_front.add_child(_ring)
	if _host != null:
		_host.add_child.call_deferred(_front) ## ön katman ebeveynin KARDEŞİ (bkz. fx_talon_form.gd aynı gerekçe)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE or _host == null or not is_instance_valid(_host):
		queue_free()
		return
	var rk: float = _t / RING_TIME
	if rk < 1.0:
		var e: float = 1.0 - (1.0 - rk) * (1.0 - rk)
		var dash_off: int = 3 + int(rk * 16.0)
		_ring_mat.set_shader_parameter("radius1", RADIUS * e)
		_ring_mat.set_shader_parameter("radius2", RADIUS * e * 0.86)
		_ring_mat.set_shader_parameter("phase1", _t * 24.0)
		_ring_mat.set_shader_parameter("phase2", -_t * 30.0)
		_ring_mat.set_shader_parameter("off1", dash_off)
		_ring_mat.set_shader_parameter("off2", dash_off + 3)
		_ring.queue_redraw()
	elif _ring.visible:
		_ring.visible = false


## Halka dörtgeni: o anki dış yarıçapı kapsayacak kadar (yarıçap büyüdükçe büyür).
func _draw_ring() -> void:
	var rk: float = _t / RING_TIME
	var e: float = 1.0 - (1.0 - rk) * (1.0 - rk)
	var r: float = RADIUS * e + 4.0 * TEXEL
	_ring.draw_rect(Rect2(BODY_CENTER - Vector2(r, r), Vector2(r, r) * 2.0), Color.WHITE)
