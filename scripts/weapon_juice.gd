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
