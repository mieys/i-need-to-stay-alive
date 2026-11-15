extends RefCounted

## TAKIM ÜSSÜ BÖLGELERİ (PvPvE, madde 607): kurulu üslerin merkezleri + ucuz sorgular. BAĞIMLILIKSIZ (hiçbir şey preload etmez): yaratık
## (enemy.gd), köprü (enemy_world_bridge.gd) ve doğurucu (enemy_spawner.gd) bunu sıcak yolda sorar - döngüsel önyükleme olmasın diye
## team_bases.gd'den ayrı. Yalnız team_bases.gd yazar; co-op'ta (ya da üsler kurulmadan) liste boş, bütün sorgular false.

## Koruma alanı yarıçapı (tam kamp). Küçük kampın kapsamı ~292 x 121 birim (merkezden en çok ~146 yana): alan kampı biraz aşar, daha fazlası değil.
## 2026-11-12: 280 -> 160 (kullanıcı: "üs koruma alanları çok büyük, yolları kapatıyor"). Rakip bu daireye giremez, yaratık içeri girmez, doğuş payı da buna bağlı.
const RADIUS := 160.0
## Kampın yarıçapa göre en küçüğü (dar zindanda kamp küçülür, alan kampla birlikte küçülür).
const MIN_RADIUS := 72.0
## Alanın kampın sığdığı boş yarıçaptan payı (kamp daralınca alan = kamp + pay).
const CAMP_PAD := 16.0

## O maçın geçerli yarıçapı (team_bases.gd `set_camp_radius` yazar; dar yerde RADIUS'tan küçük).
static var radius: float = RADIUS

## [{"center": Vector2, "team": int}]
static var active: Array = []


## Kamp yarıçapına göre alan yarıçapı: 0 (tam kamp) = RADIUS; dar yerde kamp + pay (MIN_RADIUS ile RADIUS arası). Saf (test edilir).
static func radius_for_camp(camp_r: float) -> float:
	if camp_r <= 0.0:
		return RADIUS
	return clampf(camp_r + CAMP_PAD, MIN_RADIUS, RADIUS)


static func set_camp_radius(camp_r: float) -> void:
	radius = radius_for_camp(camp_r)


## pos herhangi bir üssün içinde mi (yaratıklar o oyuncuyu hedef almaz).
static func shelters(pos: Vector2) -> bool:
	for b: Dictionary in active:
		if pos.distance_squared_to(b["center"]) <= radius * radius:
			return true
	return false


## pos herhangi bir üssün yarıçap + extra içinde mi (yaratık doğuş noktası denetimi).
static func near_any(pos: Vector2, extra: float) -> bool:
	var r: float = radius + extra
	for b: Dictionary in active:
		if pos.distance_squared_to(b["center"]) <= r * r:
			return true
	return false


static func center_of(team: int) -> Vector2:
	for b: Dictionary in active:
		if int(b["team"]) == team:
			return b["center"]
	return Vector2.INF


static func in_own_base(pos: Vector2, team: int) -> bool:
	var c: Vector2 = center_of(team)
	return c != Vector2.INF and pos.distance_squared_to(c) <= radius * radius
