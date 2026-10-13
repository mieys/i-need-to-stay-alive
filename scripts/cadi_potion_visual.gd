extends Node2D

## Cadı Q (Zehirli Duman) açıkken arkasında uçan zehir şişesi + ağzından yere dökülen duman akışı. Cadının (Player ya da
## RemotePlayer) ÇOCUĞU: CadiMath.set_potion_visual açar/kapatır - yerel oyuncuda ve uzak kuklada AYNI düğüm.
## Şişe cadının baktığı yönün tersinde durur (sağa bakarken solda; yukarı/aşağı bakarken son yanında kalır). Yerdeki
## bulutlar akışın indiği noktada doğar (CadiMath.smoke_land_offset) - kullanıcı: "duman şişeden çıkıyor gibi görünmüyor"
## düzeltmesi: şişe 45 derece eğik, duman ağzından dökülür.

const CadiMath := preload("res://scripts/cadi_math.gd")

var _side: int = -1
var _t: float = 0.0
var _bottle: AnimatedSprite2D = null
var _stream: AnimatedSprite2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	_stream = AnimatedSprite2D.new()
	_stream.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stream.sprite_frames = CadiMath.frames("stream")
	## Akış sayfası 34x30, ağız (27, 5): sprite merkezi (17, 15) -> ağız düğüm orijinine göre POTION_MOUTH_ART'ta dursun.
	_stream.position = CadiMath.POTION_MOUTH_ART - Vector2(10, -10)
	_stream.modulate.a = 0.88
	add_child(_stream)
	_stream.play(&"loop")
	_bottle = AnimatedSprite2D.new()
	_bottle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bottle.sprite_frames = CadiMath.frames("potion")
	## Şişe sayfası 24x24, gövde merkezi (13.5, 9.5): düğüm orijini gövde merkezi.
	_bottle.offset = Vector2(-1.5, 2.5)
	add_child(_bottle)
	_bottle.play(&"loop")
	_side = CadiMath.potion_side(CadiMath.facing_of(get_parent()), _side)
	_apply()


func side() -> int:
	return _side


func _process(delta: float) -> void:
	_t += delta
	_side = CadiMath.potion_side(CadiMath.facing_of(get_parent()), _side)
	_apply()


func _apply() -> void:
	## Ebeveyn kökü 0,5 ölçekli: dünya ofseti x2 = yerel konum; 1 sanat pikseli = CHAR_TEXEL yerel birim.
	var bob: float = roundf(sin(_t * CadiMath.POTION_BOB_SPEED) * CadiMath.POTION_BOB_ART) * CadiMath.CHAR_TEXEL
	position = CadiMath.potion_body_offset(_side) * 2.0 + Vector2(0.0, bob)
	## Sayfalar "şişe solda" çizildi; sağdayken aynalanır.
	scale = Vector2(CadiMath.CHAR_TEXEL * (1.0 if _side == -1 else -1.0), CadiMath.CHAR_TEXEL)
