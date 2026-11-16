extends Node2D

## Ruhani Yetenek "Taktiksel" (F): ışınlandıktan sonraki 3 sn'lik +%30 hareket hızı. Görünüm = prototip "A Ruh Işığı" (madde 730,
## kullanıcı seçimi 2026-11-16, madde 734) - eski arkada akan ince çizgiler + ayak pikselleri silindi:
## hareket ederken her 0,1 sn'de karakterin O ANKİ karesinin turkuaz silüeti dünyada bırakılır ve 0,3 sn'de 3 düz bantla söner
## (aynı anda en çok 3-4 hayalet). Durunca hayalet bırakılmaz.
## Hayaletler bu düğümün çocuğu ama her karede dünya konumlarına geri çivilenir (top_level DEĞİL): show_behind_parent sayesinde
## karakterin ARKASINDA ve onunla aynı derinlik sırasında kalırlar.
## Hareket yönü: yerel oyuncuda `velocity`, uzak kuklada `_network_velocity` (varsa).
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd TAKTIK_SPEED_TIME).

const U := preload("res://scripts/spirit_fx_util.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const EVERY := 0.1
const GHOST_LIFE := 0.3
const GHOST_ALPHA := 0.42

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.TAKTIK_SPEED_TIME
var _host: Node2D = null
var _acc: float = 0.0
var _ghosts: Array = [] ## [Sprite2D, dünya konumu, yaş]


func _ready() -> void:
	z_index = 0
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D


func _moving() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	var v: Vector2 = Vector2.ZERO
	if "velocity" in _host:
		v = _host.velocity
	elif "_network_velocity" in _host:
		v = _host._network_velocity
	return v.length() > 20.0


func _process(delta: float) -> void:
	_t += delta
	if _t < _duration and _moving():
		_acc += delta
		if _acc >= EVERY:
			_acc = 0.0
			_drop()
	else:
		_acc = EVERY ## yeniden hareket edince ilk hayalet hemen düşsün
	for gh in _ghosts:
		gh[2] = float(gh[2]) + delta
		var g: Sprite2D = gh[0]
		if is_instance_valid(g):
			g.global_position = gh[1]
			g.self_modulate.a = U.band(GHOST_ALPHA * (1.0 - float(gh[2]) / GHOST_LIFE), 3)
	for gh in _ghosts:
		if float(gh[2]) >= GHOST_LIFE and is_instance_valid(gh[0]):
			(gh[0] as Node).queue_free()
	_ghosts = _ghosts.filter(func(gh: Array) -> bool: return float(gh[2]) < GHOST_LIFE)
	if _t >= _duration and _ghosts.is_empty():
		queue_free()


func _drop() -> void:
	var spr: AnimatedSprite2D = U.host_sprite(_host)
	var g: Sprite2D = U.make_ghost(spr, U.with_a(U.WIND3, GHOST_ALPHA))
	if g == null:
		return
	add_child(g)
	g.global_position = spr.global_position
	g.global_scale = spr.global_scale
	_ghosts.append([g, spr.global_position, 0.0])
