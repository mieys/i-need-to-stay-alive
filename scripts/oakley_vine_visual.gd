extends Node2D

## Oakley'in Sarmaşıklar (E) görseli - oakley_vine.gd'nin (gerçek ya da kozmetik kopya) çocuğu.
##
## ÜÇÜNCÜ TASARIM (kullanıcı bildirimi 2026-09-25: "hareket eden sarmaşık sarmaşık gibi değil bi fidan gibi çok kötü ama
## yaratıkları sabitlediği hali iyi"): toprak tümseği + arkasında biten fidanlar kaldırıldı. Artık yerde GERÇEK hareket yolunu
## izleyen kesintisiz, dikenli bir sarmaşık gövdesi sürünür:
##  - GÖVDE: yolun her SEG_SPACING biriminde bir vine_seg parçası (16 yön için AYRI çizilmiş - döndürülmez, piksel ızgarası
##    kaymaz; eski Line2D'nin bulanıklık sorunu bu yüzden yok). Parçaların uçlarında kontur olmadığı için birleşince tek
##    gövde gibi görünür. Parçalar sahneye (dünyaya) bırakılır, SEG_LIFE sonra söner - arkada solan bir iz kalır.
##  - BAŞ: vine_head (kıvrık uçlu, dikenli; 16 yön x 3 kare) bu düğümle birlikte ilerler, ilerleme yönüne bakar.
## Yaratığa sarılan dikenler (fx_oakley_entangle.gd) ve çıkış fışkırması (oakley_vine.gd vine_emerge) aynen kaldı.
## `points`: oakley_vine.gd'nin eski Line2D arayüzü (atanıyor ama artık çizimde kullanılmıyor).

const SEG_FRAMES := preload("res://assets/fx/oakley/vine_seg_frames.tres")
const HEAD_FRAMES := preload("res://assets/fx/oakley/vine_head_frames.tres")
const TEXEL := 1.212
const N_DIRS := 16
## Ardışık iki gövde parçası arası (dünya birimi) - parça 11 sanat pikseli, 7 pikselde bir: üst üste binip kesintisiz görünür.
const SEG_SPACING := 7.0 * TEXEL
const SEG_LIFE := 1.3
const SEG_FADE := 0.45
## Varyant ağırlıkları: 0 düz, 1 dikenli, 2 yapraklı.
const SEG_VARIANTS := [0, 0, 1, 2]
## Yılankavi kıvrım (sadece GÖRSEL - sarmaşığın gerçek yolu/hedefi değişmez): gidilen yol boyunca yana salınım.
const WIGGLE_AMP := 6.0
const WIGGLE_FREQ := 0.07 ## rad / dünya birimi

var points: PackedVector2Array = PackedVector2Array()

var _head: AnimatedSprite2D = null
var _last_seg_pos: Vector2 = Vector2.ZERO
var _prev_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false
var _dir_k: int = 0
var _dist: float = 0.0
var _last_raw: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_head = AnimatedSprite2D.new()
	_head.sprite_frames = HEAD_FRAMES
	_head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_head.scale = Vector2.ONE * TEXEL
	_head.z_index = 1 ## gövde parçalarının üstünde
	add_child(_head)
	_head.play(&"d0")


static func _dir_index(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (TAU / float(N_DIRS)))), N_DIRS)


func _process(_delta: float) -> void:
	var raw: Vector2 = global_position
	if not _has_last:
		_last_seg_pos = raw
		_prev_pos = raw
		_last_raw = raw
		_has_last = true
		return
	## Yana salınım: ilerleme yönüne dik, kat edilen mesafeyle değişen ofset - baş (bu düğümün çocuğu) ve bırakılan
	## gövde parçaları aynı ofsetli yolu izler.
	var move: Vector2 = raw - _last_raw
	_dist += move.length()
	_last_raw = raw
	var fwd: Vector2 = move.normalized() if move.length() > 0.01 else Vector2.RIGHT.rotated(TAU * float(_dir_k) / float(N_DIRS))
	var lateral: Vector2 = Vector2(-fwd.y, fwd.x) * sin(_dist * WIGGLE_FREQ) * WIGGLE_AMP
	_head.position = lateral
	var here: Vector2 = raw + lateral
	## Baş ilerleme yönüne bakar (küçük titremelerde yön değişmesin diye eşik).
	var step: Vector2 = here - _prev_pos
	if step.length() > 0.3:
		var k: int = _dir_index(step)
		if k != _dir_k:
			_dir_k = k
			var f: int = _head.frame
			_head.play(StringName("d%d" % k))
			_head.frame = f
	_prev_pos = here
	## Gövde: son parçadan SEG_SPACING uzaklaşınca aradaki orta noktaya o yönde bir parça bırak.
	var seg_vec: Vector2 = here - _last_seg_pos
	if seg_vec.length() >= SEG_SPACING:
		_spawn_segment((here + _last_seg_pos) * 0.5, _dir_index(seg_vec))
		_last_seg_pos = here


func _spawn_segment(at: Vector2, k: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var s := Sprite2D.new()
	s.texture = SEG_FRAMES.get_frame_texture(StringName("d%d" % k), SEG_VARIANTS[randi() % SEG_VARIANTS.size()])
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.z_index = 0
	tree.current_scene.add_child(s)
	s.global_position = at
	## Parça kendi tween'iyle söner - sarmaşık düğümü silinse bile iz kendi kendine temizlenir.
	var tw := s.create_tween()
	tw.tween_interval(SEG_LIFE)
	tw.tween_property(s, "modulate:a", 0.0, SEG_FADE)
	tw.tween_callback(s.queue_free)
