extends Node2D

## Cadı Q (Zehirli Duman) açıkken arkasında süzülen zehir şişesi + ağzından yere dökülen duman akışı. Cadının (Player ya da
## RemotePlayer) ÇOCUĞU: CadiMath.set_potion_visual açar/kapatır - yerel oyuncuda ve uzak kuklada AYNI düğüm.
## Şişe HER yönde cadının TAM ARKASINDA durur (CadiMath.potion_body_art; kullanıcı 2026-10-13: "arkaya dönükken şişe
## arkasında değil yanlarında duruyor"): sağa/sola bakarken öbür yanında, 45 derece eğik; yukarı bakarken (sırtı kameraya)
## ekranda altında ve karakterin ÖNÜNDE çizilir; aşağı bakarken başının üstünden görünür ve karakterin ARKASINDA çizilir.
## Yerdeki bulutlar akışın indiği noktada doğar (CadiMath.smoke_land_offset) - duman şişenin ağzından dökülür.

const CadiMath := preload("res://scripts/cadi_math.gd")
## Sayfa ölçüleri (tools/gen_cadi_fx.py ÖLÇÜ çıktısı): [klip, şişe karesinde (24x24) gövde merkezi, akış karesinde (24x32) ağız]
const POSE_SIDE := [&"loop", Vector2(13.5, 9.5), Vector2(15, 5)]
const POSE_VERT := [&"down", Vector2(12, 8.5), Vector2(12, 5)]
const BOTTLE_CENTER := Vector2(12, 12)
const STREAM_CENTER := Vector2(12, 16)

var _facing: String = ""
var _flip: float = 1.0
var _t: float = 0.0
## Şişe gövdesinin yeri (ebeveynin yerel birimi); yön değişince hedefe süzülür.
var _body: Vector2 = Vector2.ZERO
var _bottle: AnimatedSprite2D = null
var _stream: AnimatedSprite2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stream = AnimatedSprite2D.new()
	_stream.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stream.sprite_frames = CadiMath.frames("stream")
	_stream.modulate.a = 0.9
	add_child(_stream)
	_bottle = AnimatedSprite2D.new()
	_bottle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bottle.sprite_frames = CadiMath.frames("potion")
	add_child(_bottle)
	_set_facing(CadiMath.facing_of(get_parent()))
	_body = _target()
	_apply()


func facing() -> String:
	return _facing


## Ebeveyn kökü 0,5 ölçekli: dünya ofseti x2 = yerel konum.
func _target() -> Vector2:
	return CadiMath.potion_body_offset(_facing, CadiMath.broom_riders(get_parent())) * 2.0


func _set_facing(f: String) -> void:
	if f == _facing:
		return
	_facing = f
	var vert: bool = f == "up" or f == "down"
	var pose: Array = POSE_VERT if vert else POSE_SIDE
	var mouth: Vector2 = CadiMath.POTION_MOUTH_VERT_ART if vert else CadiMath.POTION_MOUTH_SIDE_ART
	var body_px: Vector2 = pose[1]
	_bottle.play(pose[0])
	_stream.play(pose[0])
	## Düğüm orijini = şişe gövdesinin merkezi.
	_bottle.offset = BOTTLE_CENTER - body_px
	## Akış karesindeki ağız, şişenin ağzına otursun; iki sprite'ın piksel ızgarası çakışsın diye tam piksele yuvarlanır.
	var raw: Vector2 = mouth - (Vector2(pose[2]) - STREAM_CENTER)
	_stream.position = (raw + body_px).round() - body_px
	## Sayfalar sağa bakışa göre çizildi (şişe solda, ağzı sol alta); sola bakarken aynalanır.
	_flip = -1.0 if f == "left" else 1.0
	## Aşağı bakarken şişe cadının ardında: sprite'ından önce çizilir (başının üstünden görünür). Diğer yönlerde önünde.
	show_behind_parent = f == "down"
	z_index = 0 if f == "down" else 1


func _process(delta: float) -> void:
	_t += delta
	_set_facing(CadiMath.facing_of(get_parent()))
	_body = _body.lerp(_target(), 1.0 - exp(-CadiMath.POTION_FOLLOW_RATE * delta))
	_apply()


func _apply() -> void:
	## 1 sanat pikseli = CHAR_TEXEL yerel birim.
	var bob: float = roundf(sin(_t * CadiMath.POTION_BOB_SPEED) * CadiMath.POTION_BOB_ART) * CadiMath.CHAR_TEXEL
	position = _body + Vector2(0.0, bob)
	scale = Vector2(CadiMath.CHAR_TEXEL * _flip, CadiMath.CHAR_TEXEL)
