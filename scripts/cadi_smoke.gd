extends Node2D

## Cadı Q (Zehirli Duman) - şişeden yere dökülen dumanın bıraktığı bulut. Dünya konumunda sabit, ZEMİN efekti (tüm
## karakter/yaratıkların ALTINDA - kullanıcı: "zeminin üstünde olsun, yaratıkların üstünde olmasın"; asit gölüyle aynı çözüm).
## Bu düğüm sadece görsel + geometri: hasar/yavaşlatma kasterde tek yerde hesaplanır (player.gd _process_cadi_smoke -
## aynı yaratık kaç bulutun içinde olursa olsun saniyede BİR hasar alır), o tarama "authoritative" kopyaları `contains` ile sorar.
## Diğer istemcilerdeki kopyalar network_manager.gd "cadi_fx"/"smoke" ile AYNI seçeneklerle kurulur.

const CadiMath := preload("res://scripts/cadi_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const GROUP := "cadi_smokes"
const SAFETY_EXTRA := 2.0

var life: float = CadiMath.SMOKE_LIFE
var size_mult: float = 1.0
var owner_peer: int = 0
var authoritative: bool = false

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _ending: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = CadiMath.frames("smoke")
	## Evrim "Yoğun Duman" (+%30): sayfa büyütülür - 0,903 x 1,3 = 1,17 dünya birimi/piksel, oyunun genel efekt dokusuyla (1,212) aynı.
	_sprite.scale = Vector2.ONE * CadiMath.WORLD_TEXEL * size_mult
	_sprite.offset = -CadiMath.SMOKE_CENTER_ART
	_sprite.modulate.a = CadiMath.SMOKE_ALPHA
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"intro")
	add_to_group(GROUP)
	_place_on_ground.call_deferred()


func _place_on_ground() -> void:
	if is_inside_tree():
		EnemyAbilities.place_on_ground(get_tree(), self)


func _on_animation_finished() -> void:
	if _sprite.animation == &"intro" and not _ending:
		_sprite.play(&"loop")
	elif _sprite.animation == &"outro":
		queue_free()


## Hasar verir mi: ömrü boyunca (sönerken de) - "3 saniye boyunca kalır ve yavaşça kaybolur".
func is_active() -> bool:
	return _t < life


func contains(p: Vector2, margin: float = 0.0) -> bool:
	return CadiMath.in_ellipse(p, global_position, CadiMath.SMOKE_RX * size_mult + margin, CadiMath.SMOKE_RY * size_mult + margin)


func _process(delta: float) -> void:
	_t += delta
	if not _ending and _t >= life - CadiMath.SMOKE_OUTRO_TIME:
		_ending = true
		_sprite.play(&"outro")
	elif _t > life + SAFETY_EXTRA:
		queue_free()
