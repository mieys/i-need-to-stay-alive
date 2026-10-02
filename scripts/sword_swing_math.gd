extends RefCounted

## Uzunkılıç savuruşu - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer istemcilerdeki kozmetik
## kopya). Kullanıcı isteği (2026-09-26): "kılıcın çalışma biçimini değiştiriyoruz artık etrafımızda dönmesi yerine
## hedeflediği düşmana doğru savurulsun. animasyonlarını da buna göre yap güzel bir şekilde" + "savuruşunu daha güzel yap
## eski hali kötüydü" (diğer yakın dövüş silahlarının hedef üstünde "Z" çizen zikzağı kılıçta kötü duruyordu).
##
## Hareket (hepsi dünya koordinatında, saldırı anında sabitlenen bir "plan" üzerinden):
##   1. Atılma (APPROACH): ikon kafanın üstündeki yerinden yayın BAŞ noktasına süzülür ve bıçağı geriye yatırır (hazırlık).
##   2. Süpürme (SWEEP): ikon, hedefin biraz gerisindeki bir "el" noktası (pivot) etrafında SPAN derecelik yay çizer -
##      bıçak her an pivottan dışarı bakar, ucu hedefin tam üstünden geçer. Yay yönü her savuruşta değişir (sağ/sol).
##      Süpürme başlarken bıçak ucunun izlediği yayda pixel-art hilal (assets/fx/sword_sweep, tools/gen_weapon_fx_sprites.py
##      gen_sword_sweep) oynar.
##   3. Takip (FOLLOW) + dönüş (RETURN): kısa bir duruştan sonra yumuşakça dinlenme yerine döner.
## Hasar, bıçak hedefin üstünden geçtiği AN (contact_delay) uygulanır - efekt/sayı/vuruş aynı anda görünür.
##
## Yeni bir savuruş ayarı değiştirirsen SADECE burayı değiştir; iki çağıran dosya aynı fonksiyonları kullanır (CLAUDE.md
## "iki ayrı yer" hata sınıfı).

const APPROACH := 0.11
const SWEEP := 0.15
const FOLLOW := 0.06
const RETURN := 0.26
const HALF_SPAN := 1.3089969 ## 75 derece (yayın yarısı - toplam 150)

## Dünya px'i, oyuncu kök ölçeği REF_OWNER_SCALE (0.5) ve boyut çarpanı 1 iken. Bıçak ~28 px: sapı pivota yakın, ucu
## TIP_RADIUS'ta - hedef (pivot + dir * PIVOT_BACK) ucun geçtiği yayın ortasında kalır.
const PIVOT_BACK := 30.0
const ICON_RADIUS := 17.0
const TIP_RADIUS := 34.0
const REF_OWNER_SCALE := 0.5

const SWEEP_FRAMES: SpriteFrames = preload("res://assets/fx/sword_sweep/sweep_frames.tres")
const SWEEP_BAKED_RADIUS := 32.0 ## gen_sword_sweep R (sanat pikseli)
const SWEEP_Z_INDEX := 5 ## yaratıkların (0) ve oyuncuların (1) üstünde


## dir: saldırı yönü (normalize), target: hedefin saldırı anındaki konumu, side: +1/-1 (yay yönü), size: boyut çarpanı
## (menzil büyümesi x alan çarpanları), owner_scale: silahı taşıyan karakterin kök ölçeği.
static func make_plan(dir: Vector2, target: Vector2, side: float, size: float, owner_scale: float) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	var mid: float = dir.angle()
	var s: float = 1.0 if side >= 0.0 else -1.0
	return {
		"pivot": target - dir.normalized() * PIVOT_BACK * k,
		"mid": mid,
		"a0": mid - s * HALF_SPAN,
		"a1": mid + s * HALF_SPAN,
		"side": s,
		"k": k,
	}


## Yay üzerindeki a açısında ikonun dünya konumu (bıçak pivottan dışarı bakar; rotasyon = a - forward).
static func icon_pos(plan: Dictionary, a: float) -> Vector2:
	return (plan["pivot"] as Vector2) + Vector2.from_angle(a) * ICON_RADIUS * float(plan["k"])


## Saldırıdan bıçağın hedefin üstünden geçtiği ana kadar geçen süre (süpürme simetrik ease -> tam ortası).
static func contact_delay(speed: float) -> float:
	return (APPROACH + SWEEP * 0.5) / maxf(0.01, speed)


## Toplam animasyon süresi (dönüş hariç) - sonraki savuruşla çakışma kontrolü için.
static func busy_duration(speed: float) -> float:
	return (APPROACH + SWEEP + FOLLOW) / maxf(0.01, speed)


## İkonu plana göre oynatır. host: tween'in bağlanacağı düğüm (silah / kukla). rest_pos/rest_rot: ikonun YEREL dinlenme
## konumu/rotasyonu (dönüş canlı hesaplanır - karakter yürürken ikon doğru yere döner). fx_parent: hilalin ekleneceği
## düğüm (dünyada sabit kalsın diye sahne kökü). Dönen tween'i çağıran saklayıp bir sonraki savuruşta kesebilir.
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		speed: float, fx_parent: Node) -> Tween:
	var sp: float = maxf(0.01, speed)
	var start_pos: Vector2 = icon.global_position
	var start_rot: float = icon.global_rotation
	var a0: float = plan["a0"]
	var a1: float = plan["a1"]
	var p0: Vector2 = icon_pos(plan, a0)
	var approach_step := func(t: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = start_pos.lerp(p0, t)
			icon.global_rotation = lerp_angle(start_rot, a0 - forward, t)
	var sweep_step := func(a: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = icon_pos(plan, a)
			icon.global_rotation = a - forward
	var start_fx := func() -> void:
		spawn_sweep_fx(fx_parent, plan, sp)
	var tw: Tween = host.create_tween()
	tw.tween_method(approach_step, 0.0, 1.0, APPROACH / sp).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(start_fx)
	tw.tween_method(sweep_step, a0, a1, SWEEP / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(FOLLOW / sp)
	tw.tween_property(icon, "position", rest_pos, RETURN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## KRİTİK SAPLAMA (kullanıcı isteği 2026-09-29: "kılıç vuruşu kritik olacağı zaman saplar gibi bir animasyonu olmalı",
## bkz. weapon_crit_anim.gd). Yay çizmek yerine: kılıç hedefin gerisinde geri çekilir (APPROACH), ucu hedefi delecek
## şekilde düz bir hamleyle saplanır ve uç TAM contact_delay anında hedefe varır - hasar zamanlaması savuruşla aynı
## kalır. Saplı kalıp hafifçe titrer, sonra çekilip dinlenme yerine döner. Hilal efekti yok (düz saplama).
const STAB_BACK := 26.0 ## geri çekilme mesafesi (plan ölçeği k ile büyür)
const STAB_OVER := 8.0 ## ucun hedefi geçtiği mesafe


static func make_stab_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	## İkon merkezi, ucun TIP_RADIUS-ICON_RADIUS gerisinde (bıçak yönü = dir).
	var hilt_back: float = (TIP_RADIUS - ICON_RADIUS) * k
	return {
		"dir": dir,
		"k": k,
		"wind": target - dir * (hilt_back + STAB_BACK * k),
		"hit": target - dir * (hilt_back - STAB_OVER * k),
		"out": target - dir * (hilt_back + STAB_BACK * 0.5 * k),
	}


static func play_stab(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		speed: float) -> Tween:
	var sp: float = maxf(0.01, speed)
	var start_pos: Vector2 = icon.global_position
	var start_rot: float = icon.global_rotation
	var dir: Vector2 = plan["dir"]
	var aim: float = dir.angle() - forward
	var wind: Vector2 = plan["wind"]
	var hit: Vector2 = plan["hit"]
	var out: Vector2 = plan["out"]
	var perp := Vector2(-dir.y, dir.x)
	var wind_step := func(t: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = start_pos.lerp(wind, t)
			icon.global_rotation = lerp_angle(start_rot, aim, t)
	var lunge_step := func(t: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = wind.lerp(hit, t)
			icon.global_rotation = aim
	var stuck_step := func(t: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = hit + perp * sin(t * TAU * 3.0) * 1.6 * (1.0 - t) * float(plan["k"])
			icon.global_rotation = aim
	var pull_step := func(t: float) -> void:
		if is_instance_valid(icon):
			icon.global_position = hit.lerp(out, t)
			icon.global_rotation = aim
	var tw: Tween = host.create_tween()
	tw.tween_method(wind_step, 0.0, 1.0, APPROACH / sp).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	## Saplama contact_delay'de (APPROACH + SWEEP/2) biter - hasar tam uç hedefe girdiği anda.
	tw.tween_method(lunge_step, 0.0, 1.0, SWEEP * 0.5 / sp).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_method(stuck_step, 0.0, 1.0, (SWEEP * 0.5 + FOLLOW) / sp)
	tw.tween_method(pull_step, 0.0, 1.0, 0.07 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position", rest_pos, RETURN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## Bıçak ucunun yayındaki hilal (tek seferlik, bitince silinir). Pişirilmiş hilal -75..+75 derece saat yönünde; ters
## yönlü savuruşta dikeyde aynalanır.
static func spawn_sweep_fx(parent: Node, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx := AnimatedSprite2D.new()
	fx.name = "SwordSweep"
	fx.sprite_frames = SWEEP_FRAMES
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_index = SWEEP_Z_INDEX
	fx.flip_v = float(plan["side"]) < 0.0
	parent.add_child(fx)
	fx.global_position = plan["pivot"]
	fx.global_rotation = plan["mid"]
	fx.global_scale = Vector2.ONE * (TIP_RADIUS * float(plan["k"]) / SWEEP_BAKED_RADIUS)
	fx.speed_scale = maxf(0.01, speed)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("play")
	return fx
