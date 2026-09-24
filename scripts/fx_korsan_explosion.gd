extends Node2D

## Korsan'ın patlaması (Patlat/Q bomba patlamaları + Bombardıman/R mermi patlamaları; ayrıca bu sahneyi kullanan diğer
## patlamalar) - PIŞIRILMIŞ PIXEL-ART SPRITESHEET.
## Kullanıcı isteği (2026-09-24): "korsanın patlama yeteneğini 48x48 pixel art olarak yeniden tasarla ve spritesheete
## dönüştür pixeldraw olarak kalmasın fpsi çok düşürüyor" - eski sürüm HER KAREDE pixel_draw.gd ile 4 büyük dolu disk
## (ateş topu) + 5 yanık izi diski + duman diskleri + yüzlerce kor/diken karesi çiziyordu (patlama başına binlerce
## draw_rect; Bombardıman saniyede 3 patlama doğurur). Artık tools/gen_korsan_fx_sprites.py'nin pişirdiği 14 karelik
## (büyük) / 12 karelik (küçük) animasyon TEK bir AnimatedSprite2D ile oynatılır. Tasarım: yıldız biçimli parlama ->
## birleşik loblardan oluşan sert renk bantlı, koyu konturlu ateş bulutu -> aynı lobların iki tonlu duman bulutuna
## dönüşüp yükselmesi; ince kesikli şok halkası, uçuşan korlar, zeminde alfa ile solan yanık izi (dama deseni yok).
## Piksel yoğunluğu karakterlerle aynı (1 sanat pikseli = TEXEL dünya birimi, 48x48 karakter dili).
## setup(radius, color): görsel yarıçap. Referans yarıçapa (BIG_R0/SMALL_R0) göre en yakın sayfa seçilir ve oranla
## ölçeklenir (bomba ~150, Bombardıman mermisi 68). color varsayılan turuncudan farklıysa modulate edilir.

const SOUND_EXPLOSION: AudioStream = preload("res://assets/audio/fire_staff_explosion.mp3")
const BIG_FRAMES := preload("res://assets/fx/korsan/explosion_big_frames.tres")
const SMALL_FRAMES := preload("res://assets/fx/korsan/explosion_small_frames.tres")
const BIG_R0 := 150.0
const SMALL_R0 := 68.0
const TEXEL := 1.212 ## PixelDraw.TEXEL
const DEFAULT_TINT := Color(1.0, 0.6, 0.2)

var blast_radius: float = 150.0
var tint: Color = DEFAULT_TINT
var _anim: AnimatedSprite2D = null

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sound: AudioStreamPlayer2D = get_node_or_null("Sound")


func setup(radius: float, color: Color = DEFAULT_TINT) -> void:
	blast_radius = clampf(radius, 30.0, 320.0)
	tint = color
	_apply_size()


func _ready() -> void:
	z_index = 12
	if sprite:
		sprite.visible = false ## eski sprite artık çizilmiyor
	if sound:
		sound.stream = SOUND_EXPLOSION
		sound.pitch_scale = randf_range(0.9, 1.1)
		sound.play()
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim)
	_apply_size()
	_anim.play("play")
	_anim.animation_finished.connect(_on_finished)
	## Güvenlik: animasyon ya da ses bir sebeple bitmezse sahnede asılı kalmasın.
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _apply_size() -> void:
	if _anim == null:
		return
	var use_small: bool = blast_radius < (BIG_R0 + SMALL_R0) * 0.5
	var frames: SpriteFrames = SMALL_FRAMES if use_small else BIG_FRAMES
	if _anim.sprite_frames != frames:
		var was_playing: bool = _anim.is_playing()
		var frame: int = _anim.frame
		_anim.sprite_frames = frames
		if was_playing:
			_anim.play("play")
			_anim.frame = mini(frame, frames.get_frame_count("play") - 1)
	var r0: float = SMALL_R0 if use_small else BIG_R0
	_anim.scale = Vector2.ONE * TEXEL * (blast_radius / r0)
	_anim.modulate = Color.WHITE if tint.is_equal_approx(DEFAULT_TINT) else Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6, 1.0)


func _on_finished() -> void:
	_anim.visible = false
	if sound and is_instance_valid(sound) and sound.playing:
		await sound.finished
	if is_instance_valid(self):
		queue_free()
