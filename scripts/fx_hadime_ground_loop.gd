extends Node2D

## Suriyeli Hadime'nin karakter altındaki DÖNGÜ efektlerinin ortak oynatıcısı (tools/gen_hadime_fx.py sayfaları):
##  - fx_hadime_nightmare.tscn : R Karabasan - ayak altında karanlık havuz + dışa uzanıp çekilen gölge pençeleri.
##  - fx_hadime_levitate.tscn  : Q Lanet Kitabı - havaya süzülürken ayak altında karanlık uçma parçacıkları.
## Karakterin ARKASINDA çizilir, açılınca solarak belirir, stop() ile solarak kaybolur. Yerelde ve diğer oyuncularda AYNI
## yoldan kurulur/kaldırılır: HadimeMath.set_loop_fx (durum bayrağına göre - player.gd / remote_player.gd).

const HadimeMath := preload("res://scripts/hadime_math.gd")
## Ayak altı (karakter kökünden yerel birim) - Şovalye aurasıyla aynı zemin çizgisi. Q'da karakter havalansa da zemin
## yerinde kalır (parçacıklar ayaklardan zemine süzülür).
const GROUND_Y := 33.0

@export var frames: SpriteFrames
## Sayfada zemin merkezinin karenin ortasına göre konumu (sanat pikseli).
@export var ground_art: Vector2 = Vector2.ZERO
@export var fade_in: float = 0.25
@export var fade_out: float = 0.35

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _stopping: bool = false
var _stop_t: float = 0.0


func _ready() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.show_behind_parent = true
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2.ONE * HadimeMath.TEXEL
	_sprite.position = Vector2(0.0, GROUND_Y) - ground_art * HadimeMath.TEXEL
	add_child(_sprite)
	_sprite.play(&"loop")
	modulate.a = 0.0


func stop() -> void:
	_stopping = true


func _process(delta: float) -> void:
	if _stopping:
		_stop_t += delta
		modulate.a = clampf(1.0 - _stop_t / maxf(fade_out, 0.01), 0.0, 1.0)
		if _stop_t >= fade_out:
			queue_free()
		return
	_t += delta
	modulate.a = clampf(_t / maxf(fade_in, 0.01), 0.0, 1.0)
