extends RefCounted

## Mızrak saplaması "Işık Hattı" + cirit fırlatması - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer
## istemcilerdeki kozmetik kopya). Kullanıcı seçimi 2026-10-19 (madde 300 prototipleri -> madde 305): görünüş D "Püsküllü",
## efekt A "Işık Hattı". Mızrak hedefin önüne süzülür, geri çekilir, düz SAPLAR: uçtan hattın sonuna sivri krem ışık çizgisi
## uzanır, hattaki (hedef + arkasındakiler) her yaratıkta yıldız + yana kırıntı. Cirit (özellik, scripts/weapon_traits/cirit.gd):
## büyük geri çekiliş, mızrak düz hatta FIRLATILIR (ikonun kendisi uçar, arkasında krem iz), sonda söner, kısa süre sonra
## dinlenme yerinde yeniden belirir.
##
## Plan çerçevesi (STEPS): orijin = hedefin saldırı anındaki konumu + ANCHOR (yaratığın gövde merkezi), +x = saldırı yönü,
## +y = Godot perp (-dir.y, dir.x); sola saldırıda y aynalanır (efekt flip_v). Konumlar ikonun MERKEZİ (mızrak merkezinden döner),
## açı = ucun baktığı yön (çerçeveye göre). Değerler prototipteki (tools/proto_20261019/mizrak_proto.py SPEC["A"], Dir._thrust /
## _cirit) ile AYNI; efektler (tools/gen_mizrak_fx.py) aynı zaman çizelgesiyle pişirildi. Hasar: weapon.gd _mizrak_contact
## (saplama) + cirit.gd (cirit) - zamanlar contact_delay / throw_contact_delay / pass_delay buradan.
##
## Yeni bir ayar değiştirirsen SADECE burayı (ve efekti yeniden pişir) değiştir; iki çağıran dosya aynı fonksiyonları
## kullanır (CLAUDE.md "iki ayrı yer" hata sınıfı).

const LineFxScene: PackedScene = preload("res://scenes/fx_mizrak_line.tscn") ## hız izi + ışık çizgisi, z 60, SMEAR_AT'te
const HitFxScene: PackedScene = preload("res://scenes/fx_mizrak_hit.tscn") ## delinen yaratıkta yıldız + kırıntı, z 60
const EndFxScene: PackedScene = preload("res://scenes/fx_mizrak_end.tscn") ## cirit sonu yıldızı, z 60
const TrailFrames: SpriteFrames = preload("res://assets/fx/mizrak/trail_frames.tres") ## uçan ciritin arkasındaki iz (döngü)
const MeleeChainMath := preload("res://scripts/melee_chain_math.gd") ## vuruş sonrası bekleme (madde 347 zincir)

const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## pişmiş efektin 1 sanat pikseli (dünya px, k = 1) = Zanaatkâr silahlarıyla aynı yoğunluk
const ANCHOR := Vector2(0.0, -3.5) ## çerçeve orijini hedefin bu kadar üstünde (pence_hook_math.gd ile aynı neden)
const TIP := 14.94 ## ikon merkezinden uca (dünya px, k = 1): mizrak_L3 sanatında uç a = 27,2 x 0,955 x 0,575

## [süre (sn), ikon merkezi (çerçeve) ya da null = önceki nokta, uç açısı (derece), boy ölçeği, en ölçeği, geçiş]
## Merkez x = ucun hedeflenen yeri - TIP x boy (prototipte poz ucun yeriyle verilir: hedefin 20 px önü, 7 px geri, 16 px geçe).
const STEPS := [
	[0.13, Vector2(-34.94, 0.0), 0.0, 1.0, 1.0, "out"], ## hedefin önüne süzül (uç 20 px önde)
	[0.07, Vector2(-40.89, 0.0), 0.0, 0.93, 1.05, "inout"], ## geri çek
	[0.045, Vector2(-0.43, 0.0), 0.0, 1.1, 0.94, "in"], ## sapla: uç hedeften 16 px geçer (temas CONTACT)
	[0.06, null, 0.0, 1.0, 1.0, "shake"], ## saplıyken titre
	[0.08, Vector2(-14.94, 0.0), 0.0, 1.0, 1.0, "out"], ## çek (uç hedefin üstüne)
	[0.03, null, 0.0, 1.0, 1.0, "lin"],
]
const CONTACT := 0.2357 ## uç hedeften geçtiği an (saldırı başından): 0,20 + sqrt(27/43) x 0,045
const SMEAR_AT := 0.20 ## hat efektinin başı (saplamanın başı, 60 fps sayfa)
const SHAKE_AMP := 0.5
const SHAKE_WAVES := 3.0
const CRIT_STRETCH := Vector2(1.22, 0.86) ## kritikte daha uzun, ince saplama (ayrı kritik animasyonu yok)
const RETURN := 0.26

## Hat (çerçeve x'i, k = 1): ucun başladığı yerden hedefin 80 px gerisine; yarı genişlik. Işık çizgisinin ucu bu hızla ilerler -
## hattaki yaratıklar sırayla (uç geçtikçe) vurulur / parlar.
const LINE_X0 := -22.0
const LINE_X1 := 80.0
const LINE_HW := 14.0
const STREAK_SPEED := 1700.0

## Cirit (her N. saplama, cirit.gd): büyük geri çekiliş -> RELEASE_AT'te bırak, mızrak uçar (uç THROW_TIP_X'ten), sonda FADE'de
## küçülerek söner, REAPPEAR sonra dinlenme yerinde POP ile belirir. Uçuş süresi hızdan (oyun hızı/saldırı hızı ölçeklemez).
const THROW_STEPS := [
	[0.13, Vector2(-34.94, 0.0), 0.0, 1.0, 1.0, "out"],
	[0.12, Vector2(-47.45, 0.0), 0.0, 0.9, 1.08, "inout"], ## büyük geri çekiliş (uç hedefin 34 px önü)
]
const RELEASE_AT := 0.25
const THROW_TIP_X := -34.0
const CIRIT_SPEED := 760.0 ## dünya px/sn (Uzun Atış x1,25)
const CIRIT_RANGE := 280.0 ## karakterden (Uzun Atış 360)
const MIN_TRAVEL := 30.0
const THROW_FADE := 0.08
const REAPPEAR := 0.4
const POP := 0.1
const TRAIL_TIP_OFFSET := Vector2(-41.0, 0.0) ## iz sayfasında uç (kare merkezinden, sanat px): uç düğümün orijininde dursun
const TRAIL_GROW := 0.08


## dir: saldırı yönü, target: hedefin saldırı anındaki konumu, size: boyut çarpanı (menzil büyümesi x alan çarpanı),
## owner_scale: silahı taşıyan karakterin kök ölçeği. throw: {} = saplama; {"range", "speed", "from"} = cirit (from: karakter).
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float, throw: Dictionary = {}) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	var side: float = -1.0 if dir.x < -0.001 else 1.0
	var plan: Dictionary = {"origin": target + ANCHOR, "dir": dir, "k": k, "side": side, "throw": not throw.is_empty()}
	if not throw.is_empty():
		var rel: Vector2 = target + ANCHOR + dir * THROW_TIP_X * k
		var from: Vector2 = Vector2(throw.get("from", target - dir * 100.0))
		plan["travel"] = maxf(MIN_TRAVEL, float(throw.get("range", CIRIT_RANGE)) - (rel - from).dot(dir))
		plan["fly_speed"] = maxf(50.0, float(throw.get("speed", CIRIT_SPEED)))
	return plan


## Çerçevedeki p noktasının dünya konumu (sola saldırıda y aynalı).
static func point(plan: Dictionary, p: Vector2) -> Vector2:
	var d: Vector2 = plan["dir"]
	return (plan["origin"] as Vector2) + Vector2(p.x, p.y * float(plan["side"])).rotated(d.angle()) * float(plan["k"])


static func angle(plan: Dictionary, deg: float) -> float:
	return (plan["dir"] as Vector2).angle() + deg_to_rad(deg) * float(plan["side"])


## Saplamanın temas anı (saldırı başından, sn).
static func contact_delay(speed: float) -> float:
	return CONTACT / maxf(0.01, speed)


## Saplama hareketinin toplam süresi (dönüş hariç; cirit hariç - fırlatmada mızrak zaten dinlenme yerinde belirir).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## Ciritte uçan ucun hedefin (çerçeve orijini) üstünden geçtiği an.
static func throw_contact_delay(plan: Dictionary, speed: float) -> float:
	return RELEASE_AT / maxf(0.01, speed) + absf(THROW_TIP_X) * float(plan["k"]) / float(plan.get("fly_speed", CIRIT_SPEED))


static func release_delay(speed: float) -> float:
	return RELEASE_AT / maxf(0.01, speed)


## Ciritin bırakıldığı uç noktası ve uçuşun sonu (dünya).
static func release_point(plan: Dictionary) -> Vector2:
	return point(plan, Vector2(THROW_TIP_X, 0.0))


static func throw_end(plan: Dictionary) -> Vector2:
	return release_point(plan) + (plan["dir"] as Vector2) * float(plan.get("travel", 0.0))


static func flight_duration(plan: Dictionary) -> float:
	return float(plan.get("travel", 0.0)) / float(plan.get("fly_speed", CIRIT_SPEED))


## Hattın dünya uçları [baş, son] (saplama).
static func line_segment(plan: Dictionary) -> Array:
	return [point(plan, Vector2(LINE_X0, 0.0)), point(plan, Vector2(LINE_X1, 0.0))]


## pos'un hat ekseni boyunca çerçeve x'i (k = 1 birimi).
static func local_x(plan: Dictionary, pos: Vector2) -> float:
	return (pos - (plan["origin"] as Vector2)).dot(plan["dir"]) / float(plan["k"])


## Saplamada ışık çizgisinin ucu pos'a ulaşınca geçen süre (temastan sonra; hedefin önündekiler 0).
static func pass_delay(plan: Dictionary, pos: Vector2) -> float:
	return maxf(0.0, local_x(plan, pos)) / STREAK_SPEED


## [a, b] hattının yarı genişlik hw içinde kalan canlı yaratıklar, hat boyunca sıralı ([düşman, a'dan uzaklık]).
## Kaster hasar için, kukla yıldızlar için AYNI sorguyu kullanır (kuklada yaratık kuklaları; sonuç kozmetik).
static func enemies_on_segment(tree: SceneTree, a: Vector2, b: Vector2, hw: float) -> Array:
	var out: Array = []
	if tree == null:
		return out
	var ab: Vector2 = b - a
	var ln: float = ab.length()
	if ln < 0.5:
		return out
	var u: Vector2 = ab / ln
	for e in Enemy.get_enemies_near(tree, (a + b) * 0.5, ln * 0.5 + hw):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		var q: Vector2 = (e as Node2D).global_position - a
		var s: float = q.dot(u)
		if s < -hw * 0.5 or s > ln + hw * 0.5:
			continue
		if absf(q.dot(u.orthogonal())) > hw:
			continue
		out.append([e, s])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
	return out


## Saplama hattındaki yaratıklar (birincil hedef her zaman başta, hattın dışına kaymış olsa bile).
static func line_victims(tree: SceneTree, plan: Dictionary, primary: Node2D = null) -> Array:
	var seg: Array = line_segment(plan)
	var hits: Array = enemies_on_segment(tree, seg[0], seg[1], LINE_HW * float(plan["k"]))
	var out: Array = []
	if is_instance_valid(primary) and primary.get("is_dead") != true:
		out.append(primary)
	for h: Array in hits:
		if h[0] != primary:
			out.append(h[0])
	return out


## İkonun dünya dönüşümü (pence_hook_math.gd _apply ile aynı): doku ekseni -> dünya = R(açı) . diag(boy, en) . R(-forward) x doku ölçeği.
static func _apply(ctx: Dictionary, center: Vector2, ang: float, sl: float, sw: float) -> void:
	var icon: Node2D = ctx["icon"]
	if not is_instance_valid(icon):
		return
	var t: float = ctx["texel"]
	var f: float = ctx["forward"]
	var e1: Vector2 = Vector2.RIGHT.rotated(-f)
	var e2: Vector2 = Vector2.DOWN.rotated(-f)
	var x_axis: Vector2 = Vector2(e1.x * sl, e1.y * sw).rotated(ang) * t
	var y_axis: Vector2 = Vector2(e2.x * sl, e2.y * sw).rotated(ang) * t
	icon.global_transform = Transform2D(x_axis, y_axis, center)


static func _set_ease(tr: MethodTweener, kind: String) -> void:
	match kind:
		"out":
			tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"in":
			tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"inout":
			tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			tr.set_trans(Tween.TRANS_LINEAR)


## İkonu plana göre oynatır, efektleri zamanında çıkarır. host: tween'in bağlanacağı düğüm (silah / kukla).
## forward: sanatın ucunun baktığı açı (sprite_forward_angle_deg). rest_pos/rest_rot: ikonun YEREL dinlenme konumu/rotasyonu.
## base_scale: ikonun SABİT taban ölçeği. fx_parent: efektlerin ekleneceği düğüm (dünyada sabit kalsın diye sahne kökü).
## on_release: ciritte bırakış anında çağrılır (kaster: cirit.gd hasar simülasyonu; kukla boş). hold: saplamadan sonra, dönüşten önce son
## pozda bekleme (MeleeChainMath.hold_time; 0 = hemen döner) - sonraki saplama beklemede gelirse mızrak oradan geri çekilir. Ciritte yok.
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		base_scale: Vector2, speed: float, crit: bool, fx_parent: Node, on_release: Callable = Callable(), hold: float = 0.0) -> Tween:
	var sp: float = maxf(0.01, speed)
	var parent_scale: float = absf((icon.get_parent() as Node2D).global_scale.x) if icon.get_parent() is Node2D else 1.0
	var ctx: Dictionary = {"icon": icon, "forward": forward, "texel": absf(base_scale.x) * parent_scale}
	var perp: Vector2 = Vector2((plan["dir"] as Vector2).y * -1.0, (plan["dir"] as Vector2).x) * float(plan["side"]) * float(plan["k"])
	var tw: Tween = host.create_tween()
	var prev_c: Vector2 = icon.global_position
	var prev_a: float = icon.global_rotation + forward
	var prev_sl: float = 1.0
	var prev_sw: float = 1.0
	var is_throw: bool = bool(plan.get("throw", false))
	var steps: Array = THROW_STEPS if is_throw else STEPS
	for i in range(steps.size()):
		var st: Array = steps[i]
		var a1: float = angle(plan, float(st[2]))
		if i == 0:
			prev_a = a1 + wrapf(prev_a - a1, -PI, PI) ## ilk adım en kısa yoldan
		var sl: float = float(st[3])
		var sw: float = float(st[4])
		if crit and not is_throw and i == 2:
			sl = CRIT_STRETCH.x
			sw = CRIT_STRETCH.y
		var c1: Vector2 = prev_c if typeof(st[1]) == TYPE_NIL else point(plan, st[1])
		var ca: Vector2 = prev_c
		var aa: float = prev_a
		var sla: float = prev_sl
		var swa: float = prev_sw
		var kind: String = str(st[5])
		var step: Callable
		if kind == "shake":
			step = func(e: float) -> void:
				_apply(ctx, ca + perp * SHAKE_AMP * sin(e * PI * 2.0 * SHAKE_WAVES) * (1.0 - e), a1, sl, sw)
		else:
			step = func(e: float) -> void:
				_apply(ctx, ca.lerp(c1, e), lerpf(aa, a1, e), lerpf(sla, sl, e), lerpf(swa, sw, e))
		_set_ease(tw.tween_method(step, 0.0, 1.0, float(st[0]) / sp), kind)
		if not is_throw and i == 2:
			## saplamanın başı: hız izi + ışık çizgisi (pişmiş, SMEAR_AT'ten); yıldızlar çağıranda (hattaki yaratıklara)
			tw.parallel().tween_callback(spawn_fx.bind(LineFxScene, fx_parent, plan, sp))
		prev_c = c1
		prev_a = a1
		prev_sl = sl
		prev_sw = sw
	if is_throw:
		_append_throw(tw, ctx, plan, prev_c, prev_a, icon, rest_pos, rest_rot, base_scale, sp, fx_parent, on_release)
		return tw
	MeleeChainMath.append_hold(tw, icon, hold)
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, RETURN / sp)
	tw.parallel().tween_property(icon, "skew", 0.0, RETURN / sp)
	return tw


## Cirit: bırak -> uç (iz ikonun çocuğu) -> küçülerek sön -> bekle -> dinlenme yerinde belir.
static func _append_throw(tw: Tween, ctx: Dictionary, plan: Dictionary, c0: Vector2, a1: float, icon: Node2D, rest_pos: Vector2,
		rest_rot: float, base_scale: Vector2, sp: float, fx_parent: Node, on_release: Callable) -> void:
	var travel: float = float(plan.get("travel", 0.0))
	var d: Vector2 = plan["dir"]
	var fl: float = maxf(0.02, flight_duration(plan))
	var c1: Vector2 = c0 + d * travel
	var trail_box: Array = [null]
	tw.tween_callback(func() -> void:
		trail_box[0] = _attach_trail(icon, ctx)
		if on_release.is_valid():
			on_release.call())
	var fly := func(e: float) -> void:
		_apply(ctx, c0.lerp(c1, e), a1, lerpf(0.9, 1.0, minf(1.0, e * 6.0)), 1.0)
	_set_ease(tw.tween_method(fly, 0.0, 1.0, fl), "lin")
	tw.tween_callback(func() -> void:
		_detach_trail(trail_box[0])
		spawn_point_fx(EndFxScene, fx_parent, c1 + d * TIP * float(plan["k"]), plan, 1.0))
	var fade := func(e: float) -> void:
		var s: float = maxf(0.001, 1.0 - e)
		_apply(ctx, c1, a1, s, s)
	_set_ease(tw.tween_method(fade, 0.0, 1.0, THROW_FADE), "in")
	tw.tween_interval(maxf(0.0, REAPPEAR - THROW_FADE))
	tw.tween_callback(func() -> void:
		if not is_instance_valid(icon):
			return
		icon.position = rest_pos
		icon.rotation = rest_rot
		icon.skew = 0.0
		icon.scale = base_scale * 0.001
		spawn_point_fx(HitFxScene, fx_parent, icon.global_position, plan, 1.0))
	tw.tween_property(icon, "scale", base_scale, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Uçan ciritin arkasındaki iz: ikonun çocuğu (onunla döner), ucun ileri eksenine hizalı, kısa sürede uzar.
static func _attach_trail(icon: Node2D, ctx: Dictionary) -> Node2D:
	if not is_instance_valid(icon):
		return null
	var tr := AnimatedSprite2D.new()
	tr.name = "MizrakCiritTrail"
	tr.sprite_frames = TrailFrames
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.offset = TRAIL_TIP_OFFSET
	tr.show_behind_parent = true
	## İkonun yerel ekseni: ileri = forward açısı; uç ikon merkezinden TIP (dünya) -> yerel = TIP / doku ölçeği. İz pikseli
	## ikonla aynı yoğunlukta (FX_WORLD_PX) - ikon doku ölçeği zaten 0,575 dünya px / piksel.
	var f: float = float(ctx["forward"])
	var texel: float = maxf(0.0001, float(ctx["texel"]))
	tr.rotation = f
	tr.position = Vector2.RIGHT.rotated(f) * (TIP / texel)
	tr.scale = Vector2(0.05, 1.0) * (FX_WORLD_PX / texel)
	icon.add_child(tr)
	tr.play(&"play")
	var full: Vector2 = Vector2.ONE * (FX_WORLD_PX / texel)
	tr.create_tween().tween_property(tr, "scale", full, TRAIL_GROW)
	return tr


static func _detach_trail(tr: Variant) -> void:
	if tr != null and is_instance_valid(tr):
		(tr as Node).queue_free()


## Pişmiş efekt (tek seferlik, fx_animation.gd bitince siler): çerçeve orijininde, saldırı yönüyle dönmüş, sola saldırıda flip_v.
static func spawn_fx(scene: PackedScene, parent: Node, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	return spawn_point_fx(scene, parent, plan["origin"], plan, speed)


static func spawn_point_fx(scene: PackedScene, parent: Node, pos: Vector2, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx: AnimatedSprite2D = scene.instantiate() as AnimatedSprite2D
	parent.add_child(fx)
	fx.global_position = pos
	fx.global_rotation = (plan["dir"] as Vector2).angle()
	fx.global_scale = Vector2.ONE * FX_WORLD_PX * float(plan["k"])
	fx.flip_v = float(plan["side"]) < 0.0
	fx.speed_scale = maxf(0.01, speed)
	return fx


## Delinen yaratık yıldızları: saplamada ışık çizgisi geçtikçe (t0 = temas), ciritte uç geçtikçe (t0 = bırakış) - kaster + kukla
## aynı sıra/zaman. host: zamanlayıcı ağacı. victims: [düşman]. speed: saldırı hızı ölçeği (pişmiş çizgi bununla hızlanır).
static func schedule_hit_stars(host: Node, plan: Dictionary, victims: Array, t0: float, fx_parent: Node, speed: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var tree: SceneTree = host.get_tree()
	var is_throw: bool = bool(plan.get("throw", false))
	var rel: Vector2 = release_point(plan) if is_throw else Vector2.ZERO
	for v in victims:
		if not is_instance_valid(v) or not (v is Node2D):
			continue
		var pos: Vector2 = (v as Node2D).global_position
		var at: float = t0
		if is_throw:
			at += maxf(0.0, (pos - rel).dot(plan["dir"])) / float(plan.get("fly_speed", CIRIT_SPEED))
		else:
			at += pass_delay(plan, pos) / maxf(0.01, speed)
		var cb := func(e: Variant) -> void:
			if is_instance_valid(e) and e is Node2D:
				spawn_point_fx(HitFxScene, fx_parent, (e as Node2D).global_position + ANCHOR * float(plan["k"]), plan, 1.0)
		if at <= 0.001:
			cb.call(v)
		else:
			tree.create_timer(at, false).timeout.connect(cb.bind(v))


## Ciritin uçuş hattındaki yaratıklar (yıldızlar ve kukla için; kaster hasarı cirit.gd'de karede ilerleyen uçla).
static func throw_victims(tree: SceneTree, plan: Dictionary) -> Array:
	var out: Array = []
	for h: Array in enemies_on_segment(tree, release_point(plan), throw_end(plan), LINE_HW * float(plan["k"])):
		out.append(h[0])
	return out
