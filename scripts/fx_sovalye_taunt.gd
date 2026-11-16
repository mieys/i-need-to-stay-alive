extends Node2D

## Şovalye Adam Q - Kışkırtma (id 45) efekti: "A Kalkan Darbesi" (kullanıcı seçimi 2026-11-16, madde 726 prototipleri / 740).
## Eskiden temel Q Melek'le ortak genel mavi altıgeni (fx_kalkan_yenileme, 1,6 sn), Meydan Okuma ise yalnız ince kırmızı
## halkaları oynatıyordu. Artık TEK sahne, Q'nun tüm süresi boyunca (sayfalar tools/gen_sovalye_q_fx.py):
##  - q_cast (1 sn): ayak altından dolu mavi şok dalgası + sıçrayan kalkan kırıntıları,
##  - q_loop (1 sn döngü): ayak ışığı + HER SANİYE (kalkan yenileme tiki) ayaktan göğse yükselen halka + zerreler,
##  - q_taunt (yalnız `taunt` = "Meydan Okuma" evrimi, 1,2 sn): dış kırmızı dalga + içeri çekilen çizgiler.
## Arka katmanlar karakterin ARKASINDA (show_behind_parent), ön katman ebeveynin son çocuğu olarak ÖNÜNDE
## (fx_paladin_barrier_link.gd ile AYNI iki katman deseni). Son FADE_STEPS'te düz alfa basamaklarıyla söner.
## Kaster'da player.gd _play_and_broadcast_skill_fx(scene, {"duration", "taunt"}), diğer oyuncularda AYNI sahne + AYNI props
## "skill_scene" ile oluşur (props add_child'dan önce atanır). Yaratıkların başındaki 💢 ayrı: fx_taunt_status.gd.

const CastBack := preload("res://assets/fx/sovalye/q_cast_back_frames.tres")
const CastFront := preload("res://assets/fx/sovalye/q_cast_front_frames.tres")
const LoopBack := preload("res://assets/fx/sovalye/q_loop_back_frames.tres")
const LoopFront := preload("res://assets/fx/sovalye/q_loop_front_frames.tres")
const TauntBack := preload("res://assets/fx/sovalye/q_taunt_back_frames.tres")
## 1 sanat pikseli = karakter pikseli (0,903 dünya); oyuncu/kukla kökü 0,5 ölçekli -> 1,806 yerel birim.
const TEXEL := 1.806
## Ayak altı (kökten yerel birim): Şovalye idle karesinin en alt satırı (sprite offset -1,8, ölçek 1,806 -> +27,5).
const GROUND_Y := 27.5
## Köken (ayak) kırpılmış karede - tools/gen_sovalye_q_fx.py'nin yazdırdığı değerler (betik değişirse güncelle).
const CAST_ORIGIN := Vector2(46, 19)
const LOOP_ORIGIN := Vector2(14, 33)
const TAUNT_ORIGIN := Vector2(67, 29)
## Kapanış: [bitişe kalan sn, alfa] - düz basamaklar (dither/yumuşak geçiş yok).
const FADE_STEPS := [[0.4, 0.8], [0.27, 0.55], [0.14, 0.3]]

## props (kaster + uzak kopya aynı): Q'nun gerçek süresi (Uzun Nöbet dahil) ve Meydan Okuma alınmış mı.
var duration: float = 6.0
var taunt: bool = false

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _taunt: AnimatedSprite2D = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 0
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = _make_layer(CastBack, CAST_ORIGIN)
	add_child(_back)
	_front = _make_layer(CastFront, CAST_ORIGIN)
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_front)
	if taunt:
		_taunt = _make_layer(TauntBack, TAUNT_ORIGIN)
		add_child(_taunt)
		_taunt.animation_finished.connect(_taunt.queue_free)
	_back.animation_finished.connect(_on_cast_finished)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _make_layer(frames: SpriteFrames, origin: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.centered = false
	_set_clip(s, frames, origin)
	return s


func _set_clip(s: AnimatedSprite2D, frames: SpriteFrames, origin: Vector2) -> void:
	s.sprite_frames = frames
	s.offset = -origin
	s.position = Vector2(0.0, GROUND_Y)
	s.play(&"play")


func _on_cast_finished() -> void:
	if _back.sprite_frames == CastBack:
		_set_clip(_back, LoopBack, LOOP_ORIGIN)


func _process(delta: float) -> void:
	_t += delta
	var left: float = duration - _t
	if left <= 0.0:
		queue_free()
		return
	var a: float = 1.0
	for st: Array in FADE_STEPS:
		if left < float(st[0]):
			a = float(st[1])
	modulate.a = a
	## Ön katman sonradan (call_deferred) eklenir ve ayrı düğüm: klibi, kareyi ve alfayı arka katmana eşitle.
	if not is_instance_valid(_front) or not _front.is_inside_tree():
		return
	if _front.sprite_frames == CastFront and _back.sprite_frames == LoopBack:
		_set_clip(_front, LoopFront, LOOP_ORIGIN)
	if _front.frame != _back.frame:
		_front.frame = _back.frame
	_front.modulate.a = a
