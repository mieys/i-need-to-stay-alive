extends Node2D
class_name FxPaladinBarrierLink

## Şovalye Adam'ın Koruma Bariyeri (E, skill2 id 29) - buflanmış bir dostun KENDİ üstünde (karakterinin çocuğu olarak)
## duran saf görsel efekt. Oyun durumuna hiç etkisi yoktur - gerçek mekanik (hasar yansıtma) player.gd damage_redirect_*/
## take_damage() üzerinden çalışır, bu SADECE o durumun kimin üstünde göründüğünü gösterir.
##
## "A5 - IŞIK KUYRUĞU" (kullanıcı seçimi 2026-11-11, madde 580/581; eski iki eğik şerit + dither'li baloncuk yerine):
## bel hizasında eğik yörüngede dönen 3 haçlı ışık kalkanı, nefes alan hale, kuyruklu yıldız izi, izden dökülen parıltı.
## Sayfalar tools/gen_sovalye_bariyer_fx.py (guard_bubble_back/front, 72x72, köken = gövde ortası): "in" (8 kare, açılış:
## merkezde yıldız + sarmal) -> "loop" (90 kare = tam tur, 20 fps). Yörüngenin ARKA yarısı karakterin arkasında (back katmanı,
## show_behind_parent), ÖN yarısı önünde (front katmanı) - iki sayfa aynı kare sayısı/hızda, birlikte oynar.
## KAPANIŞ sayfada değil kodda (dismiss): hangi dönüş karesinde bitse aynı - kısa parlama + alfa basamakları, dönüş sürer.
##
## CLAUDE.md'nin "kaster görür, diğerleri görmez" hata sınıfına düşmemek için bu node hem buflanan oyuncunun KENDİ
## client'ında hem HERKESİN ekranındaki kuklasında AYNI script yolundan oluşturulur (bkz. player.gd/remote_player.gd
## _refresh_barrier_link_visual) - senkronize edilen tek şey "aktif mi" bayrağıdır; kapanırken iki taraf da dismiss() çağırır.

const BackFrames := preload("res://assets/fx/sovalye/guard_bubble_back_frames.tres")
const FrontFrames := preload("res://assets/fx/sovalye/guard_bubble_front_frames.tres")
## 1 sanat pikseli = karakter pikseli (0,903 dünya px); oyuncu/kukla kökü 0,5 ölçekli -> 1,806 yerel birim.
const TEXEL := 1.806
## Sayfa kökeni (36,36) = karakter gövdesinin ortası = kök (ayak +33, baş -38 yerel birim); sprite ortalı.
const CENTER := Vector2(0.0, 0.0)
## Kapanış: [bitiş zamanı sn, parlaklık çarpanı, alfa] basamakları.
const FADE_STEPS := [[0.07, 1.7, 1.0], [0.14, 1.0, 0.8], [0.21, 1.0, 0.55], [0.28, 1.0, 0.3]]

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _fade_t: float = -1.0


func _ready() -> void:
	## Arka katman: bu düğüm (ve çocuğu _back) ebeveynin (karakter kökü) ARKASINA çizilir. Ön katman ebeveynin
	## son çocuğu (bu düğümün kardeşi) olarak karakter sprite'ından SONRA çizilir (fx_melek_holy.gd ile AYNI iki katman deseni).
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = _make_layer(BackFrames)
	add_child(_back)
	_front = _make_layer(FrontFrames)
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_front)
	_back.animation_finished.connect(_on_back_finished)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _make_layer(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = CENTER
	s.play("in")
	return s


func _on_back_finished() -> void:
	if _back.animation == &"in":
		_back.play("loop")


## Bariyer bitti: solarak kaybol ve kendini sil. Çağıran referansını hemen bırakabilir (yeniden açılırsa yeni düğüm kurulur).
func dismiss() -> void:
	if _fade_t < 0.0:
		_fade_t = 0.0


func is_dismissing() -> bool:
	return _fade_t >= 0.0


func _set_mod(c: Color) -> void:
	_back.modulate = c
	if is_instance_valid(_front):
		_front.modulate = c


func _process(delta: float) -> void:
	if _fade_t >= 0.0:
		_fade_t += delta
		var done := true
		for st: Array in FADE_STEPS:
			if _fade_t < float(st[0]):
				var k: float = float(st[1])
				_set_mod(Color(k, k, k, float(st[2])))
				done = false
				break
		if done:
			queue_free()
			return
	## İki katman aynı kare sayısı/hızda; ön katman sonradan (call_deferred) eklendiği için klibi ve kareyi eşitle.
	if not is_instance_valid(_front) or not _front.is_inside_tree():
		return
	if _front.animation != _back.animation:
		_front.play(_back.animation)
	if _front.frame != _back.frame:
		_front.frame = _back.frame
