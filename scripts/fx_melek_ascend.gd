extends Node2D

## Melek ULTİ (Kutsal Korku, skill3 id 32 - 2026-10-11 rework): LIFE sn havalanma görünümü.
##   ARKA (show_behind_parent): sırttan açılan sarı-beyaz parıltılı pixel melek kanatları (açılır, yavaşça çırpar, kapanırken
##          söner) + gövde çevresinde dither altın ışıma + kanat uçlarından dökülen "+" parıltılar
##   ÖN   : karakterin KENDİ karesinin altın, toplamalı (ADD) kopyası - "kendi görüntüsü de parıltılı sararır". Asıl sprite'ın
##          modulate'ına DOKUNULMAZ (vuruş flaşı/görünmezlik/ağ renk yayını onu yazıyor) - üstüne ayrı bir Sprite2D biner.
##   HAVALANMA: ebeveynin AnimatedSprite2D offset'i LIFT_ART_PX yukarı (yer gölgesi yerde kalır -> havada görünür), çıkışta geri.
## Karakterin (Player) ya da diğer istemcideki kuklanın (RemotePlayer) ÇOCUĞU olarak doğar (player.gd _play_and_broadcast_skill_fx).
## Hareket kilidi player.gd'de (_melek_ascending) - bu dosya sadece görsel.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

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
var _sparkles: Array = [] ## [pos, age, life]
var _spawn_acc: float = 0.0


func _ready() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
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
	var base: Vector2 = _wing_root()
	_spawn_acc += delta
	while _spawn_acc > 0.05 and _t < LIFE - FALL_TIME:
		_spawn_acc -= 0.05
		var side: float = -1.0 if randf() < 0.5 else 1.0
		_sparkles.append([base + Vector2(side * randf_range(14.0, 40.0), randf_range(-24.0, 22.0)), 0.0, randf_range(0.45, 0.8)])
	for s in _sparkles:
		s[1] += delta
		s[0] += Vector2(0, 16.0) * delta ## tüy gibi aşağı süzülür
	_sparkles = _sparkles.filter(func(s): return float(s[1]) < float(s[2]))
	queue_redraw()


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
	return p + SHOULDER - Vector2(0, _lift_local())


func _draw() -> void:
	var env: float = _envelope()
	if env <= 0.0:
		return
	var base: Vector2 = _wing_root()
	var flick: int = int(_t * 12.0)
	## Gövde çevresinde dither altın ışıma
	PixelDraw.disc_dither(self, base + Vector2(0, 10), 34.0 * env, Color(GOLD.r, GOLD.g, GOLD.b, 0.45), flick, 2)
	## Kanatlar: açılma (env, yumuşak) + çırpma (yavaş, ~1.3 vuruş/sn)
	var open: float = env * env * (3.0 - 2.0 * env)
	var flap: float = sin(_t * 8.0)
	for side in [-1.0, 1.0]:
		_draw_wing(base, side, open, flap, env)
	## Kanat uçlarından dökülen parıltılar
	var texel: float = PixelDraw.TEXEL
	for s in _sparkles:
		var k: float = float(s[1]) / float(s[2])
		var col: Color = WHITE_GOLD if k < 0.5 else GOLD
		col.a = env
		PixelDraw.px(self, s[0], 1, col)
		if k > 0.15 and k < 0.75:
			for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				PixelDraw.px(self, s[0] + o * texel, 1, col)


## Tek kanat: omuzdan bileğe uzanan kemik + kemik boyunca dizilmiş FEATHERS tüy (içtekiler aşağı, dıştakiler dışa-yukarı).
## Önce tüm tüylerin koyu altın kenarı, sonra açık dolgu, sonra beyaz öz - tüyler birbirine kaynayıp tek kanat siluetine döner.
func _draw_wing(base: Vector2, side: float, open: float, flap: float, env: float) -> void:
	var root: Vector2 = base + Vector2(side * 3.0, 0)
	var wrist: Vector2 = root + Vector2(side * 22.0, -18.0 - flap * 4.0) * open
	var tips: Array = []
	var roots: Array = []
	for i in range(FEATHERS):
		var k: float = float(i) / float(FEATHERS - 1)
		var r: Vector2 = root.lerp(wrist, 0.25 + 0.75 * k)
		## Açı: +x'ten, aşağı pozitif. İçteki tüy ~aşağı (100°), dıştaki dışa-yukarı (-25°); çırpma hepsini birlikte döndürür.
		var ang: float = lerpf(deg_to_rad(100.0), deg_to_rad(-25.0), k) + flap * 0.18
		var dir: Vector2 = Vector2(cos(ang) * side, sin(ang))
		var length: float = lerpf(18.0, 32.0, k) * open
		roots.append(r)
		tips.append(r + dir * length)
	var a: float = env
	var outline := Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, a)
	var fill := Color(WHITE_GOLD.r, WHITE_GOLD.g, WHITE_GOLD.b, a)
	var core := Color(1.0, 1.0, 1.0, a)
	var tip_col := Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, a)
	PixelDraw.line(self, root, wrist, outline, 4)
	for i in range(FEATHERS):
		PixelDraw.line(self, roots[i], tips[i], outline, 4)
	PixelDraw.line(self, root, wrist, Color(GOLD.r, GOLD.g, GOLD.b, a), 2)
	for i in range(FEATHERS):
		PixelDraw.line(self, roots[i], tips[i], fill, 2)
	for i in range(FEATHERS):
		var tip: Vector2 = tips[i]
		PixelDraw.line(self, roots[i], (roots[i] as Vector2).lerp(tip, 0.6), core, 1)
		## Parıldayan uç: sırayla yanıp sönen beyaz-altın piksel
		var glint: bool = (i + int(_t * 10.0)) % 4 == 0
		PixelDraw.px(self, tip, 2, core if glint else tip_col)
