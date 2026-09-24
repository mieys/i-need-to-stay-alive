extends Node2D

## Ağaç canavarı dikenleri (bkz. enemy_abilities.gd _process_thorns): oyuncunun o anki konumunda önce data.warn
## saniye boyunca zeminde nabız gibi atan kırmızı UYARI halkası + çatlaklar, sonra yerden fırlayan diken kümesi.
## Dikenler çıktığı anda (ERUPT_HIT_DELAY) data.radius içindeki her oyuncu BİR kez vurulur (host/yetkili örnek),
## hasar = yaratığın normal saldırısı. Görseller tools/gen_enemy_ability_fx.py spritesheet'leri (tek AnimatedSprite2D).

const TEXEL := 1.212
const WARN_FRAMES := preload("res://assets/fx/enemy_abilities/thorns_warn_frames.tres")
const THORN_FRAMES := preload("res://assets/fx/enemy_abilities/thorns_frames.tres")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const ERUPT_HIT_DELAY := 0.14 ## erupt animasyonunda dikenlerin topraktan çıktığı an (16 fps'de ~2. kare)
## thorns_sheet karesinde (72x84) zemin merkezi y=66 - sprite'ı zemin noktası node'un konumuna gelecek şekilde kaydır.
const THORN_GROUND_OFFSET := Vector2(0.0, -(66.0 - 42.0))

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _anim: AnimatedSprite2D = null
var _warn: float = 1.0
var _radius: float = 42.0
var _t: float = 0.0
var _erupted: bool = false
var _hit_done: bool = false


func _ready() -> void:
	z_index = 0 ## zeminde - negatif z harita altında kalır (bkz. fx_korsan_zone.gd)
	_warn = float(data.get("warn", 1.0))
	_radius = float(data.get("radius", 42.0))
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * TEXEL
	_anim.sprite_frames = WARN_FRAMES
	add_child(_anim)
	_anim.play(&"loop")
	get_tree().create_timer(_warn + 3.0, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _process(delta: float) -> void:
	_t += delta
	if not _erupted:
		if _t < _warn:
			return
		_erupted = true
		z_index = 2 ## dikenler oyuncunun arkasında/önünde karışık dursun diye biraz yukarı
		_anim.sprite_frames = THORN_FRAMES
		_anim.offset = THORN_GROUND_OFFSET
		_anim.play(&"erupt")
		_anim.animation_finished.connect(queue_free)
		return
	if authoritative and not _hit_done and _t - _warn >= ERUPT_HIT_DELAY:
		_hit_done = true
		for p in AbilitiesScript.damageable_players(get_tree()):
			if (p as Node2D).global_position.distance_to(global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
				AbilitiesScript.deal_special_damage(p, damage, source, "thorns")
