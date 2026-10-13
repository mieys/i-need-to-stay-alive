extends Node2D

## Cadı R (İksir Çantası) - fırlatılan iksir şişesi: from -> to arasında yay çizerek takla atar (bottles sayfası, şişe
## başına 4 kare), yere değince kırılır (shatter sayfası).
##  - Kasterin kopyası: on_land(potion, to) dolu gelir -> player.gd _on_cadi_bottle_land (alan / patlama + etkiler).
##  - Diğer istemcilerdeki kopya (network_manager.gd "cadi_fx"/"throw"): on_land boş; alanın ya da patlamanın GÖRSELİNİ
##    zone_opts ("duration", "size") ile kendisi açar - iki taraf aynı uçuş süresini kullandığı için ek ağ mesajı gerekmez.

const CadiMath := preload("res://scripts/cadi_math.gd")

var potion: int = 0
var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var on_land: Callable = Callable()
var zone_opts: Dictionary = {}

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2 ## havada: karakterlerin üstünde
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = CadiMath.frames("bottles")
	_sprite.scale = Vector2.ONE * CadiMath.WORLD_TEXEL
	add_child(_sprite)
	_sprite.play(StringName("b%d" % (clampi(potion, 0, CadiMath.POTION_COUNT - 1) + 1)))


func _process(delta: float) -> void:
	_t += delta
	var u: float = clampf(_t / CadiMath.R_FLIGHT_TIME, 0.0, 1.0)
	global_position = from.lerp(to, u) + Vector2(0.0, -CadiMath.R_ARC_HEIGHT * sin(PI * u))
	if u >= 1.0:
		_land()


func _land() -> void:
	set_process(false)
	var root: Node = get_parent()
	var p: int = clampi(potion, 0, CadiMath.POTION_COUNT - 1)
	CadiMath.spawn_oneshot(root, "shatter", StringName("s%d" % (p + 1)), to, 1.0, Vector2(0, 10))
	if on_land.is_valid():
		on_land.call(p, to)
	elif p == CadiMath.POTION_BOOM:
		CadiMath.spawn_boom(root, to, float(zone_opts.get("size", 1.0)))
	else:
		CadiMath.spawn_zone(root, p, to, false, Callable(), zone_opts)
	queue_free()
