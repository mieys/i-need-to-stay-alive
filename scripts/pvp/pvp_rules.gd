extends RefCounted

## PvP HASAR KURALLARI (PvPvE Aşama 2, madde 615; plan docs/pvp/PLAN.md bölüm 3). Saf sayı kuralları (test edilir); yer yok, düğüm yok.
## Akış: vuran makinede rakip kuklanın vekili (pvp_target.gd) `take_damage` alır -> `outgoing` (kategori çarpanı; vurana gösterilen sayı da bu)
## -> PvpNet.send_hit -> KURBANIN makinesi `incoming_cap` (tek vuruş tavanı) + güvenli bölge / hazırlık / mesafe doğrulaması -> player.take_pvp_damage.
## Denge değerleri BAŞLANGIÇ tahminidir (plan: Aşama 0 ölçümü denge aşamasına ertelendi, kullanıcı "sonra dengeleriz" dedi): hepsi bu dosyada.

## Maç başında PvP kapalı süre (K2 "hazırlık"): bu süre boyunca rakip vekilleri hedeflenemez, gelen hasar reddedilir.
const PREP_SECONDS := 60.0
## Kategori çarpanları (plan bölüm 3): silah otomatik nişanla bedava isabet ettiği için kısık; yetenek tam; süreli / alan hasarı yarıya yakın.
const WEAPON_MULT := 0.4
const SKILL_MULT := 1.0
const AREA_MULT := 0.7
const DOT_MULT := 0.5
## Kontrol (sersemletme / dondurma) süresi ve geri itme gücü oyuncuya yarı.
const CC_MULT := 0.5
const CC_MAX_SECONDS := 1.5
## Tek vuruşun alabileceği en çok pay: kurbanın azami can + azami kalkanının bu oranı (tek atma yok).
const HIT_CAP_FRACTION := 0.25
## Vuran ile kurban kuklası arası en çok mesafe (görüş elipsi ~700 + gecikme / sekme payı). Aşan vuruş "duvar ardından / ışınlanarak" sayılıp düşer.
const MAX_HIT_RANGE := 1100.0

## Bu makinede bir PvP maçı (Main) çalışıyor mu + başladığı an (pvp_targets.gd yazar). Maç yokken hiçbir PvP hasarı geçerli değil.
static var match_running: bool = false
static var match_start_msec: int = 0


static func begin_match() -> void:
	match_running = true
	match_start_msec = Time.get_ticks_msec()


static func end_match() -> void:
	match_running = false
	match_start_msec = 0
	cc_reset()
	last_combat_msec = -100000
	respawn_protect_pending = false
	respawn_protect_until_msec = 0


## Hazırlık süresi (sn). Geliştirmede (yalnız editör, security_guard.dev_env) PVP_PREP ortam değişkeni ezer: denetim / test hemen vurabilsin.
static var _prep_seconds: float = -1.0


static func prep_seconds() -> float:
	if _prep_seconds < 0.0:
		var env: String = preload("res://scripts/security/security_guard.gd").dev_env("PVP_PREP")
		_prep_seconds = float(env) if env.is_valid_float() else PREP_SECONDS
	return _prep_seconds


## Hazırlık süresinden kalan saniye (0 = bitti). Maç çalışmıyorsa da 0 (bunu `match_running` ayrıca denetler).
static func prep_left(now_msec: int, start_msec: int) -> float:
	return maxf(0.0, prep_seconds() - float(now_msec - start_msec) / 1000.0)


static func prep_left_now() -> float:
	if not match_running:
		return 0.0
	return prep_left(Time.get_ticks_msec(), match_start_msec)


## PvP hasarı şu an geçerli mi (maç çalışıyor + hazırlık bitti).
static func fighting() -> bool:
	return match_running and prep_left_now() <= 0.0


## Silah etiketi balans kaydından gelir ("w:<silah>" = silah vuruşu, "s:..." yetenek / pasif, "" = evrim / efsun / diğer).
static func is_weapon_source(bl_src: String) -> bool:
	return bl_src.begins_with("w:")


## Vuran tarafın göndereceği (ve ekranında göstereceği) hasar. Süreli hasar (yanma / zehir / kanama tiki) alan sayılmaz, kendi çarpanını alır.
static func outgoing(amount: float, bl_src: String, is_area: bool, is_dot: bool) -> float:
	if amount <= 0.0 or is_nan(amount):
		return 0.0
	var mult: float = WEAPON_MULT if is_weapon_source(bl_src) else SKILL_MULT
	if is_dot:
		mult *= DOT_MULT
	elif is_area:
		mult *= AREA_MULT
	return amount * mult


## Kurban tarafında tek vuruş tavanı: azami can + kalkanın HIT_CAP_FRACTION'ı. max_total <= 0 (bilinmiyor) = tavan yok.
static func incoming_cap(amount: float, max_health: float, max_shield: float) -> float:
	if amount <= 0.0 or is_nan(amount):
		return 0.0
	var max_total: float = maxf(0.0, max_health) + maxf(0.0, max_shield)
	if max_total <= 0.0:
		return amount
	return minf(amount, max_total * HIT_CAP_FRACTION)


## Kontrol süresi (sn): oyuncuya yarı, üst sınırlı.
static func cc_seconds(duration: float) -> float:
	return clampf(duration * CC_MULT, 0.0, CC_MAX_SECONDS)


## AZALAN ETKİ (plan bölüm 3): aynı oyuncuya 15 sn içinde gelen kontroller: 1. tam (yarılanmış süre), 2. x0,5, 3. x0,25, ardından 3 sn bağışıklık.
## 1 sn içindeki tekrarlar (yavaşlatma alanının tikleri) AYNI uygulama sayılır: sayaç tükenmez. Kurbanın makinesinde çalışır (statik durum).
const CC_WINDOW_MSEC := 15000
const CC_SAME_APPLICATION_MSEC := 1000
const CC_IMMUNITY_MSEC := 3000
static var _cc_stamps: Array[int] = []
static var _cc_immune_until: int = 0
static var _cc_last_msec: int = -100000
static var _cc_last_scale: float = 1.0


static func cc_register(duration: float, now_msec: int = -1) -> float:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	if now_msec < _cc_immune_until:
		return 0.0
	if now_msec - _cc_last_msec < CC_SAME_APPLICATION_MSEC:
		return cc_seconds(duration) * _cc_last_scale
	var keep: Array[int] = []
	for t in _cc_stamps:
		if now_msec - t <= CC_WINDOW_MSEC:
			keep.append(t)
	_cc_stamps = keep
	var scale: float = 1.0 if _cc_stamps.is_empty() else (0.5 if _cc_stamps.size() == 1 else 0.25)
	var secs: float = cc_seconds(duration) * scale
	_cc_stamps.append(now_msec)
	_cc_last_msec = now_msec
	_cc_last_scale = scale
	if _cc_stamps.size() >= 3:
		_cc_immune_until = now_msec + int(secs * 1000.0) + CC_IMMUNITY_MSEC
		_cc_stamps.clear()
	return secs


static func cc_reset() -> void:
	_cc_stamps.clear()
	_cc_immune_until = 0
	_cc_last_msec = -100000
	_cc_last_scale = 1.0


## ---------------------------------------------------------------- ÖLÜM / ÖDÜL / ZAFER (Aşama 4, madde 617)
## Ölüm süresi (plan 2.1): cesette yatma süresi = 10 sn + kademe başına 2 sn (K1 12 sn ... K10 30 sn). Diriltme yok; süre bitince KENDİ ÜSSÜNDE doğar.
const DEATH_BASE_SECONDS := 10.0
const DEATH_PER_TIER_SECONDS := 2.0
## Rakip oyuncu öldürme altını: taban + kademe başına + öldürenin "seri bozma" eki (kurbanın ölmeden önceki öldürme serisi, en çok 5).
const KILL_GOLD_BASE := 60
const KILL_GOLD_PER_TIER := 20
const KILL_GOLD_PER_STREAK := 15
const KILL_GOLD_MAX_STREAK := 5
## Üste doğuş koruması (plan 2.1): doğduktan sonra ilk kez üsten ÇIKINCA bu kadar ms oyuncu hasarına dokunulmaz.
const RESPAWN_PROTECT_MSEC := 3000
## Oyuncu savaşı sayılma süresi: bu kadar sn içinde oyuncuya vurdum / vuruldum = savaştayım (level / pazar / sandık menüsü savaş bitene kadar ertelenir, K10).
const COMBAT_SECONDS := 6.0
## Öldüren sayılma penceresi: son oyuncu isabeti bu kadar ms önceyse ölüm o oyuncunun öldürmesi sayılır.
const KILL_CREDIT_MSEC := 8000
## K5 bossunu öldüren takımın gücü (K8): süre ve saldırı hızı payı.
const BOSS_BUFF_SECONDS := 180.0
const BOSS_BUFF_ATTACK_SPEED := 0.2

static var last_combat_msec: int = -100000
static var respawn_protect_pending: bool = false
static var respawn_protect_until_msec: int = 0


static func death_seconds(tier: int) -> float:
	var env: String = preload("res://scripts/security/security_guard.gd").dev_env("PVP_DEATH") ## yalnız editör: denetim / test kısa ölüm süresi isteyebilir
	if env.is_valid_float():
		return float(env)
	return DEATH_BASE_SECONDS + DEATH_PER_TIER_SECONDS * float(clampi(tier, 1, 10))


static func kill_gold(tier: int, victim_streak: int) -> int:
	return KILL_GOLD_BASE + KILL_GOLD_PER_TIER * clampi(tier, 1, 10) + KILL_GOLD_PER_STREAK * clampi(victim_streak, 0, KILL_GOLD_MAX_STREAK)


static func note_combat(now_msec: int = -1) -> void:
	last_combat_msec = Time.get_ticks_msec() if now_msec < 0 else now_msec


static func in_combat(now_msec: int = -1) -> bool:
	if not match_running:
		return false
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	return float(now - last_combat_msec) / 1000.0 < COMBAT_SECONDS


## Doğuş koruması: üste doğunca başlar (üssün içindeyken zaten dokunulmaz), üsten çıkınca 3 sn daha sürer. Kurbanın makinesinde çalışır.
static func begin_respawn_protection() -> void:
	respawn_protect_pending = true
	respawn_protect_until_msec = 0


## victim_check kancası: true = şu an oyuncu hasarına dokunulmaz. `in_base`: oyuncu şu an kendi üssünde mi.
static func respawn_protected(in_base: bool, now_msec: int = -1) -> bool:
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	if respawn_protect_pending:
		if in_base:
			return true
		respawn_protect_pending = false
		respawn_protect_until_msec = now + RESPAWN_PROTECT_MSEC
	return now < respawn_protect_until_msec


## Eleme kuralı (saf, test edilir): bir takımın TÜM oyuncuları kalıcı ölüyse o takım kaybeder. Dönen: kazanan takım (0 / 1), kimse elenmediyse -1.
## `team_of`: peer -> takım; `peers`: odadaki oyuncular; `dead`: kalıcı ölü peer'ler (sözlük).
static func eliminated_winner(team_of: Dictionary, peers: Array, dead: Dictionary) -> int:
	var alive: Array[int] = [0, 0]
	var total: Array[int] = [0, 0]
	for p in peers:
		var t: int = clampi(int(team_of.get(int(p), 0)), 0, 1)
		total[t] += 1
		if not dead.has(int(p)):
			alive[t] += 1
	var lost: Array[int] = []
	for t in 2:
		if total[t] > 0 and alive[t] == 0:
			lost.append(t)
	if lost.size() == 1:
		return 1 - lost[0]
	if lost.size() == 2:
		return -2 ## ikisi de aynı anda elendi: berabere
	if total[0] == 0 and total[1] > 0:
		return 1
	if total[1] == 0 and total[0] > 0:
		return 0
	return -1

