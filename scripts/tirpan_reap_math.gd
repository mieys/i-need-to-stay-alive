extends RefCounted

## Tırpan vuruşu "Kara Hasat" - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer istemcilerdeki kozmetik
## kopya). Kullanıcı seçimi 2026-11-09 (madde 507 prototip v2 D3 -> madde 512): pençenin "Kanca Çekiş"i (pence_hook_math.gd, silindi)
## yerine tırpan SAPINDAN döner: geri kurulur, gerilir, hedefin önünde 260 derece hızlanarak biçer; arkasında x1,45 büyüklükte
## koyu hayalet bıçak + koyu hilal iz, hedefte kesik + kızıl kor, saydam mor duman (kullanıcı: "dumanlar daha çabuk solsun").
##
## Plan çerçevesi (STEPS): orijin = hedefin saldırı anındaki konumu + ANCHOR (prototipte yaratığın gövde merkezi), +x = saldırı
## yönü, +y = Godot perp (-dir.y, dir.x) = bıçağın baktığı taraf. Konumlar tırpanın TUTMA NOKTASI (el, dünya px x k), açı = sapın
## baktığı yön (çerçeveye göre, derece); açı ARTARKEN biçer (bıçak çizimde sapın saat yönü tarafında, hareketin önünde).
## Sola saldırıda y aynalanır (açı a -> -a, efekt flip_v) ve ikon flip_h ile aynalanır (bıçak yine önde kesER; weapon_pence.tscn
## mirror_icon_when_aiming_left - nişanda da aynı kural). Değerler prototipteki (tools/proto_20261109/tirpan_proto.py big_track)
## ile AYNI. Efektler (tools/gen_tirpan_fx.py) aynı zaman çizelgesiyle pişirildi, hepsi FX_AT'te çıkar; ikon ve efektler birlikte
## speed ile DOĞRUSAL hızlanır (iz sayfası her karede biçilen alanın tamamı - hızlıda kare atlamak izi bıçaktan koparmaz).
## Hasar temas anlarında (weapon.gd _pence_contact: 1. parça CONTACTS[0], 2. parça segment_gap sonra).
##
## Yeni bir ayar değiştirirsen SADECE burayı (ve efekti yeniden pişir) değiştir; iki çağıran dosya aynı fonksiyonları
## kullanır (CLAUDE.md "iki ayrı yer" hata sınıfı).

const TrailFxScene: PackedScene = preload("res://scenes/fx_tirpan_trail.tscn") ## koyu hilal + hayalet bıçak + kızıl iz, z 0 (tırpanın altı)
const TopFxScene: PackedScene = preload("res://scenes/fx_tirpan_top.tscn") ## kesik + kızıl kor, z 60
const GroundFxScene: PackedScene = preload("res://scenes/fx_tirpan_ground.tscn") ## saydam mor duman, z -1 (yaratıkların altı)
const MeleeChainMath := preload("res://scripts/melee_chain_math.gd") ## vuruş sonrası bekleme (madde 347 zincir)

const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## pişmiş efektin 1 sanat pikseli (dünya px, k = 1)
const ANCHOR := Vector2(0.0, -3.5)

## Tırpan çizimi (assets/weapons/yeni/tirpan.png, 40x40): el = dönme merkezi (sanat px). Farklı boyutlu dokuda oranla ölçeklenir.
const ART_SIZE := 40.0
const GRIP_PX := Vector2(5.0, 33.0)

## [süre (sn), tutma noktası (çerçeve) ya da null = önceki, sap açısı (derece, çerçeve), geçiş]
const STEPS := [
	[0.13, Vector2(-27.0, -5.0), -150.0, "out"], ## geri kurul (bıçak arkada)
	[0.04, Vector2(-28.0, -6.0), -162.0, "inout"], ## gerilme - efektler bu adımın başında (FX_AT)
	[0.10, Vector2(-22.0, 2.0), 98.0, "acc"], ## 260 derece hızlanarak biç (temaslar bu adımda)
	[0.06, Vector2(-21.0, 3.0), 120.0, "out"], ## savuruş sonu
	[0.10, null, 120.0, "lin"],
]
const FX_AT := 0.13
## Bıçağın ucu hedefin içinden geçer (prototip angle_time(-36)) / biçme biter (2. parça).
const CONTACTS := [0.2345, 0.27]
const RETURN := 0.26


## dir: saldırı yönü, target: hedefin saldırı anındaki konumu, size: boyut çarpanı (menzil büyümesi x alan çarpanı; tırpan da
## vuruş boyunca bu kadar büyür ki bıçak büyüyen plana yetişsin), owner_scale: silahı taşıyan karakterin kök ölçeği.
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var sz: float = maxf(0.05, size)
	var k: float = sz * owner_scale / REF_OWNER_SCALE
	var side: float = -1.0 if dir.x < -0.001 else 1.0
	return {"origin": target + ANCHOR, "dir": dir, "k": k, "side": side, "size": sz}


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


## İki hasar parçası arası süre.
static func segment_gap(speed: float) -> float:
	return contact_delay(1, speed) - contact_delay(0, speed)


## Toplam animasyon (dönüş hariç).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## Prototipin geçişleri (tools/proto_20261017/topuz_proto.py ez) - tween doğrusal, eğri burada.
static func ease_of(kind: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match kind:
		"out":
			return sin(x * PI * 0.5)
		"in":
			return x * x
		"inout":
			return 0.5 - 0.5 * cos(PI * x)
		"acc":
			return 0.3 * x + 0.7 * x * x
	return x


## Aynalı (flip_h) ikonda sapın yerel açısı.
static func forward_of(forward: float, flipped: bool) -> float:
	return PI - forward if flipped else forward


## Doku merkezi - tutma noktası (yerel px); aynalıda x ters.
static func grip_off(icon: Node2D, flipped: bool) -> Vector2:
	var tex: Texture2D = (icon as Sprite2D).texture if icon is Sprite2D else null
	var art: float = tex.get_width() / ART_SIZE if tex != null else 1.0
	var size: Vector2 = tex.get_size() if tex != null else Vector2(ART_SIZE, ART_SIZE)
	var off: Vector2 = size * 0.5 - GRIP_PX * art
	return Vector2(-off.x, off.y) if flipped else off


## İkonun şu anki tutma noktası (dünya) - önceki vuruş yarıda kesildiyse oradan devam eder.
static func grip_of(icon: Node2D, off: Vector2) -> Vector2:
	return icon.global_transform * (-off)


## İkonun dünya dönüşümü: sap `ang`a bakar, tutma noktası `grip`te (topuz_slam_math.gd _apply ile aynı formül).
static func _apply(ctx: Dictionary, grip: Vector2, ang: float) -> void:
	var icon: Node2D = ctx["icon"]
	if not is_instance_valid(icon):
		return
	var t: float = ctx["texel"]
	var f: float = ctx["forward"]
	var x_axis: Vector2 = Vector2.RIGHT.rotated(ang - f) * t
	var y_axis: Vector2 = Vector2.DOWN.rotated(ang - f) * t
	var off: Vector2 = ctx["off"]
	icon.global_transform = Transform2D(x_axis, y_axis, grip + x_axis * off.x + y_axis * off.y)


## İkonu plana göre oynatır, efektleri FX_AT'te çıkarır. host: tween'in bağlanacağı düğüm (silah / kukla). forward: sanatın sap
## açısı (sprite_forward_angle_deg, aynalısız). rest_pos/rest_rot: ikonun YEREL dinlenme konumu/rotasyonu (aynalısız; sola
## saldırıda dönüş -rest_rot'a, ikon aynalı kalır). base_scale: ikonun SABİT taban ölçeği. fx_parent: efektlerin ekleneceği düğüm.
## hold: dönüşten önce son pozda bekleme (MeleeChainMath.hold_time).
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		base_scale: Vector2, speed: float, _crit: bool, fx_parent: Node, hold: float = 0.0) -> Tween:
	var sp: float = maxf(0.01, speed)
	var parent_scale: float = absf((icon.get_parent() as Node2D).global_scale.x) if icon.get_parent() is Node2D else 1.0
	var was_flipped: bool = icon.get("flip_h") == true
	var prev_g: Vector2 = grip_of(icon, grip_off(icon, was_flipped))
	var prev_a: float = icon.global_rotation + forward_of(forward, was_flipped)
	var flip: bool = float(plan["side"]) < 0.0
	if icon is Sprite2D:
		(icon as Sprite2D).flip_h = flip
	var ctx: Dictionary = {"icon": icon, "forward": forward_of(forward, flip), "off": grip_off(icon, flip),
		"texel": absf(base_scale.x) * parent_scale * float(plan.get("size", 1.0))}
	var tw: Tween = host.create_tween()
	var t_acc: float = 0.0
	for i in range(STEPS.size()):
		var st: Array = STEPS[i]
		var a1: float = angle(plan, float(st[2]))
		if i == 0:
			prev_a = a1 + wrapf(prev_a - a1, -PI, PI) ## ilk adım en kısa yoldan, sonrakiler sarmasız (biçme 260 derece)
		var g1: Vector2 = prev_g if typeof(st[1]) == TYPE_NIL else point(plan, st[1])
		var ga: Vector2 = prev_g
		var aa: float = prev_a
		var kind: String = str(st[3])
		var step := func(e: float) -> void:
			var q: float = ease_of(kind, e)
			_apply(ctx, ga.lerp(g1, q), lerpf(aa, a1, q))
		tw.tween_method(step, 0.0, 1.0, float(st[0]) / sp)
		t_acc += float(st[0])
		if is_equal_approx(t_acc, FX_AT):
			for scene: PackedScene in [GroundFxScene, TrailFxScene, TopFxScene]:
				tw.tween_callback(spawn_fx.bind(scene, fx_parent, plan, sp))
		prev_g = g1
		prev_a = a1
	MeleeChainMath.append_hold(tw, icon, hold)
	var rest_eff: float = -rest_rot if flip else rest_rot ## aynalı ikonda sap yine dik (bıçak öbür yanda)
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_eff, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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


## Menzilde düşman varken dinlenme: aynalanan (mirror_icon_when_aiming_left) yakın dövüş ikonu hedefin tarafına aynalanır, sap
## yine dik (aynalıda dönüş -rest). Dönüş [rotation, flip]. weapon.gd _wf_update_facing + remote_player.gd _wf_melee_facing ortak.
static func rest_pose(rest_rot: float, mirror: bool, focus_left: bool) -> Array:
	if mirror and focus_left:
		return [-rest_rot, true]
	return [rest_rot, false]
