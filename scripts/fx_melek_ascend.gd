extends Node2D

## Melek ULTİ (Kutsal Korku, skill3 id 32 - 2026-10-11 rework): LIFE sn havalanma görünümü.
##   ARKA (show_behind_parent): sırttan açılan sarı-beyaz parıltılı pixel melek kanatları (açılır, yavaşça çırpar, kapanırken
##          söner) + gövde çevresinde dither altın ışıma + kanat uçlarından dökülen "+" parıltılar
##   ÖN   : karakterin KENDİ karesinin altın, toplamalı (ADD) kopyası - "kendi görüntüsü de parıltılı sararır". Asıl sprite'ın
##          modulate'ına DOKUNULMAZ (vuruş flaşı/görünmezlik/ağ renk yayını onu yazıyor) - üstüne ayrı bir Sprite2D biner.
##   HAVALANMA: ebeveynin AnimatedSprite2D offset'i LIFT_ART_PX yukarı (yer gölgesi yerde kalır -> havada görünür), çıkışta geri.
## Karakterin (Player) ya da diğer istemcideki kuklanın (RemotePlayer) ÇOCUĞU olarak doğar (player.gd _play_and_broadcast_skill_fx).
## Hareket kilidi player.gd'de (_melek_ascending) - bu dosya sadece görsel.

## FPS (madde 215): kanatlar + dither ışıma + dökülen parıltılar SPRITE SAYFASINA pişirildi (assets/fx/baked/melek_ascend_wings_*,
## `tools/fx_bake.ps1`; özgün çizim `tools/fx_bake_src/fx_melek_ascend.gd`) - sayfa omuz hizasıyla pişti, burada sadece yükselmeyle
## birlikte kaldırılır. Kendi karesinin ADD kopyası (parıltı) ve sprite yükselmesi eskisi gibi kodla.
const BakedFx := preload("res://scripts/baked_fx.gd")
const WINGS := preload("res://assets/fx/baked/melek_ascend_wings_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli

## player.gd MELEK_R_ASCEND_TIME / SKILL3_TIMING[32]["duration"] bunu okur (tek kaynak).
const LIFE := 2.0
const RISE_TIME := 0.3
const FALL_TIME := 0.35
const LIFT_ART_PX := 7.0 ## sprite sanat pikseli (Melek ölçeğiyle ~15 dünya px)
## Kanat kökü: sprite'ın konumuna göre omuz hizası (fx_melek_holy BODY_CENTER (0,-4), halo -40 ile aynı çerçeve).
const SHOULDER := Vector2(0, -16)
const FEATHERS := 7

const GOLD := Color(1.0, 0.82, 0.22)
const GOLD_LIGHT := Color(1.0, 0.95, 0.6)
const GOLD_DEEP := Color(0.95, 0.6, 0.1)
const WHITE_GOLD := Color(1.0, 0.99, 0.85)

var _host: Node2D = null
var _anim: AnimatedSprite2D = null
var _base_offset: Vector2 = Vector2.ZERO
var _glow: Sprite2D = null
var _t: float = 0.0
var _wings: AnimatedSprite2D = null


func _ready() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_wings = BakedFx.attach(self, WINGS, TEXEL, false)
	if _host != null:
		_anim = _host.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _anim != null:
		_base_offset = _anim.offset
		_glow = Sprite2D.new()
		_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_glow.modulate = Color(1, 1, 1, 0)
		_host.add_child.call_deferred(_glow) ## ön katman ebeveynin KARDEŞİ (bkz. fx_melek_holy.gd aynı gerekçe)


func _exit_tree() -> void:
	if _anim != null and is_instance_valid(_anim):
		_anim.offset = _base_offset
	if _glow != null and is_instance_valid(_glow):
		_glow.queue_free()


## 0->1 (RISE_TIME), sonra 1, son FALL_TIME'da 1->0.
func _envelope() -> float:
	return clampf(minf(_t / RISE_TIME, (LIFE - _t) / FALL_TIME), 0.0, 1.0)


func _lift_local() -> float:
	if _anim == null:
		return 0.0
	var e: float = _envelope()
	return LIFT_ART_PX * e * e * (3.0 - 2.0 * e) * _anim.scale.y


func _process(delta: float) -> void:
	_t += delta
	var dead: bool = _host != null and is_instance_valid(_host) and _host.get("is_dead") == true
	if _t >= LIFE or _host == null or not is_instance_valid(_host) or dead:
		queue_free()
		return
	var env: float = _envelope()
	if _anim != null and is_instance_valid(_anim):
		var e: float = env * env * (3.0 - 2.0 * env)
		## Hafif süzülme salınımı (havada asılı)
		var bob: float = sin(_t * 5.0) * 0.8 * e
		_anim.offset = _base_offset + Vector2(0, -(LIFT_ART_PX * e + bob))
		_update_glow(env)
	_wings.position = _wing_root()


func _update_glow(env: float) -> void:
	if _glow == null or not is_instance_valid(_glow) or _anim.sprite_frames == null:
		return
	_glow.texture = _anim.sprite_frames.get_frame_texture(_anim.animation, _anim.frame)
	_glow.position = _anim.position
	_glow.scale = _anim.scale
	_glow.offset = _anim.offset
	_glow.centered = _anim.centered
	_glow.flip_h = _anim.flip_h
	_glow.flip_v = _anim.flip_v
	_glow.z_index = _anim.z_index
	var pulse: float = 0.5 + 0.5 * sin(_t * 9.0)
	_glow.modulate = Color(1.0, 0.82, 0.3, (0.38 + 0.22 * pulse) * env)


func _wing_root() -> Vector2:
	var p: Vector2 = _anim.position if _anim != null else Vector2.ZERO
	return p - Vector2(0, _lift_local()) ## omuz hizası (SHOULDER) sayfaya pişti
