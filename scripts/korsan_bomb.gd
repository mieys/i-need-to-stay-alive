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

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")
const EXPLOSION_FX_SCENE := preload("res://scenes/fx_korsan_explosion.tscn")

## #39 DÜZELTME: patlama yarıçapı 130 -> 150 (KorsanFxMath.BOMB_RADIUS). damage varsayılanı player.gd tarafından üzerine yazılır.
var damage: float = 20.0
var radius: float = KorsanFxMath.BOMB_RADIUS
var _is_detonated: bool = false
var _life: float = 0.0

## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - bombayı bırakan oyuncuya referans.
var owner_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D

const DROP_TIME := 0.28
const BOUNCE_TIME := 0.16

## 12x13 ASCII pixel-art. o: kontur, d: koyu gövde, m: orta ton, h: parlak yansıma, w: kuru kafa, c: metal başlık.
const BODY_ART: Array = [
	"....cccc....",
	"...occcco...",
	"..oddddddo..",
	".oddmmmmddo.",
	".odmhhmmmdo.",
	"odmhmmmmmmdo",
	"odmmwwwwmmdo",
	"odmmwowowmdo",
	"odmmmwwwmmdo",
	".odmmmmmmdo.",
	".oddmmmmddo.",
	"..ooddddoo..",
	"....oooo....",
]
const BODY_PAL := {
	"o": Color(0.05, 0.05, 0.09),
	"d": Color(0.14, 0.14, 0.2),
	"m": Color(0.26, 0.26, 0.35),
	"h": Color(0.62, 0.62, 0.75),
	"w": Color(0.93, 0.9, 0.84),
	"c": Color(0.42, 0.37, 0.3),
}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite:
		sprite.visible = false ## eski smooth sprite artık çizilmiyor - bkz. dosya başı notu


func _process(delta: float) -> void:
	if _is_detonated:
		return
	_life += delta
	queue_redraw()


func _draw() -> void:
	var texel: float = PixelDraw.TEXEL
	## Düşme + sekme: yükseklik (px, yukarı = negatif)
	var lift: float = 0.0
	if _life < DROP_TIME:
		var k: float = 1.0 - _life / DROP_TIME
		lift = -k * k * 34.0
	elif _life < DROP_TIME + BOUNCE_TIME:
		var b: float = (_life - DROP_TIME) / BOUNCE_TIME
		lift = -sin(b * PI) * 5.0
	## Gölge (dither): bomba yükseldikçe küçülür
	var shadow_r: float = 9.0 * (1.0 - clampf(-lift / 60.0, 0.0, 0.4))
	PixelDraw.disc_dither(self, Vector2(0, 8.0), shadow_r, Color(0.02, 0.02, 0.04, 0.55), 0, 1)
	var center := Vector2(0, lift - 1.0)
	PixelDraw.art(self, center, BODY_ART, BODY_PAL, 1.0)
	## Kuru kafa gözleri: kurulu bomba - saniyede bir kısa kırmızı yanıp söner
	var armed_blink: bool = _life > DROP_TIME + BOUNCE_TIME and fmod(_life, 1.0) < 0.16
	if armed_blink:
		var eye_col := Color(1.0, 0.18, 0.1)
		PixelDraw.px(self, center + Vector2(-texel, 0.5 * texel), 1, eye_col)
		PixelDraw.px(self, center + Vector2(texel, 0.5 * texel), 1, eye_col)
	## Fitil: başlıktan sağ-yukarı kıvrılan 5 kahverengi piksel + titreşen kıvılcım ucu
	var top: Vector2 = center + Vector2(0, -6.5 * texel)
	var fuse: Array = [Vector2(1, -1), Vector2(2, -2), Vector2(2, -3), Vector2(3, -4), Vector2(4, -4)]
	for f in fuse:
		PixelDraw.px(self, top + f * texel, 1, Color(0.56, 0.36, 0.16))
	var tip: Vector2 = top + Vector2(4, -4) * texel
	var frame: int = int(_life * 14.0) % 3
	match frame:
		0: ## artı biçimli sarı-beyaz
			PixelDraw.px(self, tip, 1, Color(1.0, 0.98, 0.8))
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				PixelDraw.px(self, tip + o * texel, 1, Color(1.0, 0.8, 0.25))
		1: ## çapraz turuncu
			PixelDraw.px(self, tip, 1, Color(1.0, 0.9, 0.5))
			for o in [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
				PixelDraw.px(self, tip + o * texel, 1, Color(1.0, 0.5, 0.12))
		_: ## küçük kırmızı-sarı
			PixelDraw.px(self, tip, 2, Color(1.0, 0.65, 0.15))
			PixelDraw.px(self, tip + Vector2(0, -2) * texel, 1, Color(1.0, 0.9, 0.4))


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
