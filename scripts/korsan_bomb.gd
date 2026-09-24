extends Node2D

## Korsan'ın TEMEL yeteneği (Saatli Bomba, skill2 id 17, bkz. player.gd _korsan_try_place_bomb/characters.gd DEFS[9])
## ile bırakılan saatli bomba. Kendisi hiçbir çarpışma/Area2D içermez - patlama hasarı doğrudan bir mesafe
## taramasıyla (bkz. detonate()) uygulanır.
##
## GÖRSEL (kullanıcı isteği: Korsan efektlerini sıfırdan pixel-art'a uygun tasarla): eski Sprite2D + modulate yanıp
## sönmesi kaldırıldı. Bomba artık pixel_draw.gd ızgarasında ASCII pixel-art olarak çizilir: karanlık yuvarlak barut
## bombası, üstünde kuru kafa, tepesinde titreşen fitil kıvılcımı; bırakılınca yere düşüp sekiyor, kuru kafanın
## gözleri kırmızı yanıp sönüyor ("kurulu" hissi), altında dither gölge. Yakın bombaların hepsi Patlat (Q) ile
## zincirleme patlar (player.gd _skill_korsan_detonate_all).
##
## Multiplayer notu: bu sahne HEM gerçek bombayı (bırakan istemcide, player.gd'nin _korsan_bombs dizisinde takip edilir,
## Q ile detonate() çağrılır) HEM DE diğer istemcilerdeki SADECE KOZMETİK kopyayı (network_manager.gd broadcast_drop
## "korsan_bomb") temsil eder. Kozmetik kopyaya asla detonate() çağrılmaz, hiçbir zaman hasar vermez.

const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")
const EXPLOSION_FX_SCENE := preload("res://scenes/fx_korsan_explosion.tscn")
## Kullanıcı isteği (2026-09-24): Korsan'ın TÜM efektleri spritesheet olmalı ("pixeldraw olarak kalmasın fpsi çok
## düşürüyor") - bomba eskiden HER KAREDE pixel_draw.gd ile ~160 draw_rect (gövde ASCII sanatı + fitil + gölge) çiziyordu.
## Artık tools/gen_korsan_fx_sprites.py'nin AYNI tasarımı (kuru kafalı barut bombası, düşüp sekme, titreşen fitil
## kıvılcımı, saniyede bir kırmızı yanıp sönen gözler, sert kenarlı mini gölge) pişirdiği "drop" + "idle" animasyonları.
const BOMB_FRAMES := preload("res://assets/fx/korsan/bomb_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL
## Karede bomba merkezi karenin ortasının 10 sanat pikseli altında (bkz. gen_korsan_fx_sprites.py bomb_frame) - node
## orijini bomba merkezine denk gelsin.
const SHEET_OFFSET := Vector2(0, -10)

## #39 DÜZELTME: patlama yarıçapı 130 -> 150 (KorsanFxMath.BOMB_RADIUS). damage varsayılanı player.gd tarafından üzerine yazılır.
var damage: float = 20.0
var radius: float = KorsanFxMath.BOMB_RADIUS
var _is_detonated: bool = false

## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - bombayı bırakan oyuncuya referans.
var owner_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
var _anim: AnimatedSprite2D = null


func _ready() -> void:
	if sprite:
		sprite.visible = false ## eski smooth sprite artık çizilmiyor - bkz. dosya başı notu
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = BOMB_FRAMES
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * TEXEL
	_anim.offset = SHEET_OFFSET
	add_child(_anim)
	_anim.play("drop")
	_anim.animation_finished.connect(func() -> void:
		if is_instance_valid(_anim) and _anim.animation == &"drop":
			_anim.play("idle"))


## Sadece GERÇEK bombayı bırakan istemci çağırır (bkz. player.gd _skill_korsan_detonate_all) - kozmetik kopyalarda hiç
## referans tutulmadığı için buraya asla ulaşılmaz.
func detonate() -> void:
	if _is_detonated:
		return
	_is_detonated = true
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - tek bir patlama, tek bir kritik zarı.
	var is_crit: bool = false
	var dmg: float = damage
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
		is_crit = owner_player._roll_ability_crit()
		dmg = owner_player._apply_ability_crit(dmg, is_crit)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
			e.take_damage(dmg, is_crit, 0.0, true)
	_spawn_explosion_fx()
	queue_free()


func _spawn_explosion_fx() -> void:
	var fx := EXPLOSION_FX_SCENE.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	if fx.has_method("setup"):
		fx.setup(radius, Color(1.0, 0.6, 0.2))
