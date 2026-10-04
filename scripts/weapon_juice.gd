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


## Büyücü Kız pasifi "Büyü Dalgası" (kullanıcı isteği 2026-10-04: "silahları aniden sertçe ileri itilip aynı anda atış yaparak") -
## güçlendirilmiş atışta ikon hedefe doğru SERTÇE ileri fırlar (namlu boyunca esner), atışla birlikte geri tepmeyle geriye savrulur
## ve yaylanarak yerine oturur; bu sırada mor parlar (surge_flash). weapon.gd _do_recoil / _deal_beam_tick ve remote_player.gd
## _animate_weapon_fire_full ("surge" bayrağı) AYNI fonksiyonu çağırır. base_pos: ikonun dinlenme konumu (yerelde Vector2.ZERO).
const SURGE_THRUST_MIN := 14.0 ## px - ileri fırlama (recoil_distance x SURGE_THRUST_MULT'tan küçükse bu)
const SURGE_THRUST_MULT := 1.8
const SURGE_STRETCH := Vector2(1.3, 0.8)
const SURGE_OUT := 0.05
const SURGE_HOLD := 0.05
const SURGE_SNAP := 0.07
const SURGE_SETTLE := 0.22
const SURGE_FLASH := Color(1.7, 1.15, 2.1)
const SURGE_FLASH_TIME := 0.35


static func arcane_surge(tween_owner: Node, icon: Node2D, dir: Vector2, base_pos: Vector2, base_scale: Vector2, recoil_dist: float) -> Tween:
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var thrust: float = maxf(SURGE_THRUST_MIN, recoil_dist * SURGE_THRUST_MULT)
	var tw: Tween = tween_owner.create_tween()
	tw.tween_property(icon, "position", base_pos + d * thrust, SURGE_OUT).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale * SURGE_STRETCH, SURGE_OUT)
	tw.tween_interval(SURGE_HOLD)
	tw.tween_property(icon, "position", base_pos - d * recoil_dist, SURGE_SNAP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "scale", base_scale * PUNCH_SQUASH, SURGE_SNAP)
	tw.tween_property(icon, "position", base_pos, SURGE_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, SURGE_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	surge_flash(tween_owner, icon)
	return tw


## Kısa mor-beyaz parlama (self_modulate rgb; alfa - ölüm solması vb. - korunur). Yakın dövüşte tek başına (savuruş zaten ileri atılış).
static func surge_flash(tween_owner: Node, icon: Node2D) -> void:
	var old: Variant = icon.get_meta("surge_flash_tween") if icon.has_meta("surge_flash_tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: Tween = tween_owner.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(icon):
			var c: Color = Color.WHITE.lerp(SURGE_FLASH, k)
			c.a = icon.self_modulate.a
			icon.self_modulate = c
	, 1.0, 0.0, SURGE_FLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	icon.set_meta("surge_flash_tween", tw)
