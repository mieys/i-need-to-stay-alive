extends Sprite2D

## ÜÇ KARDEŞ efektleri için tek satırlık sprite şeridini (assets/enemies/kardesler/fx_*.png, craftpix "gerekebilecek efektler" paketleri) bir kez oynatıp
## kendini silen düğüm. Her karede _draw yok: tek Sprite2D, kare = hframes. Yalnız görsel (ağdan bir şey gitmez; her peer kendi kopyasında oynatır).

const ART := 2.0 ## 1 sanat pikseli = dünya px: kardeşlerin sprite yoğunluğuyla aynı (sahne 1,1715 x EntityScale.SIZE x BOSS_EXTRA x boss ölçeği 2,2 = ~1,96)

var fps: float = 14.0
var _t: float = 0.0


## parent'a `tex` şeridini (nframes kare) `pos`'ta oynatır. anchor_bottom: karenin alt kenarı pos'ta (yıldırım / meteor yere iner).
static func play(parent: Node, pos: Vector2, tex: Texture2D, nframes: int, frame_fps: float, scale_mult: float = 1.0, rot: float = 0.0,
		z: int = 6, anchor_bottom: bool = false) -> Sprite2D:
	if parent == null or tex == null or not parent.is_inside_tree():
		return null
	var s := Sprite2D.new()
	s.set_script(load("res://scripts/kardes_sheet_fx.gd"))
	s.texture = tex
	s.hframes = maxi(nframes, 1)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.set("fps", frame_fps)
	s.z_index = z
	s.z_as_relative = false
	s.rotation = rot
	s.scale = Vector2.ONE * ART * scale_mult
	if anchor_bottom:
		s.offset = Vector2(0.0, -float(tex.get_height()) * 0.5 + 6.0)
	parent.add_child(s)
	s.global_position = pos
	return s


func _process(delta: float) -> void:
	_t += delta
	var f: int = int(_t * fps)
	if f >= hframes:
		queue_free()
		return
	frame = f
