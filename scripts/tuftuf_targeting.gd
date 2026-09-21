extends RefCounted

## Tüftüf'ün hedef seçimi - kullanıcı isteği: "tüftüf canı yüksek olan yaratıklara
## veya hiç zehirlenmemiş yaratıklara öncelik versin, öncelik sırası: (canı yüksek >
## hiç zehirlenmemiş > tüm yaratıklar)".
##
## weapon.gd (gerçek silah, _get_highest_health_enemy) VE remote_player.gd (diğer
## oyuncuların ekranındaki kozmetik ikon, _get_highest_health_enemy_from) SADECE bu
## fonksiyonu çağırır - seçim kuralı iki dosyada ayrı ayrı yazılmasın diye (bkz.
## proje CLAUDE.md: aynı bilgiyi iki yerde tutmak "diğerinde eski kalıyor" hatasına
## yol açıyor).
##
## Sıra (ilk BOŞ OLMAYAN sınıf seçilir, sınıfın içinden canı en yüksek olan alınır,
## eşitlikte en yakın):
##  1) CANI YÜKSEK: canı, menzildeki yaratıkların ortalama canının HIGH_HEALTH_MEAN_
##     RATIO katı ya da daha fazlası olanlar (elit/boss/zırhlı gibi dikkat çeken
##     "yüksek canlılar" - zehir yükleri en çok bunlarda değer buluyor, küçükler zaten
##     ölüyor).
##  2) HİÇ ZEHİRLENMEMİŞ: yüksek canlı yoksa (kalabalık benzer canlı yaratıklardan
##     oluşuyorsa) zehirli OLMAYANlar - zehir kalabalığa yayılsın.
##  3) TÜM YARATIKLAR: hepsi zaten zehirliyse menzildeki herkes.
## "Zehirli mi" bilgisi enemy.gd is_poisoned()'den okunur (istemcideki kukla
## yaratıklarda da zehir efektinin varlığıyla doğru çalışır).
const HIGH_HEALTH_MEAN_RATIO := 1.5


## enemies: aday yaratıklar (genelde "enemies" grubu). origin/max_range: silahın
## konumu ve menzili (max_range <= 0 = sınırsız). can_target: verilirse (örn. sis/
## görüş kontrolü) false dönen yaratıklar hiç aday olmaz.
static func pick(enemies: Array, origin: Vector2, max_range: float, can_target: Callable = Callable()) -> Node2D:
	var candidates: Array = []
	var health_sum: float = 0.0
	for e in enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if can_target.is_valid() and not can_target.call(e):
			continue
		if max_range > 0.0 and origin.distance_to(e.global_position) > max_range:
			continue
		candidates.append(e)
		health_sum += _health_of(e)
	if candidates.is_empty():
		return null

	var mean_health: float = health_sum / float(candidates.size())
	var high: Array = []
	var unpoisoned: Array = []
	for e in candidates:
		if _health_of(e) >= mean_health * HIGH_HEALTH_MEAN_RATIO:
			high.append(e)
		if not _is_poisoned(e):
			unpoisoned.append(e)

	var pool: Array = candidates
	if not high.is_empty():
		pool = high
	elif not unpoisoned.is_empty():
		pool = unpoisoned

	var best: Node2D = null
	var best_health: float = -INF
	var best_dist: float = INF
	for e in pool:
		var h: float = _health_of(e)
		var d: float = origin.distance_to(e.global_position)
		if h > best_health or (is_equal_approx(h, best_health) and d < best_dist):
			best_health = h
			best_dist = d
			best = e
	return best


static func _health_of(e: Node) -> float:
	return float(e.get("health")) if "health" in e else 0.0


static func _is_poisoned(e: Node) -> bool:
	return e.has_method("is_poisoned") and bool(e.call("is_poisoned"))
