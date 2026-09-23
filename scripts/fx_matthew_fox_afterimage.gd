extends Sprite2D

## Kullanıcı isteği (2026-09-23): "tilkinin arkasında kendi görüntüsü gibi parça parça izler olmalı" -
## tilki dash atarken (bkz. player_pet.gd dash_to/_process) yol boyunca aralıklarla bırakılan, tilkinin O
## ANKİ animasyon karesinin sönen kopyası. Renk tilkinin KENDİ renkleri (hafif ılık, yarı saydam) - önceki
## sürümün turuncu boyaması onu "tilki görüntüsü" yerine turuncu bir lekeye çeviriyordu.
## Hem gerçek tilki hem diğer istemcilerdeki kozmetik kopya aynı dash_to() ile bunları kendisi üretir, bu
## yüzden ayrıca ağdan yayınlanmasına gerek yok.

const LIFETIME := 0.22
var _t: float = 0.0
var _base_alpha: float = 0.55


func setup(src: AnimatedSprite2D, tint: Color = Color(1.0, 0.92, 0.82, 0.55)) -> void:
	if src and src.sprite_frames and src.sprite_frames.has_animation(src.animation):
		texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if src:
		flip_h = src.flip_h
		centered = src.centered
		offset = src.offset
		scale = src.global_scale
	_base_alpha = tint.a
	modulate = tint


## NOT: burada "texture yoksa queue_free()" kontrolü OLMAMALI - _ready() add_child() sırasında senkron
## çalışıyor, çağıran taraf setup()'ı add_child()'dan SONRA çağırıyor (bkz. player_pet.gd _spawn_afterimage);
## kontrol varken her hayalet texture almadan kendini siliyordu.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	modulate.a = _base_alpha * (1.0 - _t / LIFETIME)
