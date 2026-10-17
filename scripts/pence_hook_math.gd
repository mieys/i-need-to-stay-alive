extends RefCounted

## Pençe vuruşu "Kanca Çekiş" - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer istemcilerdeki
## kozmetik kopya). Kullanıcı seçimi 2026-10-17 (CLAUDE.md madde 236 prototip B -> madde 237): eski hedef önünde yana
## süpürme + iri pikselli pembe-kırmızı 3 çizgi (fx_pence_slash) yerine pençe geri siner, atılıp hedefe saplanır (1. isabet),
## saplıyken titrer ve ÇEKEREK yırtar (2. isabet): oyuncuya doğru 3 uzun yırtık + geri saçılan kıvılcım + ayak dibinde toz.
##
## Plan çerçevesi (STEPS): orijin = hedefin saldırı anındaki konumu + ANCHOR (prototipte yaratığın gövde merkezi), +x = saldırı
## yönü, +y = Godot perp (-dir.y, dir.x); sola saldırıda y aynalanır (açı a -> -a, efekt flip_v) ki toz/ışık hep aşağıda/üstte
## kalsın. Konumlar ikonun MERKEZİ (pençe merkezinden döner, offset yok), açı = tırnakların baktığı yön (çerçeveye göre).
## Değerler prototipteki (tools/proto_20261017/pence_proto.py B_track; oradaki yerel orijin hedefin 8 px önü -> burada x - 8)
## ile AYNI. Efektler (tools/gen_pence_hook_fx.py) aynı zaman çizelgesiyle pişirildi: iz SMEAR_AT'te, üst katman 1. temasta,
## yer katmanı 2. temasta çıkar - ikon ve efektler birlikte speed ile hızlanır. Hasar temas anlarında (weapon.gd _pence_contact).
##
## Yeni bir ayar değiştirirsen SADECE burayı (ve efekti yeniden pişir) değiştir; iki çağıran dosya aynı fonksiyonları
## kullanır (CLAUDE.md "iki ayrı yer" hata sınıfı).

const SmearFxScene: PackedScene = preload("res://scenes/fx_pence_hook_smear.tscn") ## atılış hız izi, z 0 (pençenin altı)
const TopFxScene: PackedScene = preload("res://scenes/fx_pence_hook_top.tscn") ## saplanma yıldızı + darbe çizgileri + yırtıklar + kıvılcım, z 60
const GroundFxScene: PackedScene = preload("res://scenes/fx_pence_hook_ground.tscn") ## ayak dibinde toz, z -1 (yaratıkların altı)

const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## pişmiş efektin 1 sanat pikseli (dünya px, k = 1) = Zanaatkâr silahlarıyla aynı yoğunluk
## Çerçeve orijini hedefin bu kadar üstünde (topuz_slam_math.gd ile aynı neden: prototip efekti yaratığın gövde merkezine göre çizdi).
const ANCHOR := Vector2(0.0, -3.5)

## [süre (sn), ikon merkezi (çerçeve) ya da null = önceki nokta, tırnak açısı (derece, çerçeve), boy ölçeği, en ölçeği, geçiş]
## Boy/en pençenin KENDİ ekseninde (atılışta uzar, saplanınca ezilir). "shake": saplıyken dik eksende titreme, ölçek 1'e döner.
const STEPS := [
	[0.10, Vector2(-28.0, -5.0), 0.0, 0.9, 1.06, "out"], ## geri sin
	[0.045, Vector2(4.0, 0.0), 0.0, 1.15, 0.92, "in"], ## atıl -> saplan (1. temas 0,145)
	[0.03, null, 0.0, 0.85, 1.12, "lin"], ## ezil
	[0.04, null, 0.0, 1.0, 1.0, "shake"], ## saplıyken titre
	[0.03, Vector2(-22.0, 3.0), 12.0, 1.0, 1.0, "out"], ## çekerek yırt (2. temas yolda, 0,235)
	[0.055, Vector2(-28.0, 4.0), 8.0, 1.0, 1.0, "out"],
	[0.10, null, 8.0, 1.0, 1.0, "lin"],
]
const CONTACTS := [0.145, 0.235]
const SMEAR_AT := 0.10
const SQUASH_STEP := 2
const SHAKE_AMP := 0.8 ## dünya px (k = 1)
const SHAKE_WAVES := 3.0
## Kritikte daha sert saplanma ezilmesi (ayrı kritik animasyonu yok - eski kritik "rake" X'i bu silahta kullanılmıyor).
const CRIT_SQUASH := Vector2(0.72, 1.24)
const RETURN := 0.26


## dir: saldırı yönü, target: hedefin saldırı anındaki konumu, size: boyut çarpanı (menzil büyümesi x alan çarpanı),
## owner_scale: silahı taşıyan karakterin kök ölçeği.
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	var side: float = -1.0 if dir.x < -0.001 else 1.0
	return {"origin": target + ANCHOR, "dir": dir, "k": k, "side": side}


## Çerçevedeki p noktasının dünya konumu (sola saldırıda y aynalı).
static func point(plan: Dictionary, p: Vector2) -> Vector2:
	var d: Vector2 = plan["dir"]
	return (plan["origin"] as Vector2) + Vector2(p.x, p.y * float(plan["side"])).rotated(d.angle()) * float(plan["k"])


## STEPS açısının (derece) dünya açısı; sarmasız.
static func angle(plan: Dictionary, deg: float) -> float:
	return (plan["dir"] as Vector2).angle() + deg_to_rad(deg) * float(plan["side"])


## i. temasın anı (saldırı başından, sn).
static func contact_delay(i: int, speed: float) -> float:
	return float(CONTACTS[clampi(i, 0, CONTACTS.size() - 1)]) / maxf(0.01, speed)


## İki hasar parçası arası süre (saplanma -> yırtma).
static func segment_gap(speed: float) -> float:
	return (float(CONTACTS[1]) - float(CONTACTS[0])) / maxf(0.01, speed)


## Toplam animasyon (dönüş hariç).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## İkonun dünya dönüşümü: doku ekseni -> dünya = R(açı) . diag(boy, en) . R(-forward) x doku ölçeği; merkez `center`da.
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


## Pişmiş efektlerin çıkış anları: [zaman (sn), sahne].
static func fx_events() -> Array:
	return [[SMEAR_AT, SmearFxScene], [float(CONTACTS[0]), TopFxScene], [float(CONTACTS[1]), GroundFxScene]]


## İkonu plana göre oynatır, efektleri zamanında çıkarır. host: tween'in bağlanacağı düğüm (silah / kukla).
## forward: sanatın ucunun baktığı açı (sprite_forward_angle_deg). rest_pos/rest_rot: ikonun YEREL dinlenme konumu/rotasyonu.
## base_scale: ikonun SABİT taban ölçeği. fx_parent: efektlerin ekleneceği düğüm (dünyada sabit kalsın diye sahne kökü).
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		base_scale: Vector2, speed: float, crit: bool, fx_parent: Node) -> Tween:
	var sp: float = maxf(0.01, speed)
	var parent_scale: float = absf((icon.get_parent() as Node2D).global_scale.x) if icon.get_parent() is Node2D else 1.0
	var ctx: Dictionary = {"icon": icon, "forward": forward, "texel": absf(base_scale.x) * parent_scale}
	var perp: Vector2 = Vector2((plan["dir"] as Vector2).y * -1.0, (plan["dir"] as Vector2).x) * float(plan["side"]) * float(plan["k"])
	var tw: Tween = host.create_tween()
	var prev_c: Vector2 = icon.global_position
	var prev_a: float = icon.global_rotation + forward
	var prev_sl: float = 1.0
	var prev_sw: float = 1.0
	var events: Array = fx_events()
	var t_acc: float = 0.0
	for i in range(STEPS.size()):
		var st: Array = STEPS[i]
		var a1: float = angle(plan, float(st[2]))
		if i == 0:
			prev_a = a1 + wrapf(prev_a - a1, -PI, PI) ## ilk adım en kısa yoldan, sonrakiler sarmasız
		var sl: float = float(st[3])
		var sw: float = float(st[4])
		if crit and i == SQUASH_STEP:
			sl = CRIT_SQUASH.x
			sw = CRIT_SQUASH.y
		var c1: Vector2 = prev_c if typeof(st[1]) == TYPE_NIL else point(plan, st[1])
		var ca: Vector2 = prev_c
		var aa: float = prev_a
		var sla: float = prev_sl
		var swa: float = prev_sw
		var kind: String = str(st[5])
		var step: Callable
		if kind == "shake":
			step = func(e: float) -> void:
				_apply(ctx, ca + perp * SHAKE_AMP * sin(e * PI * 2.0 * SHAKE_WAVES), a1, sl, sw)
		else:
			step = func(e: float) -> void:
				_apply(ctx, ca.lerp(c1, e), lerpf(aa, a1, e), lerpf(sla, sl, e), lerpf(swa, sw, e))
		var dur: float = float(st[0])
		var tr: MethodTweener = tw.tween_method(step, 0.0, 1.0, dur / sp)
		match kind:
			"out":
				tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			"in":
				tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			"inout":
				tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_:
				tr.set_trans(Tween.TRANS_LINEAR)
		## Bu adımın içine düşen efektler adımla paralel, gecikmeli (2. temas yırtmanın ortasında).
		for ev: Array in events:
			var te: float = float(ev[0])
			if te >= t_acc - 0.0001 and te < t_acc + dur - 0.0001:
				tw.parallel().tween_callback(spawn_fx.bind(ev[1], fx_parent, plan, sp)).set_delay(maxf(0.0, te - t_acc) / sp)
		t_acc += dur
		prev_c = c1
		prev_a = a1
		prev_sl = sl
		prev_sw = sw
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, RETURN / sp)
	tw.parallel().tween_property(icon, "skew", 0.0, RETURN / sp)
	return tw


## Pişmiş efekt (tek seferlik, fx_animation.gd bitince siler): çerçeve orijininde, saldırı yönüyle dönmüş, sola saldırıda flip_v.
static func spawn_fx(scene: PackedScene, parent: Node, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx: AnimatedSprite2D = scene.instantiate() as AnimatedSprite2D
	parent.add_child(fx)
	fx.global_position = plan["origin"]
	fx.global_rotation = (plan["dir"] as Vector2).angle()
	fx.global_scale = Vector2.ONE * FX_WORLD_PX * float(plan["k"])
	fx.flip_v = float(plan["side"]) < 0.0
	fx.speed_scale = maxf(0.01, speed)
	return fx
