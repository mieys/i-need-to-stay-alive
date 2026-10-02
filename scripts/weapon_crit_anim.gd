class_name WeaponCritAnim
extends RefCounted

## KRİTİK ATIŞ ANİMASYONLARI - tek kaynak: weapon.gd (gerçek silah) VE remote_player.gd (diğer oyuncuların kozmetik kopyası)
## aynı fonksiyonları çağırır (CLAUDE.md madde 3). Kullanıcı isteği (2026-09-29): "her silahın kritik animasyonu farklı
## olacak ... daha tehlikeli ve keskin görünmesi gerekiyor" - örnekler: kılıç saplar, yay daha çok geri teper, yıldırım asası
## titrer, ateş asası geri teper; "tabanca kritik yaptıktan sonra hafif dönsün". Parlama/renk YOK, sadece hareket (kullanıcı
## tercihi). Uzunkılıcın saplaması hasar zamanlamasına bağlı olduğu için sword_swing_math.gd'de (make_stab_plan/play_stab).
##
## Kritik bilgisi uzak kopyaya "weapon_fire" yayınındaki "crit" alanıyla gider (weapon.gd _broadcast_weapon_fire_anim).
## Yeni bir silah eklersen STYLES'a bir satır ekle; eklemezsen kritikte normal atış animasyonu oynar.
##
## Türler:
##   recoil  sert geri tepme (kick x recoil_distance) + namlu kalkması (rot, radyan)
##   twirl   recoil + ardından ikonun kendi etrafında bir tur dönmesi (tabanca)
##   puff    önce ileri üfleme hamlesi, sonra geri tepme (tüftüf)
##   freeze  anlık donma: büyüyüp kısa durur, sonra geri teper (buz asası)
##   surge   büyü yükselmesi: yukarı süzülüp şişer, sonra sert geri teper (arcane)
##   jitter  hızlı titreşim (yıldırım asası - sürekli ışının kritik tiki)
##   throw   fırlatmadan önce geriye çekilip sert savurma (bumerang, fişek - ikon sonra gizlenir)
##   thrust  bıçak: geri çekilip hedefe derin saplama + bilek çevirme
##   rake    pençe: hedefin üstünde çapraz "X" yırtma
##   smash   topuz: yukarı kaldırıp tepeden ağır indirme, çarpmada ezilme
const STYLES := {
	"yay": {"kind": "recoil", "kick": 2.0, "rot": 0.22, "back": 0.24},
	"crossbow": {"kind": "recoil", "kick": 1.9, "rot": 0.35, "back": 0.26},
	"tufek": {"kind": "recoil", "kick": 2.3, "rot": 0.4, "back": 0.32},
	"fire_staff": {"kind": "recoil", "kick": 2.4, "rot": 0.3, "back": 0.3},
	"tabanca": {"kind": "twirl", "kick": 1.6, "rot": 0.45, "back": 0.2},
	"tuftuf": {"kind": "puff", "kick": 1.8, "rot": 0.0, "back": 0.22},
	"buz_asasi": {"kind": "freeze", "kick": 1.7, "rot": 0.15, "back": 0.26},
	"arcane": {"kind": "surge", "kick": 1.6, "rot": 0.0, "back": 0.26},
	"lightning_staff": {"kind": "jitter"},
	"boomerang": {"kind": "throw"},
	"fisek": {"kind": "throw"},
	"dagger": {"kind": "thrust"},
	"pence": {"kind": "rake"},
	"topuz": {"kind": "smash"},
	"uzunkilic": {"kind": "stab"},
}

const MELEE_KINDS := ["thrust", "rake", "smash"]
## Fırlatma savurmasının süresi - weapon.gd ikonu bu kadar sonra gizler (bumerang/fişek uçarken ikon görünmez).
const THROW_DURATION := 0.13


static func kind_of(weapon_key: String) -> String:
	return str(STYLES.get(weapon_key, {}).get("kind", ""))


static func is_melee_kind(weapon_key: String) -> bool:
	return MELEE_KINDS.has(kind_of(weapon_key))


## Menzilli / ışın / fırlatma kritikleri. icon: ikon düğümü, base_pos: ikonun YEREL dinlenme konumu, base_scale: SABİT
## dinlenme ölçeği, recoil_dist: silahın normal geri tepme mesafesi. Pozisyon ve ölçek mutlak tween'lenir; rotasyon ise
## ARTIMLI eklenir (nişan kodu her kare ikonu hedefe çevirdiği için mutlak rotasyon tween'i onunla çekişirdi - artımlı
## ofset nişanla üst üste biner ve kendiliğinden söner). Dönen tween'i çağıran saklayıp sonraki atışta kesebilir.
static func play_ranged(host: Node, icon: Node2D, weapon_key: String, dir: Vector2, base_pos: Vector2,
		base_scale: Vector2, recoil_dist: float) -> Tween:
	var st: Dictionary = STYLES.get(weapon_key, {})
	var kind: String = str(st.get("kind", "recoil"))
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	## Namlu kalkması: ekranda yukarı. Sağa bakan ikonda saat yönünün tersi (-), sola bakanda saat yönü (+).
	var up_sign: float = -1.0 if dir.x >= 0.0 else 1.0
	var kick: Vector2 = -dir * recoil_dist * float(st.get("kick", 1.5))
	var back: float = float(st.get("back", 0.24))
	var rot: float = float(st.get("rot", 0.0)) * up_sign
	var tw: Tween = host.create_tween()
	match kind:
		"jitter":
			var perp := Vector2(-dir.y, dir.x)
			var amps := [3.5, -3.0, 2.5, -2.0, 1.2, 0.0]
			for a in amps:
				tw.tween_property(icon, "position", base_pos + perp * float(a) + dir * absf(float(a)) * 0.3, 0.025)
			_add_rotation_wobble(host, icon, 0.12, 0.15)
		"throw":
			var side: float = up_sign
			tw.tween_property(icon, "position", base_pos - dir * 12.0, THROW_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale * 1.15, THROW_DURATION * 0.45)
			tw.tween_property(icon, "position", base_pos + dir * 18.0, THROW_DURATION * 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(icon, "scale", base_scale, THROW_DURATION * 0.55)
			var swing: float = 1.4 * -side
			_add_rotation_kick(host, icon, swing, THROW_DURATION, false)
			## İkon bu noktada gizlenir (weapon.gd); geri döndüğünde dinlenme konumunda ve eski açısında olsun.
			tw.tween_property(icon, "position", base_pos, 0.01)
			tw.tween_callback(func() -> void:
				if is_instance_valid(icon):
					icon.rotation -= swing)
		"puff":
			tw.tween_property(icon, "position", base_pos + dir * 7.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(1.25, 0.8), 0.05)
			tw.tween_property(icon, "position", base_pos + kick, 0.04)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(0.85, 1.15), 0.04)
			tw.tween_property(icon, "position", base_pos, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale, back).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"freeze":
			tw.tween_property(icon, "scale", base_scale * 1.25, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.07)
			tw.tween_property(icon, "position", base_pos + kick, 0.04)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(0.8, 1.2), 0.04)
			tw.tween_property(icon, "position", base_pos, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale, back).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			host.get_tree().create_timer(0.11, false).timeout.connect(func() -> void:
				if is_instance_valid(icon):
					_add_rotation_kick(host, icon, rot, back, true))
		"surge":
			tw.tween_property(icon, "position", base_pos + Vector2(0.0, -9.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale * 1.3, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "position", base_pos + kick, 0.04)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(0.8, 1.2), 0.04)
			tw.tween_property(icon, "position", base_pos, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale, back).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			## recoil / twirl: normal geri tepmenin (0.04 çık / 0.16 dön) sert ve yavaş toparlanan hali + daha derin ezilme.
			tw.tween_property(icon, "position", base_pos + kick, 0.035)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(0.72, 1.28), 0.035)
			tw.tween_property(icon, "position", base_pos, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(1.12, 0.92), back * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "scale", base_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if rot != 0.0:
				_add_rotation_kick(host, icon, rot, back, true)
			if kind == "twirl":
				## Geri tepme bitince ikon namlu yönünde bir tur döner (kovboy çevirmesi) - artımlı, nişan açısı korunur.
				host.get_tree().create_timer(back * 0.6, false).timeout.connect(func() -> void:
					if is_instance_valid(icon):
						_add_rotation_kick(host, icon, TAU * -up_sign, 0.32, false))
	return tw


## Yakın dövüş kritikleri (bıçak/pençe/topuz). strike_center: ikonun vuracağı YEREL nokta (normal zikzağın merkezi),
## forward: sprite'ın kendi "ileri" açısı (radyan), rest_rot: dinlenme rotasyonu, hold: efekt bitene kadar bekleme.
## Yakın dövüşte nişan kodu ikonu döndürmediği için rotasyon burada mutlak tween'lenir.
static func play_melee(host: Node, icon: Node2D, weapon_key: String, dir: Vector2, base_pos: Vector2, strike_center: Vector2,
		forward: float, rest_rot: float, base_scale: Vector2, hold: float) -> Tween:
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var aim_rot: float = dir.angle() - forward
	var tw: Tween = host.create_tween()
	match kind_of(weapon_key):
		"thrust":
			tw.tween_property(icon, "position", strike_center - dir * 38.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "rotation", aim_rot, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "position", strike_center + dir * 10.0, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(icon, "scale", base_scale * Vector2(1.25, 0.85), 0.05)
			tw.tween_property(icon, "rotation", aim_rot + 0.55, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "scale", base_scale, 0.07)
		"rake":
			var pts := [
				[strike_center - dir * 16.0 + perp * 30.0, 0.06],
				[strike_center + dir * 16.0 - perp * 30.0, 0.05],
				[strike_center - dir * 16.0 - perp * 30.0, 0.04],
				[strike_center + dir * 16.0 + perp * 30.0, 0.05],
			]
			var prev: Vector2 = base_pos
			for e in pts:
				var p: Vector2 = e[0]
				var d: float = e[1]
				var seg: Vector2 = p - prev
				var r: float = (seg.angle() - forward) if seg.length() > 1.0 else aim_rot
				tw.tween_property(icon, "position", p, d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(icon, "rotation", r, d * 0.6)
				prev = p
		"smash":
			var side: float = 1.0 if dir.x >= 0.0 else -1.0
			tw.tween_property(icon, "position", strike_center + Vector2(-side * 10.0, -46.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "rotation", rest_rot - side * 0.9, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "position", strike_center + Vector2(0.0, 6.0), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(icon, "rotation", rest_rot + side * 1.4, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_property(icon, "scale", base_scale * Vector2(1.35, 0.7), 0.04)
			tw.tween_property(icon, "scale", base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(icon, "position", base_pos, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "rotation", rest_rot, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, 0.26)
	return tw


## Rotasyona toplam `amount` radyanlık ofseti `dur` içinde ARTIMLI ekler. decay=true: hemen eklenip sönen "tepme"
## (sonunda net 0), false: yumuşak ekleme (tam tur gibi - TAU sonunda aynı açı).
static func _add_rotation_kick(host: Node, icon: Node2D, amount: float, dur: float, decay: bool) -> void:
	var applied: Array = [0.0]
	var step := func(t: float) -> void:
		if not is_instance_valid(icon):
			return
		var want: float = amount * ((1.0 - t) * (1.0 - t) if decay else (1.0 - (1.0 - t) * (1.0 - t)))
		if decay and t <= 0.0:
			want = amount
		icon.rotation += want - float(applied[0])
		applied[0] = want
	var tw: Tween = host.create_tween()
	if decay:
		step.call(0.0)
	tw.tween_method(step, 0.0, 1.0, maxf(0.01, dur))


## Küçük sağ-sol rotasyon titremesi (ışın kritiği), net 0.
static func _add_rotation_wobble(host: Node, icon: Node2D, amount: float, dur: float) -> void:
	var applied: Array = [0.0]
	var step := func(t: float) -> void:
		if not is_instance_valid(icon):
			return
		var want: float = amount * sin(t * TAU * 3.0) * (1.0 - t)
		icon.rotation += want - float(applied[0])
		applied[0] = want
	host.create_tween().tween_method(step, 0.0, 1.0, maxf(0.01, dur))
