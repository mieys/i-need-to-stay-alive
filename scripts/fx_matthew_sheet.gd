extends Node2D

## Matthew şimşek efektlerinin TEK SEFERLİK sayfa oynatıcısı (madde 98): isabet kıvılcımı, top dönüşüm patlaması, kalkan çağırma
## şimşeği, kalkan patlaması. Hangi sayfa oynayacağı sahnedeki `kind` alanıyla seçilir (scenes/fx_matthew_*.tscn) - hem kaster hem
## diğer oyuncular AYNI sahneyi yükler ("hitscan_impact" / "skill_scene" yayınları sahne yolunu taşır), ses de sahnenin içinde çalar
## (ayrı bir ses yayını gerekmez, iki tarafta aynı anda duyulur).

const ML := preload("res://scripts/matthew_lightning.gd")
const CameraShakeScript: GDScript = preload("res://scripts/camera_shake.gd")

@export var kind: String = "impact"
@export var z: int = 12
## Bir sanat pikselinin boyu: karaktere bağlı / patlama = 1.212 (TEXEL), dünyada duran kıvılcım = 0.795 (WORLD_TEXEL) -
## bkz. matthew_lightning.gd ÖLÇEK notu.
@export var px: float = 1.212
## Kare ortasına göre kaydırma (sanat pikseli): çağırma şimşeğinde indiği nokta düğümün konumuna gelsin diye.
@export var offset_px: Vector2 = Vector2.ZERO
@export var random_flip: bool = false
@export var sound_path: String = ""
@export var sound_db: float = -6.0
@export var sound_pitch: float = 1.0
## Kamera sarsıntısı (0 = yok) - kalkan patlaması eski tilki patlamasıyla aynı değerleri kullanır (camera_shake.gd add_at).
@export var shake_trauma: float = 0.0
@export var shake_radius: float = 1100.0


func _ready() -> void:
	z_index = z
	if shake_trauma > 0.0:
		call_deferred("_shake") ## konum add_child'dan sonra verilebilir: sarsıntı bir kare sonra
	rotation = 0.0 ## sayfa dünya eksenine oturur (yayındaki "rotation" alanı bu efektlerde kullanılmaz)
	var spr: AnimatedSprite2D = ML.make_sprite(kind, px)
	if spr == null:
		queue_free()
		return
	spr.offset = offset_px
	if random_flip:
		spr.flip_h = randf() < 0.5
	add_child(spr)
	spr.animation_finished.connect(queue_free)
	spr.play(&"fx")
	if sound_path != "" and ResourceLoader.exists(sound_path):
		var asp := AudioStreamPlayer2D.new()
		asp.stream = load(sound_path) as AudioStream
		asp.volume_db = sound_db
		asp.pitch_scale = sound_pitch * randf_range(0.95, 1.05)
		asp.max_distance = 1500.0
		add_child(asp)
		asp.play()
		## Ses kareden uzunsa düğüm ses bitene kadar yaşar (görsel çoktan bitmiş, sprite son karede saydam).
		spr.animation_finished.disconnect(queue_free)
		spr.animation_finished.connect(spr.hide)
		asp.finished.connect(queue_free)


func _shake() -> void:
	CameraShakeScript.add_at(global_position, shake_trauma, shake_radius)
