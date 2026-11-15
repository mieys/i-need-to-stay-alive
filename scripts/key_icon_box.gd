extends Control

## HARİTA ANAHTARI arayüz kutusu (madde 605): `KeyIconBox.new(px, harita_kimliği, soluk_mu)` - Ruh Kıymığı simgesiyle (menu_dark_kit.gd ShardIcon)
## AYNI desen: kare kutu, en yakın TAM KAT (32 / 64 / 96 px), keskin. Çizim ve doku tek kaynaktan (key_icon.gd).

const KeyIcon := preload("res://scripts/key_icon.gd")

var key_id: String = ""
var dim: bool = false


func _init(px: float = 32.0, id: String = "", dimmed: bool = false) -> void:
	var side: float = KeyIcon.side_for(px)
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	key_id = id
	dim = dimmed
	KeyIcon.texture(id) ## ilk yükleme _draw'da olmasın (beyaz kare tuzağı, madde 156)


func _draw() -> void:
	var h: float = minf(size.x, size.y)
	KeyIcon.paint(self, ((size - Vector2(h, h)) * 0.5).floor(), h, key_id, dim)
