extends Node2D
class_name FxPaladinBarrierLink

## Şovalye Adam'ın Koruma Bariyeri (E, skill2 id 29) - buflanmış bir dostun KENDİ üstünde (karakterinin çocuğu olarak)
## duran saf görsel efekt. Oyun durumuna hiç etkisi yoktur - gerçek mekanik (hasar yansıtma) player.gd damage_redirect_*/
## take_damage() üzerinden çalışır, bu SADECE o durumun kimin üstünde göründüğünü gösterir.
##
## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "arkadaşlarının etrafında şuanki hali gibi çalışan 2 çizginin dönerek
## koruma baloncuğu gibi görünmesini sağlayan fakat daha iyi bir versiyonu, mor-mavi tonlarında ... spritesheete dönüştür"):
## eskiden _draw()'da her karede iki sarı yay çiziliyordu. Artık tools/gen_sovalye_fx.py "guard_bubble" sayfaları: soluk
## baloncuk kenarı + iki eğik yörüngede dönen mor-mavi şerit. Yörüngenin ARKA yarısı karakterin arkasında (back katmanı,
## show_behind_parent), ÖN yarısı önünde (front katmanı) - iki sayfa aynı kare sayısı/hızda, birlikte oynar.
##
## CLAUDE.md'nin "kaster görür, diğerleri görmez" hata sınıfına düşmemek için bu node hem buflanan oyuncunun KENDİ
## client'ında hem HERKESİN ekranındaki kuklasında AYNI script yolundan oluşturulur (bkz. player.gd/remote_player.gd
## _refresh_barrier_link_visual) - senkronize edilen tek şey "aktif mi" bayrağıdır.

const BackFrames := preload("res://assets/fx/sovalye/guard_bubble_back_frames.tres")
const FrontFrames := preload("res://assets/fx/sovalye/guard_bubble_front_frames.tres")
const TEXEL := 1.212
## Baloncuk merkezi = karakter gövdesinin ortası (kök ~ gövde ortası; ayak +33, baş -38 yerel birim).
const CENTER := Vector2(0.0, 0.0)
const FADE_IN := 0.25

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _t: float = 0.0


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
	var start: int = randi() % BackFrames.get_frame_count("loop")
	_back.frame = start
	_front.frame = start
	_set_alpha(0.0)


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _make_layer(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = CENTER
	s.play("loop")
	return s


func _set_alpha(a: float) -> void:
	_back.modulate.a = a
	if is_instance_valid(_front):
		_front.modulate.a = a


func _process(delta: float) -> void:
	if _t < FADE_IN:
		_t += delta
		_set_alpha(clampf(_t / FADE_IN, 0.0, 1.0))
	## İki katman aynı kare sayısı/hızda; yine de ön katman sonradan (call_deferred) eklendiği için kareyi eşitle.
	if is_instance_valid(_front) and _front.frame != _back.frame:
		_front.frame = _back.frame
