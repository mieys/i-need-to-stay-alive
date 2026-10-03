extends RefCounted

## Yaratık "aday" sorgusu (yaratık yeniden yazımı, PLAN Aşama 2 "grup taramaları"). Her karede TÜM "enemies" grubunu
## GDScript'te tarayan yerler bunun yerine bunu çağırır:
##
##   for e in EnemyQuery.candidates(get_tree(), merkez, yaricap): ...   # çağıranın KENDİ süzgeçleri aynen kalır
##
## Dönen dizi bir ÜST KÜMEDİR - çağıran kendi mesafe/ölü/sis kontrollerini yapmaya devam eder, yani sonuç eski yolla aynı:
##  - Yeni yol (EnemyWorld köprüsü bu sahnede varsa): merkezi `radius` içinde olan canlı kayıtlı yaratıklar (C++ ızgara
##    sorgusu) + görev kopyaları. Ölüm animasyonundaki (kaydı silinmiş, is_dead) yaratıklar DÖNMEZ.
##  - Eski yol / istemci / radius <= 0 (sınırsız): "enemies" grubunun tamamı (eskiden olduğu gibi).
## Gövde yarıçapını hesaba katan çağıran `radius`'a en büyük gövde payını (BODY_PAD) eklemeli.

const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

## En büyük yaratık gövde yarıçapı için güvenli pay (boss ~71 px, elit golem x1,5 ~107 px).
const BODY_PAD := 140.0
## C++ konumu adım başında okunur; aynı kare içinde dışarıdan taşınan (kara delik çekimi, itme) yaratık birkaç px eski
## konumda olabilir - üst küme bozulmasın diye sorgu bu kadar geniş tutulur (çağıranın süzgeci kesin mesafeyi uygular).
const MOVE_SLACK := 24.0


static func candidates(tree: SceneTree, center: Vector2, radius: float) -> Array:
	if radius > 0.0 and radius < INF:
		var near: Variant = EnemyWorldBridgeScript.enemies_near(tree, center, radius + MOVE_SLACK)
		if near != null:
			return near
	return tree.get_nodes_in_group("enemies")


## Yeni yol bu sahnede çalışıyor mu (köprü + C++ dünyası var).
static func active(tree: SceneTree) -> bool:
	return EnemyWorldBridgeScript.fog_world(tree) != null
