extends Node2D

## Vampir Çocuk'un R yeteneği (Kan Yarasaları): karakterin çevresinde dolaşan 6 küçük yarasa. Açıkken
## menzildeki yaratıklara tek tek fırlayıp vurur (saldırı gücünün %60'ı), sonra karaktere geri döner
## (her dönüşte saldırı gücünün %5'i kadar can yeniler). Hız saldırı hızına göre artar.
##
## İKİ MOD, TEK ÇİZİM (bkz. CLAUDE.md "yeni yetenek eklerken eskisi kalıyor"):
##  - authoritative=true  : SADECE yeteneği kullanan oyuncunun kendi istemcisinde. Hedef seçer, hareket
##                          ettirir; vuruş/dönüş olaylarını caster'a (player.gd vampir_bat_hit/
##                          vampir_bat_returned) bildirir - hasar/can orada işlenir.
##  - authoritative=false : diğer istemcilerdeki kozmetik kopya. Hiçbir oyun mantığı yok; main.gd'nin
##                          yayınladığı 6 konumu (apply_net_positions) yumuşakça takip eder.
## Çizim (_draw) iki modda AYNI koddur, yani caster'ın gördüğüyle diğerlerinin gördüğü yapısal olarak aynı.

const VampirMath := preload("res://scripts/vampir_math.gd")

enum BatState { HOME, OUT, BACK }

const HIDDEN := Vector2(-99999.0, -99999.0) ## ağ paketinde "bu yarasa gizli" işareti
const HIT_DISTANCE := 20.0
const HOME_ARRIVE_DISTANCE := 16.0
const RELAUNCH_DELAY := 0.35
const HOME_FOLLOW_RATE := 14.0
const NET_FOLLOW_RATE := 22.0
## Yarasa sprite'ı 16 sanat pikseli. Kullanıcı isteği (2026-09-21): önce "%60 küçült" (1.8 -> 0.72), sonra "çok küçüldü,
## küçültmeyi %40'a düşürelim" = eski boyutun %60'ı kalır: 1.8 x 0.6 = 1.08.
const DRAW_TEXEL := 1.08
const FRAME_SEQUENCE := [0, 1, 2, 1]

var authoritative: bool = false
var caster: Node2D = null
var launch_radius: float = 260.0
var bat_speed: float = 190.0 ## caster her karede saldırı hızına göre günceller (player.gd VAMPIR_R_BASE_BAT_SPEED)
var retiring: bool = false

var _pos: PackedVector2Array = PackedVector2Array()
var _state: PackedInt32Array = PackedInt32Array()
var _delay: PackedFloat32Array = PackedFloat32Array()
var _active: Array = []
var _targets: Array = []
var _net_pos: PackedVector2Array = PackedVector2Array()
var _time: float = 0.0
var _textures: Array[Texture2D] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(3):
		_textures.append(load("res://assets/characters/vampir/mini_bat_%d.png" % (i + 1)))
	var start: Vector2 = caster.global_position if is_instance_valid(caster) else Vector2.ZERO
	for i in range(VampirMath.BAT_COUNT):
		_pos.append(start)
		_state.append(BatState.HOME)
		_delay.append(0.15 + 0.12 * float(i)) ## sırayla fırlasınlar
		_active.append(true)
		_targets.append(null)
		_net_pos.append(start)


func _physics_process(delta: float) -> void:
	_time += delta
	if authoritative:
		_simulate(delta)
	else:
		_follow_net(delta)
	queue_redraw()


func retire() -> void:
	retiring = true


func unretire() -> void:
	retiring = false
	for i in range(_active.size()):
		if not _active[i]:
			_active[i] = true
			_state[i] = BatState.HOME
			_delay[i] = 0.15 + 0.12 * float(i)
			if is_instance_valid(caster):
				_pos[i] = caster.global_position


## Ağ paketi: her yarasa için dünya konumu (HIDDEN = gizli). main.gd bunu ~20Hz yayınlar.
func get_net_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(_pos.size()):
		out.append(_pos[i] if _active[i] else HIDDEN)
	return out


func apply_net_positions(arr: PackedVector2Array) -> void:
	for i in range(mini(arr.size(), _net_pos.size())):
		_net_pos[i] = arr[i]


func _follow_net(delta: float) -> void:
	var k: float = 1.0 - exp(-NET_FOLLOW_RATE * delta)
	for i in range(_pos.size()):
		var goal: Vector2 = _net_pos[i]
		if goal.x < -90000.0:
			_active[i] = false
			continue
		if not _active[i]:
			_active[i] = true
			_pos[i] = goal
		_pos[i] = _pos[i].lerp(goal, k)


func _simulate(delta: float) -> void:
	if not is_instance_valid(caster):
		queue_free()
		return
	var caster_pos: Vector2 = caster.global_position
	var any_flying: bool = false
	for i in range(_pos.size()):
		if not _active[i]:
			continue
		match _state[i]:
			BatState.HOME:
				var goal: Vector2 = caster_pos + VampirMath.bat_home_offset(i, _pos.size(), _time)
				_pos[i] = _pos[i].lerp(goal, 1.0 - exp(-HOME_FOLLOW_RATE * delta))
				if retiring:
					_active[i] = false
					continue
				_delay[i] -= delta
				if _delay[i] <= 0.0:
					var t: Node2D = _pick_target(caster_pos, i)
					if t != null:
						_targets[i] = t
						_state[i] = BatState.OUT
					else:
						_delay[i] = 0.2 ## hedef yok - kısa süre sonra tekrar bak
			BatState.OUT:
				any_flying = true
				var tgt: Variant = _targets[i]
				if not is_instance_valid(tgt) or tgt.get("is_dead") == true:
					_state[i] = BatState.BACK
					continue
				var to_t: Vector2 = tgt.global_position - _pos[i]
				if to_t.length() <= HIT_DISTANCE:
					if caster.has_method("vampir_bat_hit"):
						caster.vampir_bat_hit(tgt, _pos[i])
					_state[i] = BatState.BACK
				else:
					_pos[i] += to_t.normalized() * minf(bat_speed * delta, to_t.length())
			BatState.BACK:
				any_flying = true
				var home: Vector2 = caster_pos + VampirMath.bat_home_offset(i, _pos.size(), _time)
				var to_h: Vector2 = home - _pos[i]
				if to_h.length() <= HOME_ARRIVE_DISTANCE:
					if caster.has_method("vampir_bat_returned"):
						caster.vampir_bat_returned(_pos[i])
					_state[i] = BatState.HOME
					_delay[i] = RELAUNCH_DELAY
				else:
					_pos[i] += to_h.normalized() * minf(bat_speed * delta, to_h.length())
	if retiring and not any_flying:
		var all_hidden: bool = true
		for a in _active:
			if a:
				all_hidden = false
				break
		if all_hidden:
			queue_free()


## Menzildeki, henüz başka bir yarasanın hedeflemediği en yakın yaratık; hepsi hedeflenmişse en yakını.
func _pick_target(caster_pos: Vector2, self_index: int) -> Node2D:
	var claimed: Array = []
	for j in range(_targets.size()):
		if j != self_index and _state[j] == BatState.OUT and is_instance_valid(_targets[j]):
			claimed.append(_targets[j])
	var best_free: Node2D = null
	var best_free_d: float = INF
	var best_any: Node2D = null
	var best_any_d: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if caster.has_method("vampir_can_target") and not caster.vampir_can_target(e):
			continue
		var d: float = caster_pos.distance_to(e.global_position)
		if d > launch_radius:
			continue
		if d < best_any_d:
			best_any_d = d
			best_any = e
		if d < best_free_d and not claimed.has(e):
			best_free_d = d
			best_free = e
	return best_free if best_free != null else best_any


func _draw() -> void:
	if _textures.is_empty():
		return
	var frame_idx: int = int(_time * 12.0)
	for i in range(_pos.size()):
		if not _active[i]:
			continue
		var tex: Texture2D = _textures[FRAME_SEQUENCE[(frame_idx + i) % FRAME_SEQUENCE.size()]]
		var size: Vector2 = tex.get_size() * DRAW_TEXEL
		draw_texture_rect(tex, Rect2(to_local(_pos[i]).round() - size * 0.5, size), false)
