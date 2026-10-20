extends RefCounted

## Topuz vuruşu "Yer Sarsıntısı" - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer istemcilerdeki
## kozmetik kopya). Kullanıcı seçimi 2026-10-17 (CLAUDE.md madde 232 prototip A -> madde 235): eski "hedefin 24 px yanına
## park + turuncu halka/duman (fx_topuz_slash)" yerine topuz başın üstüne kalkar, geri gerilir, tepeden yere iner (tutukluk +
## ezilme + geri seker); yer çatlar, toz dalgası alan sınırına kadar açılır, taş kırıntıları sıçrar.
##
## Plan çerçevesi (STEPS): orijin = hedefin saldırı anındaki konumu + ANCHOR (prototipte yaratığın gövde merkezi), eksenler
## DÜNYA (efekt saldırı yönüyle dönmez), sağa saldırı; sola saldırıda x aynalanır (açı a -> PI - a, efekt flip_h). Konumlar
## topuz BAŞININ noktası (dünya px x k), açı = başın baktığı yön; topuz SAPINDAN döner (tutma noktası = baş - erim x yön,
## erim ikonun gerçek doku ölçeğiyle). Değerler prototipteki (tools/proto_20261017/topuz_proto.py A_track) ile AYNI.
## Efektler (tools/gen_topuz_slam_fx.py) aynı zaman çizelgesiyle pişirildi: iz SMEAR_AT'te, yer + üst katman temasta
## (CONTACT) çıkar - ikon ve efektler birlikte speed ile hızlanır. Hasar temas anında (weapon.gd _topuz_contact).
##
## Yeni bir ayar değiştirirsen SADECE burayı (ve efekti yeniden pişir) değiştir; iki çağıran dosya aynı fonksiyonları
## kullanır (CLAUDE.md "iki ayrı yer" hata sınıfı).

const GroundFxScene: PackedScene = preload("res://scenes/fx_topuz_slam_ground.tscn") ## çukur + çatlak + toz dalgası, z -1 (yaratıkların altı) + darbe sesi
const TopFxScene: PackedScene = preload("res://scenes/fx_topuz_slam_top.tscn") ## yıldız + toz bulutu + taş kırıntısı, z 60
const SmearFxScene: PackedScene = preload("res://scenes/fx_topuz_slam_smear.tscn") ## iniş izi, z 0 (topuzun altı)
const MeleeChainMath := preload("res://scripts/melee_chain_math.gd") ## vuruş sonrası bekleme (madde 347 zincir)

const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## pişmiş efektin 1 sanat pikseli (dünya px, k = 1) = Zanaatkâr silahlarıyla aynı yoğunluk
## Çerçeve orijini hedefin bu kadar üstünde: prototipte efekt yaratığın gövde merkezine göre çizildi (slime sprite ofseti -4,86 x
## 0,949 -> gövde merkezi orijinin ~3,5 px üstü, ayakları ~5 px altı). Toz dalgası G = orijin + (0, 7) = ayaklar.
const ANCHOR := Vector2(0.0, -3.5)

## Zanaatkâr topuzu (48x48 sanat): tutma noktası (dönme merkezi) ve tutma noktası -> baş merkezi (35,5; 13,5) uzaklığı, sanat px.
const ART_SIZE := 48.0
const GRIP_PX := Vector2(12.0, 35.0)
const HEAD_REACH_PX := 31.851

## [süre (sn), baş noktası (çerçeve) ya da null = önceki tutma noktası, baş açısı (derece), boy ölçeği, en ölçeği, geçiş]
## Boy/en topuzun KENDİ ekseninde (ezilme: boyu kısalır, eni genişler).
const STEPS := [
	[0.15, Vector2(-35.861, -45.157), -150.0, 1.0, 1.0, "out"], ## başın üstüne kaldır
	[0.06, Vector2(-39.914, -43.808), -168.0, 1.0, 1.0, "inout"], ## geri ger (beklenti) - iz burada başlar (SMEAR_AT)
	[0.06, Vector2(-4.0, 1.0), 40.0, 1.0, 1.0, "in"], ## tepeden indir -> temas 0,27
	[0.03, null, 40.0, 0.86, 1.2, "lin"], ## tutukluk + ezilme
	[0.04, null, 40.0, 1.0, 1.0, "out"],
	[0.06, Vector2(-3.049, -8.912), 22.0, 1.0, 1.0, "out"], ## geri seker
	[0.10, null, 22.0, 1.0, 1.0, "lin"],
]
const SMEAR_AT := 0.21
const CONTACT := 0.27
const SQUASH_STEP := 3
## Kritikte daha sert ezilme (ayrı kritik animasyonu yok - eski kritik "smash" zaten bu kaldır-indir hareketiydi).
const CRIT_SQUASH := Vector2(0.76, 1.32)
const RETURN := 0.26


## dir: saldırı yönü (sadece sağ/sol tarafı), target: hedefin saldırı anındaki konumu, size: boyut çarpanı (alan çarpanları),
## owner_scale: silahı taşıyan karakterin kök ölçeği.
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float) -> Dictionary:
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	var side: float = -1.0 if dir.x < -0.001 else 1.0
	return {"origin": target + ANCHOR, "k": k, "side": side}


## Çerçevedeki p noktasının dünya konumu (sola saldırıda aynalı).
static func point(plan: Dictionary, p: Vector2) -> Vector2:
	return (plan["origin"] as Vector2) + Vector2(p.x * float(plan["side"]), p.y) * float(plan["k"])


## STEPS açısının (derece) dünya açısı; sarmasız (adımlar arası dönüş yönü korunur).
static func angle(plan: Dictionary, deg: float) -> float:
	var a: float = deg_to_rad(deg)
	return a if float(plan["side"]) > 0.0 else PI - a


## Temas anı (saldırı başından, sn).
static func contact_delay(speed: float) -> float:
	return CONTACT / maxf(0.01, speed)


## Toplam animasyon (dönüş hariç).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## İkonun dünya dönüşümü: doku ekseni -> dünya = R(açı) . diag(boy, en) . R(-forward) x doku ölçeği; tutma noktası `grip`te.
static func _apply(ctx: Dictionary, grip: Vector2, ang: float, sl: float, sw: float) -> void:
	var icon: Node2D = ctx["icon"]
	if not is_instance_valid(icon):
		return
	var t: float = ctx["texel"]
	var f: float = ctx["forward"]
	var e1: Vector2 = Vector2.RIGHT.rotated(-f)
	var e2: Vector2 = Vector2.DOWN.rotated(-f)
	var x_axis: Vector2 = Vector2(e1.x * sl, e1.y * sw).rotated(ang) * t
	var y_axis: Vector2 = Vector2(e2.x * sl, e2.y * sw).rotated(ang) * t
	var off: Vector2 = ctx["off"]
	icon.global_transform = Transform2D(x_axis, y_axis, grip + x_axis * off.x + y_axis * off.y)


## İkonun şu anki tutma noktası (dünya) - önceki vuruş yarıda kesildiyse oradan devam eder.
static func grip_of(icon: Node2D, off: Vector2) -> Vector2:
	return icon.global_transform * (-off)


## İkonu plana göre oynatır, izi ve temasta yer + üst efekti çıkarır. host: tween'in bağlanacağı düğüm (silah / kukla).
## forward: sanatın ucunun baktığı açı (sprite_forward_angle_deg). rest_pos/rest_rot: ikonun YEREL dinlenme konumu/rotasyonu.
## base_scale: ikonun SABİT taban ölçeği. fx_parent: efektlerin ekleneceği düğüm (dünyada sabit kalsın diye sahne kökü).
## hold: dönüşten önce son pozda bekleme (MeleeChainMath.hold_time; 0 = hemen döner) - sonraki vuruş beklemede gelirse topuz sekme
## pozundan yeniden kalkar.
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		base_scale: Vector2, speed: float, crit: bool, fx_parent: Node, hold: float = 0.0) -> Tween:
	var sp: float = maxf(0.01, speed)
	var parent_scale: float = absf((icon.get_parent() as Node2D).global_scale.x) if icon.get_parent() is Node2D else 1.0
	var art: float = 1.0
	if icon is Sprite2D and (icon as Sprite2D).texture:
		art = (icon as Sprite2D).texture.get_width() / ART_SIZE ## eski/farklı boyutlu dokuda sanat px -> doku px
	var ctx: Dictionary = {"icon": icon, "forward": forward, "texel": absf(base_scale.x) * parent_scale,
		"off": (Vector2(ART_SIZE, ART_SIZE) * 0.5 - GRIP_PX) * art}
	var reach: float = HEAD_REACH_PX * art * float(ctx["texel"])
	var tw: Tween = host.create_tween()
	var prev_g: Vector2 = grip_of(icon, ctx["off"])
	var prev_a: float = icon.global_rotation + forward
	var prev_sl: float = 1.0
	var prev_sw: float = 1.0
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
		var g1: Vector2 = prev_g if typeof(st[1]) == TYPE_NIL else point(plan, st[1]) - Vector2.from_angle(a1) * reach * sl
		var ga: Vector2 = prev_g
		var aa: float = prev_a
		var sla: float = prev_sl
		var swa: float = prev_sw
		var step := func(e: float) -> void:
			_apply(ctx, ga.lerp(g1, e), lerpf(aa, a1, e), lerpf(sla, sl, e), lerpf(swa, sw, e))
		var tr: MethodTweener = tw.tween_method(step, 0.0, 1.0, float(st[0]) / sp)
		match str(st[5]):
			"out":
				tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			"in":
				tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			"inout":
				tr.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_:
				tr.set_trans(Tween.TRANS_LINEAR)
		t_acc += float(st[0])
		if is_equal_approx(t_acc, SMEAR_AT):
			tw.tween_callback(spawn_fx.bind(SmearFxScene, fx_parent, plan, sp))
		elif is_equal_approx(t_acc, CONTACT):
			tw.tween_callback(spawn_fx.bind(GroundFxScene, fx_parent, plan, sp))
			tw.tween_callback(spawn_fx.bind(TopFxScene, fx_parent, plan, sp))
		prev_g = g1
		prev_a = a1
		prev_sl = sl
		prev_sw = sw
	MeleeChainMath.append_hold(tw, icon, hold)
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, RETURN / sp)
	tw.parallel().tween_property(icon, "skew", 0.0, RETURN / sp)
	return tw


## Pişmiş efekt (tek seferlik, fx_animation.gd bitince siler): çerçeve orijininde, dönmeden, sola saldırıda aynalı.
static func spawn_fx(scene: PackedScene, parent: Node, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx: AnimatedSprite2D = scene.instantiate() as AnimatedSprite2D
	parent.add_child(fx)
	fx.global_position = plan["origin"]
	fx.global_rotation = 0.0
	fx.global_scale = Vector2.ONE * FX_WORLD_PX * float(plan["k"])
	fx.flip_h = float(plan["side"]) < 0.0
	fx.speed_scale = maxf(0.01, speed)
	return fx
