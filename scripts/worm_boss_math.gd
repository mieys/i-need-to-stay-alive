extends RefCounted

## YERALTI CANAVARI (Kademe 5 bossu, kullanıcı isteği 2026-10-09) - TÜM ayar sabitleri ve saf (düğümsüz) hesaplar TEK yerde.
## Kullanan: underground_boss.gd (host'ta yönetmen), worm_limb.gd (solucan uzvu), worm_acid.gd (asit atışı), testler.
##
## KURGU: Boss yeraltında, yeryüzüne ÇIKAMIYOR - kendisi görünmez/vurulamaz bir düğüm (can + kalkan havuzu, üstteki boss barı).
## Yüzeye solucan UZUVLARI çıkarır (sand worm sprite'ları): oyuncuların yakınında, hep GİTTİKLERİ YÖNÜN ÖNÜNDE (yolunu keser), arada
## yola dümdüz sıralanıp duvar olurlar. Uzuvların yarısı yakın dövüş (SAVURMA, 130 hasar), yarısı asit tükürür (110 hasar).
## Oyuncular uzuvlara vurur; uzvun yediği her hasar AYNEN bossun kalkan/can havuzundan düşer. Her uzvun bir hasar eşiği var:
## aşılınca ya parçalanıp ölür (FATE_BURST) ya da deliğine geri döner (FATE_RETREAT, eşiğin RETREAT_FRACTION'ında); ayrıca ömrü dolunca da döner.

# ---------------------------------------------------------------- boss havuzu (enemy_spawner.gd FIXED_BOSS_STATS ile AYNI sayılar değil - orada; burada yönetmen)
const FIRST_SPAWN_DELAY := 1.2 ## boss doğunca ilk uzvun çıkışına kadar

# ---------------------------------------------------------------- uzuv sayısı / çıkış sıklığı
const MAX_ACTIVE := 7 ## aynı anda yüzeyde en çok uzuv (tek oyunculu)
const MAX_ACTIVE_PER_EXTRA_PLAYER := 2 ## her ekstra oyuncu için +2
const SPAWN_INTERVAL_MIN := 1.3 ## iki tekil çıkış arası (sn)
const SPAWN_INTERVAL_MAX := 2.0
const LINE_INTERVAL_MIN := 13.0 ## iki "dümdüz sıra" olayı arası
const LINE_INTERVAL_MAX := 19.0
const FIRST_LINE_DELAY := 8.0
## "Yol kesen sıra" (kullanıcı 2026-10-09: "dip dibe dizilmesini istemiyorum, daha ayrık ve rastgele olmalılar"): eskiden 5 uzuv 46 px aralıkla DÜMDÜZ bir duvardı (sprite'lar üst üste biniyordu, geçit yoktu).
## Şimdi 4-6 uzuv, gidiş yönüne DİK ama aralıkları rastgele (100-170 px: sprite'lar birbirine değmez, aralarından geçilir), her biri gidiş yönünde ayrı ayrı kayık (+-45 px) ve
## çıkış sırası/gecikmesi rastgele: "yolu kesen dağınık bir engel dizisi", düz çizgi değil.
const LINE_COUNT_MIN := 4 ## sıradaki uzuv sayısı (rastgele)
const LINE_COUNT_MAX := 6
const LINE_SPACING_MIN := 100.0 ## komşu uzuv merkezleri arası yan aralık (rastgele; gövde sert yarıçapı 18, görsel ~55 px geniş: en az ~45 px boşluk)
const LINE_SPACING_MAX := 170.0
const LINE_DEPTH_JITTER := 45.0 ## her uzvun gidiş yönünde ayrı kayması +-
const LINE_CENTER_JITTER := 60.0 ## sıranın oyuncuya göre yan kayması +-
const LINE_DISTANCE_MIN := 200.0 ## sıra, oyuncunun gittiği yönde bu kadar önünde kurulur (rastgele)
const LINE_DISTANCE_MAX := 280.0
const LINE_STAGGER_MIN := 0.08 ## ardışık iki uzvun çıkışı arası gecikme (rastgele; çıkış sırası da karışık)
const LINE_STAGGER_MAX := 0.45
const LINE_MIN_LIMB_GAP := 80.0 ## sıradaki bir uzuv, yüzeydeki başka bir uzuvdan en az bu kadar uzakta çıkar
const SPITTER_CHANCE := 0.45 ## tekil çıkışta asit atan olma olasılığı (sıra uzuvları hep YAKIN DÖVÜŞ: yolu bedenleriyle keser)

# ---------------------------------------------------------------- konum seçimi (yol kesme)
const LEAD_MIN := 150.0 ## oyuncunun gidiş yönünde ne kadar ileride
const LEAD_MAX := 250.0
const LATERAL := 70.0 ## yan sapma +-
const STILL_SPEED := 40.0 ## bundan yavaşsa oyuncu "duruyor" sayılır
const STILL_RING_MIN := 130.0 ## duran oyuncunun çevresinde halka
const STILL_RING_MAX := 230.0
const MIN_PLAYER_DIST := 95.0 ## hiçbir oyuncunun bu kadar yakınında çıkmaz (altında/dibinde doğup sıkıştırmasın)
const MIN_LIMB_SPACING := 96.0 ## tekil çıkışta başka uzuvdan en az bu kadar uzak (sprite ~55 px geniş: üst üste binmesinler)
const PLACE_TRIES := 14

# ---------------------------------------------------------------- uzuv
const KIND_LASHER := 0 ## yakın dövüş (savurma)
const KIND_SPITTER := 1 ## asit atan
const FATE_BURST := 0 ## eşik dolunca parçalanıp ölür
const FATE_RETREAT := 1 ## eşiğin RETREAT_FRACTION'ında deliğine döner
const LIMB_THRESHOLD := 2000.0 ## uzvun alabileceği toplam hasar = bossun bu kadar havuzu eriyip gider (sahnedeki max_health ile AYNI)
const RETREAT_FRACTION := 0.55
const FATE_RETREAT_CHANCE := 0.35
const LIFETIME_MIN := 9.0 ## ömrü dolunca kendiliğinden döner
const LIFETIME_MAX := 14.0
const LINE_LIFETIME_MIN := 13.0
const LINE_LIFETIME_MAX := 17.0
const HARD_BLOCK_RADIUS := 18.0 ## oyuncuyu ŞU mesafede durduran sert gövde (normal yaratıkların yumuşak bloğu ~11 px, bkz. player.gd)
const EMERGE_TIME := 0.45 ## çıkış animasyonu (4 kare)
const HIDE_TIME := 0.85 ## gömülme animasyonu (8 kare)
const FIRST_ATTACK_DELAY := 0.8 ## çıktıktan sonra ilk saldırıya kadar

# ---------------------------------------------------------------- saldırılar
const LASH_DAMAGE := 130.0
const LASH_RANGE := 104.0 ## merkez-hedef mesafesi: bu kadar yakınsa savurur
const LASH_REACH := 112.0 ## isabet yarıçapı (menzil + oyuncu payı)
const LASH_ANIM := 0.7 ## 7 kare
const LASH_STRIKE_AT := 0.33 ## isabet karesi (kare 3)
const LASH_WARN_FROM := 0.0 ## uyarı (kırmızı parlama) animasyon başından savurmaya kadar
const LASH_COOLDOWN := 1.7
const LASH_CONE_DOT := 0.0 ## savurma yönüne göre ön yarım düzlem (dot > bu)
const ACID_DAMAGE := 110.0
const SPIT_RANGE_MIN := 40.0 ## yakındaki oyuncuya da tükürür (bedende değilse)
const SPIT_RANGE_MAX := 430.0
const SPIT_ANIM := 0.6 ## 6 kare
const SPIT_FIRE_AT := 0.30
const SPIT_COOLDOWN_MIN := 2.4
const SPIT_COOLDOWN_MAX := 3.4
const ACID_SPEED := 240.0
const ACID_RANGE := 520.0
const ACID_HIT_RADIUS := 16.0 ## + oyuncu gövdesi

# ---------------------------------------------------------------- boss sesleri
const RUMBLE_MIN := 5.0 ## yeraltı gümbürtüsü aralığı (sn)
const RUMBLE_MAX := 9.0
const GROWL_MIN := 9.0
const GROWL_MAX := 15.0
const AMBIENT_MIN := 16.0 ## Horror paketinden "Gore And Larvae" katmanı
const AMBIENT_MAX := 26.0

# ---------------------------------------------------------------- görsel pozlar (worm_limb.gd _pose_override)
## (Minotaur pozları 1-3: enemy.gd _advance_frame_sprite onları kare aralığına çevirir - uzuv pozları ÇAKIŞMASIN diye 11+)
const POSE_NONE := 0
const POSE_EMERGE := 11
const POSE_LASH := 12
const POSE_SPIT := 13
const POSE_HIDE := 14


## Uzvun türü: roll 0..1 (asit atan olma şansı SPITTER_CHANCE).
static func pick_kind(roll: float) -> int:
	return KIND_SPITTER if roll < SPITTER_CHANCE else KIND_LASHER


static func pick_fate(roll: float) -> int:
	return FATE_RETREAT if roll < FATE_RETREAT_CHANCE else FATE_BURST


## Oyuncunun yeni hız tahmini: önceki tahmin ve iki konum farkından üstel süzme (k = 0..1).
static func smooth_velocity(prev: Vector2, last_pos: Vector2, pos: Vector2, dt: float, k: float = 0.25) -> Vector2:
	if dt <= 0.0:
		return prev
	return prev.lerp((pos - last_pos) / dt, clampf(k, 0.0, 1.0))


## Oyuncunun yolunu keser: hareket ediyorsa gidiş yönünde `lead` ileride, yana `lateral` sapmayla; duruyorsa çevresinde halka (angle, ring).
static func path_cut_position(pos: Vector2, vel: Vector2, lead: float, lateral: float, angle: float, ring: float) -> Vector2:
	if vel.length() > STILL_SPEED:
		var d: Vector2 = vel.normalized()
		return pos + d * lead + d.orthogonal() * lateral
	return pos + Vector2.from_angle(angle) * ring


## Yol kesen DAĞINIK sıra: gidiş yönüne (dir) dik bir eksen boyunca 4-6 uzuv; komşu aralıkları rastgele (LINE_SPACING_MIN..MAX), her uzuv gidiş yönünde ayrıca +-LINE_DEPTH_JITTER kayık,
## sıra oyuncunun LINE_DISTANCE_MIN..MAX önünde ve yanlamasına +-LINE_CENTER_JITTER kayık. Döner: [{"pos": Vector2, "delay": çıkış gecikmesi sn}] - dizi çıkış SIRASINDA (karışık) ve gecikmeler
## artan. `rng` testlerde tohumlanır.
static func scattered_line(pos: Vector2, dir: Vector2, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var perp: Vector2 = d.orthogonal()
	var count: int = rng.randi_range(LINE_COUNT_MIN, LINE_COUNT_MAX)
	var base: Vector2 = pos + d * rng.randf_range(LINE_DISTANCE_MIN, LINE_DISTANCE_MAX) + perp * rng.randf_range(-LINE_CENTER_JITTER, LINE_CENTER_JITTER)
	## yan konumlar: soldan sağa aralıklar rastgele, sonra sıra ortalanır
	var offsets: Array[float] = []
	var at: float = 0.0
	for i in range(count):
		offsets.append(at)
		at += rng.randf_range(LINE_SPACING_MIN, LINE_SPACING_MAX)
	var mid: float = (offsets[count - 1] + offsets[0]) * 0.5
	var spots: Array[Vector2] = []
	for i in range(count):
		spots.append(base + perp * (offsets[i] - mid) + d * rng.randf_range(-LINE_DEPTH_JITTER, LINE_DEPTH_JITTER))
	## çıkış sırası karışık (Fisher-Yates)
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var out: Array[Dictionary] = []
	var t: float = 0.0
	for i in range(count):
		out.append({"pos": spots[i], "delay": t})
		t += rng.randf_range(LINE_STAGGER_MIN, LINE_STAGGER_MAX)
	return out


## Bir çıkış noktası uygun mu: engelsiz (blocked(Vector2) -> bool), hiçbir oyuncunun MIN_PLAYER_DIST'inde değil, başka uzuvla çakışmıyor.
static func spawn_ok(p: Vector2, players: Array, limbs: Array, blocked: Callable, min_limb_spacing: float = MIN_LIMB_SPACING) -> bool:
	if bool(blocked.call(p)):
		return false
	for q in players:
		if p.distance_to(q as Vector2) < MIN_PLAYER_DIST:
			return false
	for l in limbs:
		if p.distance_to(l as Vector2) < min_limb_spacing:
			return false
	return true


## Aynı anda yüzeyde olabilecek uzuv sayısı (oyuncu sayısına göre).
static func max_active(player_count: int) -> int:
	return MAX_ACTIVE + MAX_ACTIVE_PER_EXTRA_PLAYER * maxi(0, player_count - 1)


## Uzvun savurma isabeti: merkez-oyuncu mesafesi LASH_REACH içinde ve oyuncu savurma yönünün önünde mi.
static func lash_hits(limb_pos: Vector2, aim: Vector2, player_pos: Vector2) -> bool:
	var to_p: Vector2 = player_pos - limb_pos
	if to_p.length() > LASH_REACH:
		return false
	if to_p.length() < 8.0:
		return true
	return to_p.normalized().dot(aim.normalized()) > LASH_CONE_DOT
