extends Node2D
class_name FxMeteorStrike
const CameraShakeScript: GDScript = preload("res://scripts/camera_shake.gd")
const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")

## Büyücü Kız Meteor Patlaması'nın gökten düşen meteoru (2026-10-17, madde 188; kullanıcı: "yeni hazırladığın meteorlar iyiydi onlar
## kalsın"). Onaylanan prototip (tools/proto_20261016/gen_buyucu_buyu.py scene_r), sayfalar assets/fx/buyucu/meteor_*.png:
##  - düşüş boyunca hedefte büyüyen gölge + daralan uyarı halkası (meteor_warn) - eski fx_skill_ring telgraf halkasının yerine,
##  - korlu kaya + alev kuyruğu (meteor_fall) (-120, -420)'den hızlanarak düşer (eskisi gibi 0,45 sn, hasar player.gd'de 0,5 sn sonra),
##  - isabette dolu patlama + savrulan kaya parçaları (meteor_burst), hasar yarıçapında (70 dünya x ölçek) ince şok halkası (meteor_ring),
##    soğuyan krater izi (meteor_crater, ~2,7 sn) + kamera sarsıntısı.
## Kaster (player.gd _spawn_buyucu_meteor_strike) ve uzak kopya ("hitscan_impact" + setup_pos + fx_scale) AYNI sahne; ölçek = Efsunlu Büyü gücü.
## Düğüm hedefte durur (gece ışığı patlama noktasında), kaya çocuk sprite olarak düşer.

const START_OFFSET := Vector2(-120.0, -420.0)
const FX_FPS := 15.0
const CRATER_FPS := 7.5
## meteor_fall karesinde kaya (24, 38) - ortalanmış sprite'ta orijine gelsin.
const FALL_OFFSET := Vector2(0.0, -14.0)

var target_pos: Vector2 = Vector2.ZERO
var start_pos: Vector2 = Vector2.ZERO
var duration: float = 0.45
var elapsed: float = 0.0
var has_exploded: bool = false
var _rock: Sprite2D = null
var _warn: Sprite2D = null
var _started: bool = false


func setup(p_target: Vector2) -> void:
	target_pos = p_target
	start_pos = target_pos + START_OFFSET
	global_position = target_pos
	z_index = 0
	if _started:
		return
	_started = true
	_warn = _sheet("meteor_warn", float(BuyucuFxScript.SHEETS["meteor_warn"]) / duration, 0)
	_rock = _sheet("meteor_fall", FX_FPS, 52, true)
	_rock.offset = FALL_OFFSET
	_rock.position = START_OFFSET / maxf(absf(scale.x), 0.01)


func _sheet(name: String, fps: float, z: int, loop: bool = false) -> Sprite2D:
	var s: Sprite2D = BuyucuFxScript.Sheet.new()
	s.centered = true
	s.z_index = z
	s.scale = Vector2.ONE * BuyucuFxScript.PX
	add_child(s)
	s.call("setup", [[name, loop]], fps)
	return s


func _process(delta: float) -> void:
	if not _started or has_exploded:
		return
	elapsed += delta
	var p: float = clampf(elapsed / duration, 0.0, 1.0)
	if is_instance_valid(_rock):
		_rock.position = START_OFFSET * (1.0 - p * p) / maxf(absf(scale.x), 0.01) ## hızlanarak düşüş (ease-in)
	if p >= 1.0:
		_explode()


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	global_position = target_pos
	CameraShakeScript.add_at(target_pos, 0.55, 1200.0) ## kamera sarsıntısı (bkz. camera_shake.gd)
	for n in [_rock, _warn]:
		if is_instance_valid(n):
			n.queue_free()
	_sheet("meteor_burst", FX_FPS, 53)
	_sheet("meteor_ring", FX_FPS, 1)
	var crater: Sprite2D = _sheet("meteor_crater", CRATER_FPS, 0)
	crater.tree_exited.connect(queue_free)
