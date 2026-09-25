extends Node2D

## Şovalye Adam E (Koruma Bariyeri) açıkken Şovalye'nin KENDİ üstünde duran "hasarı üstüne çekme" efekti (kullanıcı
## isteği 2026-09-25: "bu efekt açıkken şovalye adamda da hasarı üstüne çekiyormuş gibi görünecek bir efekt"). tools/
## gen_sovalye_fx.py "guard_absorb": her yönden spiral çizerek göğsüne akıp emilen mor-mavi zerreler + ayak altında içeri
## daralan halka. Kaster'da player.gd _refresh_paladin_guard_visual, diğer oyuncularda remote_player.gd AYNI adlı
## fonksiyon AYNI sahneyi kurar (main.gd extra "paladin_guard" bayrağı) - iki taraf tek sahne yolunu paylaşır.

const Frames := preload("res://assets/fx/sovalye/guard_absorb_frames.tres")
const TEXEL := 1.212
## Kare 100x100, göğüs (50,46) -> kökün 2 sanat pikseli üstü; ayak altı halkası (50,74) -> ~+31 yerel birim.
const POSITION := Vector2(0.0, 2.4)
const FADE_IN := 0.25

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL
	_sprite.position = POSITION
	add_child(_sprite)
	_sprite.play("loop")
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _t < FADE_IN:
		_t += delta
		modulate.a = clampf(_t / FADE_IN, 0.0, 1.0)
