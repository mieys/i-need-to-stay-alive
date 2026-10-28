extends RefCounted

## OTOMATİK KART SEÇİMİ (2026-10-19, kullanıcı: "oyuna otomatik seçme modu ekle ayarlara istediğimizde açabilelim. level atlama kartı veya
## sandık kartı v.b çıktığında otomatik olarak duruma en uygun kartı seçsin (oyuncular afkyken diğer arkadaşları beklemesin diye)").
## Ayar: UISound.auto_pick_cards (Ayarlar > GENEL > "Otomatik Kart Seçimi", display ConfigFile). Açıkken level atlama ekranı
## (level_up_screen.gd) ve sandık kartı (chest_menu.gd) kartlar göründükten DELAY sn sonra kendiliğinden seçer; o arada oyuncu
## elle seçebilir (elle seçim önce gelirse otomatik seçim hiçbir şey yapmaz). Seçim SADECE bu istemcide - ağa ayrı veri gitmez,
## normal tıklamayla aynı yoldan (card.pressed / AL) geçer.
##
## "Duruma en uygun": puan = kart kademesi (1-4) x statın değeri. Değer taban sıralaması (saldırı > savunma > yardımcı) + durum:
## can yarının altındaysa savunma kartları x1,5; sınırına ulaşmış stat (kaçınma, kritik oran, bekleme azaltma - player.is_stat_capped)
## neredeyse 0. Evrim kartlarında FİNAL evrim önce, yoksa ilk kart. Sandıkta AL (slot varsa), yoksa SAT.

const DELAY := 1.2
const LevelSpecialCardsScript := preload("res://scripts/level_special_cards.gd")

## Taban değer (kademe 1). Sayılar sezgisel: hasar/saldırı hızı en genel güç, Can hayatta tutar, Şans/XP uzun vadeli.
const BASE_VALUE := {
	"damage": 1.0, "fire_rate": 0.95, "max_health": 0.9, "shield_amount": 0.8, "cooldown_reduction": 0.8,
	"crit_chance": 0.75, "lifesteal": 0.7, "crit_damage": 0.6, "health_regen": 0.6, "dodge": 0.6,
	"speed": 0.5, "luck": 0.45, "exp_gain": 0.45, "shield_regen": 0.6, "heal_power": 0.5,
}
const PLAIN_COST_DISCOUNT := 0.85 ## düz kart bedeli ~%15 değerinde sayılır (taban sıralama değişmez, özel kartlara karşı tartı)
const DEFENSIVE := ["max_health", "health_regen", "lifesteal", "shield_amount", "shield_regen", "dodge"]
const CAPPED_STAT := {"dodge": "dodge_chance", "crit_chance": "crit_chance_bonus", "cooldown_reduction": "cooldown_reduction_percent"}
const LOW_HEALTH_RATIO := 0.5
const LOW_HEALTH_DEF_MULT := 1.5


static func enabled() -> bool:
	return UISound != null and bool(UISound.get("auto_pick_cards"))


static func upgrade_score(id: String, tier: int, player: Node) -> float:
	var v: float = float(BASE_VALUE.get(id, 0.5))
	if LevelSpecialCardsScript.is_special(id):
		v = LevelSpecialCardsScript.auto_value(id) ## takas / silah türü kartları (madde 367)
	elif LevelSpecialCardsScript.is_plain(id):
		v *= PLAIN_COST_DISCOUNT ## düz kartlar da bedel öder (madde 379): bedelli özel kartlarla adil kıyas için taban düşer
	if player != null and is_instance_valid(player):
		if CAPPED_STAT.has(id) and player.has_method("is_stat_capped") and bool(player.call("is_stat_capped", CAPPED_STAT[id])):
			v *= 0.05
		var mh: float = float(player.get("max_health")) if player.get("max_health") != null else 0.0
		var hp: float = float(player.get("health")) if player.get("health") != null else mh
		if mh > 0.0 and hp / mh < LOW_HEALTH_RATIO and DEFENSIVE.has(id):
			v *= LOW_HEALTH_DEF_MULT
	return v * float(maxi(tier, 1))


## Görünür + basılabilir kartlar arasında en yüksek puanlı kartın indeksi (-1 = yok). ids/tiers kartlarla aynı sırada.
static func best_upgrade_index(ids: Array, tiers: Array, pickable: Array, player: Node) -> int:
	var best: int = -1
	var best_s: float = -INF
	for i in range(mini(ids.size(), pickable.size())):
		if not bool(pickable[i]):
			continue
		var s: float = upgrade_score(str(ids[i]), int(tiers[i]) if i < tiers.size() else 1, player)
		if s > best_s:
			best_s = s
			best = i
	return best


## Evrim kartları: en yüksek kademe (FİNAL 4 > normal 3), eşitlikte ilk sıradaki.
static func best_tier_index(tiers: Array, pickable: Array) -> int:
	var best: int = -1
	for i in range(mini(tiers.size(), pickable.size())):
		if bool(pickable[i]) and (best < 0 or int(tiers[i]) > int(tiers[best])):
			best = i
	return best
