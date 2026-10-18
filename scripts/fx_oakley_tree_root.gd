extends Node2D

## Oakley R "Hayat Ağacı" kökleri (madde 266, prototip madde 265 C): sabitlenen yaratığın dibinden fışkıran kalın kökler + sarılma
## halkası. fx_oakley_entangle.gd (E sarmaşığı) ile AYNI arayüz/yaşam döngüsü - enemy.gd _spawn_entangle_fx(duration, style 1)
## kurar, host root_start {"style": 1} ile herkese yayınlar; refresh() / release() aynı.
## Sayfalar tools/gen_hayat_agaci_fx.py kok_{s,m,l}_{arka,on}.png: 6 kare (0-3 büyüme, 4-5 döngü); bırakma = büyümenin tersi
## (kökler toprağa çekilerek azalır - saydamlaşmaz). Ölçek 1 (1 piksel = 1 dünya birimi). Arka yarı yaratığın ARKASINDA (bu düğüm
## show_behind_parent), ön yarı ÖNÜNDE (yaratığa kardeş eklenen ön katman) - entangle'ın iki katman deseni.

## boy -> [arka, ön, kare yüksekliği H, zemin satırı gy]
const SIZES := {
	"s": [preload("res://assets/fx/oakley/hayat_agaci/kok_s_arka.png"), preload("res://assets/fx/oakley/hayat_agaci/kok_s_on.png"), 24.0, 20.0],
	"m": [preload("res://assets/fx/oakley/hayat_agaci/kok_m_arka.png"), preload("res://assets/fx/oakley/hayat_agaci/kok_m_on.png"), 32.0, 28.0],
	"l": [preload("res://assets/fx/oakley/hayat_agaci/kok_l_arka.png"), preload("res://assets/fx/oakley/hayat_agaci/kok_l_on.png"), 44.0, 40.0],
}
const FRAMES := 6
const GROW_FRAMES := 4
const GROW_FPS := 16.0
const LOOP_FPS := 3.0
## fx_oakley_entangle.gd ile aynı: yaratık kökü ayak hizasına çok yakın.
const FEET_Y := 4.0
const SELF_RELEASE_GRACE := 0.25

var _back: Sprite2D = null
var _front: Sprite2D = null
var _time_left: float = 0.0
var _releasing: bool = false
var _phase_t: float = 0.0 ## büyüme/döngü/bırakma içindeki süre


func setup(duration: float, body_radius: float) -> void:
	var key: String = "s" if body_radius <= 16.0 else ("m" if body_radius <= 30.0 else "l")
	var cfg: Array = SIZES[key]
	var center := Vector2(0.0, FEET_Y - (float(cfg[3]) - float(cfg[2]) * 0.5))
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = _make_layer(cfg[0], center)
	add_child(_back)
	_front = _make_layer(cfg[1], center)
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_front)
	_time_left = duration
	_set_frame(0)


func refresh(duration: float) -> void:
	_time_left = maxf(_time_left, duration)
	if _releasing: ## çekilirken yeniden sabitlendi: bulunduğu kareden yeniden büyür
		_releasing = false
		_phase_t = float(_current_frame()) / GROW_FPS


func release() -> void:
	if _releasing:
		return
	_releasing = true
	_phase_t = 0.0


func _make_layer(tex: Texture2D, center: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = FRAMES
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = center
	return s


func _current_frame() -> int:
	return _back.frame if _back != null else 0


func _set_frame(f: int) -> void:
	if _back != null:
		_back.frame = f
	if is_instance_valid(_front):
		_front.frame = f


func _exit_tree() -> void:
	if is_instance_valid(_front):
		_front.queue_free()


func _process(delta: float) -> void:
	if _back == null:
		return
	_phase_t += delta
	if _releasing:
		var start: int = GROW_FRAMES - 1
		var f: int = start - int(_phase_t * GROW_FPS)
		if f < 0:
			queue_free()
			return
		_set_frame(f)
		return
	_time_left -= delta
	if _time_left <= -SELF_RELEASE_GRACE:
		release()
		return
	var gf: int = int(_phase_t * GROW_FPS)
	if gf < GROW_FRAMES:
		_set_frame(gf)
	else:
		var lt: float = _phase_t - float(GROW_FRAMES) / GROW_FPS
		_set_frame(GROW_FRAMES + (int(lt * LOOP_FPS) % (FRAMES - GROW_FRAMES)))
