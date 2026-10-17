extends RefCounted

## Bıçak vuruşu "Kıvılcım Saplama" - TEK kaynak (weapon.gd = gerçek/yetkili silah, remote_player.gd = diğer istemcilerdeki
## kozmetik kopya). Kullanıcı seçimi 2026-10-17 (CLAUDE.md madde 228 prototip B -> madde 231): eski hedef üstü "Z" zikzağı +
## yumuşak boyalı kırmızı X (fx_assasin_slash) yerine geri çekilip üç kez saplama; son saplama derin (ölçek darbesi).
##
## Plan çerçevesi (STEPS): orijin = vuruş merkezi (hedefin STRIKE_BACK gerisi), +x = saldırı yönü, dünya px (k = 1); ikon
## noktaları prototipteki (tools/proto_20261017/bicak_proto.py B_motion) değerlerin AYNISI. Bıçak her an hedefin merkezine
## bakar. Efekt (scenes/fx_dagger_stab.tscn, tools/gen_dagger_stab_fx.py) AYNI zaman çizelgesiyle pişirildi ve saldırı anında
## vuruş merkezinde, saldırı yönüyle dönmüş olarak başlar - ikon ve efekt hep birlikte speed ile hızlanır.
## Hasar parçaları temas anlarında (CONTACTS; weapon.gd _dagger_contact + segment_gap) - sayı/kıvılcım/vuruş aynı anda.
##
## Yeni bir saplama ayarı değiştirirsen SADECE burayı (ve efekti yeniden pişir) değiştir; iki çağıran dosya aynı fonksiyonları
## kullanır (CLAUDE.md "iki ayrı yer" hata sınıfı).

const FxScene: PackedScene = preload("res://scenes/fx_dagger_stab.tscn")

const STRIKE_BACK := 8.0 ## = Characters.MAIN_WEAPON slash_fx_offset (vuruş merkezi hedefin bu kadar önünde)
const REF_OWNER_SCALE := 0.5
const FX_WORLD_PX := 0.575 ## pişmiş efektin 1 sanat pikseli (dünya px, k = 1) = Zanaatkâr silahlarıyla aynı yoğunluk

## [süre (sn), hedef nokta (çerçeve) ya da null = bekle, yumuşatma: "out" geri çekiliş / "in" saplama]
const STEPS := [
	[0.09, Vector2(-14.0, -3.0), "out"], ## hazırlık: hedefin gerisine süzül
	[0.04, Vector2(-1.0, -2.5), "in"], ## 1. saplama (temas 0,13)
	[0.02, null, ""],
	[0.04, Vector2(-15.0, -0.5), "out"],
	[0.04, Vector2(-1.0, 2.5), "in"], ## 2. saplama (temas 0,23)
	[0.02, null, ""],
	[0.04, Vector2(-18.0, 0.0), "out"],
	[0.04, Vector2(2.0, 0.0), "in"], ## 3. saplama, derin (temas 0,33)
	[0.10, null, ""],
]
const CONTACTS := [0.13, 0.23, 0.33]
const RETURN := 0.24
const PULSE := 0.18 ## son saplamada ikon ölçek darbesi
const CRIT_PULSE := 0.32 ## kritikte daha sert (ayrı kritik animasyonu yok - saplama zaten bıçağın kritik hareketiydi)
const PULSE_IN := 0.04
const PULSE_OUT := 0.10


## dir: saldırı yönü, target: hedefin saldırı anındaki konumu, size: boyut çarpanı (menzil büyümesi x alan çarpanı),
## owner_scale: silahı taşıyan karakterin kök ölçeği.
static func make_plan(dir: Vector2, target: Vector2, size: float, owner_scale: float) -> Dictionary:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var k: float = maxf(0.05, size) * owner_scale / REF_OWNER_SCALE
	return {"dir": dir, "target": target, "k": k, "origin": target - dir * STRIKE_BACK * k}


## Çerçevedeki p noktasının dünya konumu.
static func point(plan: Dictionary, p: Vector2) -> Vector2:
	return (plan["origin"] as Vector2) + p.rotated((plan["dir"] as Vector2).angle()) * float(plan["k"])


## i. saplamanın temas anı (saldırı başından, sn).
static func contact_delay(i: int, speed: float) -> float:
	return float(CONTACTS[clampi(i, 0, CONTACTS.size() - 1)]) / maxf(0.01, speed)


## Hasar parçaları arası süre (temaslar eşit aralıklı).
static func segment_gap(speed: float) -> float:
	return (float(CONTACTS[1]) - float(CONTACTS[0])) / maxf(0.01, speed)


## Toplam animasyon (dönüş hariç).
static func busy_duration(speed: float) -> float:
	var s: float = 0.0
	for st: Array in STEPS:
		s += float(st[0])
	return s / maxf(0.01, speed)


## İkonu plana göre oynatır + efekti başlatır. host: tween'in bağlanacağı düğüm (silah / kukla). rest_pos/rest_rot: ikonun
## YEREL dinlenme konumu/rotasyonu. base_scale: ikonun SABİT taban ölçeği (darbe buna döner). fx_parent: efektin ekleneceği
## düğüm (dünyada sabit kalsın diye sahne kökü). Dönen tween'i çağıran saklayıp bir sonraki vuruşta kesebilir.
static func play(host: Node, icon: Node2D, plan: Dictionary, forward: float, rest_pos: Vector2, rest_rot: float,
		base_scale: Vector2, speed: float, crit: bool, fx_parent: Node) -> Tween:
	var sp: float = maxf(0.01, speed)
	var target: Vector2 = plan["target"]
	spawn_fx(fx_parent, plan, sp)
	var tw: Tween = host.create_tween()
	var prev: Vector2 = icon.global_position
	var first := true
	var n: int = STEPS.size()
	for i in range(n):
		var st: Array = STEPS[i]
		var dur: float = float(st[0]) / sp
		if typeof(st[1]) == TYPE_NIL:
			if i == n - 1:
				## Son saplamada saplı kalırken ölçek darbesi geri iner.
				tw.tween_property(icon, "scale", base_scale, PULSE_OUT / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				if dur > PULSE_OUT / sp:
					tw.tween_interval(dur - PULSE_OUT / sp)
			else:
				tw.tween_interval(dur)
			continue
		var a: Vector2 = prev
		var b: Vector2 = point(plan, st[1])
		var from_rot: float = icon.global_rotation
		var lead_in: bool = first
		var step := func(t: float) -> void:
			if not is_instance_valid(icon):
				return
			var p: Vector2 = a.lerp(b, t)
			icon.global_position = p
			var aim: float = (target - p).angle() - forward
			icon.global_rotation = lerp_angle(from_rot, aim, t) if lead_in else aim
		## İlk adım ikonun o anki yerinden (önceki vuruş yarıda kesildiyse oradan) başlar ve bıçağı hedefe çevirir.
		if str(st[2]) == "in":
			tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if i == n - 2:
			var amp: float = CRIT_PULSE if crit else PULSE
			tw.parallel().tween_property(icon, "scale", base_scale * (1.0 + amp), PULSE_IN / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		prev = b
		first = false
	tw.tween_property(icon, "position", rest_pos, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, RETURN / sp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, RETURN / sp)
	return tw


## Pişmiş saplama efekti (tek seferlik, fx_animation.gd bitince siler): vuruş merkezinde, saldırı yönüyle dönmüş.
static func spawn_fx(parent: Node, plan: Dictionary, speed: float) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx: AnimatedSprite2D = FxScene.instantiate() as AnimatedSprite2D
	parent.add_child(fx)
	fx.global_position = plan["origin"]
	fx.global_rotation = (plan["dir"] as Vector2).angle()
	fx.global_scale = Vector2.ONE * FX_WORLD_PX * float(plan["k"])
	fx.speed_scale = maxf(0.01, speed)
	return fx
