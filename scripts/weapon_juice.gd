class_name WeaponJuice
extends RefCounted

## Süzülen silah ikonlarının "canlılık" animasyonları - TEK kaynak: weapon.gd (gerçek silah) VE remote_player.gd (diğer
## oyuncuların kozmetik kopyası) aynı fonksiyonu çağırır (CLAUDE.md madde 3: iki tarafa ayrı formül yazılmaz).
##
## Kullanıcı isteği (2026-09-25): "silah animasyonları fena değil ancak daha eğlenceli olabilirler. bu konuda insiyatifi sana
## bırakıyorum". Eskiden yerel ikon ateşte sadece geri tepiyordu, uzak kopya ise ayrıca düz %15 büyüyordu (iki taraf farklıydı).
## Artık ikisinde de "punch": ikon ateş yönünde ezilir (squash), sonra hafif esneyip taşar (stretch) ve yaylanarak yerine
## oturur - çizgi film "vuruş" hissi. Geri tepme (konum) değişmedi; bu SADECE ölçek.

## Ezilme (ikonun kendi x ekseni = namlu yönü boyunca kısa ve kalın) -> esneme (uzun ve ince) -> taban.
const PUNCH_SQUASH := Vector2(0.8, 1.2)
const PUNCH_STRETCH := Vector2(1.1, 0.93)
const PUNCH_IN := 0.035
const PUNCH_MID := 0.07
const PUNCH_OUT := 0.14


## target'ın ölçeğine punch tween'i kurar ve döndürür. base_scale: ikonun SABİT dinlenme ölçeği (o anki değil - hızlı
## ateşte üst üste binen tween'ler ölçeği büyütmesin; bkz. remote_player.gd _weapon_base_scales notu).
static func fire_punch(tween_owner: Node, target: Node2D, base_scale: Vector2) -> Tween:
	var tw: Tween = tween_owner.create_tween()
	tw.tween_property(target, "scale", base_scale * PUNCH_SQUASH, PUNCH_IN)
	tw.tween_property(target, "scale", base_scale * PUNCH_STRETCH, PUNCH_MID).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "scale", base_scale, PUNCH_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Menzilli silahların normal atış geri tepmesi (kullanıcı isteği 2026-10-04: "yay, crossbow, tabanca, ateş asası, buz asası, tüfek,
## tüftüf silahları ateşlendiğinde biraz geri tepsin"). Eski tepme düz 10 px'ti (0.04 sn çıkış / 0.16 sn dönüş) ve tek karede gözden
## kayboluyordu: şimdi silah başına biraz daha uzun bir tepme + namlu kalkması (ikon ateş yönünde döner gibi yukarı yükselir) + yaylanarak
## dönüş. Kritik animasyonlar (weapon_crit_anim.gd) bundan HER ZAMAN daha sert kalır (kick 1.6-2.4x, dönüş/ezilme). weapon.gd (_do_recoil)
## ve remote_player.gd (_animate_weapon_fire_full) AYNI fonksiyonu çağırır; tabloda olmayan silah (arcane, bumerang, fişek...) eski yolda kalır.
## kick: recoil_distance'a çarpan; rot: namlu kalkması (radyan, artımlı eklenir - nişan her kare ikonu hedefe çevirdiği için).
const RANGED_RECOIL := {
	"yay": {"kick": 1.4, "rot": 0.10},
	"crossbow": {"kick": 1.4, "rot": 0.14},
	"tabanca": {"kick": 1.4, "rot": 0.26},
	"fire_staff": {"kick": 1.5, "rot": 0.12},
	"buz_asasi": {"kick": 1.4, "rot": 0.10},
	"tufek": {"kick": 1.7, "rot": 0.18},
	"pompali": {"kick": 2.6, "rot": 0.26}, ## madde 448
	"makineli": {"kick": 1.1, "rot": 0.12}, ## madde 652 (saniyede 12+ atış: büyük tepme titreme olur)
	"tuftuf": {"kick": 1.5, "rot": 0.12}, ## Zehir Asası (madde 410): üfleme borusu değil asa -> Ateş Asası gibi baş kalkar
}
const RECOIL_OUT := 0.045
const RECOIL_BACK := 0.22
const RECOIL_STRETCH_TIME := 0.1
const RECOIL_SETTLE := 0.1


## Ateşli silahlar ateşte EZİLİP ESNEMEZ (kullanıcı isteği 2026-11-13: "saldırı esnasında evrilip kıvrılıyor ... sıvıymış gibi,
## bu efektin olmasını istemiyorum"): yalnız geri tepme (konum) + namlu kalkması (rotasyon), ölçek hep taban. Normal atış
## (ranged_recoil) VE kritik (weapon_crit_anim.gd play_ranged) bu listeye bakar; kaster + uzak kopya aynı fonksiyonlardan geçer.
const RIGID_GUNS := ["tabanca", "tufek", "pompali", "makineli"]


static func is_rigid(weapon_key: String) -> bool:
	return RIGID_GUNS.has(weapon_key)


static func has_ranged_recoil(weapon_key: String) -> bool:
	return RANGED_RECOIL.has(weapon_key)


## icon: ikon düğümü, base_pos: ikonun YEREL dinlenme konumu (yerelde Vector2.ZERO), base_scale: SABİT dinlenme ölçeği, dir: HEDEFE doğru yön
## (tepme bunun tersine), recoil_dist: silahın recoil_distance'ı. Döner: konum+ölçek tween'i (çağıran saklayıp sonraki atışta kesebilir).
static func ranged_recoil(tween_owner: Node, icon: Node2D, weapon_key: String, dir: Vector2, base_pos: Vector2, base_scale: Vector2,
		recoil_dist: float) -> Tween:
	var st: Dictionary = RANGED_RECOIL.get(weapon_key, {})
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var kick: Vector2 = -d * recoil_dist * float(st.get("kick", 1.0))
	var tw: Tween = tween_owner.create_tween()
	if is_rigid(weapon_key):
		## Ateşli silah: şekil bozulmaz - yarıda kesilmiş eski bir tween'in bıraktığı ölçek de anında tabana döner.
		icon.scale = base_scale
		tw.tween_property(icon, "position", base_pos + kick, RECOIL_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(icon, "position", base_pos, RECOIL_BACK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		## 1) ani geri tepme + ezilme
		tw.tween_property(icon, "position", base_pos + kick, RECOIL_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_SQUASH, RECOIL_OUT)
		## 2) yaylanarak yerine dönüş (hafif aşar) + ikon esner
		tw.tween_property(icon, "position", base_pos, RECOIL_BACK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_STRETCH, RECOIL_STRETCH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		## 3) ölçek tabana oturur
		tw.tween_property(icon, "scale", base_scale, RECOIL_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rot: float = float(st.get("rot", 0.0))
	if rot != 0.0:
		var up_sign: float = -1.0 if d.x >= 0.0 else 1.0 ## namlu ekranda yukarı kalkar (sağa bakan ikonda saat yönünün tersi)
		WeaponCritAnim.rotation_kick(tween_owner, icon, rot * up_sign, RECOIL_BACK, true)
	return tw


## Yıldırım asası aktifken (ışın hedefe kilitli) ikonun hafif titremesi (kullanıcı isteği 2026-10-04). Konum ofseti: TREMOR_HZ'de bir
## sahte-rastgele yeni nokta (dinlenme konumuna eklenir). weapon.gd (_apply_beam_tremor) ve remote_player.gd (_update_beam_tremor) çağırır.
const TREMOR_AMP := 1.6
const TREMOR_HZ := 30.0


static func tremor_offset(time_sec: float) -> Vector2:
	var n: float = floorf(time_sec * TREMOR_HZ)
	return Vector2(sin(n * 12.9898), cos(n * 78.233)) * TREMOR_AMP
