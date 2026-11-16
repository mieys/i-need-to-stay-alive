extends Node2D

## Büyücü Kız Don Nova buz yavaşlatması (kullanıcı isteği 2026-10-04: "yavaşlatma için yaratıkların hafif mavimsi ve donuyormuş
## gibi görünmesi") - yavaşlayan yaratığın ayağında kırağı lekesi (ARKA katman, yaratığın arkasında) + ayak çevresinde buz
## kristalleri ve gövdesinden yükselen kar zerreleri (ÖN katman, yaratığa kardeş). Gövdenin buz mavisi tonu enemy.gd
## _status_tint_color'da (bu düğüm yaşadıkça). Sayfalar tools/gen_buyucu_evo_fx.py "frost_chill_{s,m,l}_{back,front}" (sayfa
## merkezi = ayak noktası); boy yaratığın gövde yarıçapına göre - fx_oakley_entangle.gd ile aynı iki katman deseni ve boy seçimi.
## Senkron: enemy.gd _apply_frost_slow_host (host) / broadcast_enemy_vfx "frost_slow_start" (istemci) - iki tarafta AYNI sahne.
## Ömrünü kendisi sayar (istemci kuklası durum sayacı işletmez), bitince ebeveynin _on_frost_chill_fx_finished'ini çağırır.

const TEXEL := 1.212
const FRAMES_DIR := "res://assets/fx/evolution/"
## Yaratıkların kökü ayak hizasına çok yakın (fx_oakley_entangle.gd FEET_Y ölçümü).
const FEET_Y := 4.0
const FADE_IN := 0.25
const FADE_OUT := 0.45

static var _frames_cache: Dictionary = {}

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _time_left: float = 0.0
var _t: float = 0.0
var _finished: bool = false


static func _frames(sheet_name: String) -> SpriteFrames:
	if not _frames_cache.has(sheet_name):
		var path: String = FRAMES_DIR + sheet_name + "_frames.tres"
		_frames_cache[sheet_name] = load(path) if ResourceLoader.exists(path) else null
	return _frames_cache[sheet_name]


## Buz Asası yavaşlatması (madde 749, kullanıcı 2026-11-16: "ilk saldırıdan hasar alan yaratığın altında buz çıkmasını değil hafif
## donuyormuş gibi mavi tonlarında olmasını istiyorum"): tint_only = kırağı / kristal katmanı YOK, düğüm yalnız tonun ömrünü sayar
## (gövde tonu enemy.gd _status_tint_color, bu düğüm yaşadıkça). Aynı yaratığa sonradan Don Nova gelirse add_layers katmanları ekler.
var tint_only: bool = false
var _body_radius: float = 16.0


## enemy.gd ekledikten hemen sonra çağırır. body_radius: enemy.gd _body_radius (boss ölçeği dahil).
func setup(duration: float, body_radius: float, only_tint: bool = false) -> void:
	tint_only = only_tint
	_body_radius = body_radius
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	_time_left = duration
	if not tint_only:
		add_layers()


## Kırağı + kristal katmanları (Don Nova). Yalnız tonla başlamış düğüme de sonradan eklenebilir.
func add_layers() -> void:
	tint_only = false
	if _back != null:
		return
	var key: String = "s" if _body_radius <= 16.0 else ("m" if _body_radius <= 30.0 else "l")
	_back = _make_layer(_frames("frost_chill_%s_back" % key))
	add_child(_back)
	_front = _make_layer(_frames("frost_chill_%s_front" % key))
	_front.modulate.a = modulate.a
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_front)


## Yavaşlatma yenilendi (yeni Don Nova): süre uzar, sönmekteyse geri belirir.
func refresh(duration: float) -> void:
	_time_left = maxf(_time_left, duration)


func _make_layer(frames: SpriteFrames) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = Vector2(0.0, FEET_Y)
	if frames != null and frames.has_animation(&"loop"):
		s.play(&"loop")
	return s


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_time_left -= delta
	var a: float = clampf(minf(_t / FADE_IN, _time_left / FADE_OUT), 0.0, 1.0)
	modulate.a = a
	if is_instance_valid(_front):
		_front.modulate.a = a
		if _back != null and _front.frame != _back.frame:
			_front.frame = _back.frame
	if _time_left <= 0.0:
		_finished = true
		var host: Node = get_parent()
		if host != null and host.has_method("_on_frost_chill_fx_finished"):
			host.call("_on_frost_chill_fx_finished")
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_front):
		_front.queue_free()
