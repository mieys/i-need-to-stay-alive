extends Node2D

## Talon'un Ayna Formu (R): anime "öfke/süper form" tarzı dönüşüm. Turuncu-kırmızı pixel-art alev aurası + parıltı:
##  - dönüşüm anı: yukarı fırlayan ışık sütunu, genişleyen pixel şok halkası, dışa saçılan ışınlar, kısa beyaz parlama
##  - form boyunca: karakterin ARKASINDA yukarı yalayan sivri pixel alev sütunları (ortadakiler daha uzun), dither
##    ışıma ve yükselen kor; ÖNÜNDE gövdede/silahlarda rastgele beliren pixel "+" parıltıları
## Boyut %10 artışı (karakter + silahlar) player.gd/remote_player.gd'de (TalonFormationMath.FORM_SCALE_MULT);
## bu FX sadece görseldir. Player ya da RemotePlayer'ın ÇOCUĞU olarak doğar; ömrü ebeveynin form bayrağını izler
## (yerel: _talon_mirror_form_active, uzak: _talon_form_active - bkz. main.gd extra["talon_form"]).
##
## PERF (kullanıcı bildirimi 2026-09-24: "talon oyunu çok kastırıyor yetenek kullandığında"): ÖLÇÜM (gerçek render,
## 60 yaratık + 5 silah): taban ~7 ms/kare, R açıkken 15.4 ms (65 fps), bu FX gizlenince 8.4 ms (119 fps) - eski sürüm
## HER KAREDE pixel_draw.gd ile iki dither disk + 37 sütunluk 2 katmanlı alev ızgarası + kor/parıltı/zikzak çiziyordu
## (binlerce draw_rect, 15 sn boyunca; Silah Salvosu ile birlikte 50 fps). Artık AYNI çizim tools/gen_talon_form_sprites.py
## ile sanat pikseli çözünürlüğünde spritesheet'e pişirildi: arka + ön katman için birer AnimatedSprite2D ("intro" 0.7 sn
## tek seferlik, sonra 2π sn'lik kusursuz "loop"). Kapanış eski "küçülerek sönme" yerine FADE_OUT'ta saydamlaşma. Sadece
## silahların üstündeki "+" parıltılar silah KONUMUNA bağlı olduğu için hâlâ prosedürel (birkaç piksel).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const BackFrames := preload("res://assets/fx/talon_form/back_frames.tres")
const FrontFrames := preload("res://assets/fx/talon_form/front_frames.tres")

const INTRO_TIME := 0.7
const FADE_OUT := 0.35
const NO_FLAG_GRACE := 2.0 ## uzak kopyada durum paketi gecikirse bayrak henüz true olmayabilir
## gen_talon_form_sprites.py tuvali: arka katmanın orijini (0,0) sayfada (56, 94). Yarım texel kayma: pixel_draw.gd'nin
## kareleri snap(pos) MERKEZLİ, raster pikselleri ise köşeden başlar.
const BACK_OFFSET := Vector2(-0.5, -26.5)
const FRONT_OFFSET := Vector2(-0.5, -0.5)

var _host: Node2D = null
var _t: float = 0.0
var _seen_on: bool = false
var _off_time: float = 0.0
var _closing: float = 0.0 ## 0 = açık, >0 = kapanıyor (sn)
var _sparks: Array = [] ## silah parıltıları: [pos (host yereli), age, life]
var _front: Node2D = null
var _back_anim: AnimatedSprite2D = null
var _front_anim: AnimatedSprite2D = null


func _ready() -> void:
	show_behind_parent = true ## alev karakterin ARKASINDA (siblings: anim/silahlar sonra çizilir)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_back_anim = _make_anim(BackFrames, BACK_OFFSET)
	add_child(_back_anim)
	## Ön katman: parıltılar karakterin/silahların ÖNÜNDE. show_behind_parent'lı bu düğümün çocuğu olsaydı o da arkada
	## kalırdı - bu yüzden ebeveynin (karakterin) KARDEŞİ olarak eklenir (doğum anında ebeveyn meşgul: call_deferred).
	_front = Node2D.new()
	_front.z_index = 0
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.draw.connect(_draw_front)
	_front_anim = _make_anim(FrontFrames, FRONT_OFFSET)
	_front.add_child(_front_anim)
	if _host != null:
		_host.add_child.call_deferred(_front)


func _make_anim(frames: SpriteFrames, offset_px: Vector2) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.scale = Vector2.ONE * PixelDraw.TEXEL
	a.offset = offset_px
	a.play(&"intro")
	a.animation_finished.connect(func() -> void:
		if a.animation == &"intro":
			a.play(&"loop")
			## Döngü, girişin bittiği ana (INTRO_TIME) denk gelen kareden devam etsin (alev fazı sıçramasın).
			var n: int = frames.get_frame_count(&"loop")
			a.frame = int(INTRO_TIME * frames.get_animation_speed(&"loop")) % maxi(n, 1))
	return a


func _exit_tree() -> void:
	if _front != null and is_instance_valid(_front):
		_front.queue_free()


func _flag_on() -> bool:
	if _host == null or not is_instance_valid(_host):
		return false
	if "_talon_mirror_form_active" in _host:
		return bool(_host._talon_mirror_form_active)
	if "_talon_form_active" in _host:
		return bool(_host._talon_form_active)
	return true


func _weapon_points() -> Array:
	var pts: Array = []
	if _host == null or not is_instance_valid(_host):
		return pts
	if "owned_weapon_nodes" in _host:
		for w in _host.owned_weapon_nodes:
			if is_instance_valid(w) and w.has_method("set_icon_offset"):
				pts.append((w as Node2D).global_position)
	elif "_weapon_icons" in _host:
		for ic in _host._weapon_icons:
			if is_instance_valid(ic):
				pts.append((ic as Node2D).global_position)
	return pts


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	var on: bool = _flag_on()
	if on:
		_seen_on = true
		_off_time = 0.0
	else:
		_off_time += delta
	var should_close: bool = (_seen_on and _off_time > 0.4) or ((not _seen_on) and _t > NO_FLAG_GRACE)
	if should_close and _closing <= 0.0:
		_closing = 0.0001
	if _closing > 0.0:
		_closing += delta
		if _closing >= FADE_OUT:
			queue_free()
			return
		var alpha: float = clampf(1.0 - _closing / FADE_OUT, 0.0, 1.0)
		modulate.a = alpha
		if _front and is_instance_valid(_front):
			_front.modulate.a = alpha
	## Silah parıltıları (silah konumuna bağlı - pişirilemez, birkaç piksel)
	var had_sparks: bool = not _sparks.is_empty()
	if _closing <= 0.0 and randf() < delta * 10.0:
		var wp: Array = _weapon_points()
		if not wp.is_empty():
			var w: Vector2 = wp[randi() % wp.size()]
			_sparks.append([w - _host.global_position + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)), 0.0, randf_range(0.25, 0.4)])
	for s in _sparks:
		s[1] += delta
	_sparks = _sparks.filter(func(s): return float(s[1]) < float(s[2]))
	if (had_sparks or not _sparks.is_empty()) and _front and is_instance_valid(_front):
		_front.queue_redraw()


## --- ÖN KATMAN: sadece silah parıltıları (gövde parıltıları/şok halkası/zikzaklar _front_anim'de pişmiş) ---
func _draw_front() -> void:
	var texel: float = PixelDraw.TEXEL
	var c := Color(1.0, 0.85, 0.4)
	for s in _sparks:
		var k: float = float(s[1]) / float(s[2])
		var p: Vector2 = s[0]
		PixelDraw.px(_front, p, 1, c)
		if k > 0.25 and k < 0.75:
			PixelDraw.px(_front, p + Vector2(texel * 2.0, 0), 1, c)
			PixelDraw.px(_front, p - Vector2(texel * 2.0, 0), 1, c)
			PixelDraw.px(_front, p + Vector2(0, texel * 2.0), 1, c)
			PixelDraw.px(_front, p - Vector2(0, texel * 2.0), 1, c)
