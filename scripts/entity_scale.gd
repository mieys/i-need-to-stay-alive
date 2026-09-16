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

## Tüm varlıkların görseli VE ona bağlı çarpışma çemberi %5 küçülür.
## (Projedeki "hem scale hem collision" deseni - bkz. xp_orb.gd TIERS ve
## enemy.gd apply_boss_stats, ikisi de aynı şeyi yapar.)
const SIZE := 0.95

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
static func shrink_collision(collision: CollisionShape2D) -> void:
	if collision == null or not (collision.shape is CircleShape2D):
		return
	## Şekil paylaşılan bir kaynak olabilir (ayrı .tscn'ler aynı shape'i
	## kullanmıyorsa da duplicate en güvenlisi) - asla yerinde değiştirilmez.
	var shape: CircleShape2D = collision.shape.duplicate()
	shape.radius *= SIZE
	collision.shape = shape
