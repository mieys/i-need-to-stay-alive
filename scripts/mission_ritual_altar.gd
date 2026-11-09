extends Node2D

## RİTÜEL HEYKELİ (madde 496, "Ritüeli Boz"): salt görsel + hareket engeli, her makinede main.gd kurar (host'ta da; kristaller host'ta gerçek,
## istemcide kozmetik - ikisi de "mission_targets" grubunda, heykel onları görev kimliğiyle bulur). Sanat: Batık Nekropol setinin ruh ateşli
## heykeli (harita/zindan/batik_nekropol/Statue_fire.png, 6 x 80x80) - ana haritada da aynı (oyunun kendi sanatı). Ruh ateşinden yaşayan her
## kristale titreyen enerji ipi; ritüel süresi azaldıkça ip parlar, heykel hızlanır. Bitince: bozulduysa alev söner, tamamlandıysa parlayıp söner.

const SHEET: Texture2D = preload("res://harita/zindan/batik_nekropol/Statue_fire.png")
const HFRAMES := 6
const FPS := 8.0
const SPRITE_OFFSET := Vector2(0, -34) ## heykel tabanı düğüm noktasında
const FLAME_POS := Vector2(0, -58) ## ipin heykel ucu (ruh ateşi)
const DEPTH_HEIGHT := 70.0
const DEPTH_HALF_WIDTH := 26.0
const BEAM_CORE := Color(0.92, 0.78, 1.0, 0.95)
const BEAM_EDGE := Color(0.55, 0.3, 0.85, 0.55)

var mission_id: int = 0
var block_radius: float = 18.0 ## "move_blockers" (player.gd)
var _spr: Sprite2D = null
var _t: float = 0.0
var _duration: float = 75.0
var _left: float = 75.0
var _done: bool = false


func setup(mid: int, duration: float) -> void:
	mission_id = mid
	_duration = maxf(1.0, duration)
	_left = _duration


func _ready() -> void:
	add_to_group("move_blockers")
	_spr = Sprite2D.new()
	_spr.texture = SHEET
	_spr.hframes = HFRAMES
	_spr.offset = SPRITE_OFFSET
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)


func block_center() -> Vector2:
	return global_position + Vector2(0, -4)


func _process(delta: float) -> void:
	if _done:
		return
	_left = maxf(0.0, _left - delta)
	var urgency: float = 1.0 - _left / _duration
	_t += delta * FPS * (1.0 + urgency * 1.5)
	_spr.frame = int(_t) % HFRAMES
	_update_depth()
	queue_redraw()


func _crystals() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group("mission_targets"):
		if is_instance_valid(n) and int(n.get("mission_id")) == mission_id and n.get("is_dead") != true and n.has_method("beam_anchor"):
			out.append(n)
	return out


## Enerji ipi: kristalden heykelin ateşine, ortası hafifçe sarkan ve titreyen 2 px çekirdek + kenar (piksel ızgarasına oturur).
func _draw() -> void:
	if _done:
		return
	var urgency: float = 1.0 - _left / _duration
	var flick: float = 0.75 + 0.25 * sin(_t * 2.7)
	for c: Node in _crystals():
		var a: Vector2 = to_local((c as Node).call("beam_anchor"))
		var b: Vector2 = FLAME_POS
		var mid: Vector2 = (a + b) * 0.5 + Vector2(0, 6.0 + 3.0 * sin(_t * 0.9 + a.x * 0.05))
		var pts := PackedVector2Array()
		for i in range(9):
			var k: float = float(i) / 8.0
			var p: Vector2 = a.lerp(mid, k).lerp(mid.lerp(b, k), k)
			pts.append(p.round())
		var edge := BEAM_EDGE
		edge.a *= flick * (0.7 + urgency * 0.6)
		var core := BEAM_CORE
		core.a *= flick
		draw_polyline(pts, edge, 4.0)
		draw_polyline(pts, core, 2.0)


func _update_depth() -> void:
	var behind: bool = false
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not (p is Node2D) or not is_instance_valid(p):
				continue
			var feet: Vector2 = (p as Node2D).global_position + Vector2(0.0, 12.75)
			if feet.y < global_position.y and feet.y > global_position.y - DEPTH_HEIGHT and absf(feet.x - global_position.x) < DEPTH_HALF_WIDTH:
				behind = true
	z_index = 2 if behind else 0


## Görev bitti (her makinede, main.gd tamamlandı yayınında): bozulduysa (başarı) ateş söner; tamamlandıysa (başarısızlık) parlar. Sonra silinir.
func finish(broken: bool) -> void:
	if _done:
		return
	_done = true
	queue_redraw()
	remove_from_group("move_blockers")
	var tw := create_tween()
	if broken:
		_spr.frame = 0
		tw.tween_property(_spr, "modulate", Color(0.55, 0.55, 0.6, 1.0), 0.6)
		tw.tween_interval(1.2)
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
	else:
		tw.tween_property(_spr, "modulate", Color(1.8, 1.4, 2.2, 1.0), 0.25)
		tw.tween_property(_spr, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
		tw.tween_interval(0.8)
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
