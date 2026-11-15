extends RefCounted

## MANA KALKANI BALONCUĞU + MENZİLLİ ATIŞ KURALI (madde 572; kullanıcı 2026-11-11: "menzilli atışlar kalkanın içine
## girememeli kalkan varken, kalkanın dışına vurmalı"). Mana kalkanı (item_shield_hp > 0) olan oyuncuya gelen yaratık
## mermisi / kemik / ateş topu / boss büyüsü / asit, gövdeye değil BALONCUĞUN dış kenarına çarpıp orada söner.
## - Kural her makinede o makinedeki mermi kopyasıyla AYNI işler (host yetkili kopya + istemcideki görsel kopya): kopyalar
##   hep baloncuğun kenarında söner, darbe efekti (A yaması + seken kıvılcımlar, mana_shield_fx.gd ranged_hit) de her
##   ekranda kendi kopyasının değdiği noktada oynar - ağ olayı yok. Hasarı yalnız yetkili kopya verir (yaratık yeteneği
##   türüyle, deal_special_damage); hedefin kendi player.gd'si bu türü RANGED_KINDS'te görünce darbe efektini İKİNCİ kez
##   oynatmaz ve "shield_hit_flash" yayınlamaz (bkz. take_damage).
## - Baloncuk = ShieldVisual/BubbleSprite (oyuncu + kukla aynı sahne düzeni); yarıçap onun gerçek ölçeğinden (BUBBLE_R texel).
## Kalkan yoksa / ölü / yerde / içeride / ruh hâlinde: kural yok, eski gövde isabeti.

const BUBBLE_R := 11.0 ## baloncuk sanatının görünen yarıçapı (24x24 karede texel; shaders/kalkan_darbe.gdshader R)
## Baloncuğa çarpan mermilerin hasar türleri (deal_special_damage kind). Yeni bir yaratık mermisi eklenirse buraya da ekle.
const RANGED_KINDS := ["projectile", "bone", "fireball", "bossfire", "demonfire", "worm_acid"]


static func is_ranged_kind(kind: String) -> bool:
	return RANGED_KINDS.has(kind)


static func _bubble(n: Node) -> Node2D:
	return n.get_node_or_null("ShieldVisual/BubbleSprite") as Node2D


## n'in (yerel oyuncu / uzak kukla) mana kalkanı baloncuğunun dünya yarıçapı; kural işlemiyorsa 0.
static func radius_of(n: Node) -> float:
	if n == null or not is_instance_valid(n) or not (n is Node2D):
		return 0.0
	if n.get("is_dead") == true or n.get("is_downed") == true or n.get("is_indoors") == true or n.get("in_limbo") == true:
		return 0.0
	var hp: Variant = n.get("item_shield_hp")
	if hp == null or float(hp) <= 0.0:
		return 0.0
	var b := _bubble(n)
	if b == null:
		return 0.0
	return BUBBLE_R * absf(b.global_scale.x)


static func center_of(n: Node2D) -> Vector2:
	var b := _bubble(n)
	return b.global_position if b != null else n.global_position


## `pos`taki (yarıçapı proj_r) mermi n'in baloncuğuna değdi mi.
static func touches(n: Node, pos: Vector2, proj_r: float) -> bool:
	var r := radius_of(n)
	if r <= 0.0:
		return false
	var reach := r + proj_r
	return pos.distance_squared_to(center_of(n as Node2D)) <= reach * reach


## Değme anı: n'in kalkanında menzilli darbe efekti (her makine kendi kopyası için çağırır).
static func impact(n: Node, pos: Vector2) -> void:
	var fx: Variant = n.get("mana_fx")
	if fx is Node and is_instance_valid(fx) and (fx as Node).has_method("ranged_hit"):
		(fx as Node).call("ranged_hit", (pos - center_of(n as Node2D)).angle())
