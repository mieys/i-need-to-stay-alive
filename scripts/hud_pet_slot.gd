extends Control

## Oyuncu panelindeki (hud.gd dock) evcil hayvan yuvası - pasif ikonuyla aynı boyda (36 px) küçük çerçeve, içinde seçili
## hayvanın kendi sprite karesi (PetCatalog.icon), tam sayı ölçekle. Kullanıcı isteği (2026-10-14): "pet için de bi yer".
## Üstüne gelince hayvanın adı + etkisi (standart ipucu).

const PetCatalog := preload("res://scripts/pet_catalog.gd")
const FRAME: Texture2D = preload("res://assets/ui/kit/hud_skill_frame_small.png")
const HudTheme := preload("res://scripts/hud_theme.gd")
const UNDER := HudTheme.INSET
const FIT := 32.0 ## hayvan en çok bu kareye sığar (çerçevenin iç kenarına 2 px taşabilir; çerçeve üstte çizilir)

var _tex: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_pet(PetCatalog.selected())


func set_pet(key: String) -> void:
	_tex = PetCatalog.icon(key)
	tooltip_text = "%s\n%s" % [PetCatalog.display_name(key), PetCatalog.description(key)]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(-4.0), UNDER)
	if _tex:
		var ts: Vector2 = _tex.get_size()
		var s: float = maxf(1.0, floorf(FIT / maxf(ts.x, ts.y)))
		draw_texture_rect(_tex, Rect2((size * 0.5 - ts * s * 0.5).round(), ts * s), false)
	draw_texture_rect(FRAME, Rect2(Vector2.ZERO, size), false)
