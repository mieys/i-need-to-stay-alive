extends Node2D
class_name MatthewExplosionFx

## Matthew ULTİ'si (Feda Kalkanı) hasarla kırılınca çıkan PATLAMA (bkz. player.gd _matthew_dome_explosion - 220 birimlik
## alan hasarı + itme). Kullanıcı isteği (2026-09-24): "kalkan patlama efektini pixel tarzda yeniden tasarla ...
## spritesheete dönüştür ki performans kaybı olmasın" - eski sürüm HER KAREDE _draw() ile 35 cam kıymığı + 2 şok
## dalgası çiziyordu (halka pikselleri Array.has() ile tekilleştiriliyordu - kare başına karesel maliyet).
## Artık tools/gen_matthew_shield_fx.py'nin pişirdiği 16 karelik (20 fps, 0.8 sn) animasyon TEK bir AnimatedSprite2D:
## turuncu-beyaz yıldız parlama, iki kesikli şok dalgası (R = 182 sanat px = 220 dünya birimi, hasar yarıçapıyla aynı),
## dönen kehribar cam kıymıkları, yükselen tilki ateşi korları. Dünyada durur (1 sanat pikseli = TEXEL dünya birimi).
## Diğer oyunculara player.gd "hitscan_impact" yayınıyla AYNI sahne gider (bkz. oradaki çağrı).

const TEXEL := 1.212
const FRAMES := preload("res://assets/fx/matthew_fox_shield/explosion_frames.tres")
const SAFETY_LIFETIME := 4.0

var _anim: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 12
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.sprite_frames = FRAMES
	_anim.scale = Vector2.ONE * TEXEL
	add_child(_anim)
	_anim.play(&"play")
	_anim.animation_finished.connect(_on_anim_finished)
	## Kalkan kırılma sesi (sahnedeki Sound düğümü) aynen korunuyor.
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.85, 1.0)
		s.play()
	get_tree().create_timer(SAFETY_LIFETIME, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


## Görsel bitti ama kırılma sesi animasyondan uzun sürebilir - düğüm (ve ses) ses bitince silinir.
func _on_anim_finished() -> void:
	_anim.visible = false
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s and s.playing:
		s.finished.connect(queue_free)
	else:
		queue_free()
