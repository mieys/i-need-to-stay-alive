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
## Ardışık sarsıntı darbeleri (kalkan patlaması "çıldırış" titremesi, madde 356): ilk sarsıntıdan sonra shake_pulse_gap arayla
## shake_pulses kez shake_pulse_trauma eklenir.
@export var shake_pulses: int = 0
@export var shake_pulse_trauma: float = 0.3
@export var shake_pulse_gap: float = 0.14
## İkinci ses katmanı (isteğe bağlı; ör. patlamada gök gürültüsü + elektrik çatırtısı).
@export var sound2_path: String = ""
@export var sound2_db: float = -6.0
@export var sound2_pitch: float = 1.0


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
		var asp: AudioStreamPlayer2D = _play_sound(sound_path, sound_db, sound_pitch)
		## Ses kareden uzunsa düğüm ses bitene kadar yaşar (görsel çoktan bitmiş, sprite son karede saydam).
		spr.animation_finished.disconnect(queue_free)
		spr.animation_finished.connect(spr.hide)
		asp.finished.connect(queue_free)
		if sound2_path != "" and ResourceLoader.exists(sound2_path):
			_play_sound(sound2_path, sound2_db, sound2_pitch) ## düğüm ilk sesle yaşar (ikinci katman kısa olmalı)


func _play_sound(path: String, db: float, pitch: float) -> AudioStreamPlayer2D:
	var asp := AudioStreamPlayer2D.new()
	asp.stream = load(path) as AudioStream
	asp.volume_db = db
	asp.pitch_scale = pitch * randf_range(0.95, 1.05)
	asp.max_distance = 1500.0
	add_child(asp)
	asp.play()
	return asp


func _shake() -> void:
	var at: Vector2 = global_position
	CameraShakeScript.add_at(at, shake_trauma, shake_radius)
	if shake_pulses <= 0 or not is_inside_tree():
		return
	var amount: float = shake_pulse_trauma
	var radius: float = shake_radius
	for i in range(shake_pulses):
		## Zamanlayıcı ağaçta yaşar: düğüm sayfa bitince silinse de darbeler sürer (lambda düğümü değil değerleri tutar).
		get_tree().create_timer(shake_pulse_gap * float(i + 1)).timeout.connect(
			func() -> void: CameraShakeScript.add_at(at, amount, radius))
