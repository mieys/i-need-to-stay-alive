extends Node2D

## Sağanak havasında TEK bir yıldırım düşüşü (kullanıcı isteği 2026-09-25: "rasgele aralıklarla rasgele konumlara
## yıldırım düşmeli, yıldırım düştüğü yerdeki yaratıklara ciddi hasar vermeli ve düşmeden önce düşeceği yerde hafif
## elektriklenme olmalı ki dikkatli olalım"). Zaman akışı (hepsi bu düğümde, ek düğüm/parçacık yok - optimize):
##   0 .. warn_time : zeminde titreyen elektrik halkası (etki alanının kendisi) + elektriklenme sesi; düşüş yaklaştıkça
##                    parlaklık artar, son anlarda hızlanır.
##   warn_time      : yıldırım (gökten zemine) + çarpma patlaması + gök gürültüsü; on_strike geri çağrısı hasarı uygular.
##   sonra          : zeminde yanık izi SCORCH_TIME'da solar, düğüm kendini siler.
## weather_storm.gd kurar - host'un seçtiği konum NetworkManager.broadcast_lightning_strike ile herkese gittiği için HER
## istemci aynı noktada, aynı akışı kendi yerel olarak oynatır (tek referans: bu script + assets/fx/storm sayfaları).
##
## Katmanlar: kök zemine (karakterlerin altına) taşınır (weather_storm.gd, drop_attraction.gd place_on_ground ile aynı
## yol) -> uyarı halkası ve yanık izi karakterlerin ALTINDA; yıldırım ve patlama z_index 60 ile her şeyin ÜSTÜNDE.

const WarningFrames := preload("res://assets/fx/storm/warning_frames.tres")
const BoltFrames := preload("res://assets/fx/storm/bolt_frames.tres")
const ImpactFrames := preload("res://assets/fx/storm/impact_frames.tres")
const ScorchTexture := preload("res://assets/fx/storm/scorch.png")

const CHARGE_SOUND := "res://assets/audio/storm/charge.wav"
const STRIKE_SOUNDS := ["res://assets/audio/storm/thunder_strike_1.wav", "res://assets/audio/storm/thunder_strike_2.wav"]

## Sayfalardaki çapa noktaları (sanat pikseli = dünya birimi, bkz. tools/gen_storm_fx.py): karenin ortasına göre zemin.
const WARNING_CENTER := Vector2.ZERO ## 128x80, zemin (64,40) = kare ortası
const BOLT_OFFSET := Vector2(0.0, -(222.0 - 115.0)) ## 72x230, zemin (36,222); kare ortası (36,115)
const IMPACT_OFFSET := Vector2(0.0, -(50.0 - 45.0)) ## 150x90, zemin (75,50); kare ortası (75,45)
const ABOVE_Z := 60
const SCORCH_TIME := 4.0

var warn_time: float = 1.3
## Yıldırım düştüğü an çağrılır (hasar) - weather_storm.gd bağlar.
var on_strike: Callable = Callable()
## Yıldırım anı yerel oyuncunun ekranında görünür mü (ses/flaş kararı weather_storm.gd'de).
var play_sounds: bool = true

var _t: float = 0.0
var _struck: bool = false
var _warning: AnimatedSprite2D = null
var _bolt: AnimatedSprite2D = null
var _impact: AnimatedSprite2D = null
var _scorch: Sprite2D = null
var _charge_player: AudioStreamPlayer2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_warning = _sprite(WarningFrames, WARNING_CENTER, 0)
	_warning.play("loop")
	_warning.modulate.a = 0.0
	if play_sounds:
		_charge_player = _sound(CHARGE_SOUND, -13.0, 900.0, 1.0) ## 2026-09-25: -4 dB ("hava sesleri biraz fazla")


func _sprite(frames: SpriteFrames, offset: Vector2, z: int) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = offset
	s.z_index = z
	add_child(s)
	return s


func _sound(path: String, volume_db: float, max_distance: float, attenuation: float) -> AudioStreamPlayer2D:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = load(path)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.attenuation = attenuation
	p.pitch_scale = randf_range(0.93, 1.07)
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	_t += delta
	if not _struck:
		var k: float = clampf(_t / warn_time, 0.0, 1.0)
		## Belirir, güçlenir; son %30'da hızlanan titreme (dikkat!).
		var flicker: float = 1.0
		if k > 0.7:
			flicker = 0.75 + 0.25 * signf(sin(_t * 55.0))
		_warning.modulate.a = lerpf(0.35, 1.0, k) * flicker
		_warning.speed_scale = lerpf(1.0, 2.2, k)
		if _t >= warn_time:
			_strike()
		return
	var since: float = _t - warn_time
	if _scorch != null:
		_scorch.modulate.a = clampf(1.0 - (since - 0.4) / SCORCH_TIME, 0.0, 1.0)
	if since >= SCORCH_TIME + 0.5:
		queue_free()


func _strike() -> void:
	_struck = true
	_warning.queue_free()
	_warning = null
	if _charge_player != null and is_instance_valid(_charge_player):
		_charge_player.queue_free()
	_scorch = Sprite2D.new()
	_scorch.texture = ScorchTexture
	_scorch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_scorch)
	_bolt = _sprite(BoltFrames, BOLT_OFFSET, ABOVE_Z)
	_bolt.play("strike")
	_bolt.animation_finished.connect(_bolt.queue_free)
	_impact = _sprite(ImpactFrames, IMPACT_OFFSET, ABOVE_Z)
	_impact.play("burst")
	_impact.animation_finished.connect(_impact.queue_free)
	if play_sounds:
		_sound(STRIKE_SOUNDS[randi() % STRIKE_SOUNDS.size()], -3.0, 3000.0, 0.7) ## 2026-09-25: -5 dB
	if on_strike.is_valid():
		on_strike.call(global_position)


## Gece ışığı kancası (night_glow.gd, bkz. night_glow_catalog.gd BY_SCENE): uyarıda hafif, yıldırımda tam, sonra söner.
func get_night_glow_energy() -> float:
	if not _struck:
		return 0.25 * clampf(_t / warn_time, 0.0, 1.0)
	return clampf(1.0 - (_t - warn_time) / 0.6, 0.0, 1.0)
