extends Node2D

## Cadı R (İksir Çantası) - kırılan şişenin açtığı alan: Delilik (dönen pembe sis), Don (kırağı + buz sisi), Şifa (ışık
## çemberi), Korku (kara-mor sis). Patlama iksiri alan açmaz (CadiMath.spawn_boom). Sayfalar: tools/gen_cadi_fx.py zone_*
## (intro -> loop -> outro).
## ZEMİN efekti: tüm karakter/yaratıkların ALTINDA çizilir (kullanıcı 2026-10-13: "zeminin üstünde olsun, yaratıkların
## üstünde olmasın") - EnemyAbilities.place_on_ground, asit gölü / kara delik ile aynı çözüm.
## Kopyalar:
##  - authoritative (kasterin kendi kopyası): her ZONE_SCAN_INTERVAL'de on_scan(self) -> player.gd _on_cadi_zone_scan
##    (kimin içeride olduğuna bakıp delilik/don/korku/şifa uygular; hasar kasterde bir kez hesaplanır).
##  - diğer istemcilerdeki kopyalar sadece görsel (şişenin uzak kopyası yere değince AYNI süre/boyutla açar).

const CadiMath := preload("res://scripts/cadi_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const GROUP := "cadi_zones"
const SAFETY_EXTRA := 2.0

var potion: int = CadiMath.POTION_MAD
var duration: float = CadiMath.ZONE_DURATION
var size_mult: float = 1.0
var authoritative: bool = false
var on_scan: Callable = Callable()
## Yetkili taramanın belleği (player.gd doldurur): "bir kez" etkilenen yaratıklar / delilik yenileme zamanları.
var hit_ids: Dictionary = {}
var heal_timer: float = 0.0

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0
var _scan_timer: float = 0.0
var _ending: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = CadiMath.frames(str(CadiMath.ZONE_SHEETS.get(potion, "zone_mad")))
	## Evrim "Geniş Karışım" (+%40): sayfa büyütülür - 0,903 x 1,4 = 1,26 dünya birimi/piksel (oyunun efekt dokusu 1,212).
	_sprite.scale = Vector2.ONE * CadiMath.WORLD_TEXEL * size_mult
	_sprite.offset = -CadiMath.ZONE_CENTER_ART
	_sprite.modulate.a = float(CadiMath.ZONE_ALPHA[clampi(potion, 0, CadiMath.ZONE_ALPHA.size() - 1)])
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


func radius() -> Vector2:
	return CadiMath.zone_radius(size_mult)


func contains(p: Vector2, margin: float = 0.0) -> bool:
	var r: Vector2 = radius()
	return CadiMath.in_ellipse(p, global_position, r.x + margin, r.y + margin)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < duration:
		if authoritative and on_scan.is_valid():
			_scan_timer -= delta
			if _scan_timer <= 0.0:
				_scan_timer += CadiMath.ZONE_SCAN_INTERVAL
				on_scan.call(self, CadiMath.ZONE_SCAN_INTERVAL)
		if not _ending and _t >= duration - CadiMath.ZONE_OUTRO_TIME:
			_ending = true
			_sprite.play(&"outro")
	elif _t > duration + SAFETY_EXTRA:
		queue_free()
