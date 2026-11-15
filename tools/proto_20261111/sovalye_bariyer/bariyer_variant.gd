extends Node2D

## PROTOTİP (oyuna bağlı DEĞİL): Şovalye E "Koruma Bariyeri"nin dostun etrafındaki görselinin yeni seçenekleri (A-D).
## fx_paladin_barrier_link.gd ile AYNI iki katman deseni: bu düğüm (arka katman) karakterin ARKASINDA (show_behind_parent),
## ön katman ebeveynin son çocuğu olarak karakterin ÖNÜNDE. Sayfalar bariyer_proto.py'den (out/sheets, içe aktarılmaz:
## Image.load_from_file). Açılış "in" -> "loop", stop() -> "out" -> silinir.

## Karakter pikseli 0,903 dünya px; kukla kökü 0,5 ölçekli -> 1,806 yerel birim.
const TEXEL := 1.806
const SHEETS := "res://tools/proto_20261111/sovalye_bariyer/out/sheets/"

var variant: String = "a"
var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
## "out" klibi olmayan sayfalarda (A1-A4) kapanış kodda: hangi dönüş karesinde bitse aynı - kısa parlama + alfa basamakları,
## dönüş sürer. Oyuna alınırken de bu yol (çıkış klibi sayfa açısına bağlı olurdu).
const FADE_STEPS := [[0.07, 1.7, 1.0], [0.14, 1.0, 0.8], [0.21, 1.0, 0.55], [0.28, 1.0, 0.3]]
var _has_out_clip: bool = true
var _fade_t: float = -1.0


func _ready() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "meta.json"))
	var meta: Dictionary = all[variant]
	_has_out_clip = int(meta["out"]) > 0
	_back = _make(SHEETS + variant + "_back.png", meta)
	add_child(_back)
	_front = _make(SHEETS + variant + "_front.png", meta)
	get_parent().add_child.call_deferred(_front)
	_back.play("in")
	_back.animation_finished.connect(_on_back_finished)


func _make(path: String, meta: Dictionary) -> AnimatedSprite2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var tex := ImageTexture.create_from_image(img)
	var w: int = int(meta["w"])
	var h: int = int(meta["h"])
	var sf := SpriteFrames.new()
	var idx: int = 0
	for anim: String in ["in", "loop", "out"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(meta["fps"]))
		sf.set_animation_loop(anim, anim == "loop")
		for i in range(int(meta.get(anim, 0))):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(idx * w, 0, w, h)
			sf.add_frame(anim, at)
			idx += 1
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.centered = false
	s.offset = -Vector2(float(meta["ox"]), float(meta["oy"]))
	s.scale = Vector2.ONE * TEXEL
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _on_back_finished() -> void:
	if _back.animation == &"in":
		_back.play("loop")
	elif _back.animation == &"out":
		if is_instance_valid(_front):
			_front.queue_free()
		queue_free()


func stop() -> void:
	if _has_out_clip:
		_back.play("out")
	else:
		_fade_t = 0.0


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
				_set_mod(Color(float(st[1]), float(st[1]), float(st[1]), float(st[2])))
				done = false
				break
		if done:
			if is_instance_valid(_front):
				_front.queue_free()
			queue_free()
			return
	if not is_instance_valid(_front) or not _front.is_inside_tree():
		return
	if _front.animation != _back.animation:
		_front.play(_back.animation)
	if _front.frame != _back.frame:
		_front.frame = _back.frame
