class_name EntityScale
extends RefCounted

## OYUNDAKİ TÜM "varlıkların" (oynanabilir karakterler, uzak oyuncu kuklaları,
## yaratıklar ve evcil hayvanlar) ortak boyut/hız ayarı.
##
## Kullanıcı isteği (bildirim: "oyundaki tüm oynanabilir karakterleri ve
## yaratıkları v.s %5 küçültüp hareket hızlarını %10 azaltmanı istiyorum").
##
## NEDEN AYRI BİR MODÜL: varlıkların boyutu sahne dosyalarında (.tscn'de her
## yaratığın kendi Sprite2D/AnimatedSprite2D ölçeği ve çarpışma yarıçapı)
## tanımlı - 60+ sahneyi elle değiştirmek yerine, hepsi _ready()'de buradaki
## TEK çarpanı uygular (projenin enemy.gd'deki GLOBAL_SPEED_SCALE ile aynı
## deseni: "düşman hızları sahne dosyalarında tek tek tanımlı olduğu için
## burada topluca çarpılıyor").
##
## Sahne dosyalarındaki değerler DEĞİŞTİRİLMEZ: burada sadece çalışma zamanı
## çarpanı uygulanır, böylece ileride "biraz daha küçült/büyüt" isteği TEK bir
## sayıyı değiştirmekle tüm oyuna uygulanır.

## 2026-10-09'a kadarki boyut (%5 küçültme). Elle ölçülmüş sabitler (can çubuğu yüksekliği, ayak/gövde ofseti, gölge, kalkan baloncuğu...)
## bu boyuta göre yazılmıştı; yeni boyuta uyarlarken `LEGACY_SIZE` ya da `BODY_REL` ile çarpılır.
const LEGACY_SIZE := 0.95

## Kullanıcı isteği (2026-10-09): "tüm yaratıkları ve oyuncuları %15 küçült" - eski boyuta GÖRE çarpan. Gövde boyutuna bağlı elle yazılmış
## sabitler (ayak ofseti, gölge, çubuk yüksekliği...) bununla çarpılır.
const BODY_REL := 0.85

## "bossları %20 küçült" - eski boyuta göre bossların TOPLAM çarpanı (yaratıkların %15'inin ÜSTÜNE binmez: boss = eski boyutun %80'i).
## Bosslar zaten SIZE ile küçüldüğü için ek çarpan BOSS_REL / BODY_REL (apply_boss_stats ve uzuvlar uygular).
const BOSS_REL := 0.80
const BOSS_EXTRA := BOSS_REL / BODY_REL

## Tüm varlıkların görseli VE ona bağlı çarpışma çemberi küçülür (0.95 x 0.85 = %19,25 küçültme, bkz. LEGACY_SIZE).
## (Projedeki "hem scale hem collision" deseni - bkz. xp_orb.gd TIERS ve
## enemy.gd apply_boss_stats, ikisi de aynı şeyi yapar.)
const SIZE := LEGACY_SIZE * BODY_REL

## Karaktere BAĞLI ama gövdeyle birlikte küçülmeyen parçalar (kalkan baloncuğu; silahlar zaten kendi ICON_SIZE_MULT'ünde): kullanıcı 2026-10-09
## "herşeyle beraber küçült ama silahlar kalkan v.b." - bunların boyutu eski kaldı. Karakterle birlikte küçülsünler istenirse SIZE'a eşitle.
const ATTACHED_SIZE := LEGACY_SIZE

## Tüm hareket hızları %10 azalır.
## NOT: yaratıklarda bu, sahnelere tek tek yazılmış hızların üstüne
## enemy.gd'deki GLOBAL_SPEED_SCALE ile BİRLİKTE çarpılır (çarpmalar
## birikimli, ikisi de yüzdesel).
const SPEED := 0.9


## Bir varlığın görselini (Sprite2D/AnimatedSprite2D) ve varsa gövde çarpışma
## çemberini AYNI oranda küçültür. Düğümler çağıran tarafından açıkça verilir
## (körlemesine "tüm Sprite2D çocukları" taranmaz: yaratıkların olay anında
## eklenen efekt/hasar çubuğu gibi görselleri yanlışlıkla küçülmesin).
static func shrink(visual: Node2D, collision: CollisionShape2D = null) -> void:
	if visual:
		visual.scale *= SIZE
	shrink_collision(collision)


## Sadece çarpışma çemberini küçültür (görseli olmayan/başka yerde ölçeklenen
## düğümler için - ör. oyuncunun gövde çemberi ayrı ele alınıyor).
## CircleShape2D dışındaki şekiller desteklenmiyor: projedeki TÜM varlık
## gövdeleri çember (bkz. creature .tscn'leri, pet .tscn'leri, enemy.gd
## apply_boss_stats de yalnızca radius ölçekliyor).
static func shrink_collision(collision: CollisionShape2D, mult: float = SIZE) -> void:
	if collision == null or not (collision.shape is CircleShape2D):
		return
	## Şekil paylaşılan bir kaynak olabilir (ayrı .tscn'ler aynı shape'i
	## kullanmıyorsa da duplicate en güvenlisi) - asla yerinde değiştirilmez.
	var shape: CircleShape2D = collision.shape.duplicate()
	shape.radius *= mult
	collision.shape = shape
