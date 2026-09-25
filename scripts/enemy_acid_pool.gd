extends Node2D

## Zombinin ölüm patlaması + zehirli asit gölü (kullanıcı isteği: "zombiler ölünce patlayarak yere 4 saniyeliğine
## zehirli asit bırakıp oraya basanlara normal hasarı kadar hasar versin"). Önce "burst" (irin balonu patlar), aynı
## anda göl yayılır ("intro" -> "loop"), data.duration dolunca "outro" ile söner. Yetkili (host/tek oyunculu) örnek
## gölün içinde duran her oyuncuya TICK_INTERVAL'da bir zombinin normal (temas) hasarını verir - göle ilk basış
## anında hasar gelir, sonra her saniye. Görseller tools/gen_enemy_ability_fx.py spritesheet'leri.

const TEXEL := 1.212
const ACID_FRAMES := preload("res://assets/fx/enemy_abilities/acid_frames.tres")
const BURST_FRAMES := preload("res://assets/fx/enemy_abilities/zombie_frames.tres")
const FxScript := preload("res://scripts/fx_enemy_ability.gd")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
## DÜZELTME (kullanıcı bildirimi 2026-09-25: "zombilerin asiti neredeyse hiç vurmuyor, sanırım sadece 1 kez vuruyor,
## üstünde durduğumuz sürece hasar vermeliydi"). Üç kök neden vardı:
##  1) Tikler normal bir VURUŞ gibi işleniyordu - oyuncunun sıyrılma şansı (en fazla %60) ve 150 ms temas kilidi tikleri
##     sessizce yutuyordu. Artık asit yanma gibi SÜREKLİ hasar (player.gd take_special_damage "acid" -> _special_dmg_is_dot).
##  2) "Gölün içinde mi" kontrolü oyuncunun GÖVDE merkezine bakıyordu; göl yerde, ayaklar ise kökün ~14 birim altında -
##     ekranda gölün üstünde duran oyuncu çoğu zaman "dışarıda" sayılıyordu. Artık ayak noktası (FEET_OFFSET).
##  3) 1 sn'lik tik "bir kere vurdu" hissi veriyordu: 0.5 sn'de bir, tik başına yarı hasar (saniyelik hasar AYNI -
##     ACID_DAMAGE_MULT kullanıcı isteğiyle belirlenmişti, değişmedi).
const TICK_INTERVAL := 0.5
const TICK_DAMAGE_SCALE := TICK_INTERVAL / 1.0
const FEET_OFFSET := Vector2(0.0, 14.0)
## acid_sheet'teki göl elipsinin yarıçapları (34x16 sanat pikseli) dünya biriminde.
const RADIUS_X := 34.0 * TEXEL
const RADIUS_Y := 16.0 * TEXEL

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _anim: AnimatedSprite2D = null
var _duration: float = 4.0
var _t: float = 0.0
var _outro: bool = false
var _next_hit: Dictionary = {} ## oyuncu instance_id -> bir sonraki hasarın zamanı (_t)


func _ready() -> void:
	z_index = 0 ## zeminde - negatif z harita altında kalır (bkz. fx_korsan_zone.gd)
	_duration = float(data.get("duration", 4.0))
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * TEXEL
	_anim.sprite_frames = ACID_FRAMES
	add_child(_anim)
	_anim.play(&"intro")
	_anim.animation_finished.connect(_on_anim_finished)
	FxScript.spawn(get_parent(), global_position + Vector2(0.0, -6.0), BURST_FRAMES, &"burst", 3)
	get_tree().create_timer(_duration + 3.0, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _on_anim_finished() -> void:
	if _anim.animation == &"intro":
		_anim.play(&"loop")
	elif _anim.animation == &"outro":
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		if not _outro:
			_outro = true
			_anim.play(&"outro")
		return
	if not authoritative:
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var rel: Vector2 = (p as Node2D).global_position + FEET_OFFSET - global_position
		var rx: float = RADIUS_X + AbilitiesScript.TARGET_BODY_RADIUS
		var ry: float = RADIUS_Y + AbilitiesScript.TARGET_BODY_RADIUS
		if (rel.x / rx) * (rel.x / rx) + (rel.y / ry) * (rel.y / ry) > 1.0:
			continue
		var id: int = p.get_instance_id()
		if _t < float(_next_hit.get(id, 0.0)):
			continue
		_next_hit[id] = _t + TICK_INTERVAL
		AbilitiesScript.deal_special_damage(p, damage * TICK_DAMAGE_SCALE, source, "acid")
